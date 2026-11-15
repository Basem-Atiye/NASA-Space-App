/// Figma 09–12: the Supply Run bonus round (intro, flight, cargo full,
/// supplies delivered).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../base/base_engine.dart';
import '../base/ui/base_screens.dart';
import '../base/ui/base_style.dart';
import '../main.dart';
import '../services/audio.dart';
import '../ui/figma_art.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
import '../ui/theme.dart';
import 'supply_game.dart';

Color podColor(PodKind k) => switch (k) {
      PodKind.oxygen => C.air,
      PodKind.water => C.water,
      PodKind.food => C.food,
      PodKind.power => C.yellow,
      PodKind.parts => C.orange,
    };

LineIconData podIcon(PodKind k) => switch (k) {
      PodKind.oxygen => Ln.wind,
      PodKind.water => Ln.droplet,
      PodKind.food => Ln.sprout,
      PodKind.power => Ln.zap,
      PodKind.parts => Ln.wrench,
    };

enum _Stage { intro, flight, delivered }

class SupplyRunScreen extends StatefulWidget {
  final int nextMission;
  const SupplyRunScreen({super.key, required this.nextMission});

  @override
  State<SupplyRunScreen> createState() => _SupplyRunScreenState();
}

class _SupplyRunScreenState extends State<SupplyRunScreen> with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.intro;
  SupplyGame _g = SupplyGame(seed: DateTime.now().millisecond);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _frame = ValueNotifier<int>(0);
  double _t = 0;
  int _steer = 0; // −1 left, 1 right
  bool _paused = false;
  int? _dropSlot;
  double _shake = 0;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => Services.of(context).nav.gameBack = _back);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Services get sv => Services.of(context);

  void _back() {
    if (_stage == _Stage.flight) {
      setState(() => _paused = !_paused);
    } else {
      sv.nav.gameBack = null;
      sv.nav.back();
    }
  }

  void _launch() {
    setState(() {
      _g = SupplyGame(seed: DateTime.now().millisecond);
      _stage = _Stage.flight;
      _paused = false;
    });
    sv.audio.play(Sfx.success, volume: 0.5);
    HapticFeedback.mediumImpact();
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero ? 1 / 60 : ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = d;
    _t += dt;
    _shake = math.max(0, _shake - dt * 3);
    if (_stage != _Stage.flight || _paused || _g.phase == RunPhase.cargoFull) {
      _frame.value++;
      return;
    }
    if (_steer != 0) _g.steer(_steer.toDouble(), dt);
    final before = _g.phase;
    for (final e in _g.update(dt)) {
      switch (e) {
        case 'pod':
          sv.audio.play(Sfx.sparkle, volume: 0.45);
          HapticFeedback.selectionClick();
        case 'rock':
          sv.audio.play(Sfx.fail, volume: 0.5);
          HapticFeedback.heavyImpact();
          _shake = 1;
        case 'full':
          sv.audio.play(Sfx.alert, volume: 0.5);
          setState(() => _dropSlot = null);
        case 'landed':
          _landed();
      }
    }
    if (before != _g.phase) setState(() {});
    _frame.value++;
  }

  Future<void> _landed() async {
    _ticker.stop();
    sv.audio.play(_g.roughLanding ? Sfx.fail : Sfx.success, volume: 0.6);
    final add = StartSupplies(
      power: _g.count(PodKind.power) * 6.0,
      oxygen: _g.count(PodKind.oxygen) * 5.0,
      water: _g.count(PodKind.water) * 5.0,
      food: _g.count(PodKind.food) * 5.0,
      parts: _g.count(PodKind.parts).toDouble(),
    );
    if (!_saved) {
      _saved = true;
      await sv.base.finishSupplyRun(_g.stars, add);
      sv.session.recordSupplyRun({'stars': _g.stars, 'pods': _g.hold.length, 'fuel_left': _g.fuel.round(), 'hits': _g.hits, 'played_at': DateTime.now().toUtc().toIso8601String()});
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _stage = _Stage.delivered);
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
        _Stage.intro => _intro(),
        _Stage.flight => _flight(),
        _Stage.delivered => _delivered(),
      };

  // ---------------------------------------------------------------- 09 intro

  Widget _intro() {
    return SpaceBackground(
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 10), children: [
                SizedBox(
                  height: 300,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(child: RepaintBoundary(child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, __) => CustomPaint(painter: _IntroArt(_t))))),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: tint(C.yellow, 0.14, C.bg), borderRadius: BorderRadius.circular(16)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const LineIcon(Ln.star, size: 15, color: C.yellow),
                          const SizedBox(width: 6),
                          GameText('BONUS ROUND', style: T.label.copyWith(color: C.yellow, fontSize: 12)),
                        ]),
                      ),
                    ),
                    Positioned(left: 0, top: 40, child: GameText('Supply Run', style: T.hero.copyWith(fontSize: 46))),
                    Positioned(left: 0, top: 96, child: GameText('Fly from Earth to your\nMoon base', style: T.body.copyWith(fontSize: 16.5, color: C.frozen.withValues(alpha: 0.85)))),
                  ]),
                ),
                KitCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Overline('How to play', size: 11.5),
                    const SizedBox(height: 10),
                    for (final (icon, color, title, sub) in const [
                      (Ln.rocket, C.cyan, 'Steer your rocket', 'Tap left or right to move'),
                      (Ln.star, C.green, 'Grab supply pods', 'Each pod restocks your Moon base'),
                      (Ln.alert, C.red, 'Dodge asteroids', 'A hit damages your cargo'),
                      (Ln.zap, C.orange, 'Watch your fuel', 'A heavier rocket burns more fuel!'),
                    ]) ...[
                      Row(children: [
                        IconBox(icon, color: color, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            GameText(title, style: T.h3.copyWith(fontSize: 17)),
                            GameText(sub, style: T.body.copyWith(fontSize: 14, color: C.frozen.withValues(alpha: 0.8))),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
              child: KitButton('Launch!', onTap: _launch),
            ),
            TextButton(
              onPressed: () {
                sv.nav.gameBack = null;
                if (widget.nextMission <= 10 && sv.base.unlocked(widget.nextMission)) {
                  sv.nav.baseMissionN = widget.nextMission;
                  sv.nav.go(Screen.baseBriefing);
                } else {
                  sv.nav.resetTo(Screen.missionSelect);
                }
              },
              child: GameText('Skip the bonus round', style: T.body.copyWith(color: C.muted, fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 10 flight

  Widget _flight() {
    final g = _g;
    return Stack(children: [
      Positioned.fill(
        child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => g.steerTo((d.localPosition.dx / size.width).clamp(0.0, 1.0), 1 / 30),
            child: RepaintBoundary(child: CustomPaint(size: size, painter: _FlightPainter(g, _frame, () => _t, () => _shake))),
          );
        }),
      ),
      SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(children: [
                RoundButton(icon: Ln.pause, tooltip: 'Pause', onTap: _back),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, _, __) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        GameText('EARTH', style: T.label.copyWith(color: C.frozen, fontSize: 11.5)),
                        Expanded(child: GameText('${(g.progress * 100).round()}% OF THE WAY', textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 11.5))),
                        GameText('MOON', style: T.label.copyWith(color: C.frozen, fontSize: 11.5)),
                      ]),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, b) => SizedBox(
                          height: 16,
                          child: Stack(clipBehavior: Clip.none, children: [
                            Positioned(left: 0, right: 0, top: 4, child: KitBar(frac: g.progress, color: C.water, track: C.panel, height: 8)),
                            Positioned(left: (b.maxWidth - 16) * g.progress, top: 0, child: Transform.rotate(angle: math.pi / 4, child: const LineIcon(Ln.rocket, size: 16, color: C.cyan))),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, __) => Row(children: [
                  Expanded(
                    child: KitCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      radius: 18,
                      color: C.panel.withValues(alpha: 0.85),
                      child: Column(children: [
                        Row(children: [
                          const LineIcon(Ln.zap, size: 16, color: C.orange),
                          const SizedBox(width: 6),
                          GameText('FUEL', style: T.label.copyWith(color: C.frozen, fontSize: 12)),
                          const Spacer(),
                          GameText('${g.fuel.round()}%', style: T.h3.copyWith(color: g.fuel < g.fuelNeeded ? C.red : C.orange, fontSize: 18)),
                        ]),
                        const SizedBox(height: 10),
                        KitBar(frac: g.fuel / 100, color: g.fuel < SupplyGame.landFuel + 8 ? C.red : C.orange),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KitCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      radius: 18,
                      color: C.panel.withValues(alpha: 0.85),
                      child: Column(children: [
                        Row(children: [
                          const LineIcon(Ln.wrench, size: 16, color: C.cyan),
                          const SizedBox(width: 6),
                          GameText('CARGO', style: T.label.copyWith(color: C.frozen, fontSize: 12)),
                          const Spacer(),
                          GameText('${g.hold.length} / ${SupplyGame.holdSize}', style: T.h3.copyWith(color: C.cyan, fontSize: 18)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          for (var i = 0; i < SupplyGame.holdSize; i++)
                            Expanded(
                              child: Container(
                                height: 9,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(color: i < g.hold.length ? podColor(g.hold[i]) : C.raised, borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Row(children: [
                _HoldButton(icon: Ln.back, onDown: () => _steer = -1, onUp: () => _steer = 0),
                const SizedBox(width: 18),
                Expanded(
                  child: KitButton('Boost', sub: '−5 fuel', height: 70, onTap: () {
                    if (_g.boost()) {
                      sv.audio.play(Sfx.success, volume: 0.35);
                      HapticFeedback.mediumImpact();
                    }
                  }),
                ),
                const SizedBox(width: 18),
                _HoldButton(icon: Ln.next, onDown: () => _steer = 1, onUp: () => _steer = 0),
              ]),
            ),
          ]),
        ),
      ),
      if (_g.phase == RunPhase.cargoFull) _cargoFull(),
      if (_paused) _pauseCard(),
    ]);
  }

  Widget _pauseCard() => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xB3050A1E),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ModalCard(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const GameText('Paused', style: T.h1),
                    const SizedBox(height: 18),
                    KitButton('Resume', onTap: () => setState(() => _paused = false)),
                    const SizedBox(height: 10),
                    KitButton('Restart', style: KitButtonStyle.secondary, onTap: _launch),
                    const SizedBox(height: 10),
                    KitButton('Quit', style: KitButtonStyle.secondary, onTap: () {
                      sv.nav.gameBack = null;
                      sv.nav.resetTo(Screen.missionSelect);
                    }),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  // ---------------------------------------------------------------- 11 cargo full

  Widget _cargoFull() {
    final g = _g;
    final w = g.waiting!;
    final drop = _dropSlot;
    final need = g.fuelNeeded;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3050A1E),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ModalCard(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      SizedBox(width: 64, height: 64, child: CustomPaint(painter: _PodPainter(w.kind))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const TagChip('CARGO HOLD FULL', color: C.yellow, icon: Ln.alert, size: 12.5),
                          const SizedBox(height: 6),
                          GameText('${w.kind.title} pod ahead!', style: T.h2.copyWith(fontSize: 24)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    GameText('Your rocket carries ${SupplyGame.holdSize} pods. Tap one to drop it, or skip this pod.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 15.5)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(20)),
                      child: GridView.count(
                        crossAxisCount: 5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (var i = 0; i < g.hold.length; i++)
                            TapScale(
                              onTap: () => setState(() => _dropSlot = i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: drop == i ? tint(C.red, 0.15, C.panel) : C.raised,
                                  borderRadius: BorderRadius.circular(14),
                                  border: drop == i ? Border.all(color: C.red, width: 2) : null,
                                ),
                                child: Stack(children: [
                                  Center(child: Padding(padding: const EdgeInsets.all(8), child: CustomPaint(size: const Size.square(40), painter: _PodPainter(g.hold[i])))),
                                  if (drop == i) const Positioned(right: 3, top: 3, child: LineIcon(Ln.close, size: 14, color: C.red)),
                                ]),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(color: tint(C.orange, 0.12), borderRadius: BorderRadius.circular(18)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        IconBox(Ln.zap, color: C.orange, size: 40, on: tint(C.orange, 0.12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            GameText('Heavier rocket = more fuel', style: T.h3.copyWith(color: C.orange, fontSize: 17)),
                            const SizedBox(height: 4),
                            GameText('A full hold uses 2× fuel per second. You need about ${need.round()}% to land — you have ${g.fuel.round()}%.', style: T.body.copyWith(fontSize: 14.5)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: KitButton('Skip it', style: KitButtonStyle.secondary, onTap: () => setState(g.skip))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KitButton(
                          drop == null ? 'Swap' : 'Swap ${g.hold[drop].title}',
                          onTap: drop == null
                              ? null
                              : () {
                                  sv.audio.play(Sfx.sparkle, volume: 0.4);
                                  setState(() {
                                    g.swap(drop);
                                    _dropSlot = null;
                                  });
                                },
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 12 delivered

  Widget _delivered() {
    final g = _g;
    final next = widget.nextMission;
    final rows = [for (final k in PodKind.values) if (g.count(k) > 0) k];
    String gain(PodKind k) {
      final n = g.count(k);
      return switch (k) {
        PodKind.oxygen => '+${n * 5}% Oxygen',
        PodKind.water => '+${n * 5}% Water',
        PodKind.food => '+${n * 5}% Food',
        PodKind.power => '+${n * 6}% Battery',
        PodKind.parts => '+$n Repair kit${n == 1 ? '' : 's'}',
      };
    }

    return SpaceBackground(
      glow: const Color(0xFF1F8F7A),
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 10), children: [
                SizedBox(height: 150, child: CustomPaint(painter: _DeliveredArt())),
                Center(child: TagChip(g.roughLanding ? 'ROUGH LANDING' : 'SUPPLY RUN COMPLETE', color: g.roughLanding ? C.yellow : C.green, icon: Ln.rocket, on: C.bg, size: 13)),
                const SizedBox(height: 14),
                GameText(rows.isEmpty ? 'Nothing delivered' : 'Supplies delivered!', textAlign: TextAlign.center, style: T.h1),
                const SizedBox(height: 14),
                Center(child: KitStars(stars: g.stars, size: 44, animate: true)),
                const SizedBox(height: 18),
                KitCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Overline('Added to your Moon base', size: 11.5),
                    const SizedBox(height: 10),
                    if (rows.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: GameText('Grab pods on the way next time!', style: T.body.copyWith(color: C.muted))),
                    for (final k in rows) ...[
                      Row(children: [
                        SizedBox(width: 38, height: 38, child: CustomPaint(painter: _PodPainter(k))),
                        const SizedBox(width: 12),
                        Expanded(child: GameText('${k.title}  ×${g.count(k)}', style: T.h3.copyWith(fontSize: 17))),
                        TagChip(gain(k), color: podColor(k), icon: Ln.up, size: 13.5),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    if (g.lostOnLanding.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: GameText('${g.lostOnLanding.length} pods broke in the hard landing (not enough fuel).', style: T.bodySmall.copyWith(color: C.yellow))),
                  ]),
                ),
                const SizedBox(height: 12),
                const TipCard(title: 'Real science', text: 'Real rockets work the same way: every extra kilogram of cargo needs more fuel to fly and land.', color: Color(0xFF3B3A63)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: KitButton(
                next <= 10 && sv.base.unlocked(next) ? 'Continue to Mission ${two(next)}' : 'Back to Missions',
                onTap: () {
                  sv.nav.gameBack = null;
                  if (next <= 10 && sv.base.unlocked(next)) {
                    sv.nav.baseMissionN = next;
                    sv.nav.go(Screen.baseBriefing);
                  } else {
                    sv.nav.resetTo(Screen.missionSelect);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  final LineIconData icon;
  final VoidCallback onDown, onUp;
  const _HoldButton({required this.icon, required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) {
          HapticFeedback.selectionClick();
          onDown();
        },
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.raised, shape: BoxShape.circle, border: Border.all(color: C.line, width: 1.5)),
          child: LineIcon(icon, size: 30, color: C.frozen, stroke: 2.4),
        ),
      );
}

// ======================================================================= PAINTERS

class _PodPainter extends CustomPainter {
  final PodKind k;
  _PodPainter(this.k);
  @override
  void paint(Canvas canvas, Size size) => paintPod(canvas, size.center(Offset.zero), size.shortestSide * 0.42, podColor(k), podIcon(k), glow: 0.6);
  @override
  bool shouldRepaint(covariant _PodPainter old) => old.k != k;
}

class _IntroArt extends CustomPainter {
  final double t;
  _IntroArt(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintMoonBall(canvas, Offset(w * 0.82, h * 0.2), w * 0.17);
    paintEarthBall(canvas, Offset(-w * 0.05, h * 1.0), w * 0.28);
    // the dotted path from Earth to the Moon
    final dash = Paint()
      ..color = C.cyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final a = Offset(w * 0.15, h * 0.82), b = Offset(w * 0.72, h * 0.3);
    for (var i = 0; i < 18; i++) {
      final k = i / 18;
      final p = Offset.lerp(a, b, k)! + Offset(0, -math.sin(k * math.pi) * h * 0.08);
      canvas.drawCircle(p, 1.8, dash);
    }
    paintRocket(canvas, Offset(w * 0.36, h * 0.66), 70, tilt: 0.75, t: t);
    paintPod(canvas, Offset(w * 0.6, h * 0.52), 15, C.food, Ln.sprout);
    paintPod(canvas, Offset(w * 0.5, h * 0.8), 15, C.air, Ln.wind);
    paintAsteroid(canvas, Offset(w * 0.8, h * 0.68), 22, seed: 2);
  }

  @override
  bool shouldRepaint(covariant _IntroArt old) => true;
}

class _DeliveredArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintMoonBall(canvas, Offset(size.width * 0.82, size.height * 0.3), size.height * 0.42);
    paintRocket(canvas, Offset(size.width * 0.42, size.height * 0.45), size.height * 0.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlightPainter extends CustomPainter {
  final SupplyGame g;
  final double Function() t;
  final double Function() shake;
  _FlightPainter(this.g, Listenable repaint, this.t, this.shake) : super(repaint: repaint);

  static final _stars = List.generate(80, (i) {
    final r = math.Random(i * 31 + 5);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final time = t();
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.bg, Color(0xFF171B41)]).createShader(Offset.zero & size));
    final sh = shake();
    if (sh > 0) canvas.translate(math.sin(time * 70) * 6 * sh, 0);
    // stars and speed lines streaming past
    final sp = Paint();
    final speed = g.boostLeft > 0 ? 2.2 : 1.0;
    for (var i = 0; i < _stars.length; i++) {
      final (x, y0, k) = _stars[i];
      final y = ((y0 + time * (0.05 + k * 0.12) * speed) % 1.0) * h;
      if (i % 5 == 0) {
        sp
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x * w, y), Offset(x * w, y - 40 * speed * (0.5 + k)), sp);
      } else {
        sp.color = Colors.white.withValues(alpha: 0.3 + 0.5 * k);
        canvas.drawCircle(Offset(x * w, y), 0.6 + k, sp);
      }
    }
    // the Moon grows as you get closer; Earth shrinks behind you
    paintMoonBall(canvas, Offset(w * 0.82, h * (0.2 + 0.05 * g.progress)), w * (0.06 + 0.12 * g.progress));
    if (g.progress < 0.35) paintEarthBall(canvas, Offset(w * 0.1, h * (1.05 + g.progress)), w * (0.35 - 0.5 * g.progress));
    for (final r in g.rocks) {
      paintAsteroid(canvas, Offset(r.x * w, r.y * h), r.r * w, spin: r.spin, seed: r.id);
    }
    for (final p in g.pods) {
      paintPod(canvas, Offset(p.x * w, p.y * h), p.r * w, podColor(p.kind), podIcon(p.kind), glow: 0.8 + 0.2 * math.sin(time * 4 + p.id));
    }
    // the rocket, with an engine glow (flashes when hit)
    final ro = Offset(g.x * w, SupplyGame.rocketY * h);
    canvas.drawCircle(ro + const Offset(0, 50), 70, Paint()..shader = RadialGradient(colors: [C.orange.withValues(alpha: 0.35), C.orange.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: ro + const Offset(0, 50), radius: 70)));
    if (g.hitCooldown <= 0 || (time * 12).floor().isEven) {
      paintRocket(canvas, ro, 110, flame: g.boostLeft > 0 ? 1.6 : 1, t: time, tilt: 0);
    }
    // "+1 Water" pills next to the rocket
    var k = 0;
    for (final (kind, left) in g.popups) {
      final a = (left / 1.2).clamp(0.0, 1.0);
      final tp = TextPainter(text: TextSpan(text: '+1 ${kind.title}', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white.withValues(alpha: a))), textDirection: TextDirection.ltr)..layout();
      final pos = ro + Offset(36, -40 - (1 - a) * 30 - k * 36);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx, pos.dy, tp.width + 40, 32), const Radius.circular(16));
      canvas.drawRRect(r, Paint()..color = podColor(kind).withValues(alpha: 0.9 * a));
      paintLineIcon(canvas, podIcon(kind), Offset(pos.dx + 10, pos.dy + 8), 16, Colors.white.withValues(alpha: a));
      tp.paint(canvas, Offset(pos.dx + 30, pos.dy + 6));
      k++;
    }
  }

  @override
  bool shouldRepaint(covariant _FlightPainter old) => true;
}
