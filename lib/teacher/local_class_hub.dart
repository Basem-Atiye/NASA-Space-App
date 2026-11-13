/// Shared on-device class roster: when a player joins a demo (or teacher-made)
/// class code, they are enrolled here so the teacher dashboard shows them
/// next to the sample students. Persists across sign-out / sign-in on this device.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/models.dart';
import '../data/catalogue.dart';
import '../services/progress.dart';
import '../story/campaign.dart';
import '../story/story_model.dart' show AgeMode, AgeModeInfo;

class LocalEnrollment {
  final String studentId;
  final String classId;
  final String joinCode;
  final String name;
  final String? username;
  final int levelsDone;
  final int stars;
  final int currentLevel;
  final DateTime lastActive;
  final Map<Skill, int> skills;
  final int? pre;
  final int? post;
  final int attemptsWeek;
  final int hintsWeek;
  final int failsRecent;

  const LocalEnrollment({
    required this.studentId,
    required this.classId,
    required this.joinCode,
    required this.name,
    this.username,
    this.levelsDone = 0,
    this.stars = 0,
    this.currentLevel = 1,
    required this.lastActive,
    this.skills = const {},
    this.pre,
    this.post,
    this.attemptsWeek = 0,
    this.hintsWeek = 0,
    this.failsRecent = 0,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'class_id': classId,
        'join_code': joinCode,
        'name': name,
        if (username != null) 'username': username,
        'levels_done': levelsDone,
        'stars': stars,
        'current_level': currentLevel,
        'last_active': lastActive.toIso8601String(),
        'skills': {for (final e in skills.entries) e.key.db: e.value},
        if (pre != null) 'pre': pre,
        if (post != null) 'post': post,
        'attempts_week': attemptsWeek,
        'hints_week': hintsWeek,
        'fails_recent': failsRecent,
      };

  factory LocalEnrollment.fromJson(Map<String, dynamic> m) => LocalEnrollment(
        studentId: '${m['student_id']}',
        classId: '${m['class_id']}',
        joinCode: '${m['join_code']}'.toUpperCase(),
        name: '${m['name']}',
        username: m['username'] as String?,
        levelsDone: (m['levels_done'] as num?)?.toInt() ?? 0,
        stars: (m['stars'] as num?)?.toInt() ?? 0,
        currentLevel: (m['current_level'] as num?)?.toInt() ?? 1,
        lastActive: DateTime.tryParse('${m['last_active']}') ?? DateTime.now(),
        skills: {
          for (final e in ((m['skills'] as Map?) ?? const {}).entries)
            if (SkillInfo.parse('${e.key}') != null) SkillInfo.parse('${e.key}')!: (e.value as num).toInt(),
        },
        pre: (m['pre'] as num?)?.toInt(),
        post: (m['post'] as num?)?.toInt(),
        attemptsWeek: (m['attempts_week'] as num?)?.toInt() ?? 0,
        hintsWeek: (m['hints_week'] as num?)?.toInt() ?? 0,
        failsRecent: (m['fails_recent'] as num?)?.toInt() ?? 0,
      );

  StudentRow toRow() {
    final notStarted = levelsDone <= 0 && stars <= 0;
    return StudentRow(
      id: studentId,
      name: name,
      username: username,
      levelsDone: levelsDone,
      stars: stars,
      currentLevel: currentLevel,
      lastActive: lastActive,
      attemptsWeek: attemptsWeek,
      hintsWeek: hintsWeek,
      failsRecent: failsRecent,
      pre: pre,
      post: post,
      needsHelp: notStarted || failsRecent >= 2,
      reason: notStarted
          ? HelpReason.notStarted
          : (failsRecent >= 2 ? HelpReason.stuck : (hintsWeek >= 5 ? HelpReason.manyHints : null)),
    );
  }
}

/// Built-in demo rooms every teacher and player share on this device.
const demoClassCatalog = <String, ClassInfo>{
  'MOON7B': ClassInfo(id: 'demo-explorer', name: 'Grade 7 Blue', joinCode: 'MOON7B', ageMode: AgeMode.explorer, lockRank: true),
  'STAR4A': ClassInfo(id: 'demo-cadet', name: 'Grade 4 Stars', joinCode: 'STAR4A', ageMode: AgeMode.cadet, lockRank: true),
  'ART11P': ClassInfo(id: 'demo-engineer', name: 'Physics 11', joinCode: 'ART11P', ageMode: AgeMode.engineer, lockRank: true),
};

class LocalClassHub {
  LocalClassHub._();
  static final LocalClassHub instance = LocalClassHub._();

  static const _classesKey = 'local_class_hub_classes_v1';
  static const _rosterKey = 'local_class_hub_roster_v1';

  SharedPreferences? _prefs;
  final Map<String, ClassInfo> _classesByCode = {};
  final List<LocalEnrollment> _roster = [];

