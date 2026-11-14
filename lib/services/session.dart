/// The player's session: who is signed in, their class, and the offline sync.
/// Local AuthService + optional Cloud + Progress.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud.dart';
import '../cloud/link.dart';
import '../cloud/supabase_link.dart';
import '../cloud/models.dart';
import '../cloud/teacher_repo.dart';
import '../data/catalogue.dart';
import '../story/level_record.dart';
import '../teacher/demo_repo.dart';
import '../teacher/local_class_hub.dart';
import 'auth_service.dart';
import 'env.dart';
import 'progress.dart';
import 'sync_queue.dart';

class PrefsQueueStore implements QueueStore {
  final SharedPreferences? prefs;
  PrefsQueueStore(this.prefs);
  @override
  String? read() => prefs?.getString('sync_queue');
  @override
  Future<void> write(String v) async => prefs?.setString('sync_queue', v);
}

class Session extends ChangeNotifier {
  final Progress progress;
  final AuthService auth;
  late final Cloud cloud = Cloud(auth);
  late final SyncQueue queue = SyncQueue(PrefsQueueStore(progress.prefs));

  Profile? profile;
  List<Nudge> nudges = [];
  List<Assignment> assignments = [];
  String? lastError;
  bool busy = false;
  DemoTeacherRepo? _demo;
  Timer? _retry;

  // ---- live lesson (student side)
  Link? _live;
  String? _liveClass;
  StreamSubscription<LinkMessage>? _liveSub;

  /// The level the teacher started live (null when there is no live lesson).
  int? liveLevel;

  /// The teacher paused the whole class.
  bool livePaused = false;

  Session({required this.progress, AuthService? auth}) : auth = auth ?? AuthService() {
    this.auth.addListener(notifyListeners);
  }

  bool get cloudAvailable => Env.cloudConfigured;
  bool get signedIn => auth.signedIn;
  bool get isTeacher => signedIn && (profile?.isTeacher ?? progress.accountRole == 'teacher');
  bool get isStudent => signedIn && !isTeacher;
  String get name => profile?.displayName ?? progress.displayName ?? auth.displayName;
  /// Astronaut name shown in the story follows the student's username.
  String get characterName => auth.username ?? profile?.username ?? (signedIn ? name : 'Nova');
  int get pending => queue.length;

  /// Teacher dashboard always uses rich local demo classes (students + levels).
  TeacherRepo get teacherRepo => _demo ??= DemoTeacherRepo(teacherName: isTeacher ? name : null);

  Future<void> start() async {
    await auth.init(progress.prefs);
    await LocalClassHub.instance.init(progress.prefs);
    await cloud.init();
    if (signedIn) unawaited(refresh());
    _retry = Timer.periodic(const Duration(minutes: 3), (_) => flush());
    notifyListeners();
  }

  /// Push this player's progress into the on-device class roster (teacher demo).
  Future<void> _syncClassRoster() async {
    if (!signedIn || isTeacher) return;
    final id = auth.userId;
    if (id == null || progress.classId == null) return;
    await LocalClassHub.instance.upsertPlayer(
      studentId: id,
      name: name,
      username: auth.username ?? profile?.username,
      progress: progress,
    );
  }

  @override
  void dispose() {
    _retry?.cancel();
    _closeLive();
    auth.removeListener(notifyListeners);
    auth.disposeAuth();
    super.dispose();
  }

