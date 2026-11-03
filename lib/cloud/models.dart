/// Plain data the cloud returns (rows of the Supabase tables and functions).
/// Pure Dart: shared by the real cloud service and the teacher demo data.
library;

import '../data/catalogue.dart';
import '../story/story_model.dart' show AgeMode, AgeModeInfo;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? d : d);
int? _intN(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
double? _dblN(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String _str(Object? v, [String d = '']) => v is String ? v : (v == null ? d : '$v');

enum Role { student, teacher, parent, admin }

class Profile {
  final String id;
  final Role role;
  final String displayName;
  final String avatar;
  final AgeMode ageMode;
  final String? username;

  const Profile({required this.id, required this.role, required this.displayName, this.avatar = 'nova', this.ageMode = AgeMode.explorer, this.username});

  bool get isTeacher => role == Role.teacher || role == Role.admin;

  factory Profile.fromRow(Map<String, dynamic> r) => Profile(
        id: _str(r['id']),
        role: Role.values.firstWhere((x) => x.name == r['role'], orElse: () => Role.student),
        displayName: _str(r['display_name'], 'Cadet'),
        avatar: _str(r['avatar'], 'nova'),
        ageMode: AgeModeInfo.parse(r['age_mode'] as String?),
        username: r['username'] as String?,
      );
}

/// A class as the teacher sees it.
class ClassInfo {
  final String id;
  final String name;
  final String joinCode;
  final AgeMode ageMode;
  final bool lockRank;
  final DateTime? createdAt;

  const ClassInfo({required this.id, required this.name, required this.joinCode, required this.ageMode, this.lockRank = true, this.createdAt});

  factory ClassInfo.fromRow(Map<String, dynamic> r) => ClassInfo(
        id: _str(r['id'] ?? r['class_id']),
        name: _str(r['name'] ?? r['class_name']),
        joinCode: _str(r['join_code']),
        ageMode: AgeModeInfo.parse(r['age_mode'] as String?),
        lockRank: r['lock_rank'] as bool? ?? true,
        createdAt: _date(r['created_at']),
      );

  CampaignId get campaign => CampaignId.values[ageMode.index];

  ClassInfo copyWith({String? name, AgeMode? ageMode, bool? lockRank}) =>
      ClassInfo(id: id, name: name ?? this.name, joinCode: joinCode, ageMode: ageMode ?? this.ageMode, lockRank: lockRank ?? this.lockRank, createdAt: createdAt);
}

/// A class as a student sees it (from my_classes / join_class).
class MyClass {
  final String id;
  final String name;
  final AgeMode ageMode;
  final bool lockRank;
  final String teacherName;
  const MyClass({required this.id, required this.name, required this.ageMode, this.lockRank = true, this.teacherName = ''});

  factory MyClass.fromRow(Map<String, dynamic> r) => MyClass(
        id: _str(r['class_id'] ?? r['id']),
        name: _str(r['class_name'] ?? r['name']),
        ageMode: AgeModeInfo.parse(r['age_mode'] as String?),
        lockRank: r['lock_rank'] as bool? ?? true,
        teacherName: _str(r['teacher_name']),
      );
}

class ClassOverview {
  final int students;
  final int activeToday;
  final int activeWeek;
  final int levelsTotal;
  final double avgLevelsDone;
  final double? avgStars;
  final int? preAvg;
  final int? postAvg;
  final int? gainPoints;
  final Skill? weakestSkill;
  final Skill? strongestSkill;
  final int needsHelp;

  const ClassOverview({
    required this.students,
    required this.activeToday,
    required this.activeWeek,
    required this.levelsTotal,
    required this.avgLevelsDone,
    this.avgStars,
    this.preAvg,
    this.postAvg,
    this.gainPoints,
    this.weakestSkill,
    this.strongestSkill,
    this.needsHelp = 0,
  });

  static const empty = ClassOverview(students: 0, activeToday: 0, activeWeek: 0, levelsTotal: 0, avgLevelsDone: 0);

  /// Share of the campaign the average student has finished, 0..1.
  double get progress => levelsTotal == 0 ? 0 : (avgLevelsDone / levelsTotal).clamp(0, 1).toDouble();

  factory ClassOverview.fromRow(Map<String, dynamic> r) => ClassOverview(
        students: _int(r['students']),
        activeToday: _int(r['active_today']),
        activeWeek: _int(r['active_week']),
        levelsTotal: _int(r['levels_total']),
        avgLevelsDone: _dblN(r['avg_levels_done']) ?? 0,
        avgStars: _dblN(r['avg_stars']),
        preAvg: _intN(r['pre_avg']),
        postAvg: _intN(r['post_avg']),
        gainPoints: _intN(r['gain_points']),
        weakestSkill: SkillInfo.parse(r['weakest_skill'] as String?),
        strongestSkill: SkillInfo.parse(r['strongest_skill'] as String?),
        needsHelp: _int(r['needs_help']),
      );
}

enum HelpReason { stuck, manyHints, inactive, notStarted }

extension HelpReasonInfo on HelpReason {
  String get title => const ['Stuck on a level', 'Using many hints', 'Not played this week', 'Not started yet'][index];

  static HelpReason? parse(String? s) => switch (s) {
        'stuck' => HelpReason.stuck,
        'many_hints' => HelpReason.manyHints,
        'inactive' => HelpReason.inactive,
        'not_started' => HelpReason.notStarted,
        _ => null,
      };
}

class StudentRow {
  final String id;
  final String name;
  final String avatar;
  final String? username;
  final int levelsDone;
  final int stars;
  final int currentLevel;
  final DateTime? lastActive;
  final int attemptsWeek;
  final int hintsWeek;
  final int failsRecent;
  final int? pre;
  final int? post;
  final bool needsHelp;
  final HelpReason? reason;
  final String? stuckLevel;

  const StudentRow({
    required this.id,
    required this.name,
    this.avatar = 'nova',
    this.username,
    this.levelsDone = 0,
    this.stars = 0,
    this.currentLevel = 1,
    this.lastActive,
    this.attemptsWeek = 0,
    this.hintsWeek = 0,
    this.failsRecent = 0,
    this.pre,
    this.post,
    this.needsHelp = false,
    this.reason,
    this.stuckLevel,
  });

  int? get gain => pre != null && post != null ? post! - pre! : null;

  factory StudentRow.fromRow(Map<String, dynamic> r) => StudentRow(
        id: _str(r['student_id']),
        name: _str(r['display_name'], 'Student'),
        avatar: _str(r['avatar'], 'nova'),
        username: r['username'] as String?,
        levelsDone: _int(r['levels_done']),
        stars: _int(r['stars']),
        currentLevel: _int(r['current_level'], 1),
        lastActive: _date(r['last_active']),
        attemptsWeek: _int(r['attempts_week']),
        hintsWeek: _int(r['hints_week']),
        failsRecent: _int(r['fails_recent']),
        pre: _intN(r['pre_score']),
        post: _intN(r['post_score']),
        needsHelp: r['needs_help'] == true,
        reason: HelpReasonInfo.parse(r['help_reason'] as String?),
        stuckLevel: r['stuck_level'] as String?,
      );
}

class SkillScore {
  final Skill skill;
  final int score;
  final int classAvg;
  final int evidence;
  const SkillScore(this.skill, this.score, {this.classAvg = 0, this.evidence = 0});

  factory SkillScore.fromRow(Map<String, dynamic> r) => SkillScore(
        SkillInfo.parse(r['skill'] as String?) ?? Skill.prioritise,
        _int(r['score']),
        classAvg: _int(r['class_avg'], _int(r['score'])),
        evidence: _int(r['evidence']),
      );
}

class LevelStat {
  final String levelId;
  final int number;
  final String title;
  final int finished;
  final int playing;
  final double? avgStars;
  final double? avgMistakes;
  final double? avgHints;
  const LevelStat({required this.levelId, required this.number, required this.title, this.finished = 0, this.playing = 0, this.avgStars, this.avgMistakes, this.avgHints});

  factory LevelStat.fromRow(Map<String, dynamic> r) => LevelStat(
        levelId: _str(r['level_id']),
        number: _int(r['number']),
        title: _str(r['title']),
        finished: _int(r['finished']),
        playing: _int(r['playing']),
        avgStars: _dblN(r['avg_stars']),
        avgMistakes: _dblN(r['avg_mistakes']),
        avgHints: _dblN(r['avg_hints']),
      );
}

/// One decision a student made, for the teacher's "decisions" list.
class Decision {
  final String step;
  final String choice;
  final bool good;
  const Decision(this.step, this.choice, this.good);

  Map<String, dynamic> toJson() => {'step': step, 'choice': choice, 'good': good};

  static Decision? fromJson(Object? j) =>
      j is Map ? Decision(_str(j['step']), _str(j['choice']), j['good'] == true) : null;
}

class AttemptRow {
  final String levelId;
  final DateTime startedAt;
  final String? outcome;
  final int? stars;
  final int mistakes;
  final int hints;
  final int? durationS;
  final List<Decision> decisions;
  const AttemptRow({required this.levelId, required this.startedAt, this.outcome, this.stars, this.mistakes = 0, this.hints = 0, this.durationS, this.decisions = const []});

  factory AttemptRow.fromRow(Map<String, dynamic> r) => AttemptRow(
        levelId: _str(r['level_id']),
        startedAt: _date(r['started_at']) ?? DateTime.now(),
        outcome: r['outcome'] as String?,
        stars: _intN(r['stars']),
        mistakes: _int(r['mistakes']),
        hints: _int(r['hints']),
        durationS: _intN(r['duration_s']),
        decisions: (r['decisions'] as List? ?? const []).map(Decision.fromJson).whereType<Decision>().toList(),
      );
}

enum NudgeKind { hint, replay, reminder, wellDone }

extension NudgeKindInfo on NudgeKind {
  String get db => const ['hint', 'replay', 'reminder', 'well_done'][index];
  String get title => const ['Send a hint', 'Ask to replay', 'Friendly reminder', 'Well done!'][index];

  /// What the student sees (preset text only: teachers cannot type messages to children).
  String studentText(String? level) => switch (this) {
        NudgeKind.hint => 'Your teacher sent a hint${level == null ? '' : ' for $level'}: open the HINT button and read Pip\'s card.',
        NudgeKind.replay => 'Your teacher would like you to play ${level ?? 'your last level'} again. You can do it!',
        NudgeKind.reminder => 'Mission Control is waiting! Your teacher reminds you to play your next level.',
        NudgeKind.wellDone => 'Well done! Your teacher saw your great work${level == null ? '' : ' on $level'}.',
      };

  static NudgeKind parse(String? s) => NudgeKind.values.firstWhere((k) => k.db == s, orElse: () => NudgeKind.reminder);
}

class Nudge {
  final String id;
  final NudgeKind kind;
  final String? levelId;
  final DateTime createdAt;
  const Nudge({required this.id, required this.kind, this.levelId, required this.createdAt});

  factory Nudge.fromRow(Map<String, dynamic> r) => Nudge(
        id: _str(r['id']),
        kind: NudgeKindInfo.parse(r['kind'] as String?),
        levelId: r['level_id'] as String?,
        createdAt: _date(r['created_at']) ?? DateTime.now(),
      );
}

class Assignment {
  final String id;
  final String levelId;
  final String? studentId;
  final DateTime? dueAt;
  const Assignment({required this.id, required this.levelId, this.studentId, this.dueAt});

  factory Assignment.fromRow(Map<String, dynamic> r) =>
      Assignment(id: _str(r['id']), levelId: _str(r['level_id']), studentId: r['student_id'] as String?, dueAt: _date(r['due_at']));
}

class ClassGoal {
  final String id;
  final String title;
  final Skill? skill;
  final String? levelId;
  final int target;
  final DateTime? dueAt;
  const ClassGoal({required this.id, required this.title, this.skill, this.levelId, required this.target, this.dueAt});

  factory ClassGoal.fromRow(Map<String, dynamic> r) => ClassGoal(
        id: _str(r['id']),
        title: _str(r['title']),
        skill: SkillInfo.parse(r['skill'] as String?),
        levelId: r['level_id'] as String?,
        target: _int(r['target'], 70),
        dueAt: _date(r['due_at']),
      );
}

/// A printable sign-in card made for a new student.
class StudentCard {
  final String name;
  final String username;
  final String pin;
  final String studentId;
  const StudentCard({required this.name, required this.username, required this.pin, required this.studentId});

  factory StudentCard.fromJson(Map<String, dynamic> j) =>
      StudentCard(name: _str(j['name']), username: _str(j['username']), pin: _str(j['pin']), studentId: _str(j['student_id']));
}

class SpaceWeather {
  final String level; // calm | watch | storm
  final String summary;
  final String? strongest;
  final int flares;
  final int cmes;
  const SpaceWeather({required this.level, required this.summary, this.strongest, this.flares = 0, this.cmes = 0});

  factory SpaceWeather.fromJson(Map<String, dynamic> j) => SpaceWeather(
        level: _str(j['level'], 'calm'),
        summary: _str(j['summary']),
        strongest: j['strongest'] as String?,
        flares: _int(j['flares']),
        cmes: _int(j['cmes']),
      );
}
