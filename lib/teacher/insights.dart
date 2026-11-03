/// Pip's insights for the teacher: plain-language rules over the class data.
/// Pure logic (apart from icons and colours), so it is easy to test.
library;

import 'package:flutter/material.dart';

import '../cloud/models.dart';
import '../data/catalogue.dart';
import '../story/campaign.dart';
import 'charts.dart';

class Insight {
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  /// A level the teacher can assign straight from the insight.
  final String? levelId;
  const Insight(this.title, this.body, this.icon, this.color, {this.levelId});
}

/// The level where the most students stop: the biggest drop in "finished".
LevelStat? bottleneck(List<LevelStat> levels, int students) {
  if (levels.length < 2 || students == 0) return null;
  LevelStat? worst;
  var drop = 0;
  for (var i = 1; i < levels.length; i++) {
    final d = levels[i - 1].finished - levels[i].finished;
    if (d > drop && levels[i - 1].finished > 0) {
      drop = d;
      worst = levels[i];
    }
  }
  return drop >= (students * 0.2).ceil() ? worst : null;
}

/// The level of the campaign that practises a skill best (first match, else null).
String? levelForSkill(Campaign camp, Skill s) {
  for (var n = 1; n <= camp.length; n++) {
    final e = catalogueEntry(camp.levelIdFor(n));
    if (e != null && e.skills.isNotEmpty && e.skills.first == s) return e.id;
  }
  for (var n = 1; n <= camp.length; n++) {
    final e = catalogueEntry(camp.levelIdFor(n));
    if (e != null && e.skills.contains(s)) return e.id;
  }
  return null;
}

List<Insight> classInsights(ClassOverview o, List<StudentRow> students, List<SkillScore> skills, List<LevelStat> levels, Campaign camp) {
  final out = <Insight>[];
  if (o.students == 0) {
    return const [Insight('Add your students', 'Make sign-in cards from the Me tab, or share the join code. The dashboard fills in as they play.', Icons.person_add_alt_1_rounded, TC.blue)];
  }
  final stuck = students.where((s) => s.reason == HelpReason.stuck).toList();
  if (stuck.isNotEmpty) {
    final lvl = stuck.first.stuckLevel;
    final sameLevel = lvl == null ? stuck.length : stuck.where((s) => s.stuckLevel == lvl).length;
    final title = lvl == null ? null : catalogueEntry(lvl)?.title;
    out.add(Insight(
      '${stuck.length} stuck${title == null ? '' : ' on $title'}',
      sameLevel >= 3 ? 'Several students fail the same level. A 5-minute class demo of it will help more than hints.' : 'Send a hint from their row, or sit with them for the next try.',
      Icons.flag_rounded,
      TC.bad,
    ));
  }
  final b = bottleneck(levels, o.students);
  if (b != null) {
    out.add(Insight('Level ${b.number} is the wall', 'Most of the class stops at ${b.title}. Play it together in a live lesson.', Icons.stacked_bar_chart_rounded, TC.warn, levelId: b.levelId));
  }
  final scored = skills.where((s) => s.evidence > 0).toList()..sort((a, b) => a.score.compareTo(b.score));
  if (scored.isNotEmpty && scored.first.score < 65) {
    final s = scored.first;
    out.add(Insight('Weakest skill: ${s.skill.title} (${s.score})', '${s.skill.blurb} The level below practises it most.', Icons.trending_down_rounded, TC.indigo, levelId: levelForSkill(camp, s.skill)));
  }
  if (o.gainPoints != null) {
    out.add(Insight(
      o.gainPoints! >= 0 ? 'Learning gain: +${o.gainPoints} points' : 'Scores went down by ${-o.gainPoints!}',
      'Readiness Check, class average: ${o.preAvg ?? '—'}% before, ${o.postAvg ?? '—'}% after.',
      Icons.school_rounded,
      TC.good,
    ));
  } else if (o.preAvg != null) {
    out.add(Insight('Baseline: ${o.preAvg}%', 'Students took the Readiness Check. They take it again at the end, and you see the gain here.', Icons.school_rounded, TC.teal));
  }
  final inactive = students.where((s) => s.reason == HelpReason.inactive).length;
  if (inactive > 0) {
    out.add(Insight('$inactive not played this week', 'A reminder from their row often brings them back.', Icons.bedtime_rounded, TC.indigo));
  }
  if (out.isEmpty) out.add(const Insight('All on track', 'No warnings today. Try a co-op mission as a class reward.', Icons.celebration_rounded, TC.good));
  return out.take(4).toList();
}
