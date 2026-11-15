import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../data/missions.dart';
import '../engine/mission.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/kit.dart';
import '../ui/widgets/common.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
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
    final p = sv.progress;
    return AuroraBackground(
      intensity: 0.8,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(children: [
                RoundButton(onTap: () {
                  sv.audio.tap();
                  sv.nav.back();
                }),
                const Spacer(),
                const SparkleStar(size: 16),
                const SizedBox(width: 6),
                GameText('${p.totalStars} / ${missions.length * 3}', style: T.h3),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText('FLIGHT DIRECTOR', style: T.label.copyWith(letterSpacing: 3)),
                const SizedBox(height: 6),
                GameText('Survival', style: T.hero.copyWith(fontSize: 36)),
                const SizedBox(height: 8),
                GameText('Keep the base running for days at a time, using real NASA daily rates: 0.84 kg oxygen, 2.37 kg water and 0.62 kg food per astronaut.', style: T.body.copyWith(color: C.muted)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(children: [
              for (var i = 0; i < chapters.length; i++)
                EnterAnim(delayMs: 60 * i, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _ChapterCard(chapter: chapters[i]))),
            ]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 20 + MediaQuery.of(context).padding.bottom)),
        ]),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final ms = missions.where((m) => m.chapter == chapter.number).toList();
    final unlocked = ms.any((m) => p.isUnlocked(m.id));
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderColor: unlocked ? C.line : C.lineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GameText('CHAPTER ${chapter.number}', style: T.label.copyWith(color: unlocked ? C.cyan : C.dim)),
            const Spacer(),
            if (p.quizBadges.contains(chapter.number))
              const Tooltip(message: 'Quiz badge earned', child: Icon(Icons.workspace_premium_rounded, color: C.gold, size: 18)),
          ]),
          const SizedBox(height: 4),
          GameText(chapter.title.toUpperCase(), style: T.h2.copyWith(color: unlocked ? C.text : C.dim)),
          GameText(chapter.theme, style: T.bodySmall),
          const HudDivider(),
          for (final m in ms) _MissionTile(m: m),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final MissionConfig m;
  const _MissionTile({required this.m});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final open = p.isUnlocked(m.id);
    final stars = p.stars(m.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: open
            ? () {
                sv.audio.tap();
                sv.nav.go(Screen.briefing, mission: m.id);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: open ? C.cyan.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: open ? (m.isBoss ? C.amber.withValues(alpha: 0.7) : C.line) : C.lineSoft),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: open ? C.sapphire : Colors.transparent, border: Border.all(color: open ? C.sapphire : C.dim)),
              child: open
                  ? GameText('${m.id}', style: T.h3.copyWith(color: Colors.white))
                  : const Icon(Icons.lock_rounded, size: 16, color: C.dim),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: GameText(m.title, style: T.h3.copyWith(color: open ? C.text : C.dim), overflow: TextOverflow.ellipsis)),
                  if (m.isBoss) ...[
                    const SizedBox(width: 6),
                    GameText('BOSS', style: T.label.copyWith(color: C.amber, fontSize: 8.5)),
                  ],
                ]),
                GameText(m.subtitle, style: T.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                StarRow(stars: stars, size: 14),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
