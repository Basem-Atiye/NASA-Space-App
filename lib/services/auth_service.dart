/// Sign-in with Clerk (pure-Dart `clerk_auth` package, our own screens).
///
/// Three kinds of player:
///  * guests play offline, nothing leaves the phone;
///  * students sign in with the username and 4-digit PIN on the card their
///    teacher printed (no email, no password to remember);
///  * teachers sign up and in with email, password and a 6-digit email code.
library;

import 'dart:async';
import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

enum AuthStatus { offline, starting, signedOut, signedIn }

/// The password Clerk stores for a student account. The create-students Edge
/// Function derives it the same way (backend/supabase/functions/_shared/students.ts).
String studentPassword(String username, String pin) => 'ShStn-$pin-$username';

/// Normalises what a child types on the sign-in screen.
String cleanUsername(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
String cleanPin(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Keeps Clerk's client state in SharedPreferences (no file system access needed).
class PrefsPersistor implements Persistor {
  final SharedPreferences prefs;
  static const _key = 'clerk_sdk_cache';
  final Map<String, dynamic> _cache = {};
  Timer? _timer;

  PrefsPersistor(this.prefs);

  @override
  Future<void> initialize() async {
    try {
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) _cache.addAll(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_key);
    }
  }

  @override
  void terminate() => _timer?.cancel();

  @override
  FutureOr<T?> read<T>(String key) {
    final v = _cache[key];
    return v is T ? v : null;
  }

  @override
  FutureOr<void> write<T>(String key, T value) {
    _cache[key] = value;
    _save();
  }

  @override
  FutureOr<void> delete(String key) {
    if (_cache.remove(key) != null) _save();
  }

  void _save() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      try {
        prefs.setString(_key, jsonEncode(_cache));
      } catch (_) {}
    });
  }
}

class AuthService extends ChangeNotifier {
  Auth? _auth;
  AuthStatus status = Env.cloudConfigured ? AuthStatus.starting : AuthStatus.offline;

  /// Set while a teacher sign-up waits for the email code.
  bool awaitingCode = false;
  bool busy = false;
  SharedPreferences? _prefs;

  bool get available => status != AuthStatus.offline;
  bool get signedIn => status == AuthStatus.signedIn && userId != null;
  String? get userId => _safe(() => _auth?.user?.id);
  String? get firstName => _safe(() => _auth?.user?.firstName);
  String? get username => _safe(() => _auth?.user?.username);

