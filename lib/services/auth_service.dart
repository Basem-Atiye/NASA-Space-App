/// Local in-app accounts. Guests can play without signing in; signed-in
/// progress stays on this device. Teachers get built-in demo classes.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { offline, starting, signedOut, signedIn }

String studentPassword(String username, String pin) => 'ShStn-$pin-$username';
String cleanUsername(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
String cleanPin(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
String studentEmail(String username) => '${cleanUsername(username)}@students.openbounds.app';

/// Built-in demos (teachers open the dashboard with sample students + levels).
class DemoAccount {
  final String email;
  final String password;
  final String name;
  final String role; // teacher | student
  const DemoAccount(this.email, this.password, this.name, this.role);
}

const demoAccounts = <DemoAccount>[
  DemoAccount('teacher1@openbounds.app', 'TeacherDemo1!', 'Ms Nova', 'teacher'),
  DemoAccount('teacher2@openbounds.app', 'TeacherDemo2!', 'Mr Orion', 'teacher'),
  DemoAccount('player1@openbounds.app', 'PlayerDemo1!', 'Cadet One', 'student'),
];

const _legacyDemoEmails = <String>[
  'teacher1@shackleton.app',
  'teacher2@shackleton.app',
  'player1@shackleton.app',
];

class _LocalUser {
  final String id;
  final String email;
  final String password;
  final String displayName;
  final String roleIntent;
  final String? username;

  const _LocalUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.roleIntent,
    this.username,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'password': password,
        'display_name': displayName,
        'role_intent': roleIntent,
        if (username != null) 'username': username,
      };

  factory _LocalUser.fromJson(Map<String, dynamic> m) => _LocalUser(
        id: '${m['id']}',
        email: '${m['email']}'.toLowerCase(),
        password: '${m['password']}',
        displayName: '${m['display_name'] ?? m['name'] ?? 'Cadet'}',
        roleIntent: '${m['role_intent'] ?? 'student'}',
        username: m['username'] as String?,
      );
}

class AuthService extends ChangeNotifier {
  static const _sessionKey = 'local_auth_session_v1';
  static const _usersKey = 'local_auth_users_v1';

  AuthStatus status = AuthStatus.starting;
  bool busy = false;
  SharedPreferences? _prefs;
  _LocalUser? _user;
  final Map<String, _LocalUser> _users = {};

  bool get available => true;
  bool get signedIn => status == AuthStatus.signedIn && _user != null;

  String? get userId => _user?.id;
  String? get email => _user?.email;
  String? get firstName => _user?.displayName;
  String? get username =>
      _user?.username ??
      (_user?.email.endsWith('@students.openbounds.app') == true || _user?.email.endsWith('@students.shackleton.app') == true
          ? _user!.email.split('@').first
          : null);
  String get displayName {
    final n = firstName ?? username ?? email?.split('@').first;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Cadet';
  }

  String? get roleIntent => _user?.roleIntent;

  /// Cloud may still init Supabase separately; auth itself is local.
  Future<void> ensureSupabase() async {}

  Future<void> init(SharedPreferences? prefs) async {
    _prefs = prefs;
    status = AuthStatus.starting;
    notifyListeners();
    _loadUsers();
    _seedDemos();
    final sid = prefs?.getString(_sessionKey);
    if (sid != null && _users.containsKey(sid)) {
      _user = _users[sid];
      status = AuthStatus.signedIn;
    } else {
      status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (status == AuthStatus.signedIn) return;
    await init(_prefs);
  }

  Future<String?> token() async => signedIn ? 'local-${_user!.id}' : null;

  void _loadUsers() {
    _users.clear();
    final raw = _prefs?.getString(_usersKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
        final u = _LocalUser.fromJson(map);
        _users[u.email] = u;
      }
    } catch (e) {
      debugPrint('local auth load: $e');
    }
  }

  void _seedDemos() {
    for (final legacy in _legacyDemoEmails) {
      _users.remove(legacy);
    }
    for (final d in demoAccounts) {
      final email = d.email.toLowerCase();
      final old = _users[email];
      _users[email] = _LocalUser(
        id: old?.id ?? 'demo-${email.hashCode.abs()}',
        email: email,
        password: d.password,
        displayName: d.name,
        roleIntent: d.role,
        username: old?.username,
      );
    }
    _persistUsers();
  }

  Future<void> _persistUsers() async {
    await _prefs?.setString(_usersKey, jsonEncode([for (final u in _users.values) u.toJson()]));
  }

  Future<void> _setSession(_LocalUser u) async {
    _user = u;
    status = AuthStatus.signedIn;
    await _prefs?.setString(_sessionKey, u.email);
    notifyListeners();
  }

  Future<String?> signInEmail(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (!e.contains('@') || e.startsWith('@') || e.endsWith('@')) return 'Enter a valid email address.';
    if (password.length < 4) return 'Password must be at least 4 characters.';
    return _run(() async {
      final existing = _users[e];
      if (existing != null) {
        if (existing.password != password) throw Exception('wrong');
        await _setSession(existing);
        return;
      }
      final u = _LocalUser(
        id: 'u-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
        email: e,
        password: password,
        displayName: e.split('@').first,
        roleIntent: 'student',
      );
      _users[e] = u;
      await _persistUsers();
      await _setSession(u);
    }, wrong: 'That email and password do not match.');
  }

  Future<String?> signUp({
    required String displayName,
    required String email,
    required String password,
    required bool asTeacher,
  }) async {
    final name = displayName.trim();
    final e = email.trim().toLowerCase();
    if (name.length < 2) return 'Enter the name others will see.';
    if (!e.contains('@') || e.startsWith('@') || e.endsWith('@')) return 'Enter a valid email address.';
    if (password.length < 4) return 'Choose a password of at least 4 characters.';
    return _run(() async {
      if (_users.containsKey(e)) throw Exception('exists');
      final u = _LocalUser(
        id: 'u-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
        email: e,
        password: password,
        displayName: name,
        roleIntent: asTeacher ? 'teacher' : 'student',
      );
      _users[e] = u;
      await _persistUsers();
      await _setSession(u);
    });
  }

  Future<String?> signInStudent(String username, String pin) async {
    final u = cleanUsername(username), p = cleanPin(pin);
    if (u.length < 2) return 'Type the username from your card.';
    if (p.length != 4) return 'Your PIN has 4 numbers.';
    final email = studentEmail(u);
    final pass = studentPassword(u, p);
    if (_users.containsKey(email)) return signInEmail(email, pass);
    return _run(() async {
      final user = _LocalUser(
        id: 'stu-${u.hashCode.abs()}',
        email: email,
        password: pass,
        displayName: u.split('_').first,
        roleIntent: 'student',
        username: u,
      );
      _users[email] = user;
      await _persistUsers();
      await _setSession(user);
    });
  }

  Future<String?> signInTeacher(String email, String password) async {
    final err = await signInEmail(email, password);
    if (err != null) return err;
    final e = email.trim().toLowerCase();
    final u = _users[e];
    if (u == null) return err;
    if (u.roleIntent == 'teacher') return null;
    final demo = demoAccounts.where((d) => d.email == e && d.role == 'teacher');
    if (demo.isNotEmpty || e.contains('teacher')) {
      final upgraded = _LocalUser(
        id: u.id,
        email: u.email,
        password: u.password,
        displayName: demo.isNotEmpty ? demo.first.name : u.displayName,
        roleIntent: 'teacher',
        username: u.username,
      );
      _users[e] = upgraded;
      await _persistUsers();
      await _setSession(upgraded);
    }
    return null;
  }

  Future<String?> startTeacherSignUp(String name, String email, String password) =>
      signUp(displayName: name, email: email, password: password, asTeacher: true);

  bool get awaitingCode => false;
  Future<String?> verifyTeacherCode(String code) async => 'Sign in with your email and password.';
  Future<void> cancelSignUp() async {}

  Future<void> signOut() async {
    _user = null;
    await _prefs?.remove(_sessionKey);
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() body, {String? wrong}) async {
    busy = true;
    notifyListeners();
    try {
      await body();
      return null;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('wrong') && wrong != null) return wrong;
      if (msg.contains('exists')) return 'An account with this email already exists. Sign in instead.';
      debugPrint('local auth: $e');
      return 'Could not sign in. Try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void disposeAuth() {}
}
