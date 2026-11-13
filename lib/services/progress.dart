import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalogue.dart';
import '../data/missions.dart';
import '../story/campaign.dart';
import '../story/story_model.dart' show AgeMode, AgeModeInfo;

/// Saved progress and settings. Everything is stored on the device.
class Progress extends ChangeNotifier {
  SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;

  final Map<int, int> _stars = {};

  /// Best stars per level id ("cadet-03", "explorer-12"...), every campaign.
  final Map<String, int> _levelStars = {};

  /// The run carried from one level to the next, per campaign (JSON), and the
  /// level that saved carry is ready for.
  final Map<String, String> _carry = {};
  final Map<String, int> _carryTask = {};

  /// The last 20 pieces of evidence per skill (true = good decision).
  final Map<Skill, List<bool>> skillLog = {};

  /// Readiness Check results in percent: "<campaign>_pre" / "<campaign>_post".
  final Map<String, int> assessments = {};

  /// The class a signed-in student is in (from the cloud), cached for offline starts.
  String? classId;
  String? className;
  String? teacherName;

  /// Cached account kind for a fast start: null guest, 'student' or 'teacher'.
  String? accountRole;
  String? displayName;
  bool welcomeSeen = false;
  final Set<String> memory = {};
  final Set<String> memoryUsed = {};
  final Set<int> quizBadges = {};

  bool sound = true;
  bool music = true;
  bool haptics = true;
  bool lowGraphics = false;
  bool unlockAll = false;
  double textSpeed = 1.0; // 0.5 slow .. 2 fast
  bool tutorialHints = true;
  bool reducedMotion = false;

  /// Soft clicks while messages type onto the screen.
  bool typingSound = true;

  /// Text size from Settings (A A A): 0 small, 1 normal, 2 large.
  int textSize = 1;

  /// Read lines aloud. Null means "default": on for Cadets, off otherwise.
  bool? voice;
  bool get voiceOn => voice ?? (ageMode == AgeMode.cadet);

  /// The player's rank (age mode). Null until chosen on first launch.
  String? ageModeName;

  /// A teacher locked the rank for the class.
  bool rankLocked = false;

  /// Facts found with Pip's scanner (Moon Encyclopedia).
  final Set<String> facts = {};

  /// The cutscene of the arrival has been seen.
  bool introSeen = false;

