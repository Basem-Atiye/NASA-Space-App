/// Figma 07 Mission Complete and 08 Mission Failed.
library;

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../ui/astro_art.dart';
import '../../ui/kit.dart';
import '../../ui/line_icons.dart';
import '../../ui/theme.dart';
import '../base_badges.dart';
import '../base_engine.dart';
import '../base_kid_copy.dart';
import 'base_screens.dart';
import 'base_style.dart';
import 'mission_control.dart';

class BaseResultScreen extends StatelessWidget {
  final BaseState state;
  final MissionResult result;
  const BaseResultScreen({super.key, required this.state, required this.result});

  @override
  Widget build(BuildContext context) => result.won ? _Complete(state: state, r: result) : _Failed(state: state, r: result);
}

LineIconData _ratingIcon(String k) => switch (k) {
      'Power' => Ln.zap,
      'Crew' => Ln.heart,
      'Food' => Ln.sprout,
      'Water' => Ln.droplet,
      'Air' => Ln.wind,
      _ => Ln.flask,
    };

Color _ratingColor(String k) => switch (k) {
      'Power' => C.power,
      'Crew' => C.red,
      'Food' => C.food,
      'Water' => C.water,
      'Air' => C.air,
      _ => C.frozen,
    };

/// New badges, shown as a strip under the results.
class _NewBadges extends StatelessWidget {
  final List<String> ids;
  const _NewBadges(this.ids);

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: KitCard(
        border: C.yellow,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          for (final id in ids.take(3)) Padding(padding: const EdgeInsets.only(right: 8), child: BadgeMedal(icon: iconNamed(badgeById(id).icon), color: colorNamed(badgeById(id).color), earned: true, size: 48)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(ids.length == 1 ? 'New badge' : 'New badges', color: C.yellow, size: 11.5),
              Text(ids.map((i) => badgeById(i).title).join(', '), style: T.h3.copyWith(fontSize: 17)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ======================================================================= 07 COMPLETE

class _Complete extends StatelessWidget {
  final BaseState state;
  final MissionResult r;
  const _Complete({required this.state, required this.r});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final n = state.mission.n;
    final last = n == 5 || n == 10;
    return SpaceBackground(
      glow: const Color(0xFF1F8F7A),
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), children: [
                const Center(child: AstronautFigure(size: 170, tilt: -0.12)),
                const SizedBox(height: 4),
                Center(child: TagChip('MISSION ${two(n)} COMPLETE', color: C.green, icon: Ln.rocket, on: C.bg, size: 13)),
                const SizedBox(height: 14),
                Text(r.headline, textAlign: TextAlign.center, style: T.h1),
                const SizedBox(height: 8),
                Text(r.subline, textAlign: TextAlign.center, style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 16)),
                const SizedBox(height: 16),
                Center(child: KitStars(stars: r.stars, size: 50, animate: !sv.progress.reducedMotion)),
                const SizedBox(height: 18),
                KitCard(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                  child: Row(children: [
                    for (final e in r.ratings.entries)
                      Expanded(
                        child: Column(children: [
                          LineIcon(_ratingIcon(e.key), size: 24, color: _ratingColor(e.key)),
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const LineIcon(Ln.star, size: 13, color: C.yellow),
                            const SizedBox(width: 2),
                            Text('${e.value}/5', style: T.h3.copyWith(fontSize: 17)),
                          ]),
                          Text(e.key, style: T.body.copyWith(fontSize: 13, color: C.muted)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (r.best != null)
                  _Insight(
                    icon: Ln.up,
                    color: C.green,
                    title: 'Best decision',
                    text: 'Day ${r.best!.day}: ${r.best!.title}.${r.best!.why != null ? ' ${r.best!.why}' : ''}',
                  ),
                const SizedBox(height: 12),
                _Insight(icon: Ln.alert, color: C.yellow, title: 'Main problem', text: r.mainProblem),
                _NewBadges(sv.base.justEarned),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Row(children: [
                Expanded(child: KitButton('Try Again', style: KitButtonStyle.secondary, onTap: () => sv.nav.startBase(n, sv, fresh: true))),
                const SizedBox(width: 12),
                Expanded(
                  child: KitButton(
                    last ? 'Missions' : 'Next Mission',
                    onTap: () {
                      if (last) {
                        sv.nav.resetTo(Screen.missionSelect);
                      } else if (n < 5) {
                        // a bonus Supply Run between Moon missions
                        sv.nav.supplyNext = n + 1;
                        sv.nav.go(Screen.supplyRun);
                      } else {
                        sv.nav.baseMissionN = n + 1;
                        sv.nav.go(Screen.baseBriefing);
                      }
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final String title, text;
  const _Insight({required this.icon, required this.color, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => KitCard(
        color: tint(color, 0.06, C.panel),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBox(icon, color: color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(title, color: color, size: 11.5),
              const SizedBox(height: 4),
              Text(text, style: T.body.copyWith(fontSize: 15, height: 1.4)),
            ]),
          ),
        ]),
      );
}

// ======================================================================= 08 FAILED

class _Failed extends StatelessWidget {
  final BaseState state;
  final MissionResult r;
  const _Failed({required this.state, required this.r});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final n = state.mission.n;
    final icon = switch (state.lostCause) { 'oxygen' => Ln.wind, 'water' => Ln.droplet, 'food' => Ln.sprout, 'launch' => Ln.wrench, 'crew' => Ln.heart, _ => Ln.battery };
    final steps = r.whatHappened;
    return SpaceBackground(
      glow: C.red,
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), children: [
                Center(child: GlowDisc(icon: icon, color: C.red, size: 92)),
                const SizedBox(height: 18),
                Text(r.headline, textAlign: TextAlign.center, style: T.h1),
                const SizedBox(height: 8),
                Text(r.subline, textAlign: TextAlign.center, style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 16)),
                const SizedBox(height: 22),
                const Text('What happened?', style: T.h2),
                const SizedBox(height: 12),
                for (var i = 0; i < steps.length; i++) ...[
                  _WhatCard(entry: steps[i], last: i == steps.length - 1),
                  if (i < steps.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Center(child: LineIcon(Ln.down, size: 20, color: C.frozen))),
                ],
                const SizedBox(height: 14),
                TipCard(
                  title: useKidBaseCopy(Services.of(context).progress.ageMode) ? 'Lesson 💡' : 'Lesson',
                  text: useKidBaseCopy(Services.of(context).progress.ageMode)
                      ? kidLesson(r.lesson, mission: state.mission.n)
                      : r.lesson,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  collapsedIconColor: C.muted,
                  iconColor: C.muted,
                  title: Text('See the whole mission log', style: T.h3.copyWith(fontSize: 16, color: C.muted)),
                  children: [for (final e in state.log.reversed) LogRow(entry: e)],
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Row(children: [
                Expanded(child: KitButton('Missions', style: KitButtonStyle.secondary, onTap: () => sv.nav.resetTo(Screen.missionSelect))),
                const SizedBox(width: 12),
                Expanded(child: KitButton('Try Again', onTap: () => sv.nav.startBase(n, sv, fresh: true))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WhatCard extends StatelessWidget {
  final LogEntry entry;
  final bool last;
  const _WhatCard({required this.entry, required this.last});

  @override
  Widget build(BuildContext context) {
    final color = last ? C.red : (entry.kind == 'sun' || entry.kind.startsWith('adjust') ? C.orange : C.yellow);
    final icon = entry.kind.startsWith('adjust-') ? sysIcon(Sys.values[int.parse(entry.kind.substring(7))]) : (last ? Ln.wind : (entry.kind == 'sun' ? Ln.sun : Ln.battery));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.9), width: 2)),
      child: Row(children: [
        IconBox(icon, color: color, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline('Day ${entry.day}', color: color, size: 11.5),
            const SizedBox(height: 2),
            Text(entry.title, style: T.h3.copyWith(fontSize: 17, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}
