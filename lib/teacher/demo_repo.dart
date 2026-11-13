/// A sample class for the teacher dashboard: lets teachers, parents and judges
/// explore every screen without accounts or a network. Deterministic, so the
/// same numbers show up in a demo every time. Edits (new classes, nudges,
/// assignments) live in memory for the session.
library;

import 'dart:async';
import 'dart:math' as math;

import '../cloud/link.dart';
import '../cloud/models.dart';
import '../cloud/teacher_repo.dart';
import '../data/catalogue.dart';
import '../story/campaign.dart';
import '../story/story_model.dart' show AgeMode;
import 'local_class_hub.dart';

class _DemoStudent {
  final StudentRow row;
  final Map<Skill, int> skills;
  final List<AttemptRow> attempts;
  _DemoStudent(this.row, this.skills, this.attempts);
}

class DemoTeacherRepo implements TeacherRepo {
  final _rnd = math.Random(2026);
  final List<ClassInfo> _classes = [];
  final Map<String, List<_DemoStudent>> _students = {};
  final Map<String, List<Assignment>> _assign = {};
  final Map<String, List<ClassGoal>> _goals = {};
  final LocalHub hub = LocalHub(delay: const Duration(milliseconds: 120));
  final String? teacherName;
  int _ids = 0;

  static const _names = [
    'Rana', 'Omar', 'Lina', 'Karim', 'Maya', 'Jad', 'Sara', 'Ali', 'Nour', 'Hadi', 'Yara', 'Elie',
    'Tala', 'Rami', 'Zeina', 'Fadi', 'Leila', 'Sami', 'Mira', 'Joe', 'Aya', 'Ziad', 'Dana', 'Nadim',
  ];

  DemoTeacherRepo({this.teacherName}) {
    final now = DateTime.now();
    final nova = (teacherName ?? '').toLowerCase().contains('orion');
    // Two ready-made teacher demos: Ms Nova (explorer-heavy) and Mr Orion (cadet + engineer).
    if (nova) {
      _classes.add(ClassInfo(id: 'demo-orion-a', name: 'Grade 4 Stars', joinCode: 'STAR4A', ageMode: AgeMode.cadet, createdAt: now.subtract(const Duration(days: 9))));
      _classes.add(ClassInfo(id: 'demo-orion-b', name: 'Physics 11', joinCode: 'ART11P', ageMode: AgeMode.engineer, createdAt: now.subtract(const Duration(days: 30))));
      _students['demo-orion-a'] = _makeClass(_classes[0], 18);
      _students['demo-orion-b'] = _makeClass(_classes[1], 16);
      _assign['demo-orion-a'] = [Assignment(id: 'a-orion-1', levelId: 'cadet-03', dueAt: now.add(const Duration(days: 2)))];
      _assign['demo-orion-b'] = [Assignment(id: 'a-orion-2', levelId: 'engineer-04', dueAt: now.add(const Duration(days: 5)))];
      _goals['demo-orion-a'] = [const ClassGoal(id: 'g-orion-1', title: 'Cadets clear Day 4', skill: Skill.procedure, target: 65)];
      _goals['demo-orion-b'] = [const ClassGoal(id: 'g-orion-2', title: 'Root cause above 70', skill: Skill.rootCause, target: 70)];
    } else {
      _classes.add(ClassInfo(id: 'demo-explorer', name: 'Grade 7 Blue', joinCode: 'MOON7B', ageMode: AgeMode.explorer, createdAt: now.subtract(const Duration(days: 21))));
      _classes.add(ClassInfo(id: 'demo-cadet', name: 'Grade 4 Stars', joinCode: 'STAR4A', ageMode: AgeMode.cadet, createdAt: now.subtract(const Duration(days: 9))));
      _classes.add(ClassInfo(id: 'demo-engineer', name: 'Physics 11', joinCode: 'ART11P', ageMode: AgeMode.engineer, createdAt: now.subtract(const Duration(days: 30))));
      for (final c in _classes) {
        _students[c.id] = _makeClass(c, c.id == 'demo-explorer' ? 24 : (c.id == 'demo-cadet' ? 18 : 16));
      }
      _assign['demo-explorer'] = [Assignment(id: 'a1', levelId: 'explorer-05', dueAt: now.add(const Duration(days: 3)))];
      _assign['demo-explorer']!.add(Assignment(id: 'a2', levelId: 'explorer-08', dueAt: now.add(const Duration(days: 7))));
      _goals['demo-explorer'] = [const ClassGoal(id: 'g1', title: 'Everyone reaches Systems 70', skill: Skill.systems, target: 70)];
      _goals['demo-cadet'] = [const ClassGoal(id: 'g2', title: 'Teamwork above 60', skill: Skill.teamwork, target: 60)];
    }
  }

