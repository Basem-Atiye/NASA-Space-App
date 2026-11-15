/// The Figma screens around the base game: 02 Missions,
/// 03 Mission Briefing, 13 How to Play and 19 Badges.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../ui/game_helper.dart';

import '../../main.dart';
import '../../story/story_model.dart';
import '../../ui/figma_art.dart';
import '../../ui/kit.dart';
import '../../ui/line_icons.dart';
import '../../ui/theme.dart';
import '../base_badges.dart';
import '../base_content.dart';
import '../base_engine.dart';
import 'base_style.dart';

/// A centred, phone-width column with the design's 24 side margins.
class PhoneColumn extends StatelessWidget {
  final Widget child;
  const PhoneColumn({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: child));
}

// ======================================================================= 02 MISSIONS

class MissionSelectScreen extends StatefulWidget {
  const MissionSelectScreen({super.key});

  @override
  State<MissionSelectScreen> createState() => _MissionSelectScreenState();
}

class _MissionSelectScreenState extends State<MissionSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final store = sv.base;
    final mars = sv.nav.showMars;
    final list = mars ? marsMissions : moonMissions;
    final saved = store.savedMission;
    return SpaceBackground(
      child: SafeArea(
        bottom: false,
        child: PhoneColumn(
          child: Column(children: [
            ScreenHeader(
              title: 'Missions',
              onBack: () => sv.nav.resetTo(Screen.title),
              trailing: RoundButton(icon: Ln.award, tooltip: 'Badges', onTap: () => sv.nav.go(Screen.badges)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 6, 24, 40), children: [
                Row(children: [
                  Expanded(
                    child: _PlanetCard(
                      title: 'Moon',
                      sub: '5 missions · ${store.moonDoneCount} done',
                      selected: !mars,
                      painter: const _BallPainter(false, false),
                      onTap: () => setState(() => sv.nav.showMars = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlanetCard(
                      title: 'Mars',
                      sub: store.unlocked(6) ? '5 missions · ${store.marsDoneCount} done' : 'Unlocks after Moon',
                      selected: mars,
                      dim: !store.unlocked(6),
                      painter: _BallPainter(true, !store.unlocked(6)),
                      onTap: store.unlocked(6)
                          ? () => setState(() => sv.nav.showMars = true)
                          : () => _toast(context, 'Finish all 5 Moon missions to fly to Mars.'),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                GameText(mars ? 'Mars Outpost' : 'Moon Crash Landing', style: T.h2.copyWith(fontSize: 21)),
                const SizedBox(height: 14),
                for (final m in list) ...[
                  _MissionRow(
                    m: m,
                    stars: store.stars[m.n] ?? 0,
                    current: m.n == store.current,
                    unlocked: store.unlocked(m.n),
                    saved: saved == m.n,
                    onTap: () {
                      if (!store.unlocked(m.n)) {
                        _toast(context, 'Finish Mission ${two(m.n - 1)} first.');
                        return;
                      }
                      sv.audio.tap();
                      sv.nav.baseMissionN = m.n;
                      sv.nav.go(Screen.baseBriefing);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (!mars) ...[
                  const SizedBox(height: 18),
                  const Overline('Bonus round'),
                  const SizedBox(height: 10),
                  _LinkRow(
                    icon: Ln.rocket,
                    color: C.yellow,
                    title: 'Supply Run',
                    sub: store.supplyRuns == 0 ? 'Fly supplies from Earth to your base' : 'Best: ${store.supplyBest} ★ · ${store.supplyRuns} runs',
                    onTap: () {
                      sv.nav.supplyNext = store.current;
                      sv.nav.go(Screen.supplyRun);
                    },
                  ),
                ],
                const SizedBox(height: 22),
                const Overline('Story missions'),
                const SizedBox(height: 10),
                _LinkRow(
                  icon: Ln.map,
                  color: C.cyan,
                  title: sv.progress.campaign.title,
                  sub: 'Walk Nova across the Moon · ${sv.progress.levelsDone()} of ${sv.progress.campaign.length} levels',
                  onTap: () {
                    if (!sv.progress.rankChosen) {
                      sv.nav.afterRank = Screen.map;
                      sv.nav.go(Screen.rank);
                    } else {
                      sv.nav.go(Screen.map);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _LinkRow(icon: Ln.alert, color: C.orange, title: 'Survival missions', sub: 'Quick emergencies with real numbers', onTap: () => sv.nav.go(Screen.missions)),
                const SizedBox(height: 22),
                const Overline('More'),
                const SizedBox(height: 10),
                _LinkRow(icon: Ln.star, color: C.yellow, title: 'My skills', sub: 'What your choices show you can do', onTap: () => sv.nav.go(Screen.skills)),
                const SizedBox(height: 10),
                _LinkRow(icon: Ln.book, color: C.green, title: 'Encyclopedia', sub: 'Facts and words you collected', onTap: () => sv.nav.go(Screen.encyclopedia)),
                const SizedBox(height: 10),
                _LinkRow(icon: Ln.settings, color: C.frozen, title: 'Settings', sub: 'Sound, age group, text size', onTap: () => sv.nav.go(Screen.settings)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: GameText(text, style: T.body),
      duration: const Duration(seconds: 2),
    ));
}

class _BallPainter extends CustomPainter {
  final bool mars;
  final bool locked;
  const _BallPainter(this.mars, this.locked);
  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero), r = size.shortestSide / 2;
    if (mars) {
      paintMarsBall(canvas, o, r, locked: locked);
    } else {
      paintMoonBall(canvas, o, r);
    }
  }

  @override
  bool shouldRepaint(covariant _BallPainter old) => old.mars != mars || old.locked != locked;
}

class _PlanetCard extends StatelessWidget {
  final String title, sub;
  final bool selected, dim;
  final CustomPainter painter;
  final VoidCallback? onTap;
  const _PlanetCard({required this.title, required this.sub, required this.selected, required this.painter, this.dim = false, this.onTap});

  @override
  Widget build(BuildContext context) => KitCard(
        onTap: onTap,
        color: selected ? C.raised : C.panel,
        border: selected ? C.cyan : null,
        borderWidth: 2.5,
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Opacity(
          opacity: dim ? 0.85 : 1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 64, height: 64, child: CustomPaint(painter: painter)),
            const SizedBox(height: 16),
            GameText(title, style: T.h2.copyWith(fontSize: 22)),
            const SizedBox(height: 2),
            GameText(sub, style: T.bodySmall.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

class _MissionRow extends StatelessWidget {
  final BaseMission m;
  final int stars;
  final bool current, unlocked, saved;
  final VoidCallback onTap;
  const _MissionRow({required this.m, required this.stars, required this.current, required this.unlocked, required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = stars > 0;
    final cur = current && unlocked && !done;
    final bg = cur ? C.cyan : (unlocked ? C.raised : C.locked);
    final fg = cur ? C.ink : (unlocked ? C.frozen : const Color(0xFF819B9D));
    final sub = cur ? C.ink.withValues(alpha: 0.85) : (unlocked ? C.muted : const Color(0xFF6E7F8C));
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: cur ? const [BoxShadow(color: C.cyanEdge, offset: Offset(0, 5))] : null,
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cur ? C.ink : (done ? tint(C.cyan, 0.22, C.raised) : (unlocked ? C.panel : const Color(0xFF3F3A6A))),
              borderRadius: BorderRadius.circular(14),
            ),
            child: GameText(two(m.n), style: T.h3.copyWith(fontSize: 18, color: cur || done ? C.cyan : (unlocked ? C.frozen : const Color(0xFF8A8FA6)))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              GameText(m.title, style: T.h3.copyWith(fontSize: 18, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
              GameText(saved ? 'Saved on a day in progress' : (m.n == 5 || m.n == 10 ? m.newThing : 'New: ${m.newThing}'), style: T.body.copyWith(fontSize: 14.5, color: sub, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (done)
            Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(left: 4), child: LineIcon(Ln.star, size: 19, color: i < stars ? C.yellow : C.line))])
          else if (cur)
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle), child: const LineIcon(Ln.forward, size: 20, color: C.cyan))
          else if (!unlocked)
            LineIcon(Ln.lock, size: 22, color: const Color(0xFF8A8FA6).withValues(alpha: 0.9))
          else
            const LineIcon(Ln.next, size: 22, color: C.muted),
        ]),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => KitCard(
        onTap: onTap,
        color: C.panel,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        radius: 20,
        child: Row(children: [
          IconBox(icon, color: color, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText(title, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              GameText(sub, style: T.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const LineIcon(Ln.next, size: 20, color: C.muted),
        ]),
      );
}

// ======================================================================= 03 BRIEFING

class BaseBriefingScreen extends StatelessWidget {
  final int n;
  const BaseBriefingScreen({super.key, required this.n});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final m = baseMission(n);
    final saved = sv.base.savedMission == n;
    final bonus = sv.base.bonus;
    final s = m.start;
    return SpaceBackground(
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            ScreenHeader(overline: 'Mission ${two(n)} · Briefing', title: m.title, onBack: () => sv.nav.back()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 6, 24, 16), children: [
                _BaseArtCard(m: m),
                const SizedBox(height: 18),
                KitCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(children: [
                    const IconBox(Ln.users, color: C.cyan, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Overline('Your goal', size: 11.5),
                        const SizedBox(height: 4),
                        GameText(m.goal, style: T.h3.copyWith(fontSize: 17.5, height: 1.3)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                const Overline('Starting supplies'),
                const SizedBox(height: 12),
                KitCard(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 16),
                  child: Row(children: [
                    _Supply(Ln.zap, C.power, s.power + (bonus?.power ?? 0), 'Power'),
                    _Supply(Ln.wind, C.air, s.oxygen + (bonus?.oxygen ?? 0), 'Oxygen'),
                    _Supply(Ln.droplet, C.water, s.water + (bonus?.water ?? 0), 'Water'),
                    _Supply(Ln.sprout, C.food, s.food + (bonus?.food ?? 0), 'Food'),
                  ]),
                ),
                if (bonus != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const LineIcon(Ln.rocket, size: 16, color: C.yellow),
                    const SizedBox(width: 6),
                    Expanded(child: GameText('Includes the supplies from your Supply Run.', style: T.bodySmall.copyWith(color: C.yellow))),
                  ]),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(color: C.info, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.sapphire, width: 1.5)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tint(C.sapphire, 0.25, C.info), shape: BoxShape.circle),
                      child: LineIcon(_newIcon(m), size: 20, color: C.violet),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TagChip(m.newTitle, color: C.cyan, on: C.info, size: 12.5),
                        const SizedBox(height: 10),
                        GameText(m.newText, style: T.body.copyWith(fontSize: 15, height: 1.45)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                Center(child: GameText('Level: ${levelName(sv)} · ${m.days} days', style: T.bodySmall)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Column(children: [
                if (saved) ...[
                  KitButton('Continue Day ${sv.base.resume(n)?.day ?? 1}', onTap: () => sv.nav.startBase(n, sv)),
                  const SizedBox(height: 10),
                  KitButton('Start again', style: KitButtonStyle.secondary, onTap: () => sv.nav.startBase(n, sv, fresh: true)),
                ] else
                  KitButton('Begin Mission', onTap: () => sv.nav.startBase(n, sv, fresh: true)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static LineIconData _newIcon(BaseMission m) => switch (m.n) {
        1 => Ln.wind,
        2 => Ln.droplet,
        3 => Ln.sprout,
        4 => Ln.radiation,
        5 => Ln.wrench,
        _ => Ln.sun,
      };
}

String levelName(Services sv) => switch (sv.progress.ageMode) { AgeMode.cadet => 'Little Explorer', AgeMode.explorer => 'Explorer', AgeMode.engineer => 'Engineer' };

class _Supply extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final double value;
  final String label;
  const _Supply(this.icon, this.color, this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          LineIcon(icon, size: 26, color: color),
          const SizedBox(height: 8),
          GameText(pct(math.min(100, value)), style: T.h2.copyWith(fontSize: 21)),
          GameText(label, style: T.body.copyWith(fontSize: 14, color: C.muted)),
        ]),
      );
}

/// The base picture in a rounded card, with the "MOON · DAY 1 OF 30" pill.
class _BaseArtCard extends StatefulWidget {
  final BaseMission m;
  const _BaseArtCard({required this.m});

  @override
  State<_BaseArtCard> createState() => _BaseArtCardState();
}

class _BaseArtCardState extends State<_BaseArtCard> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final visible = {
      BaseModule.power,
      BaseModule.habitat,
      BaseModule.lab,
      if (m.systems.contains(Sys.greenhouse) || m.n >= 2) BaseModule.greenhouse,
      if (m.systems.contains(Sys.recycler)) BaseModule.recycler,
    };
    return Container(
      height: 176,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line, width: 1.5)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => CustomPaint(painter: _BasePreview(BaseLook(t: _t.value * 20, markers: false, visible: visible, mars: m.mars, shield: m.systems.contains(Sys.shield) ? 0.4 : 0))),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(18)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LineIcon(Ln.calendar, size: 16, color: C.frozen),
                const SizedBox(width: 8),
                GameText('${m.mars ? 'MARS' : 'MOON'} · ${m.mars ? 'SOL' : 'DAY'} 1 OF ${m.days}', style: T.label.copyWith(color: C.frozen, fontSize: 12.5, letterSpacing: 1.6)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BasePreview extends CustomPainter {
  final BaseLook look;
  _BasePreview(this.look);
  @override
  void paint(Canvas canvas, Size size) => paintMoonBase(canvas, size, look);
  @override
  bool shouldRepaint(covariant _BasePreview old) => old.look.t != look.t;
}

// ======================================================================= 13 HOW TO PLAY

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    return SpaceBackground(
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            ScreenHeader(title: 'How to Play', onBack: () => sv.nav.back()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), children: [
                GameText('Keep your crew alive', style: T.h2.copyWith(fontSize: 21)),
                const SizedBox(height: 6),
                GameText('You run a base on the Moon. Your job is to keep everyone safe until the last day.', style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 15.5)),
                const SizedBox(height: 18),
                _Step(
                  n: 1,
                  title: 'Check your supplies',
                  text: 'Air, water, food and power each have a meter.',
                  extra: Row(children: [
                    for (final (i, c) in [(Ln.wind, C.air), (Ln.droplet, C.water), (Ln.sprout, C.food), (Ln.zap, C.power)]) Padding(padding: const EdgeInsets.only(right: 6), child: IconBox(i, color: c, size: 34, on: C.panel, alpha: 0.25)),
                  ]),
                ),
                const SizedBox(height: 12),
                const _Step(n: 2, title: 'Tap a part of the base', text: 'Turn it up or down. You will see what changes.'),
                const SizedBox(height: 12),
                const _Step(n: 3, title: 'Press Next Day', text: 'Watch what happens. Surprises can pop up!'),
                const SizedBox(height: 12),
                const TipCard(title: 'Every choice has a cost', text: 'More food uses more water and power. You can\'t max everything!', color: Color(0xFF3E3A6A)),
                const SizedBox(height: 12),
                const TipCard(title: 'Real science', text: 'Real Moon bases will sit near the south pole, where there is sunlight for power and ice for water.', icon: Ln.sparkles, iconColor: C.yellow, color: Color(0xFF3E3A6A)),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 6, 24, 14), child: KitButton('Got It', onTap: () => sv.nav.back())),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title, text;
  final Widget? extra;
  const _Step({required this.n, required this.title, required this.text, this.extra});

  @override
  Widget build(BuildContext context) => KitCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: C.cyan, shape: BoxShape.circle), child: GameText('$n', style: T.h3.copyWith(color: C.ink))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText(title, style: T.h3.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              GameText(text, style: T.body.copyWith(fontSize: 14.5, color: C.frozen.withValues(alpha: 0.8))),
              if (extra != null) ...[const SizedBox(height: 10), extra!],
            ]),
          ),
        ]),
      );
}

// ======================================================================= 19 BADGES

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final earned = sv.base.earned;
    final next = nextBadge(earned, sv.base.current);
    return SpaceBackground(
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            ScreenHeader(overline: '${earned.length} of ${badges.length} earned', title: 'Badges', onBack: () => sv.nav.back()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 24), children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                  children: [
                    for (final b in badges)
                      TapScale(
                        onTap: () => _toast(context, '${b.title}: ${b.how}'),
                        child: Column(children: [
                          LayoutBuilder(builder: (context, box) => BadgeMedal(icon: iconNamed(b.icon), color: colorNamed(b.color), earned: earned.contains(b.id), size: (box.maxWidth * 0.8).clamp(64.0, 96.0))),
                          const SizedBox(height: 8),
                          GameText(b.title, textAlign: TextAlign.center, maxLines: 2, style: T.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: earned.contains(b.id) ? C.frozen : C.muted, height: 1.25)),
                        ]),
                      ),
                  ],
                ),
                if (next != null) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: KitCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        IconBox(iconNamed(next.icon), color: colorNamed(next.color), size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            GameText('Next badge: ${next.title}', style: T.h3),
                            const SizedBox(height: 4),
                            GameText(next.how, style: T.body.copyWith(fontSize: 14.5, color: C.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
