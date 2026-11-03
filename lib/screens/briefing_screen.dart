import 'package:flutter/material.dart';

import '../data/missions.dart';
import '../engine/mission.dart';
import '../game/game_controller.dart';
import '../main.dart';
import '../services/audio.dart';
import '../ui/theme.dart';
import '../ui/widgets/avatar.dart';
import '../ui/widgets/common.dart';
import '../data/messages.dart';

class BriefingScreen extends StatefulWidget {
  final MissionConfig mission;
  const BriefingScreen({super.key, required this.mission});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      final sv = Services.of(context);
      sv.audio.ambient('music');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final m = widget.mission;
    final ch = chapters.firstWhere((c) => c.number == m.chapter);
    final best = sv.progress.stars(m.id);
    final bottom = MediaQuery.of(context).padding.bottom;
    return AuroraBackground(
      intensity: 0.8,
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              IconButton(
                onPressed: () {
                  sv.audio.tap();
                  sv.nav.back();
                },
                icon: const Icon(Icons.arrow_back_rounded, color: C.frozen),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CHAPTER ${ch.number} · ${ch.title.toUpperCase()}  ·  MISSION ${m.id}${m.isBoss ? '  ·  BOSS' : ''}',
                          style: T.label.copyWith(color: m.isBoss ? C.amber : C.cyan)),
                      const SizedBox(height: 6),
                      const SizedBox(height: 4),
                      Text(m.title, style: T.hero.copyWith(fontSize: 32)),
                      Text(m.subtitle, style: T.bodySmall.copyWith(fontSize: 13)),
                      const HudDivider(),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const AstronautAvatar(mood: Mood.calm, size: 46),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m.goalText, style: T.body.copyWith(fontSize: 15))),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: C.cyan.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.lineSoft),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: C.cyan, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('NEW: ${m.newThisMission}', style: T.bodySmall.copyWith(color: C.text))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 18, runSpacing: 8, children: [
                        _kv('CREW', '${m.crew}'),
                        _kv('DAYS', '${m.days}'),
                        _kv('O₂', '${m.o2} kg'),
                        _kv('WATER', '${m.water.toStringAsFixed(0)} kg'),
                        _kv('FOOD', '${m.food} kg'),
                        _kv('DOSE LIMIT', '${m.doseLimit.toStringAsFixed(0)} mSv'),
                      ]),
                      const HudDivider(),
                      Row(children: [const StarRow(stars: 2, size: 13), const SizedBox(width: 6), Expanded(child: Text(m.star2.label, style: T.bodySmall))]),
                      const SizedBox(height: 3),
                      Row(children: [const StarRow(stars: 3, size: 13), const SizedBox(width: 6), Expanded(child: Text(m.star3.label, style: T.bodySmall))]),
                      if (best > 0) ...[
                        const SizedBox(height: 8),
                        Row(children: [Text('YOUR BEST  ', style: T.label.copyWith(fontSize: 9)), StarRow(stars: best, size: 14)]),
                      ],
                    ],
                  ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
            child: PrimaryButton(
              label: 'Begin mission',
              icon: Icons.play_arrow_rounded,
              onTap: () {
                sv.audio.play(Sfx.success, volume: 0.4);
                final g = GameController(mission: m, audio: sv.audio, progress: sv.progress);
                sv.nav.game?.dispose();
                sv.nav.game = g;
                g.start();
                sv.nav.go(Screen.game);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: T.label.copyWith(fontSize: 10.5)),
        Text(v, style: T.h3.copyWith(fontSize: 16)),
      ]);
}
