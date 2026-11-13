/// Supabase: profiles, classes, progress sync, teacher data and Realtime.
///
/// Auth uses Supabase email/password. RLS sees `auth.uid()` from the session.
/// The service role key never ships in the app.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalogue.dart';
import '../services/auth_service.dart';
import '../services/env.dart';
import '../services/sync_queue.dart';
import '../story/story_model.dart' show AgeMode;
import 'link.dart';
import 'supabase_link.dart';
import 'models.dart';
import 'teacher_repo.dart';

/// A message safe to show in the interface.
class CloudError implements Exception {
  final String message;
  const CloudError(this.message);
  @override
  String toString() => message;
}

String cloudMessage(Object e) {
  if (e is CloudError) return e.message;
  if (e is PostgrestException) {
    if (e.code == '42501') return 'You do not have access to that.';
    if (e.code == 'P0002' || e.code == '22023') return e.message;
    if (e.code == '28000') return 'Sign in first.';
    return 'The server said: ${e.message}';
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    return 'The server could not do that (${e.status}).';
  }
  if (e is TimeoutException) return 'The connection is slow. Try again.';
  return 'No connection. Check the internet and try again.';
}

class Cloud extends ChangeNotifier {
  final AuthService auth;
  SupabaseClient? _db;
  bool _starting = false;

  Cloud(this.auth);

  bool get ready => _db != null;
  bool get signedIn => ready && auth.signedIn;
  SupabaseClient? get client => _db;

  SupabaseClient get _c {
    final d = _db;
    if (d == null) throw const CloudError('Cloud is not set up in this build.');
    return d;
  }

  String get _uid {
    final id = auth.userId;
    if (id == null) throw const CloudError('Sign in first.');
    return id;
  }

  Future<void> init() async {
    if (_db != null || _starting || !Env.realtimeConfigured) return;
    _starting = true;
    try {
      // Auth is local; Supabase is only for optional cloud sync / catalogue.
      try {
        _db = Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabasePublishableKey,
          debug: false,
        );
        _db = Supabase.instance.client;
      }
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<T> _timed<T>(Future<T> f) => f.timeout(const Duration(seconds: 15));

  // ---------------------------------------------------------------- profile

  Future<Profile> ensureProfile({required Role role, String? displayName, AgeMode? ageMode}) async {
    final row = await _timed(_c.rpc('ensure_profile', params: {
      'p_role': role == Role.teacher ? 'teacher' : 'student',
      'p_display_name': displayName,
      'p_avatar': 'nova',
      'p_age_mode': (ageMode ?? AgeMode.explorer).name,
    }));
    final map = row is List ? (row.isEmpty ? null : row.first) : row;
    if (map is! Map) throw const CloudError('Could not load your profile.');
    return Profile.fromRow(Map<String, dynamic>.from(map));
  }

  Future<Profile?> myProfile() async {
    final row = await _timed(_c.from('profiles').select().eq('id', _uid).maybeSingle());
    return row == null ? null : Profile.fromRow(row);
  }

  Future<void> updateProfile({String? displayName, String? avatar, AgeMode? ageMode}) async {
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (avatar != null) 'avatar': avatar,
      if (ageMode != null) 'age_mode': ageMode.name,
    };
    if (patch.isEmpty) return;
    await _timed(_c.from('profiles').update(patch).eq('id', _uid));
  }

  // ---------------------------------------------------------------- student side

  Future<MyClass> joinClass(String code) async {
    final rows = await _timed(_c.rpc('join_class', params: {'code': code}));
    if (rows is List && rows.isNotEmpty) return MyClass.fromRow(Map<String, dynamic>.from(rows.first as Map));
    throw const CloudError('Unknown class code.');
  }