  AgeMode get ageMode => AgeModeInfo.parse(ageModeName);
  bool get rankChosen => ageModeName != null;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      for (final m in missions) {
        final s = p.getInt('stars_${m.id}');
        if (s != null) _stars[m.id] = s;
      }
      _levelStars.addAll(_intMap(p.getString('level_stars')));
      // 1.x saved the story as sstars_1..10: that is the Explorer campaign now
      for (var n = 1; n <= 10; n++) {
        final s = p.getInt('sstars_$n');
        final id = levelId(CampaignId.explorer, n);
        if (s != null && (s > (_levelStars[id] ?? 0))) _levelStars[id] = s;
      }
      for (final c in CampaignId.values) {
        final j = p.getString('carry_${c.name}');
        if (j != null) _carry[c.name] = j;
        final t = p.getInt('carry_task_${c.name}');
        if (t != null) _carryTask[c.name] = t;
      }
      final old = p.getString('story_carry');
      if (old != null && old.isNotEmpty && !_carry.containsKey('explorer')) {
        _carry['explorer'] = old;
        _carryTask['explorer'] = p.getInt('story_carry_task') ?? 0;
      }
      try {
        final raw = p.getString('skill_log');
        if (raw != null) {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          for (final e in m.entries) {
            final k = SkillInfo.parse(e.key);
            if (k != null) skillLog[k] = [for (final b in (e.value as List)) b == true];
          }
        }
      } catch (_) {}
      assessments.addAll(_intMap(p.getString('assessments')));
      classId = p.getString('class_id');
      className = p.getString('class_name');
      teacherName = p.getString('teacher_name');
      accountRole = p.getString('account_role');
      displayName = p.getString('display_name');
      welcomeSeen = p.getBool('welcome_seen') ?? false;
      memory.addAll(p.getStringList('memory') ?? const []);
      memoryUsed.addAll(p.getStringList('memory_used') ?? const []);
      quizBadges.addAll((p.getStringList('quiz') ?? const []).map(int.parse));
      sound = p.getBool('sound') ?? true;
      music = p.getBool('music') ?? true;
      haptics = p.getBool('haptics') ?? true;
      lowGraphics = p.getBool('low_graphics') ?? false;
      unlockAll = p.getBool('unlock_all') ?? false;
      textSpeed = p.getDouble('text_speed') ?? 1.0;
      tutorialHints = p.getBool('hints') ?? true;
      reducedMotion = p.getBool('reduced_motion') ?? false;
      typingSound = p.getBool('typing_sound') ?? true;
      textSize = p.getInt('text_size') ?? 1;
      voice = p.getBool('voice');
      ageModeName = p.getString('age_mode');
      rankLocked = p.getBool('rank_locked') ?? false;
      facts.addAll(p.getStringList('facts') ?? const []);
      introSeen = p.getBool('intro_seen') ?? false;
    } catch (_) {
      // Storage unavailable: the game still runs, progress just isn't saved.
    }
    notifyListeners();
  }

  static Map<String, int> _intMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()};
    } catch (_) {
      return {};
    }
  }

  int stars(int missionId) => _stars[missionId] ?? 0;

  // ---- Campaigns (the one for the player's age level, unless given)

  /// The campaign the player is on: the age level picks it.
  Campaign get campaign => campaignFor(ageMode);

  int levelStars(String id) => _levelStars[id] ?? 0;

  int storyStars(int n, [Campaign? c]) => levelStars((c ?? campaign).levelIdFor(n));

  int storyTotalStars([Campaign? c]) {
    final k = c ?? campaign;
    var sum = 0;
    for (var n = 1; n <= k.length; n++) {
      sum += storyStars(n, k);
    }
    return sum;
  }

  int levelsDone([Campaign? c]) {
    final k = c ?? campaign;
    var d = 0;
    for (var n = 1; n <= k.length; n++) {
      if (storyStars(n, k) > 0) d++;
    }
    return d;
  }

  bool storyUnlocked(int n, [Campaign? c]) => unlockAll || n == 1 || storyStars(n - 1, c) > 0;

  int nextStoryTask([Campaign? c]) {
    final k = c ?? campaign;
    for (var n = 1; n <= k.length; n++) {
      if (storyStars(n, k) == 0) return n;
    }
    return k.length;
  }

  bool storyStarted([Campaign? c]) => levelsDone(c) > 0;

  bool campaignComplete([Campaign? c]) => levelsDone(c) >= (c ?? campaign).length;

  String carryFor(CampaignId c) => _carry[c.name] ?? '';
  int carryTaskFor(CampaignId c) => _carryTask[c.name] ?? 0;

  /// Remembers best stars and the carried numbers for the next level.
  Future<void> recordLevel(CampaignId c, int n, int stars, String carryJson) async {
    final id = levelId(c, n);
    if (stars > levelStars(id)) _levelStars[id] = stars;
    _carry[c.name] = carryJson;
    _carryTask[c.name] = n + 1;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString('level_stars', jsonEncode(_levelStars));
      await p.setString('carry_${c.name}', carryJson);
      await p.setInt('carry_task_${c.name}', n + 1);
    } catch (_) {}
  }

  /// Cloud progress from another phone: keep the best of both.
  Future<void> mergeCloud({Map<String, int> stars = const {}, Set<String> cloudFacts = const {}, Map<String, Map<String, dynamic>> carry = const {}}) async {
    var changed = false;
    for (final e in stars.entries) {
      if (e.value > levelStars(e.key)) {
        _levelStars[e.key] = e.value;
        changed = true;
      }
    }
    final newFacts = cloudFacts.difference(facts);
    if (newFacts.isNotEmpty) {
      facts.addAll(newFacts);
      changed = true;
    }
    for (final e in carry.entries) {
      final cur = _carryTask[e.key] ?? 0;
      final next = (e.value['current_level'] as num?)?.toInt() ?? 0;
      if (next > cur && e.value['carry'] is Map) {
        _carry[e.key] = jsonEncode(e.value['carry']);
        _carryTask[e.key] = next;
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString('level_stars', jsonEncode(_levelStars));
      await p.setStringList('facts', facts.toList());
      for (final c in _carry.keys) {
        await p.setString('carry_$c', _carry[c]!);
        await p.setInt('carry_task_$c', _carryTask[c] ?? 0);
      }
    } catch (_) {}
  }

  // ---- Skills and the Readiness Check

  void addSkillEvidence(Skill s, bool good) {
    final l = skillLog.putIfAbsent(s, () => []);
    l.add(good);
    if (l.length > 20) l.removeRange(0, l.length - 20);
  }

  Future<void> saveSkills() async {
    notifyListeners();
    try {
      await _prefs?.setString('skill_log', jsonEncode({for (final e in skillLog.entries) e.key.db: e.value}));
    } catch (_) {}
  }

  /// Mastery 0..100 from the last 20 decisions, or null with no evidence yet.
  int? mastery(Skill s) {
    final l = skillLog[s];
    if (l == null || l.isEmpty) return null;
    return (100 * l.where((b) => b).length / l.length).round();
  }

  int? assessment(CampaignId c, String kind) => assessments['${c.name}_$kind'];

  Future<void> recordAssessment(CampaignId c, String kind, int percent) async {
    assessments['${c.name}_$kind'] = percent;
    notifyListeners();
    try {
      await _prefs?.setString('assessments', jsonEncode(assessments));
    } catch (_) {}
  }

  // ---- Account and class

  Future<void> setAccount({String? role, String? name}) async {
    accountRole = role;
    displayName = name;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      if (role == null) {
        await p.remove('account_role');
      } else {
        await p.setString('account_role', role);
      }
      if (name == null) {
        await p.remove('display_name');
      } else {
        await p.setString('display_name', name);
      }
    } catch (_) {}
  }

  /// A student joined a class: the teacher's age level, locked if the teacher wants.
  Future<void> setClass({String? id, String? name, String? teacher, AgeMode? mode, bool lock = false}) async {
    classId = id;
    className = name;
    teacherName = teacher;
    if (mode != null) ageModeName = mode.name;
    rankLocked = id != null && lock;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      for (final (k, v) in [('class_id', id), ('class_name', name), ('teacher_name', teacher)]) {
        if (v == null) {
          await p.remove(k);
        } else {
          await p.setString(k, v);
        }
      }
      if (mode != null) await p.setString('age_mode', mode.name);
      await p.setBool('rank_locked', rankLocked);
    } catch (_) {}
  }

  Future<void> markWelcomeSeen() async {
    welcomeSeen = true;
    try {
      await _prefs?.setBool('welcome_seen', true);
    } catch (_) {}
  }

  Future<void> setAgeMode(AgeMode m) async {
    ageModeName = m.name;
    notifyListeners();
    try {
      await _prefs?.setString('age_mode', m.name);
    } catch (_) {}
  }

  /// Returns true when the fact is new.
  bool addFact(String id) {
    if (!facts.add(id)) return false;
    notifyListeners();
    _prefs?.setStringList('facts', facts.toList()).catchError((Object _) => false);
    return true;
  }

  Future<void> markIntroSeen() async {
    introSeen = true;
    try {
      await _prefs?.setBool('intro_seen', true);
    } catch (_) {}
  }

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  bool isUnlocked(int missionId) {
    if (unlockAll || missionId == missions.first.id) return true;
    final i = missions.indexWhere((m) => m.id == missionId);
    if (i <= 0) return true;
    return stars(missions[i - 1].id) > 0;
  }

  int get nextMissionId {
    for (final m in missions) {
      if (stars(m.id) == 0 && isUnlocked(m.id)) return m.id;
    }
    return missions.last.id;
  }

  bool get hasStarted => _stars.isNotEmpty;

  Future<void> recordResult(int missionId, int stars, Set<String> newMemory) async {
    if (stars > (this.stars(missionId))) _stars[missionId] = stars;
    memory.addAll(newMemory);
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setInt('stars_$missionId', this.stars(missionId));
      await p.setStringList('memory', memory.toList());
    } catch (_) {}
  }

  Future<void> markMemoryUsed(String flag) async {
    memoryUsed.add(flag);
    try {
      await _prefs?.setStringList('memory_used', memoryUsed.toList());
    } catch (_) {}
  }

  Future<void> addQuizBadge(int chapter) async {
    quizBadges.add(chapter);
    notifyListeners();
    try {
      await _prefs?.setStringList('quiz', quizBadges.map((e) => '$e').toList());
    } catch (_) {}
  }

  Future<void> setSetting(String key, Object value) async {
    switch (key) {
      case 'sound':
        sound = value as bool;
        break;
      case 'music':
        music = value as bool;
        break;
      case 'haptics':
        haptics = value as bool;
        break;
      case 'low_graphics':
        lowGraphics = value as bool;
        break;
      case 'unlock_all':
        unlockAll = value as bool;
        break;
      case 'text_speed':
        textSpeed = value as double;
        break;
      case 'hints':
        tutorialHints = value as bool;
        break;
      case 'reduced_motion':
        reducedMotion = value as bool;
        break;
      case 'typing_sound':
        typingSound = value as bool;
        break;
      case 'text_size':
        textSize = value as int;
        break;
      case 'voice':
        voice = value as bool;
        break;
      case 'rank_locked':
        rankLocked = value as bool;
        break;
    }
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      if (value is bool) await p.setBool(key, value);
      if (value is double) await p.setDouble(key, value);
      if (value is int) await p.setInt(key, value);
    } catch (_) {}
  }

  Future<void> resetAll() async {
    _stars.clear();
    _levelStars.clear();
    _carry.clear();
    _carryTask.clear();
    skillLog.clear();
    assessments.clear();
    memory.clear();
    memoryUsed.clear();
    quizBadges.clear();
    facts.clear();
    introSeen = false;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      for (final m in missions) {
        await p.remove('stars_${m.id}');
      }
      for (var n = 1; n <= 10; n++) {
        await p.remove('sstars_$n');
      }
      await p.remove('story_carry');
      await p.remove('story_carry_task');
      await p.remove('level_stars');
      await p.remove('skill_log');
      await p.remove('assessments');
      for (final c in CampaignId.values) {
        await p.remove('carry_${c.name}');
        await p.remove('carry_task_${c.name}');
      }
      await p.remove('memory');
      await p.remove('memory_used');
      await p.remove('quiz');
      await p.remove('facts');
      await p.remove('intro_seen');
    } catch (_) {}
  }
}