  /// Builds a local profile after sign-in. Cloud sync is optional.
  Future<void> refresh({Role? intent}) async {
    if (!signedIn) return;
    try {
      final role = intent ?? (auth.roleIntent == 'teacher' ? Role.teacher : Role.student);
      profile = Profile(
        id: auth.userId ?? 'local',
        role: role,
        displayName: auth.displayName,
        ageMode: progress.ageMode,
        username: auth.username,
      );
      await progress.setAccount(role: profile!.isTeacher ? 'teacher' : 'student', name: profile!.displayName);
      // Reset demo repo so teacher name / classes match the signed-in teacher.
      if (profile!.isTeacher) _demo = DemoTeacherRepo(teacherName: profile!.displayName);
      // Re-publish player progress into the local class roster (survives app restarts).
      if (!profile!.isTeacher) unawaited(_syncClassRoster());

      if (!profile!.isTeacher && cloud.ready) {
        try {
          final classes = await cloud.myClasses();
          if (classes.isNotEmpty) {
            final c = classes.first;
            await progress.setClass(id: c.id, name: c.name, teacher: c.teacherName, mode: c.ageMode, lock: c.lockRank);
          }
          final pulled = await cloud.pullProgress();
          await progress.mergeCloud(stars: pulled.stars, cloudFacts: pulled.facts, carry: pulled.carry);
          nudges = await cloud.unseenNudges();
          assignments = await cloud.myAssignments();
          unawaited(_connectLive());
        } catch (e) {
          debugPrint('optional cloud refresh: $e');
        }
      }
      lastError = null;
      await flush();
    } catch (e) {
      lastError = cloudMessage(e);
      debugPrint('session refresh: $e');
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- sign in

  Future<String?> signInEmail(String email, String password, {Role role = Role.student}) async {
    final err = await auth.signInEmail(email, password);
    if (err == null) await refresh(intent: role);
    return err ?? (signedIn && profile == null ? lastError : null);
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required bool asTeacher,
  }) async {
    final err = await auth.signUp(displayName: name, email: email, password: password, asTeacher: asTeacher);
    if (err == null) await refresh(intent: asTeacher ? Role.teacher : Role.student);
    return err ?? (signedIn && profile == null ? lastError : null);
  }

  Future<String?> signInStudent(String username, String pin) async {
    final err = await auth.signInStudent(username, pin);
    if (err == null) await refresh(intent: Role.student);
    return err ?? (signedIn && profile == null ? lastError : null);
  }

  Future<String?> signInTeacher(String email, String password) async {
    final err = await auth.signInTeacher(email, password);
    if (err == null) await refresh(intent: Role.teacher);
    return err;
  }

  Future<String?> startTeacherSignUp(String name, String email, String password) =>
      signUp(name: name, email: email, password: password, asTeacher: true);

  Future<String?> verifyTeacherCode(String code) async {
    final err = await auth.verifyTeacherCode(code);
    if (err == null) await refresh(intent: Role.teacher);
    return err;
  }

  Future<void> signOut() async {
    await flush();
    await _closeLive();
    await auth.signOut();
    profile = null;
    nudges = [];
    assignments = [];
    await progress.setAccount();
    await progress.setClass();
    notifyListeners();
  }

  /// A signed-in student joins a class with the teacher's code.
  Future<String?> joinClass(String code) async {
    if (!signedIn) return 'Sign in first.';
    if (isTeacher) return 'Switch to a player account to join a class.';
    busy = true;
    notifyListeners();
    try {
      final cleaned = code.trim().toUpperCase();
      // Local demo / teacher-made rooms on this device (shared with the teacher dashboard).
      final local = LocalClassHub.instance.findByCode(cleaned) ?? demoClassCatalog[cleaned];
      if (local != null) {
        await LocalClassHub.instance.registerClass(local);
        await progress.setClass(id: local.id, name: local.name, teacher: 'Demo teacher', mode: local.ageMode, lock: local.lockRank);
        await _syncClassRoster();
        notifyListeners();
        return null;
      }
      if (cloud.ready) {
        final c = await cloud.joinClass(cleaned);
        await progress.setClass(id: c.id, name: c.name, teacher: c.teacherName, mode: c.ageMode, lock: c.lockRank);
        await _syncClassRoster();
        unawaited(refresh());
        return null;
      }
      return 'Unknown class code. Try MOON7B, STAR4A or ART11P.';
    } catch (e) {
      return cloudMessage(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> dismissNudge(Nudge n) async {
    nudges = [for (final x in nudges) if (x.id != n.id) x];
    notifyListeners();
    try {
      await cloud.markNudgeSeen(n.id);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- live lesson

  Future<void> _connectLive() async {
    final cid = progress.classId;
    final me = auth.userId;
    if (cid == null || me == null || !cloud.ready || _liveClass == cid) return;
    await _closeLive();
    _liveClass = cid;
    final l = SupabaseLink(cloud, 'class:$cid', private: true, presenceKey: me);
    _live = l;
    _liveSub = l.messages.listen((m) {
      switch (m.event) {
        case 'start':
          liveLevel = (m.data['level'] as num?)?.toInt();
          livePaused = false;
        case 'pause':
          livePaused = true;
        case 'resume':
          livePaused = false;
        case 'end':
          liveLevel = null;
          livePaused = false;
      }
      notifyListeners();
    });
    final ok = await l.connect({'role': 'student', 'name': name, 'step': 0});
    if (!ok) await _closeLive();
  }

  Future<void> _closeLive() async {
    final l = _live;
    _live = null;
    _liveClass = null;
    await _liveSub?.cancel();
    _liveSub = null;
    liveLevel = null;
    livePaused = false;
    if (l != null) await l.close();
  }

  void liveStep(int step, int of) {
    final l = _live;
    if (l == null || liveLevel == null) return;
    l.send('step', {'name': name, 'step': step, 'of': of});
    l.updatePresence({'role': 'student', 'name': name, 'step': step});
  }

  void liveHelp(int step) {
    if (liveLevel == null) return;
    _live?.send('help', {'name': name, 'step': step});
  }

  void liveDone(int stars) {
    if (liveLevel == null) return;
    _live?.send('done', {'name': name, 'stars': stars});
  }

  // ---------------------------------------------------------------- recording

  bool get _records => signedIn && !isTeacher;

  /// A level finished: queue the attempt, its skill evidence, the carried
  /// numbers and any new facts. Sent now if online, later if not.
  Future<void> recordLevel(LevelRecord r) async {
    if (r.complete) liveDone(r.stars);
    if (!_records) return;
    await queue.add(SyncOp('attempt', {'attempt': r.attemptJson(), 'skills': r.skillsJson()}));
    if (r.complete) {
      await queue.add(SyncOp('campaign', {'campaign': r.campaign.name, 'carry': r.carry, 'current_level': (r.n + 1).clamp(1, 99)}, key: r.campaign.name));
    }
    await queue.add(SyncOp('facts', {'ids': progress.facts.where((f) => RegExp(r'^[a-z0-9_:.-]{1,64}$').hasMatch(f)).toList()}, key: 'all'));
    unawaited(_syncClassRoster());
    notifyListeners();
    unawaited(flush());
  }

  Future<void> recordAssessment(CampaignId c, String kind, int score, int max, List<Map<String, dynamic>> answers) async {
    await progress.recordAssessment(c, kind, (100 * score / max).round());
    if (!_records) return;
    await queue.add(SyncOp('assessment', {
      'client_id': newClientId(),
      'campaign': c.name,
      'kind': kind,
      'score': score,
      'max_score': max,
      'answers': answers,
      'taken_at': DateTime.now().toUtc().toIso8601String(),
    }));
    unawaited(_syncClassRoster());
    notifyListeners();
    unawaited(flush());
  }

  /// A Base Commander mission finished: queue it for the teacher dashboard.
  Future<void> recordBaseRun(Map<String, dynamic> run, {List<String> badges = const []}) async {
    if (!_records) return;
    await queue.add(SyncOp('base_run', {'client_id': newClientId(), ...run}));
    if (badges.isNotEmpty) await queue.add(SyncOp('badges', {'ids': badges}));
    notifyListeners();
    unawaited(flush());
  }

  /// A Supply Run finished.
  Future<void> recordSupplyRun(Map<String, dynamic> run) async {
    if (!_records) return;
    await queue.add(SyncOp('supply_run', {'client_id': newClientId(), ...run}));
    unawaited(flush());
  }

  Future<void> saveSettings() async {
    if (!_records) return;
    await queue.add(SyncOp('settings', {
      'sound': progress.sound,
      'music': progress.music,
      'voice': progress.voice,
      'reduced_motion': progress.reducedMotion,
      'text_speed': progress.textSpeed.clamp(0.5, 2.0),
    }, key: 'settings'));
    unawaited(flush());
  }

  Future<void> flush() async {
    if (!_records || !cloud.ready || queue.isEmpty) return;
    final sent = await queue.flush(cloud.send);
    if (sent > 0) notifyListeners();
  }

  /// For the account screen.
  String debugQueue() => const JsonEncoder.withIndent('  ').convert([for (final o in queue.pending) o.toJson()]);
}