  Future<void> init(SharedPreferences? prefs) async {
    _prefs = prefs;
    _classesByCode
      ..clear()
      ..addAll(demoClassCatalog);
    _roster.clear();
    final rawClasses = prefs?.getString(_classesKey);
    if (rawClasses != null) {
      try {
        for (final m in (jsonDecode(rawClasses) as List)) {
          final c = _classFromJson(Map<String, dynamic>.from(m as Map));
          _classesByCode[c.joinCode.toUpperCase()] = c;
        }
      } catch (_) {}
    }
    final rawRoster = prefs?.getString(_rosterKey);
    if (rawRoster != null) {
      try {
        for (final m in (jsonDecode(rawRoster) as List)) {
          _roster.add(LocalEnrollment.fromJson(Map<String, dynamic>.from(m as Map)));
        }
      } catch (_) {}
    }
  }

  ClassInfo? findByCode(String code) => _classesByCode[code.trim().toUpperCase()];

  Future<void> registerClass(ClassInfo c) async {
    _classesByCode[c.joinCode.toUpperCase()] = c;
    await _saveClasses();
  }

  /// Enroll / refresh a signed-in player from their live [Progress].
  Future<void> upsertPlayer({
    required String studentId,
    required String name,
    String? username,
    required Progress progress,
  }) async {
    final cid = progress.classId;
    final code = _codeForClassId(cid) ?? _codeForClassName(progress.className);
    if (cid == null || code == null) return;

    final camp = campaignFor(progress.ageMode);
    final done = progress.levelsDone(camp);
    final stars = progress.storyTotalStars(camp);
    final current = progress.nextStoryTask(camp);
    final skills = {for (final k in Skill.values) k: progress.mastery(k) ?? 0};
    final pre = progress.assessment(camp.id, 'pre');
    final post = progress.assessment(camp.id, 'post');

    final next = LocalEnrollment(
      studentId: studentId,
      classId: cid,
      joinCode: code,
      name: name,
      username: username,
      levelsDone: done,
      stars: stars,
      currentLevel: current,
      lastActive: DateTime.now(),
      skills: skills,
      pre: pre,
      post: post,
      attemptsWeek: done > 0 ? 1 + done.clamp(0, 6) : 0,
      hintsWeek: 0,
      failsRecent: 0,
    );

    final i = _roster.indexWhere((e) => e.studentId == studentId && (e.classId == cid || e.joinCode == code));
    if (i >= 0) {
      _roster[i] = next;
    } else {
      _roster.add(next);
    }
    await _saveRoster();
  }

  List<LocalEnrollment> liveStudents({String? classId, String? joinCode}) {
    final code = joinCode?.toUpperCase();
    final seen = <String>{};
    final out = <LocalEnrollment>[];
    for (final e in _roster) {
      final match = (classId != null && e.classId == classId) || (code != null && e.joinCode == code);
      if (!match || seen.contains(e.studentId)) continue;
      seen.add(e.studentId);
      out.add(e);
    }
    return out;
  }

  String? _codeForClassId(String? id) {
    if (id == null) return null;
    for (final c in _classesByCode.values) {
      if (c.id == id) return c.joinCode.toUpperCase();
    }
    // Orion uses alternate ids for the same demo codes.
    if (id.startsWith('demo-orion')) {
      for (final c in demoClassCatalog.values) {
        if (c.ageMode == (id.endsWith('-b') ? AgeMode.engineer : AgeMode.cadet)) return c.joinCode;
      }
    }
    return null;
  }

  String? _codeForClassName(String? name) {
    if (name == null) return null;
    for (final c in _classesByCode.values) {
      if (c.name == name) return c.joinCode.toUpperCase();
    }
    return null;
  }

  Future<void> _saveClasses() async {
    final p = _prefs;
    if (p == null) return;
    final custom = [
      for (final c in _classesByCode.values)
        if (!demoClassCatalog.containsKey(c.joinCode.toUpperCase())) _classToJson(c),
    ];
    await p.setString(_classesKey, jsonEncode(custom));
  }

  Future<void> _saveRoster() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_rosterKey, jsonEncode([for (final e in _roster) e.toJson()]));
  }

  static Map<String, dynamic> _classToJson(ClassInfo c) => {
        'id': c.id,
        'name': c.name,
        'join_code': c.joinCode,
        'age_mode': c.ageMode.name,
        'lock_rank': c.lockRank,
        if (c.createdAt != null) 'created_at': c.createdAt!.toIso8601String(),
      };

  static ClassInfo _classFromJson(Map<String, dynamic> m) => ClassInfo(
        id: '${m['id']}',
        name: '${m['name']}',
        joinCode: '${m['join_code']}'.toUpperCase(),
        ageMode: AgeModeInfo.parse(m['age_mode'] as String?),
        lockRank: m['lock_rank'] != false,
        createdAt: DateTime.tryParse('${m['created_at'] ?? ''}'),
      );
}
