import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/messages.dart';
import '../data/missions.dart';
import '../engine/simulation.dart';
import '../game/game_controller.dart';
import '../main.dart';
import '../services/audio.dart';
import '../ui/theme.dart';
import '../ui/widgets/avatar.dart';
import '../ui/widgets/common.dart';

String lossText(LossReason? r) {
  switch (r) {
    case LossReason.oxygen:
      return 'Nova ran out of oxygen.';
    case LossReason.water:
      return 'The base ran out of water.';
    case LossReason.food:
      return 'The crew ran out of food.';
    case LossReason.cold:
      return 'The habitat froze during the night.';
    case LossReason.radiation:
      return 'Radiation damaged Nova\'s health too much.';
    case LossReason.exhaustion:
      return 'Nova was exhausted for too long.';
    case LossReason.doseLimit:
      return 'Nova passed the mission radiation dose limit. Mission Control ordered her home.';
    case LossReason.objectives:
      return 'Time ran out before the mission objectives were done.';
    case null:
      return 'The mission ended.';
  }
}

String lossTip(LossReason? r) {
  switch (r) {
    case LossReason.oxygen:
      return 'Watch the O₂ time-left. Raise the oxygen generator rate in POWER, and repair it right away if it breaks.';
    case LossReason.water:
      return 'Keep the water recycler ON, and remember the oxygen generator uses water too. Ice from Shadow Crater refills the tanks.';
    case LossReason.food:
      return 'Turn on the greenhouse early and set Nova\'s task to GREENHOUSE to grow food twice as fast.';
    case LossReason.cold:
      return 'Before sunset, charge the battery and switch off everything except heaters and life support.';
    case LossReason.radiation:
    case LossReason.doseLimit:
      return 'When a flare is detected, recall any EVA and send Nova to the STORM SHELTER before the protons arrive.';
    case LossReason.exhaustion:
      return 'Give Nova REST shifts between hard tasks, especially between EVAs.';
    case LossReason.objectives:
      return 'Start EVAs early, while Nova is rested and there is no storm warning.';
    case null:
      return 'Try a different plan.';
  }
}

class DebriefScreen extends StatefulWidget {
  final GameController controller;
  const DebriefScreen({super.key, required this.controller});

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  int _shownStars = 0;
  final Map<int, int> _answers = {};
  bool _init = false;