  Future<List<MyClass>> myClasses() async {
    final rows = await _timed(_c.rpc('my_classes'));
    return [for (final r in (rows as List? ?? const [])) MyClass.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> leaveClass(String classId) => _timed(_c.rpc('leave_class', params: {'cid': classId}));

  Future<List<Nudge>> unseenNudges() async {
    final rows = await _timed(_c.from('nudges').select('id, kind, level_id, created_at').eq('student_id', _uid).isFilter('seen_at', null).order('created_at').limit(10));
    return [for (final r in rows) Nudge.fromRow(r)];
  }

  Future<void> markNudgeSeen(String id) =>
      _timed(_c.from('nudges').update({'seen_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id));

  Future<List<Assignment>> myAssignments() async {
    final rows = await _timed(_c.from('assignments').select('id, level_id, student_id, due_at').order('created_at', ascending: false).limit(20));
    return [for (final r in rows) Assignment.fromRow(r)];
  }

  /// Best stars per level, facts and carried numbers, to restore progress on a new phone.
  Future<({Map<String, int> stars, Set<String> facts, Map<String, Map<String, dynamic>> carry})> pullProgress() async {
    final uid = _uid;
    final lp = await _timed(_c.from('level_progress').select('level_id, best_stars, completed_at').eq('user_id', uid));
    final fx = await _timed(_c.from('fact_unlocks').select('fact_id').eq('user_id', uid));
    final cs = await _timed(_c.from('campaign_state').select('campaign, carry, current_level').eq('user_id', uid));
    return (
      stars: {for (final r in lp) if (r['completed_at'] != null) r['level_id'] as String: (r['best_stars'] as num?)?.toInt() ?? 0},
      facts: {for (final r in fx) r['fact_id'] as String},
      carry: {
        for (final r in cs)
          r['campaign'] as String: {'carry': r['carry'], 'current_level': r['current_level']},
      },
    );
  }

  Future<SpaceWeather?> spaceWeather() async {
    if (!ready) return null;
    try {
      final res = await _timed(_c.functions.invoke('space-weather', method: HttpMethod.get));
      final d = res.data;
      return d is Map ? SpaceWeather.fromJson(Map<String, dynamic>.from(d)) : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- sync

  /// Sends one queued op. Throws [PermanentSyncError] for data the server will never take.
  Future<void> send(SyncOp op) async {
    final uid = _uid;
    try {
      switch (op.kind) {
        case 'attempt':
          await _timed(_c.rpc('submit_attempt', params: {'attempt': op.data['attempt'], 'skills': op.data['skills'] ?? const []}));
        case 'assessment':
          await _timed(_c.from('assessments').upsert({...op.data, 'user_id': uid}, onConflict: 'client_id', ignoreDuplicates: true));
        case 'facts':
          final ids = (op.data['ids'] as List? ?? const []).map((e) => '$e').toList();
          if (ids.isEmpty) return;
          await _timed(_c.from('fact_unlocks').upsert([for (final f in ids) {'user_id': uid, 'fact_id': f}], onConflict: 'user_id,fact_id', ignoreDuplicates: true));
        case 'campaign':
          await _timed(_c.from('campaign_state').upsert({...op.data, 'user_id': uid, 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'user_id,campaign'));
        case 'settings':
          await _timed(_c.from('settings').upsert({...op.data, 'user_id': uid}, onConflict: 'user_id'));
        case 'base_run':
          await _timed(_c.from('base_runs').upsert({...op.data, 'user_id': uid}, onConflict: 'client_id', ignoreDuplicates: true));
        case 'supply_run':
          await _timed(_c.from('supply_runs').upsert({...op.data, 'user_id': uid}, onConflict: 'client_id', ignoreDuplicates: true));
        case 'badges':
          final ids = (op.data['ids'] as List? ?? const []).map((e) => '$e').toList();
          if (ids.isEmpty) return;
          await _timed(_c.from('badges_earned').upsert([for (final b in ids) {'user_id': uid, 'badge_id': b}], onConflict: 'user_id,badge_id', ignoreDuplicates: true));
        default:
          throw PermanentSyncError('unknown op ${op.kind}');
      }
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      // data errors (22xxx), constraint violations (23xxx), not allowed (42501), raised (P0001)
      if (code.startsWith('22') || code.startsWith('23') || code == '42501' || code == 'P0001' || code == 'PGRST204') {
        throw PermanentSyncError('${e.code}: ${e.message}');
      }
      rethrow;
    }
  }

  RealtimeChannel channel(String name, {bool private = false, String presenceKey = ''}) =>
      _c.channel(name, opts: RealtimeChannelConfig(self: false, ack: false, private: private, key: presenceKey));

  Future<void> removeChannel(RealtimeChannel ch) async {
    try {
      await _c.removeChannel(ch);
    } catch (_) {}
  }

  TeacherRepo teacherRepo() => CloudTeacherRepo(this);
}

/// The teacher dashboard, backed by the Supabase functions in 0002_security.
class CloudTeacherRepo implements TeacherRepo {
  final Cloud cloud;
  CloudTeacherRepo(this.cloud);

  SupabaseClient get _c => cloud._c;
  String get _uid => cloud._uid;
  Future<T> _t<T>(Future<T> f) => f.timeout(const Duration(seconds: 15));

  List<Map<String, dynamic>> _rows(Object? v) => [for (final r in (v as List? ?? const [])) Map<String, dynamic>.from(r as Map)];

  @override
  bool get isDemo => false;

  @override
  Future<List<ClassInfo>> classes() async {
    final rows = await _t(_c.from('classes').select().eq('teacher_id', _uid).eq('archived', false).order('created_at'));
    return [for (final r in rows) ClassInfo.fromRow(r)];
  }

  @override
  Future<ClassInfo> createClass(String name, AgeMode mode, {bool lockRank = true}) async {
    final row = await _t(_c.from('classes').insert({'name': name.trim(), 'age_mode': mode.name, 'lock_rank': lockRank, 'teacher_id': _uid}).select().single());
    return ClassInfo.fromRow(row);
  }

  @override
  Future<void> updateClass(ClassInfo c) =>
      _t(_c.from('classes').update({'name': c.name, 'age_mode': c.ageMode.name, 'lock_rank': c.lockRank}).eq('id', c.id));

  @override
  Future<void> archiveClass(String id) => _t(_c.from('classes').update({'archived': true}).eq('id', id));

  @override
  Future<ClassOverview> overview(String cid) async {
    final rows = _rows(await _t(_c.rpc('class_overview', params: {'cid': cid})));
    return rows.isEmpty ? ClassOverview.empty : ClassOverview.fromRow(rows.first);
  }

  @override
  Future<List<StudentRow>> students(String cid) async =>
      [for (final r in _rows(await _t(_c.rpc('class_students', params: {'cid': cid})))) StudentRow.fromRow(r)];

  @override
  Future<List<SkillScore>> classSkills(String cid) async =>
      [for (final r in _rows(await _t(_c.rpc('class_skills', params: {'cid': cid})))) SkillScore.fromRow(r)];

  @override
  Future<List<LevelStat>> levels(String cid) async =>
      [for (final r in _rows(await _t(_c.rpc('class_levels', params: {'cid': cid})))) LevelStat.fromRow(r)];

  @override
  Future<List<SkillScore>> studentSkills(String sid, String cid) async =>
      [for (final r in _rows(await _t(_c.rpc('student_skills', params: {'sid': sid, 'cid': cid})))) SkillScore.fromRow(r)];

  @override
  Future<List<AttemptRow>> studentAttempts(String sid, {int limit = 20}) async {
    final rows = await _t(_c
        .from('attempts')
        .select('level_id, started_at, outcome, stars, mistakes, hints, duration_s, decisions')
        .eq('user_id', sid)
        .order('started_at', ascending: false)
        .limit(limit));
    return [for (final r in rows) AttemptRow.fromRow(r)];
  }

  Future<Map<String, dynamic>> _fn(String name, Map<String, dynamic> body) async {
    final res = await _t(_c.functions.invoke(name, body: body));
    final d = res.data;
    if (d is Map) {
      if (d['error'] is String) throw CloudError(d['error'] as String);
      return Map<String, dynamic>.from(d);
    }
    throw const CloudError('Unexpected answer from the server.');
  }

  @override
  Future<CreateStudentsResult> createStudents(String cid, List<String> names) async {
    final d = await _fn('create-students', {'action': 'create', 'class_id': cid, 'names': names});
    return CreateStudentsResult(
      cards: [for (final c in (d['cards'] as List? ?? const [])) StudentCard.fromJson(Map<String, dynamic>.from(c as Map))],
      failed: [for (final f in (d['failed'] as List? ?? const [])) '${(f as Map)['name']}: ${f['reason']}'],
    );
  }

  @override
  Future<StudentCard> resetPin(String cid, String sid) async {
    final d = await _fn('create-students', {'action': 'reset_pin', 'class_id': cid, 'student_id': sid});
    return StudentCard.fromJson(Map<String, dynamic>.from(d['card'] as Map));
  }

  @override
  Future<void> removeStudent(String cid, String sid) async {
    await _fn('create-students', {'action': 'remove', 'class_id': cid, 'student_id': sid});
  }

  @override
  Future<void> sendNudge(String cid, String sid, NudgeKind kind, {String? levelId}) =>
      _t(_c.from('nudges').insert({'class_id': cid, 'student_id': sid, 'kind': kind.db, 'level_id': levelId}));

  @override
  Future<List<Assignment>> assignments(String cid) async {
    final rows = await _t(_c.from('assignments').select().eq('class_id', cid).order('created_at', ascending: false));
    return [for (final r in rows) Assignment.fromRow(r)];
  }

  @override
  Future<void> assign(String cid, String levelId, {String? studentId, DateTime? dueAt}) => _t(_c.from('assignments').insert({
        'class_id': cid,
        'level_id': levelId,
        'student_id': studentId,
        'due_at': dueAt?.toUtc().toIso8601String(),
      }));

  @override
  Future<void> unassign(String id) => _t(_c.from('assignments').delete().eq('id', id));

  @override
  Future<List<ClassGoal>> goals(String cid) async {
    final rows = await _t(_c.from('class_goals').select().eq('class_id', cid).order('created_at'));
    return [for (final r in rows) ClassGoal.fromRow(r)];
  }

  @override
  Future<void> addGoal(String cid, {required String title, Skill? skill, String? levelId, required int target}) =>
      _t(_c.from('class_goals').insert({'class_id': cid, 'title': title, 'skill': skill?.db, 'level_id': levelId, 'target': target}));

  @override
  Future<void> removeGoal(String id) => _t(_c.from('class_goals').delete().eq('id', id));

  @override
  Future<List<BaseMissionStat>> baseSummary(String cid) async {
    final rows = await _t(_c.rpc('class_base_summary', params: {'cid': cid}));
    return [for (final r in rows as List) BaseMissionStat.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<String> reportCsv(String cid) async {
    final res = await _t(_c.functions.invoke('class-report', method: HttpMethod.get, queryParameters: {'class_id': cid}));
    final d = res.data;
    if (d is String) return d;
    throw const CloudError('Could not build the report.');
  }

  @override
  Link? liveLink(String cid) => SupabaseLink(cloud, 'class:$cid', private: true, presenceKey: _uid);
}