  List<_DemoStudent> _makeClass(ClassInfo c, int count) {
    final camp = campaignFor(c.ageMode);
    final now = DateTime.now();
    final list = <_DemoStudent>[];
    for (var i = 0; i < count; i++) {
      final name = _names[(i * 7 + c.name.length) % _names.length];
      final ability = 0.35 + _rnd.nextDouble() * 0.6;
      final done = (ability * camp.length * 0.85).round().clamp(0, camp.length);
      final stuck = i % 7 == 3;
      final inactive = i % 11 == 5;
      final notStarted = i == count - 1;
      final levelsDone = notStarted ? 0 : (stuck ? math.max(1, done ~/ 2) : done);
      final pre = notStarted ? null : (25 + _rnd.nextInt(30));
      final post = levelsDone >= camp.length * 0.6 && pre != null ? math.min(100, pre + 15 + (ability * 40).round()) : null;
      final skills = {
        for (final k in Skill.values) k: notStarted ? 0 : ((ability * 70 + _rnd.nextInt(30)) - (k == Skill.rootCause ? 12 : 0)).round().clamp(10, 100),
      };
      final last = notStarted ? null : now.subtract(Duration(hours: inactive ? 24 * 9 : _rnd.nextInt(60)));
      final attempts = <AttemptRow>[];
      final base = last ?? now;
      AttemptRow at(int n, int ago, bool ok) => AttemptRow(
            levelId: camp.levelIdFor(n.clamp(1, camp.length)),
            startedAt: base.subtract(Duration(hours: ago * 20)),
            outcome: ok ? 'complete' : 'failed',
            stars: ok ? 1 + (ability * 2.2).floor().clamp(0, 2) : 0,
            mistakes: (3 * (1 - ability)).round() + (ok ? 0 : 2),
            hints: ok ? (ability < 0.5 ? 1 : 0) : 3,
            durationS: 300 + _rnd.nextInt(600),
            decisions: [
              Decision('triage', ability > 0.55 ? 'o2_first' : 'comms_first', ability > 0.55),
              const Decision('fix', 'sealant', true),
              Decision('power', ability > 0.7 ? 'life_support' : 'lights', ability > 0.7),
            ],
          );
      if (stuck) {
        for (var k = 0; k < 3; k++) {
          attempts.add(at(levelsDone + 1, k, false));
        }
      }
      for (var n = levelsDone; n >= 1 && attempts.length < 12; n--) {
        attempts.add(at(n, attempts.length + 1, true));
      }
      final reason = notStarted
          ? HelpReason.notStarted
          : stuck
              ? HelpReason.stuck
              : inactive
                  ? HelpReason.inactive
                  : (ability < 0.42 ? HelpReason.manyHints : null);
      list.add(_DemoStudent(
        StudentRow(
          id: 'demo-${c.id}-$i',
          name: name,
          username: '${name.toLowerCase()}_${(1000 + i * 37).toRadixString(36)}',
          levelsDone: levelsDone,
          stars: levelsDone * (1 + (ability * 2).round()).clamp(1, 3),
          currentLevel: math.min(camp.length, levelsDone + 1),
          lastActive: last,
          attemptsWeek: inactive || notStarted ? 0 : 2 + _rnd.nextInt(5),
          hintsWeek: stuck ? 7 : (ability < 0.42 ? 6 : _rnd.nextInt(3)),
          failsRecent: stuck ? 3 : 0,
          pre: pre,
          post: post,
          needsHelp: reason != null && reason != HelpReason.notStarted ? true : notStarted,
          reason: reason,
          stuckLevel: stuck ? camp.levelIdFor(math.min(camp.length, levelsDone + 1)) : null,
        ),
        skills,
        attempts,
      ));
    }
    return list;
  }

  Future<T> _later<T>(T v) => Future.delayed(const Duration(milliseconds: 220), () => v);

  @override
  bool get isDemo => true;

  @override
  Future<List<ClassInfo>> classes() => _later(List.of(_classes));