  GameController get g => widget.controller;
  MissionSim get s => g.sim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final sv = Services.of(context);
    sv.audio.ambient('music');
    for (int i = 1; i <= g.stars; i++) {
      Future.delayed(Duration(milliseconds: 450 + i * 420), () {
        if (!mounted) return;
        setState(() => _shownStars = i);
        sv.audio.play(Sfx.star);
        sv.audio.haptic(light: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final m = s.mission;
    final won = s.outcome == Outcome.won;
    final idx = missions.indexWhere((x) => x.id == m.id);
    final next = idx >= 0 && idx < missions.length - 1 ? missions[idx + 1] : null;
    final quiz = m.isBoss ? quizzes[m.chapter] : null;
    final nasa = won ? whatWouldNasaDo[m.id] : null;

    return AuroraBackground(
      intensity: 0.8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: ListView(children: [
            // left: result and stats
            EnterAnim(
              child: GlassPanel(
                borderColor: won ? C.green : C.red,
                padding: const EdgeInsets.all(16),
                child: _Plain(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MISSION ${m.id} · ${m.title.toUpperCase()}', style: T.label),
                    const SizedBox(height: 4),
                    Text(won ? 'Mission complete' : 'Mission failed', style: T.hero.copyWith(fontSize: 32, color: won ? C.frozen : C.red)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (int i = 0; i < 3; i++)
                        AnimatedScale(
                          scale: i < _shownStars ? 1 : 0.6,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          child: Padding(padding: const EdgeInsets.only(right: 8), child: SparkleStar(size: 36, color: i < _shownStars ? C.cyan : C.lineSoft)),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    if (!won) ...[
                      Text(lossText(s.lossReason), style: T.body),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb_rounded, color: C.amber, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(lossTip(s.lossReason), style: T.bodySmall.copyWith(color: C.text))),
                      ]),
                    ] else ...[
                      _starLine(1, true, 'Mission complete'),
                      _starLine(2, s.meetsStar(m.star2), m.star2.label),
                      _starLine(3, s.meetsStar(m.star3), m.star3.label),
                    ],
                    const HudDivider(),
                    Wrap(spacing: 16, runSpacing: 8, children: [
                      _kv('SURVIVED', '${s.hour}h of ${m.totalHours}h'),
                      _kv('HEALTH', '${s.health.toStringAsFixed(0)}%'),
                      _kv('DOSE', '${s.dose.toStringAsFixed(1)} / ${m.doseLimit.toStringAsFixed(0)} mSv'),
                      _kv('O₂ LEFT', '${s.o2.toStringAsFixed(1)} kg'),
                      _kv('WATER LEFT', '${s.water.toStringAsFixed(1)} kg'),
                      _kv('FOOD LEFT', '${s.food.toStringAsFixed(1)} kg'),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (won && next != null)
                        HudButton(
                          label: 'NEXT MISSION',
                          icon: Icons.arrow_forward_rounded,
                          filled: true,
                          onTap: () {
                            sv.audio.tap();
                            sv.nav.resetTo(Screen.missions);
                            sv.nav.go(Screen.briefing, mission: next.id);
                          },
                        ),
                      HudButton(
                        label: 'TRY AGAIN',
                        icon: Icons.replay_rounded,
                        filled: !won,
                        onTap: () {
                          sv.audio.tap();
                          sv.nav.resetTo(Screen.missions);
                          sv.nav.go(Screen.briefing, mission: m.id);
                        },
                      ),
                      HudButton(
                        label: 'MISSIONS',
                        icon: Icons.public_rounded,
                        compact: true,
                        onTap: () {
                          sv.audio.tap();
                          sv.nav.resetTo(Screen.missions);
                        },
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // learning content
            EnterAnim(
              delayMs: 150,
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                child: _Plain(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (won && m.isBoss) ...[_report(), const HudDivider()],
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SpeakerAvatar(speaker: Speaker.capcom, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SectionLabel('Real NASA fact', color: C.cyan),
                          const SizedBox(height: 3),
                          Text(debriefFacts[m.id] ?? '', style: T.body),
                        ]),
                      ),
                    ]),
                    if (nasa != null) ...[
                      const HudDivider(),
                      const SectionLabel('What would NASA do?', color: C.amber),
                      const SizedBox(height: 6),
                      for (final n in nasa)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.rocket_launch_rounded, color: C.amber, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n.title, style: T.h3),
                                Text(n.body, style: T.bodySmall.copyWith(color: C.text)),
                              ]),
                            ),
                          ]),
                        ),
                    ],
                    if (quiz != null) ...[
                      const HudDivider(),
                      Row(children: [
                        const SectionLabel('Chapter check', color: C.cyan),
                        const Spacer(),
                        if (sv.progress.quizBadges.contains(m.chapter))
                          Row(children: [
                            const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 16),
                            Text(' BADGE EARNED', style: T.label.copyWith(color: C.gold, fontSize: 9)),
                          ]),
                      ]),
                      const SizedBox(height: 6),
                      for (int qi = 0; qi < quiz.length; qi++) _question(qi, quiz[qi], quiz.length, sv),
                    ],
                    const HudDivider(),
                    const SectionLabel('Mission timeline'),
                    const SizedBox(height: 6),
                    for (final e in s.log)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: 92, child: Text(missionClock(e.hour), style: T.monoSmall.copyWith(fontSize: 10.5))),
                          Expanded(child: Text(e.text, style: T.bodySmall.copyWith(color: C.text))),
                        ]),
                      ),
                    if (s.log.isEmpty) const Text('A quiet mission.', style: T.bodySmall),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _report() {
    final m = s.mission;
    final ch = chapters.firstWhere((c) => c.number == m.chapter);
    final best = <String>[];
    if (s.shelteredInStorm && !s.wasOutsideInStorm) best.add('Got the crew to shelter before the storm hit');
    if (s.broken.isEmpty && s.log.any((l) => l.text.startsWith('Repaired'))) best.add('Fixed every breakdown');
    if (s.harvests > 0) best.add('Grew ${s.harvests * 2.5} kg of fresh food');
    if (s.brownouts == 0) best.add('Never let the battery run empty');
    if (s.lowestO2Days > 0.5) best.add('Kept a safe oxygen margin all mission');
    if (s.samples > 0) best.add('Collected ${s.samples} rock samples');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.cyan.withValues(alpha: 0.12), C.gold.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.gold.withValues(alpha: 0.6)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AstronautAvatar(mood: Mood.happy, size: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CHAPTER ${ch.number} REPORT CARD', style: T.label.copyWith(color: C.gold)),
            Text('${ch.title}: ${ch.theme}', style: T.h3),
            const SizedBox(height: 6),
            Text('Flight Director rating: ${'★' * g.stars}${'☆' * (3 - g.stars)}', style: T.mono.copyWith(color: C.gold)),
            const SizedBox(height: 6),
            for (final b in best.take(3))
              Row(children: [const Icon(Icons.check_rounded, size: 14, color: C.green), const SizedBox(width: 6), Expanded(child: Text(b, style: T.bodySmall.copyWith(color: C.text)))]),
            const SizedBox(height: 6),
            Text('Take a screenshot to share your report card.', style: T.bodySmall.copyWith(fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _question(int qi, QuizQuestion q, int total, Services sv) {
    final answered = _answers[qi];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${qi + 1}. ${q.question}', style: T.h3),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (int oi = 0; oi < q.options.length; oi++)
            GestureDetector(
              onTap: answered != null
                  ? null
                  : () {
                      setState(() => _answers[qi] = oi);
                      if (oi == q.correct) {
                        sv.audio.play(Sfx.star);
                      } else {
                        sv.audio.play(Sfx.alert, volume: 0.4);
                      }
                      final allRight = List.generate(total, (i) => i).every((i) => _answers[i] != null && _answers[i] == quizzes[s.mission.chapter]![i].correct);
                      if (allRight) sv.progress.addQuizBadge(s.mission.chapter);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: answered == null
                      ? C.bg.withValues(alpha: 0.4)
                      : (oi == q.correct ? C.green.withValues(alpha: 0.18) : (answered == oi ? C.red.withValues(alpha: 0.18) : C.bg.withValues(alpha: 0.3))),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: answered == null ? C.line : (oi == q.correct ? C.green : (answered == oi ? C.red : C.lineSoft)),
                  ),
                ),
                child: Text(q.options[oi], style: T.bodySmall.copyWith(color: C.text)),
              ),
            ),
        ]),
        if (answered != null) ...[
          const SizedBox(height: 5),
          Text(q.why, style: T.bodySmall.copyWith(color: answered == q.correct ? C.green : C.amber)),
        ],
      ]),
    );
  }

  Widget _starLine(int n, bool ok, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: ok ? C.green : C.dim),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: T.bodySmall.copyWith(color: ok ? C.text : C.muted))),
        ]),
      );

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: T.label.copyWith(fontSize: 9)),
        Text(v, style: T.mono.copyWith(fontSize: 12)),
      ]);
}

/// Passes its child through (the debrief scrolls as one list on a phone).
class _Plain extends StatelessWidget {
  final Widget child;
  const _Plain({required this.child});
  @override
  Widget build(BuildContext context) => child;
}
