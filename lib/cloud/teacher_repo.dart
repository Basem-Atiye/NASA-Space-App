/// What the teacher app needs from a backend. Two implementations: the real
/// one over Supabase ([CloudTeacherRepo] in cloud.dart) and a sample class for
/// demos and judging without accounts ([DemoTeacherRepo]).
library;

import '../data/catalogue.dart';
import '../story/story_model.dart' show AgeMode;
import 'link.dart';
import 'models.dart';

class CreateStudentsResult {
  final List<StudentCard> cards;
  final List<String> failed;
  const CreateStudentsResult({required this.cards, this.failed = const []});
}

abstract class TeacherRepo {
  bool get isDemo;

  Future<List<ClassInfo>> classes();
  Future<ClassInfo> createClass(String name, AgeMode mode, {bool lockRank = true});
  Future<void> updateClass(ClassInfo c);
  Future<void> archiveClass(String id);

  Future<ClassOverview> overview(String cid);
  Future<List<StudentRow>> students(String cid);
  Future<List<SkillScore>> classSkills(String cid);
  Future<List<LevelStat>> levels(String cid);
  Future<List<SkillScore>> studentSkills(String sid, String cid);
  Future<List<AttemptRow>> studentAttempts(String sid, {int limit = 20});

  Future<CreateStudentsResult> createStudents(String cid, List<String> names);
  Future<StudentCard> resetPin(String cid, String sid);
  Future<void> removeStudent(String cid, String sid);

  Future<void> sendNudge(String cid, String sid, NudgeKind kind, {String? levelId});
  Future<List<Assignment>> assignments(String cid);
  Future<void> assign(String cid, String levelId, {String? studentId, DateTime? dueAt});
  Future<void> unassign(String id);
  Future<List<ClassGoal>> goals(String cid);
  Future<void> addGoal(String cid, {required String title, Skill? skill, String? levelId, required int target});
  Future<void> removeGoal(String id);

  /// The class as CSV (opens in any spreadsheet).
  Future<String> reportCsv(String cid);

  /// Base Commander: one row per student and mission (best stars, tries,
  /// wins and the most common reason the mission was lost).
  Future<List<BaseMissionStat>> baseSummary(String cid);

  /// The live lesson channel for the class (null when there is no Realtime).
  Link? liveLink(String cid);
}

/// One student's results in one Base Commander mission.
class BaseMissionStat {
  final String studentId;
  final String name;
  final int mission;
  final int bestStars;
  final int tries;
  final int wins;
  final String? topCause;
  const BaseMissionStat({required this.studentId, required this.name, required this.mission, required this.bestStars, required this.tries, required this.wins, this.topCause});

  factory BaseMissionStat.fromRow(Map<String, dynamic> r) => BaseMissionStat(
        studentId: r['student_id'] as String,
        name: (r['display_name'] ?? '') as String,
        mission: (r['mission'] as num).toInt(),
        bestStars: ((r['best_stars'] ?? 0) as num).toInt(),
        tries: ((r['tries'] ?? 0) as num).toInt(),
        wins: ((r['wins'] ?? 0) as num).toInt(),
        topCause: r['top_cause'] as String?,
      );
}