  static T? _safe<T>(T? Function() f) {
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  Future<void> init(SharedPreferences? prefs) async {
    _prefs = prefs;
    if (!Env.cloudConfigured || prefs == null) {
      status = AuthStatus.offline;
      notifyListeners();
      return;
    }
    await _start();
  }

  /// Retry after starting without a connection.
  Future<void> retry() async {
    if (!Env.cloudConfigured || _prefs == null || status == AuthStatus.signedIn) return;
    await _start();
  }

  Future<void> _start() async {
    status = AuthStatus.starting;
    notifyListeners();
    try {
      final auth = _auth ?? Auth(config: AuthConfig(publishableKey: Env.clerkPublishableKey, persistor: PrefsPersistor(_prefs!)));
      if (_auth == null) {
        await auth.initialize().timeout(const Duration(seconds: 15));
        _auth = auth;
      } else {
        await auth.refreshClient().timeout(const Duration(seconds: 15));
      }
      status = auth.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
    } catch (e) {
      debugPrint('Clerk unavailable: $e');
      // stays usable as a guest; sign-in is retried from the welcome screen
      if (_auth == null) {
        status = AuthStatus.offline;
      } else {
        status = _safe(() => _auth!.isSignedIn) == true ? AuthStatus.signedIn : AuthStatus.signedOut;
      }
    }
    notifyListeners();
  }

  /// A fresh session token for Supabase and the Edge Functions (null for guests).
  Future<String?> token() async {
    final a = _auth;
    if (a == null || !signedIn) return null;
    try {
      return (await a.sessionToken()).jwt;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- students

  /// Returns null on success, or a message a child can understand.
  Future<String?> signInStudent(String username, String pin) async {
    final u = cleanUsername(username), p = cleanPin(pin);
    if (u.length < 4) return 'Type the username from your card.';
    if (p.length != 4) return 'Your PIN has 4 numbers.';
    return _run(() async {
      await _auth!.attemptSignIn(strategy: Strategy.password, identifier: u, password: studentPassword(u, p));
    }, wrong: 'That username and PIN do not match. Check your card or ask your teacher.');
  }

  // ---------------------------------------------------------------- teachers

  Future<String?> signInTeacher(String email, String password) async {
    final e = email.trim();
    if (!e.contains('@')) return 'Enter your school email address.';
    if (password.length < 8) return 'Your password has at least 8 characters.';
    return _run(() async {
      await _auth!.attemptSignIn(strategy: Strategy.password, identifier: e, password: password);
    }, wrong: 'That email and password do not match.');
  }

  /// Step 1 of a teacher sign-up: Clerk emails a 6-digit code.
  Future<String?> startTeacherSignUp(String firstName, String email, String password) async {
    final e = email.trim(), n = firstName.trim();
    if (n.length < 2) return 'Enter your name as students will see it.';
    if (!e.contains('@')) return 'Enter your school email address.';
    if (password.length < 8) return 'Choose a password of at least 8 characters.';
    final err = await _run(() async {
      await _auth!.attemptSignUp(
        strategy: Strategy.emailCode,
        firstName: n,
        emailAddress: e,
        password: password,
        passwordConfirmation: password,
        legalAccepted: true,
      );
    });
    if (err == null && !signedIn) awaitingCode = true;
    notifyListeners();
    return err;
  }

  /// Step 2: the code from the email.
  Future<String?> verifyTeacherCode(String code) async {
    final c = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (c.length != 6) return 'The code in the email has 6 numbers.';
    final err = await _run(() async {
      await _auth!.attemptSignUp(strategy: Strategy.emailCode, code: c);
    }, wrong: 'That code is not right. Check the latest email.');
    if (err == null && signedIn) awaitingCode = false;
    if (err == null && !signedIn) return 'Almost there: that code did not finish sign-up. Try again.';
    return err;
  }

  Future<void> cancelSignUp() async {
    awaitingCode = false;
    try {
      await _auth?.resetClient();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
    awaitingCode = false;
    status = _auth == null ? AuthStatus.offline : AuthStatus.signedOut;
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() body, {String? wrong}) async {
    if (_auth == null) {
      await retry();
      if (_auth == null) return 'No connection to the sign-in service. You can still play as a guest.';
    }
    busy = true;
    notifyListeners();
    try {
      await body().timeout(const Duration(seconds: 20));
      status = _auth!.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
      return null;
    } on ClerkError catch (e) {
      return _message(e, wrong);
    } on TimeoutException {
      return 'The connection is slow. Try again in a moment.';
    } catch (e) {
      debugPrint('sign-in error: $e');
      return 'Could not reach the sign-in service. Check the internet connection.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _message(ClerkError e, String? wrong) {
    final raw = (e.argument ?? e.message).replaceAll(RegExp(r'\s*\((ERROR RECEIVED FROM SERVER|EXTERNAL ERROR)\)'), '').trim();
    final low = raw.toLowerCase();
    if (wrong != null && (low.contains('password') || low.contains('identifier') || low.contains("couldn't find") || low.contains('incorrect') || low.contains('code'))) {
      return wrong;
    }
    if (low.contains('taken') || low.contains('exists')) return 'An account with this email already exists. Sign in instead.';
    if (low.contains('too many') || low.contains('rate')) return 'Too many tries. Wait a minute and try again.';
    if (e.code == ClerkErrorCode.passwordMatchError) return 'The passwords do not match.';
    return raw.isEmpty ? 'Something went wrong. Try again.' : raw;
  }
}