  @override
  Future<ClassInfo> createClass(String name, AgeMode mode, {bool lockRank = true}) async {
    final code = String.fromCharCodes([for (var i = 0; i < 6; i++) 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(_rnd.nextInt(32))]);
    final c = ClassInfo(id: 'demo-new-${_ids++}', name: name, joinCode: code, ageMode: mode, lockRank: lockRank, createdAt: DateTime.now());
    _classes.add(c);
    _students[c.id] = [];
    await LocalClassHub.instance.registerClass(c);
    return _later(c);
  }

  @override
  Future<void> updateClass(ClassInfo c) async {
    final i = _classes.indexWhere((x) => x.id == c.id);
    if (i >= 0) _classes[i] = c;
    // students follow the teacher's age level, like the database trigger
    if (i >= 0) _students[c.id] = _makeClass(c, _students[c.id]?.length ?? 0);
  }

  @override
  Future<void> archiveClass(String id) async => _classes.removeWhere((c) => c.id == id);

  ClassInfo _class(String cid) => _classes.firstWhere((c) => c.id == cid, orElse: () => _classes.first);

  /// Sample students plus any real players who joined this class on this device.
  List<_DemoStudent> _of(String cid) {
    final demo = _students[cid] ?? const <_DemoStudent>[];
    ClassInfo? info;
    for (final c in _classes) {
      if (c.id == cid) {
        info = c;
        break;
      }
    }
    final live = LocalClassHub.instance.liveStudents(classId: cid, joinCode: info?.joinCode);
    if (live.isEmpty) return demo;
    final liveIds = {for (final e in live) e.studentId};
    final merged = <_DemoStudent>[
      for (final e in live)
        _DemoStudent(e.toRow(), {for (final k in Skill.values) k: e.skills[k] ?? 0}, const []),
      for (final d in demo)
        if (!liveIds.contains(d.row.id)) d,
    ];
    return merged;
  }

