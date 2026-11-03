import 'package:flutter/material.dart';

import '../cloud/models.dart';
import '../data/catalogue.dart';
import '../main.dart';
import '../story/story_model.dart' show AgeModeInfo;
import '../teacher/charts.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'info_screens.dart';

/// The player's own skills map: six skills from the last 20 decisions each,
/// the Readiness Check before and after, and messages from the teacher.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final camp = p.campaign;
    return AnimatedBuilder(
      animation: Listenable.merge([p, sv.session]),
      builder: (context, _) {
        final values = [for (final k in Skill.values) (p.mastery(k) ?? 0) / 100.0];
        final any = Skill.values.any((k) => p.mastery(k) != null);
        final pre = p.assessment(camp.id, 'pre');
        final post = p.assessment(camp.id, 'post');
        final nudges = sv.session.nudges;
        final rank = skillRank(values);
        return InfoFrame(
          title: 'My skills',
          subtitle: '${camp.title} · ${camp.mode.title} level. Every decision you make counts as evidence for one of six skills.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final n in nudges) _nudge(context, n),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
              child: Column(children: [
                Row(children: [
                  Text('SKILLS MAP', style: T.label.copyWith(fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(10)),
                    child: Text(rank.toUpperCase(), style: T.label.copyWith(color: C.frozen, fontSize: 10, letterSpacing: 1.4)),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 270,
                  child: any
                      ? RadarChart(labels: [for (final k in Skill.values) k.short], values: values, dark: true)
                      : Center(child: Text('Play a level to start your skills map.', style: T.body.copyWith(color: C.muted))),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            for (final k in Skill.values) _row(k, p.mastery(k)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('READINESS CHECK', style: T.label.copyWith(fontSize: 12)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _score('Before', pre)),
                  const Icon(Icons.arrow_forward_rounded, color: C.dim),
                  Expanded(child: _score('After', post)),
                ]),
                const SizedBox(height: 12),
                if (pre == null || (post == null && p.campaignComplete()))
                  HudButton(label: pre == null ? 'TAKE THE READINESS CHECK' : 'TAKE THE FINAL CHECK', icon: Icons.quiz_rounded, onTap: () => sv.nav.go(Screen.readiness))
                else if (post == null)
                  Text('The final check opens when you finish the campaign (${p.levelsDone()} of ${camp.length} levels done).', style: T.bodySmall),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _nudge(BuildContext context, Nudge n) {
    final sv = Services.of(context);
    final level = n.levelId == null ? null : catalogueEntry(n.levelId!)?.title;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.sapphire.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.sapphire)),
      child: Row(children: [
        const Icon(Icons.mark_email_unread_rounded, color: C.frozen),
        const SizedBox(width: 10),
        Expanded(child: Text(n.kind.studentText(level), style: T.body.copyWith(fontSize: 14))),
        IconButton(onPressed: () => sv.session.dismissNudge(n), icon: const Icon(Icons.check_rounded, color: C.cyan)),
      ]),
    );
  }

  Widget _row(Skill k, int? v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
            width: 128,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.title, style: T.h3.copyWith(fontSize: 13.5)),
              Text(k.blurb, style: T.bodySmall.copyWith(fontSize: 11), maxLines: 2),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: GaugeBar(label: '', value: v == null ? '—' : '$v', frac: (v ?? 0) / 100, color: (v ?? 0) >= 70 ? C.cyan : C.violet)),
        ]),
      );

  Widget _score(String label, int? v) => Column(children: [
        Text(label, style: T.bodySmall),
        Text(v == null ? '—' : '$v%', style: T.hero.copyWith(fontSize: 32, color: v == null ? C.dim : C.frozen)),
      ]);
}

/// The skill rank, from Trainee to Flight Director, from the average mastery.
String skillRank(List<double> values) {
  if (values.isEmpty) return 'Trainee';
  final avg = values.reduce((a, b) => a + b) / values.length;
  if (avg >= 0.9) return 'Flight Director';
  if (avg >= 0.75) return 'Mission Specialist';
  if (avg >= 0.55) return 'Flight Engineer';
  if (avg >= 0.3) return 'Crew Member';
  return 'Trainee';
}
