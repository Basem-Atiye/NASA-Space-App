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

  /// The live lesson channel for the class (null when there is no Realtime).
  Link? liveLink(String cid);
}