  @override
  Future<ClassOverview> overview(String cid) {
    final s = _of(cid);
    final camp = campaignFor(_class(cid).ageMode);
    final today = DateTime.now().subtract(const Duration(hours: 18));
    final week = DateTime.now().subtract(const Duration(days: 7));
    final pre = [for (final x in s) if (x.row.pre != null) x.row.pre!];
    final post = [for (final x in s) if (x.row.post != null) x.row.post!];
    final gains = [for (final x in s) if (x.row.gain != null) x.row.gain!];
    final avgSkill = {for (final k in Skill.values) k: s.isEmpty ? 0.0 : s.map((x) => x.skills[k] ?? 0).reduce((a, b) => a + b) / s.length};
    final sorted = avgSkill.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    double avg(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
    return _later(ClassOverview(
      students: s.length,
      activeToday: s.where((x) => x.row.lastActive != null && x.row.lastActive!.isAfter(today)).length,
      activeWeek: s.where((x) => x.row.lastActive != null && x.row.lastActive!.isAfter(week)).length,
      levelsTotal: camp.length,
      avgLevelsDone: s.isEmpty ? 0 : s.map((x) => x.row.levelsDone).reduce((a, b) => a + b) / s.length,
      avgStars: s.isEmpty ? null : 2.3,
      preAvg: pre.isEmpty ? null : avg(pre).round(),
      postAvg: post.isEmpty ? null : avg(post).round(),
      gainPoints: gains.isEmpty ? null : avg(gains).round(),
      weakestSkill: s.isEmpty ? null : sorted.first.key,
      strongestSkill: s.isEmpty ? null : sorted.last.key,
      needsHelp: s.where((x) => x.row.needsHelp).length,
    ));
  }

  @override
  Future<List<StudentRow>> students(String cid) => _later([for (final x in _of(cid)) x.row]..sort((a, b) => a.needsHelp == b.needsHelp ? a.name.compareTo(b.name) : (a.needsHelp ? -1 : 1)));

  @override
  Future<List<SkillScore>> classSkills(String cid) {
    final s = _of(cid);
    return _later([
      for (final k in Skill.values)
        SkillScore(k, s.isEmpty ? 0 : (s.map((x) => x.skills[k] ?? 0).reduce((a, b) => a + b) / s.length).round(), evidence: s.length * 9),
    ]);
  }

  @override
  Future<List<LevelStat>> levels(String cid) {
    final s = _of(cid);
    final camp = campaignFor(_class(cid).ageMode);
    return _later([
      for (var n = 1; n <= camp.length; n++)
        LevelStat(
          levelId: camp.levelIdFor(n),
          number: n,
          title: camp.task(n).title,
          finished: s.where((x) => x.row.levelsDone >= n).length,
          playing: s.where((x) => x.row.levelsDone == n - 1 && x.row.lastActive != null).length,
          avgStars: s.where((x) => x.row.levelsDone >= n).isEmpty ? null : 2.0 + (n % 3) * 0.3,
          avgMistakes: 1.0 + (n % 4) * 0.6,
          avgHints: n == 5 || n == 9 ? 1.6 : 0.4,
        ),
    ]);
  }

  @override
  Future<List<SkillScore>> studentSkills(String sid, String cid) {
    final s = _of(cid);
    final me = s.firstWhere((x) => x.row.id == sid, orElse: () => s.first);
    return _later([
      for (final k in Skill.values)
        SkillScore(k, me.skills[k] ?? 0, classAvg: s.isEmpty ? 0 : (s.map((x) => x.skills[k] ?? 0).reduce((a, b) => a + b) / s.length).round(), evidence: 12),
    ]);
  }

  @override
  Future<List<AttemptRow>> studentAttempts(String sid, {int limit = 20}) {
    for (final l in _students.values) {
      for (final x in l) {
        if (x.row.id == sid) return _later(x.attempts.take(limit).toList());
      }
    }
    return _later(const []);
  }

  @override
  Future<CreateStudentsResult> createStudents(String cid, List<String> names) {
    final c = _class(cid);
    final cards = <StudentCard>[];
    for (final raw in names) {
      final n = raw.trim();
      if (n.length < 2) continue;
      final user = '${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_${(100000 + _rnd.nextInt(899999)).toRadixString(36)}';
      final pin = (_rnd.nextInt(9000) + 1000).toString();
      final id = 'demo-$cid-new-${_ids++}';
      cards.add(StudentCard(name: n, username: user, pin: pin, studentId: id));
      _students.putIfAbsent(cid, () => []).add(_DemoStudent(StudentRow(id: id, name: n, username: user, reason: HelpReason.notStarted, needsHelp: true), {for (final k in Skill.values) k: 0}, const []));
    }
    _class(c.id);
    return _later(CreateStudentsResult(cards: cards));
  }

  @override
  Future<StudentCard> resetPin(String cid, String sid) {
    final x = _of(cid).firstWhere((s) => s.row.id == sid);
    return _later(StudentCard(name: x.row.name, username: x.row.username ?? 'student', pin: (_rnd.nextInt(9000) + 1000).toString(), studentId: sid));
  }

  @override
  Future<void> removeStudent(String cid, String sid) async => _students[cid]?.removeWhere((x) => x.row.id == sid);

  @override
  Future<void> sendNudge(String cid, String sid, NudgeKind kind, {String? levelId}) => _later(null);

  @override
  Future<List<Assignment>> assignments(String cid) => _later(List.of(_assign[cid] ?? const []));

  @override
  Future<void> assign(String cid, String levelId, {String? studentId, DateTime? dueAt}) async {
    _assign.putIfAbsent(cid, () => []).insert(0, Assignment(id: 'a${_ids++}', levelId: levelId, studentId: studentId, dueAt: dueAt));
  }

  @override
  Future<void> unassign(String id) async {
    for (final l in _assign.values) {
      l.removeWhere((a) => a.id == id);
    }
  }

  @override
  Future<List<ClassGoal>> goals(String cid) => _later(List.of(_goals[cid] ?? const []));

  @override
  Future<void> addGoal(String cid, {required String title, Skill? skill, String? levelId, required int target}) async {
    _goals.putIfAbsent(cid, () => []).add(ClassGoal(id: 'g${_ids++}', title: title, skill: skill, levelId: levelId, target: target));
  }

  @override
  Future<void> removeGoal(String id) async {
    for (final l in _goals.values) {
      l.removeWhere((g) => g.id == id);
    }
  }

  @override
  Future<List<BaseMissionStat>> baseSummary(String cid) async {
    // a believable class: most finish the first missions; the solar storm
    // (mission 4) is where many lose power
    final out = <BaseMissionStat>[];
    final ss = await students(cid);
    for (var k = 0; k < ss.length; k++) {
      final st = ss[k];
      final reached = 5 - (k % 4);
      for (var m = 1; m <= reached; m++) {
        final lostHere = m == 4 && k % 3 != 0;
        out.add(BaseMissionStat(
          studentId: st.id,
          name: st.name,
          mission: m,
          bestStars: lostHere ? 0 : 1 + ((k + m) % 3),
          tries: lostHere ? 2 + k % 2 : 1 + (m == 2 ? k % 2 : 0),
          wins: lostHere ? 0 : 1,
          topCause: lostHere ? (k.isEven ? 'power' : 'crew') : (m == 2 && k % 2 == 1 ? 'water' : null),
        ));
      }
    }
    return out;
  }

  @override
  Future<String> reportCsv(String cid) async {
    final rows = [for (final x in _of(cid)) x];
    final b = StringBuffer('Name,Username,Levels done,Stars,Before %,After %,Gain,${Skill.values.map((k) => 'Skill: ${k.title}').join(',')},Needs help\r\n');
    for (final x in rows) {
      final r = x.row;
      b.write('"${r.name}","${r.username ?? ''}",${r.levelsDone},${r.stars},${r.pre ?? ''},${r.post ?? ''},${r.gain ?? ''},${Skill.values.map((k) => x.skills[k] ?? '').join(',')},${r.needsHelp ? 'yes' : 'no'}\r\n');
    }
    return b.toString();
  }

  /// The demo live lesson: simulated students move through the level.
  @override
  Link? liveLink(String cid) => _DemoLiveLink(hub, cid, _of(cid).map((s) => s.row).toList(), campaignFor(_class(cid).ageMode));
}

/// Pretends to be a class playing a level together: students join, then move
/// from step to step, some get stuck. Sends the same events a real class would.
class _DemoLiveLink implements Link {
  final LocalHub hub;
  final String cid;
  final List<StudentRow> students;
  final Campaign camp;
  late final LocalLink _me = hub.link('teacher');
  final List<LocalLink> _kids = [];
  final List<Timer> _timers = [];
  final _rnd = math.Random(7);

  _DemoLiveLink(this.hub, this.cid, this.students, this.camp);

  @override
  String get selfId => _me.selfId;
  @override
  LinkState get state => _me.state;
  @override
  Stream<LinkState> get states => _me.states;
  @override
  Stream<LinkMessage> get messages => _me.messages;
  @override
  Stream<List<Map<String, dynamic>>> get peers => _me.peers;
  @override
  List<Map<String, dynamic>> get currentPeers => _me.currentPeers;

  int _level = 1;
  bool _paused = false;

  @override
  Future<bool> connect(Map<String, dynamic> me) async {
    await _me.connect(me);
    _me.messages.listen((m) {
      if (m.event == 'start') _level = (m.data['level'] as num?)?.toInt() ?? 1;
      if (m.event == 'pause') _paused = true;
      if (m.event == 'resume') _paused = false;
    });
    final steps = camp.task(_level).steps.length;
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      if (s.lastActive == null) continue;
      _timers.add(Timer(Duration(milliseconds: 400 + i * 260), () async {
        final k = hub.link(s.id);
        _kids.add(k);
        await k.connect({'name': s.name, 'role': 'student', 'step': 0});
        var step = 0;
        final slow = s.needsHelp;
        _timers.add(Timer.periodic(Duration(milliseconds: 2200 + _rnd.nextInt(2600)), (t) {
          if (_paused) return;
          if (step >= steps) {
            t.cancel();
            k.send('done', {'name': s.name, 'stars': slow ? 1 : 2 + _rnd.nextInt(2)});
            return;
          }
          if (slow && step == 2 && _rnd.nextDouble() < 0.7) {
            k.send('help', {'name': s.name, 'step': step});
            return;
          }
          step++;
          k.updatePresence({'name': s.name, 'role': 'student', 'step': step, 'mistakes': slow ? 2 : _rnd.nextInt(2)});
          k.send('step', {'name': s.name, 'step': step, 'of': steps});
        }));
      }));
    }
    return true;
  }

  @override
  Future<void> updatePresence(Map<String, dynamic> me) => _me.updatePresence(me);

  @override
  Future<void> send(String event, Map<String, dynamic> data) => _me.send(event, data);

  @override
  Future<void> close() async {
    for (final t in _timers) {
      t.cancel();
    }
    for (final k in _kids) {
      await k.close();
    }
    await _me.close();
  }
}
