/// Hands-on versions of the mission puzzles. Instead of tapping a list in
/// order or moving sliders, the player works with live machines:
///
/// * [TriageGame]: an emergency board where every problem is alive (gas
///   venting, sparks, a falling needle). Its danger bar grows, fastest for
///   the most urgent one. Press and hold a problem to fix it.
/// * [CargoGame]: drag real bags and crates between the shield wall and the
///   spare-parts bay.
/// * [TankGame]: fill the daily food and water jars by dragging the level.
/// * [Knob] and [Gauge]: twist dials with clicks you can feel, and read the
///   result on needle gauges with green and red zones (used by SIMs).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/story.dart';
import '../services/audio.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/rotary_dial.dart';
import 'minigames.dart';
import 'story_logic.dart';
import 'story_model.dart';

// ======================================================================= TRIAGE

enum HazardKind { gas, spark, heat, signal, gauge, warn }

/// What a problem looks like, from its words.
HazardKind hazardFor(String text) {
  final t = text.toLowerCase();
  bool any(List<String> w) => w.any(t.contains);
  if (any(['o2', 'oxygen', 'air', 'leak', 'pressure', 'seal', 'vent', 'hatch', 'co2', 'breath', 'life support', 'life-support'])) {
    return HazardKind.gas;
  }
  if (any(['power', 'volt', 'battery', 'bus', 'fuse', 'wire', 'cable', 'charg', 'electric'])) return HazardKind.spark;
  if (any(['heat', 'fire', 'temp', 'hot', 'cold', 'thermal', 'heater', 'radiation', 'storm', 'sun'])) return HazardKind.heat;
  if (any(['comm', 'radio', 'link', 'antenna', 'signal', 'earth', 'call', 'light', 'greenhouse'])) return HazardKind.signal;
  if (any(['fuel', 'water', 'pump', 'tank', 'food', 'level', 'tracker', 'sensor', 'science', 'instrument'])) return HazardKind.gauge;
  return HazardKind.warn;
}

Color hazardColor(HazardKind k) => switch (k) {
      HazardKind.gas => const Color(0xFF7FE3FF),
      HazardKind.spark => const Color(0xFFFFD45C),
      HazardKind.heat => const Color(0xFFFF7A59),
      HazardKind.signal => const Color(0xFFB9A8FF),
      HazardKind.gauge => const Color(0xFF5BE38A),
      HazardKind.warn => const Color(0xFFFFB347),
    };

class TriageGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const TriageGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<TriageGame> createState() => _TriageGameState();
}

class _TriageGameState extends State<TriageGame> with SingleTickerProviderStateMixin {
  late final List<int> _display = shuffled(widget.spec.items.length, widget.spec.title.hashCode);
  final List<int> _fixed = [];
  late final List<double> _danger;
  late final List<double> _rate;
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;
  int _mistakes = 0;
  int? _holding;
  double _hold = 0;
  int? _wrong;
  double _wrongT = 0;
  String? _status;
  late bool _showIntro;

  static const _holdTime = 0.85;

  bool get _isLoadShedding => widget.spec.title.toUpperCase().contains('LOAD SHEDDING');

  @override
  void initState() {
    super.initState();
    _showIntro = _isLoadShedding;
    final n = widget.spec.items.length;
    _danger = List.filled(n, 0);
    _rate = List.filled(n, 0);
    // the most urgent problem grows fastest: watching the bars teaches the order
    for (var k = 0; k < widget.spec.answer.length; k++) {
      final item = widget.spec.answer[k];
      _rate[item] = 0.11 - k * 0.018;
      _danger[item] = 0.22 - k * 0.03;
    }
    _ticker = createTicker(_tick);
    if (!_showIntro) _ticker.start();
  }

  void _beginPlay() {
    widget.audio.play(Sfx.tap, volume: 0.45);
    setState(() => _showIntro = false);
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _t += dt;
    for (var i = 0; i < _danger.length; i++) {
      if (_fixed.contains(i)) continue;
      _danger[i] = math.min(1, _danger[i] + _rate[i].clamp(0.02, 1.0) * dt);
    }
    if (_wrongT > 0) _wrongT = math.max(0, _wrongT - dt);
    final h = _holding;
    if (h != null) {
      _hold += dt / _holdTime;
      if ((_hold * 8).floor() != ((_hold - dt / _holdTime) * 8).floor()) widget.audio.typeClick();
      if (_hold >= 1) _complete(h);
    }
    setState(() {});
  }

  void _start(int i) {
    if (_fixed.contains(i) || _fixed.length == widget.spec.items.length) return;
    if (_holding == i) return;
    widget.audio.haptic(light: true);
    _holding = i;
    _hold = 0;
  }

  /// Finish a press: a short tap still selects (label says TAP IN ORDER),
  /// and a full hold already completed in [_tick]. Using [Listener] so the
  /// parent scroll view on Chrome cannot cancel the gesture mid-hold.
  void _endPress() {
    final h = _holding;
    final progress = _hold;
    if (h == null) return;
    if (progress >= 1) {
      _holding = null;
      _hold = 0;
      return;
    }
    // Snap the ring to full, then commit — so the circle always "completes".
    _hold = 1;
    _complete(h);
  }

  void _cancel() {
    _holding = null;
    _hold = 0;
  }

  void _complete(int item) {
    _holding = null;
    _hold = 0;
    final want = widget.spec.answer[_fixed.length];
    if (item == want) {
      widget.audio.play(Sfx.sparkle, volume: 0.5);
      widget.audio.haptic();
      _fixed.add(item);
      _wrong = null;
      _status = _fixed.length == widget.spec.items.length ? 'Everything is safe. Great work!' : null;
      if (_fixed.length == widget.spec.items.length) {
        widget.audio.play(Sfx.success, volume: 0.6);
        Timer(const Duration(milliseconds: 1000), () {
          if (mounted) widget.onDone(GameResult(mistakes: _mistakes));
        });
      }
    } else {
      widget.audio.play(Sfx.fail, volume: 0.5);
      widget.audio.haptic(heavy: true);
      _mistakes++;
      _wrong = item;
      _wrongT = 0.5;
      _status = widget.spec.wrong.isNotEmpty
          ? widget.spec.wrong.replaceAll('{item}', widget.spec.items[item])
          : 'Not yet: "${widget.spec.items[item]}" can wait. Which danger bar is growing fastest?';
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) return _LoadSheddingIntro(onReady: _beginPlay);
    final s = widget.spec;
    final left = s.items.length - _fixed.length;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status,
      statusColor: _wrong != null ? C.amber : C.green,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(s.label.isEmpty ? 'TAP A PROBLEM TO FIX IT · MOST DANGEROUS FIRST' : s.label, style: T.label)),
          Text('$left LEFT', style: T.label.copyWith(color: left == 0 ? C.green : C.muted)),
        ]),
        const SizedBox(height: 10),
        for (final i in _display) _card(i),
      ]),
    );
  }

  Widget _card(int i) {
    final text = widget.spec.items[i];
    final kind = hazardFor(text);
    final col = hazardColor(kind);
    final fixed = _fixed.contains(i);
    final order = _fixed.indexOf(i);
    final holding = _holding == i;
    final shake = _wrong == i && _wrongT > 0 ? math.sin(_wrongT * 60) * 6 * (_wrongT / 0.5) : 0.0;
    final d = _danger[i];
    final critical = d >= 1 && !fixed;
    return Transform.translate(
      offset: Offset(shake, 0),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _start(i),
        onPointerUp: (_) => _endPress(),
        onPointerCancel: (_) => _cancel(),
        child: AnimatedContainer(
          duration: Motion.fast,
          height: fixed ? 50 : 72,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: fixed ? C.green.withValues(alpha: 0.1) : Color.lerp(C.panelDeep, col, holding ? 0.18 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: fixed ? C.green.withValues(alpha: 0.5) : (critical ? C.red.withValues(alpha: 0.5 + 0.5 * math.sin(_t * 9).abs()) : col.withValues(alpha: holding ? 0.9 : 0.4)),
              width: holding ? 2 : 1.2,
            ),
            boxShadow: holding ? [BoxShadow(color: col.withValues(alpha: 0.35), blurRadius: 18)] : null,
          ),
          child: Row(children: [
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              height: 56,
              child: fixed
                  ? Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                        child: Text('${order + 1}', style: T.h3.copyWith(color: C.ink, fontSize: 14)),
                      ),
                    )
                  : CustomPaint(painter: _HazardPainter(kind, _t + i * 0.7, danger: d, hold: holding ? _hold : 0, color: col)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(text,
                    style: T.h3.copyWith(fontSize: 14, color: fixed ? C.muted : C.text, decoration: fixed ? TextDecoration.lineThrough : null),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (!fixed) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: Stack(fit: StackFit.expand, children: [
                        const ColoredBox(color: C.lineSoft),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: d.clamp(0.02, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [col.withValues(alpha: 0.7), Color.lerp(col, C.red, d)!])),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            if (!fixed) Text(critical ? 'CRITICAL' : '${(d * 100).round()}%', style: T.monoSmall.copyWith(color: critical ? C.red : col, fontSize: 11)),
            const SizedBox(width: 14),
          ]),
        ),
      ),
    );
  }
}

/// Coach card before Load Shedding: turn nice-to-haves off first; keep life support on.
class _LoadSheddingIntro extends StatelessWidget {
  final VoidCallback onReady;
  const _LoadSheddingIntro({required this.onReady});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: C.cyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.cyan.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: C.cyan, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Power is short', style: T.h2.copyWith(fontSize: 24))),
                ]),
                const SizedBox(height: 14),
                Text(
                  'When the battery dips, you switch loads off — but not all at once. Start with the nice-to-haves. Keep the critical systems running.',
                  style: T.body.copyWith(color: C.muted, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 18),
                _priorityCard(
                  step: '1',
                  title: 'Switch off first',
                  body: 'Science tools, rover charging, greenhouse lights — useful, but the crew can wait.',
                  color: C.amber,
                  icon: Icons.power_settings_new_rounded,
                ),
                const SizedBox(height: 10),
                _priorityCard(
                  step: '2',
                  title: 'Keep critical on',
                  body: 'Heaters and life support stay on longest. People first. Always.',
                  color: C.green,
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: C.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.cyan.withValues(alpha: 0.35)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: C.cyan, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap each load in order: first to switch off → last to switch off.',
                        style: T.body.copyWith(fontSize: 13.5, color: C.frozen, height: 1.35),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        KitButton("Got it — let's shed", icon: Ln.play, onTap: onReady),
      ],
    );
  }

  Widget _priorityCard({
    required String step,
    required String title,
    required String body,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: C.panelDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Text(step, style: T.h3.copyWith(color: color, fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: T.h3.copyWith(fontSize: 15, color: C.frozen))),
            ]),
            const SizedBox(height: 4),
            Text(body, style: T.body.copyWith(fontSize: 13, color: C.muted, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

/// A small living picture of each kind of problem, plus the hold-to-fix ring.
class _HazardPainter extends CustomPainter {
  final HazardKind kind;
  final double t;
  final double danger;
  final double hold;
  final Color color;
  _HazardPainter(this.kind, this.t, {required this.danger, required this.hold, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r - 2, Paint()..color = color.withValues(alpha: 0.1 + 0.08 * danger));
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final speed = 1 + danger * 2;
    switch (kind) {
      case HazardKind.gas:
        // a pipe venting puffs of gas
        canvas.drawLine(c + Offset(-r * 0.6, r * 0.25), c + Offset(-r * 0.1, r * 0.25), p..strokeWidth = 4);
        p.strokeWidth = 2;
        for (var k = 0; k < 4; k++) {
          final f = (t * 0.9 * speed + k / 4) % 1;
          final q = Paint()..color = color.withValues(alpha: 0.7 * (1 - f));
          canvas.drawCircle(c + Offset(-r * 0.05 + f * r * 0.6, r * 0.25 - f * r * 0.7 + math.sin(f * 9 + k) * 3), 2 + f * 7, q);
        }
      case HazardKind.spark:
        // a broken wire with jumping sparks
        canvas.drawLine(c + Offset(-r * 0.65, 0), c + Offset(-r * 0.12, 0), p..strokeWidth = 3);
        canvas.drawLine(c + Offset(r * 0.12, r * 0.08), c + Offset(r * 0.65, r * 0.08), p);
        p.strokeWidth = 1.6;
        final rnd = math.Random((t * 14 * speed).floor());
        for (var k = 0; k < 3; k++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final l = 4 + rnd.nextDouble() * 10;
          canvas.drawLine(c, c + Offset(math.cos(a) * l, math.sin(a) * l), p..color = Color.lerp(color, Colors.white, rnd.nextDouble())!);
        }
      case HazardKind.heat:
        // flickering heat flames
        for (var k = -1; k <= 1; k++) {
          final h = r * (0.45 + 0.2 * math.sin(t * 7 * speed + k * 2).abs());
          final base = c + Offset(k * r * 0.3, r * 0.45);
          final path = Path()
            ..moveTo(base.dx - 6, base.dy)
            ..quadraticBezierTo(base.dx - 7, base.dy - h * 0.6, base.dx + math.sin(t * 5 + k) * 3, base.dy - h)
            ..quadraticBezierTo(base.dx + 7, base.dy - h * 0.6, base.dx + 6, base.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = Color.lerp(color, const Color(0xFFFFE08A), 0.3 + 0.3 * k.abs())!.withValues(alpha: 0.85));
        }
      case HazardKind.signal:
        // radio waves that break up
        canvas.drawLine(c + Offset(0, r * 0.55), c + Offset(0, -r * 0.1), p..strokeWidth = 2.5);
        for (var k = 1; k <= 3; k++) {
          final on = math.sin(t * 6 * speed + k * 1.3) > -0.2;
          if (!on) continue;
          final rect = Rect.fromCircle(center: c + Offset(0, -r * 0.1), radius: k * r * 0.22);
          canvas.drawArc(rect, -math.pi * 0.8, math.pi * 0.6, false, p..strokeWidth = 1.8);
        }
      case HazardKind.gauge:
        // a gauge whose needle sinks into the red
        final rect = Rect.fromCircle(center: c + Offset(0, r * 0.2), radius: r * 0.55);
        canvas.drawArc(rect, math.pi, math.pi, false, p..strokeWidth = 3);
        canvas.drawArc(
            rect,
            math.pi,
            math.pi * 0.3,
            false,
            Paint()
              ..color = C.red
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke);
        final a = math.pi + math.pi * (0.9 - danger * 0.8) + math.sin(t * 9) * 0.05;
        canvas.drawLine(rect.center, rect.center + Offset(math.cos(a), math.sin(a)) * r * 0.5, p..color = Colors.white);
      case HazardKind.warn:
        // warning triangle (not arc wedges — those looked like a broken select ring)
        final pulse = 0.7 + 0.3 * math.sin(t * 5 * speed).abs();
        final path = Path()
          ..moveTo(c.dx, c.dy - r * 0.48)
          ..lineTo(c.dx + r * 0.48, c.dy + r * 0.4)
          ..lineTo(c.dx - r * 0.48, c.dy + r * 0.4)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: 0.25 * pulse)
              ..style = PaintingStyle.fill);
        canvas.drawPath(path, p..strokeWidth = 2.2);
        canvas.drawCircle(c + Offset(0, r * 0.18), 2.2, Paint()..color = color);
        canvas.drawLine(c + Offset(0, -r * 0.18), c + Offset(0, r * 0.02), p..strokeWidth = 2.4);
    }
    // selection / hold-to-fix ring — dim track + filling arc
    if (hold > 0) {
      final ring = Rect.fromCircle(center: c, radius: r - 2);
      canvas.drawCircle(
        c,
        r - 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
      canvas.drawArc(
        ring,
        -math.pi / 2,
        math.pi * 2 * hold.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HazardPainter old) => true;
}

// ======================================================================= CARGO

/// Split the materials between the shield wall and the spare parts by
/// dragging each bag or crate where it should go.
class CargoGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const CargoGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<CargoGame> createState() => _CargoGameState();
}

class _CargoGameState extends State<CargoGame> {
  late final int _total = widget.spec.total.toInt();
  late int _shield = (_total / 4).round();
  int _mistakes = 0;
  List<String> _problems = const [];
  bool _done = false;

  void _move(bool toShield) {
    if (_done) return;
    if (toShield && _shield < _total) _shield++;
    if (!toShield && _shield > 0) _shield--;
    widget.audio.play(Sfx.step, volume: 0.35);
    widget.audio.haptic(light: true);
    setState(() => _problems = const []);
  }

  void _confirm() {
    if (_done) return;
    final problems = materialsVerdict(_shield, _total).warnings;
    if (problems.isNotEmpty) {
      widget.audio.play(Sfx.fail, volume: 0.5);
      setState(() {
        _mistakes = math.min(2, _mistakes + 1);
        _problems = problems;
      });
      return;
    }
    widget.audio.play(Sfx.success, volume: 0.6);
    setState(() => _done = true);
    Timer(const Duration(milliseconds: 700), () => widget.onDone(GameResult(mistakes: _mistakes, data: {'shielding': _shield})));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final spares = _total - _shield;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _done ? 'Loaded and locked.' : (_problems.isEmpty ? null : _problems.join('\n')),
      statusColor: _done ? C.green : C.amber,
      footer: confirmButton('Confirm the load', _done ? null : _confirm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('DRAG BAGS ONTO THE ROOF, CRATES INTO THE BAY', style: T.label),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _bay(
              title: 'SHIELD WALL',
              sub: '$_shield bags of regolith',
              color: C.cyan,
              accept: false,
              child: CustomPaint(size: const Size.fromHeight(150), painter: _RoofPainter(_shield, _total)),
              units: _shield,
              unitIcon: Icons.shield_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bay(
              title: 'SPARE PARTS',
              sub: '$spares crates for the lander',
              color: C.violet,
              accept: true,
              child: CustomPaint(size: const Size.fromHeight(150), painter: _CratePainter(spares)),
              units: spares,
              unitIcon: Icons.settings_rounded,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Tip: tap a bag to move it to the other side.', style: T.bodySmall),
      ]),
    );
  }

  /// [accept] true: this bay accepts units coming from the shield wall.
  Widget _bay({required String title, required String sub, required Color color, required bool accept, required Widget child, required int units, required IconData unitIcon}) {
    return DragTarget<bool>(
      onWillAcceptWithDetails: (d) => d.data == accept && !_done,
      onAcceptWithDetails: (d) => _move(!accept),
      builder: (context, cand, _) => AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: cand.isNotEmpty ? 0.2 : 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: cand.isNotEmpty ? 0.9 : 0.35), width: cand.isNotEmpty ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: T.label.copyWith(color: color)),
          Text(sub, style: T.bodySmall.copyWith(fontSize: 11.5)),
          const SizedBox(height: 6),
          child,
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var k = 0; k < units; k++)
              Draggable<bool>(
                data: !accept,
                maxSimultaneousDrags: _done ? 0 : 1,
                feedback: _unit(unitIcon, color, lifted: true),
                childWhenDragging: Opacity(opacity: 0.25, child: _unit(unitIcon, color)),
                child: GestureDetector(onTap: () => _move(accept), child: _unit(unitIcon, color)),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _unit(IconData icon, Color color, {bool lifted = false}) => Material(
        color: Colors.transparent,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color.lerp(C.panelDeep, color, 0.35),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.7)),
            boxShadow: lifted ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))] : null,
          ),
          child: Icon(icon, size: 18, color: C.frozen),
        ),
      );
}

/// The habitat dome with sandbags piling up on the roof.
class _RoofPainter extends CustomPainter {
  final int bags;
  final int total;
  _RoofPainter(this.bags, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h - 8;
    final dome = Rect.fromLTWH(w * 0.1, base - h * 0.62, w * 0.8, h * 1.2);
    canvas.drawRect(Rect.fromLTWH(0, base, w, 8), Paint()..color = const Color(0xFF8E8A84));
    canvas.drawArc(dome, math.pi, math.pi, true, Paint()..color = const Color(0xFFE6E2DA));
    canvas.drawArc(
        dome,
        math.pi,
        math.pi,
        true,
        Paint()
          ..color = const Color(0xFF9C988F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // bags in rows over the dome
    final bag = Paint()..color = const Color(0xFFB9A98E);
    final seam = Paint()
      ..color = const Color(0xFF7D6E58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 0; k < bags; k++) {
      final a = math.pi + (k % 6 + 0.5) / 6 * math.pi;
      final row = k ~/ 6;
      final rr = dome.width / 2 + 7 + row * 11;
      final p = dome.center + Offset(math.cos(a) * rr, math.sin(a) * rr * (dome.height / dome.width));
      if (p.dy > base - 4) continue;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 22, height: 11), const Radius.circular(5));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.translate(-p.dx, -p.dy);
      canvas.drawRRect(r, bag);
      canvas.drawRRect(r, seam);
      canvas.restore();
    }
    // radiation arrows: blocked when the wall is thick enough
    final blocked = bags >= 5;
    final arrow = Paint()
      ..color = (blocked ? C.green : C.red).withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final x = w * (0.3 + k * 0.2);
      final end = blocked ? dome.top - 18 - (bags ~/ 6) * 10 : dome.top + 30;
      canvas.drawLine(Offset(x - 10, 4), Offset(x, end), arrow);
      if (blocked) canvas.drawCircle(Offset(x, end), 3, Paint()..color = C.green);
    }
  }

  @override
  bool shouldRepaint(covariant _RoofPainter old) => old.bags != bags;
}

/// The spare-parts bay with crates stacking up.
class _CratePainter extends CustomPainter {
  final int crates;
  _CratePainter(this.crates);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, h - 8, w, 8), Paint()..color = const Color(0xFF8E8A84));
    const cw = 30.0, ch = 24.0;
    final perRow = math.max(1, (w / (cw + 4)).floor());
    for (var k = 0; k < crates; k++) {
      final row = k ~/ perRow, col = k % perRow;
      final x = col * (cw + 4) + (row.isOdd ? cw / 2 : 0) + 2;
      final y = h - 8 - (row + 1) * (ch + 2);
      if (x + cw > w || y < 0) continue;
      final r = Rect.fromLTWH(x, y, cw, ch);
      canvas.drawRect(r, Paint()..color = const Color(0xFF6D6A8F));
      canvas.drawRect(
          r.deflate(3),
          Paint()
            ..color = const Color(0xFF9AA4FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      canvas.drawLine(
          r.topLeft + const Offset(3, 3),
          r.bottomRight - const Offset(3, 3),
          Paint()
            ..color = const Color(0xFF9AA4FF)
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant _CratePainter old) => old.crates != crates;
}

// ======================================================================= TANKS

/// Daily food and water: drag the level in each jar up or down.
class TankGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const TankGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<TankGame> createState() => _TankGameState();
}

class _TankGameState extends State<TankGame> with SingleTickerProviderStateMixin {
  double _food = 0.75;
  double _water = 2.8;
  int _mistakes = 0;
  List<String> _problems = const [];
  bool _done = false;
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_done) return;
    final problems = rationVerdict(foodPerDay: _food, waterPerDay: _water, foodStock: 8, waterStock: 30, days: rescueDays).problems;
    if (problems.isNotEmpty) {
      widget.audio.play(Sfx.fail, volume: 0.5);
      setState(() {
        _mistakes = math.min(2, _mistakes + 1);
        _problems = problems;
      });
      return;
    }
    widget.audio.play(Sfx.success, volume: 0.6);
    setState(() => _done = true);
    Timer(const Duration(milliseconds: 700), () => widget.onDone(GameResult(mistakes: _mistakes, data: {'food': _food, 'water': _water})));
  }

  @override
  Widget build(BuildContext context) {
    final v = rationVerdict(foodPerDay: _food, waterPerDay: _water, foodStock: 8, waterStock: 30, days: rescueDays);
    final need = rescueDays * 1.1;
    return GameFrame(
      spec: widget.spec,
      mistakes: _mistakes,
      status: _done ? 'Rations set.' : (_problems.isEmpty ? null : _problems.join('\n')),
      statusColor: _done ? C.green : C.amber,
      footer: confirmButton('Confirm rations', _done ? null : _confirm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('DRAG UP OR DOWN IN EACH JAR: HOW MUCH PER DAY?', style: T.label),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _jar('FOOD', _food, 0.3, 0.8, v.daysFood, need, const Color(0xFFFFC27A), (x) => _food = x)),
          const SizedBox(width: 12),
          Expanded(child: _jar('WATER', _water, 1.5, 3.0, v.daysWater, need, const Color(0xFF6FC8FF), (x) => _water = x)),
        ]),
        const SizedBox(height: 10),
        Text('Needed: $rescueDays days + 10% reserve = ${need.toStringAsFixed(1)} days', style: T.bodySmall),
      ]),
    );
  }

  Widget _jar(String label, double value, double min, double max, double lasts, double need, Color color, void Function(double) set) {
    final ok = lasts >= need;
    final f = (value - min) / (max - min);
    return LayoutBuilder(builder: (context, box) {
      const h = 190.0;
      void drag(double dy) {
        if (_done) return;
        final before = (value * 20).round();
        final nv = (value - dy / h * (max - min)).clamp(min, max).toDouble();
        set((nv * 100).round() / 100);
        if ((nv * 20).round() != before) widget.audio.typeClick();
        setState(() => _problems = const []);
      }

      return GestureDetector(
        onVerticalDragUpdate: (d) => drag(d.delta.dy),
        child: Column(children: [
          Text(label, style: T.label.copyWith(color: color)),
          const SizedBox(height: 6),
          SizedBox(
            height: h,
            width: double.infinity,
            child: AnimatedBuilder(animation: _wave, builder: (context, _) => CustomPaint(painter: _JarPainter(f, color, _wave.value))),
          ),
          const SizedBox(height: 6),
          Text('${value.toStringAsFixed(2)} kg/day', style: T.h3.copyWith(fontSize: 15)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 15, color: ok ? C.green : C.red),
            const SizedBox(width: 4),
            Text('lasts ${lasts.isFinite ? lasts.toStringAsFixed(1) : '∞'} d', style: T.bodySmall.copyWith(color: ok ? C.green : C.red)),
          ]),
        ]),
      );
    });
  }
}

class _JarPainter extends CustomPainter {
  final double fill;
  final Color color;
  final double t;
  _JarPainter(this.fill, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width, 110.0);
    final jar = RRect.fromRectAndRadius(Rect.fromCenter(center: size.center(Offset.zero), width: w, height: size.height - 6), const Radius.circular(22));
    canvas.drawRRect(jar, Paint()..color = C.panelDeep);
    canvas.save();
    canvas.clipRRect(jar);
    final top = jar.bottom - (jar.height - 10) * fill.clamp(0.02, 1.0) - 6;
    final path = Path()..moveTo(jar.left, top);
    for (var x = 0.0; x <= w; x += 6) {
      path.lineTo(jar.left + x, top + math.sin(x / w * math.pi * 2 + t * math.pi * 2) * 3);
    }
    path
      ..lineTo(jar.right, jar.bottom)
      ..lineTo(jar.left, jar.bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, Color.lerp(color, Colors.black, 0.35)!]).createShader(jar.outerRect),
    );
    // bubbles
    for (var k = 0; k < 5; k++) {
      final f = (t + k / 5) % 1;
      final y = jar.bottom - f * (jar.bottom - top);
      canvas.drawCircle(Offset(jar.left + w * (0.2 + 0.15 * k), y), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.3 * (1 - f)));
    }
    canvas.restore();
    canvas.drawRRect(
        jar,
        Paint()
          ..color = C.frozen.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // glass shine and a grab handle on the surface
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(jar.left + 8, jar.top + 14, 6, jar.height * 0.5), const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(jar.center.dx, top), width: 36, height: 8), const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) => true;
}

// ======================================================================= KNOBS & GAUGES

/// A dial you twist with your finger. Each step gives a soft click.
class Knob extends StatelessWidget {
  final double value, min, max, step;
  final String label;
  final String text;
  final Color color;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onClick;
  final double size;
  const Knob({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.text,
    this.color = C.cyan,
    this.onChanged,
    this.onClick,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      RotaryDial(
        value: value,
        min: min,
        max: max,
        step: step,
        size: size,
        color: color,
        onChanged: onChanged,
        onStep: onClick,
        onClamp: onClick,
      ),
      const SizedBox(height: 2),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _nudge(Icons.remove_rounded, onChanged == null ? null : () {
          final v = (value - step).clamp(min, max).toDouble();
          final snapped = (v / step).round() * step;
          final next = snapped.clamp(min, max).toDouble();
          if (next != value) {
            onClick?.call();
            onChanged!(next);
          }
        }),
        const SizedBox(width: 6),
        _nudge(Icons.add_rounded, onChanged == null ? null : () {
          final v = (value + step).clamp(min, max).toDouble();
          final snapped = (v / step).round() * step;
          final next = snapped.clamp(min, max).toDouble();
          if (next != value) {
            onClick?.call();
            onChanged!(next);
          }
        }),
      ]),
      const SizedBox(height: 4),
      Text(text, style: T.mono.copyWith(color: color, fontSize: 13)),
      Text(label, style: T.bodySmall.copyWith(fontSize: 11), textAlign: TextAlign.center, maxLines: 2),
    ]);
  }

  Widget _nudge(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.panelDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.line),
          ),
          child: Icon(icon, size: 16, color: onTap == null ? C.dim : color),
        ),
      );
}

/// A needle gauge for one SIM result: green when safe, red when not.
class Gauge extends StatefulWidget {
  final String label;
  final String text;

  /// null: just information (no safe zone).
  final bool? ok;
  final double size;
  const Gauge({super.key, required this.label, required this.text, this.ok, this.size = 92});

  @override
  State<Gauge> createState() => _GaugeState();
}

class _GaugeState extends State<Gauge> with SingleTickerProviderStateMixin {
  late final AnimationController _needle = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: _target);

  double get _target => widget.ok == null ? 0.5 : (widget.ok! ? 0.72 : 0.18);

  @override
  void didUpdateWidget(covariant Gauge old) {
    super.didUpdateWidget(old);
    if (old.ok != widget.ok) _needle.animateTo(_target, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _needle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.ok == null ? C.muted : (widget.ok! ? C.green : C.red);
    return SizedBox(
      width: widget.size,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: widget.size,
          height: widget.size * 0.6,
          child: AnimatedBuilder(animation: _needle, builder: (context, _) => CustomPaint(painter: _GaugePainter(_needle.value, info: widget.ok == null))),
        ),
        Text(widget.text, style: T.mono.copyWith(color: col, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(widget.label, style: T.bodySmall.copyWith(fontSize: 10.5), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final bool info;
  _GaugePainter(this.v, {required this.info});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 4);
    final r = math.min(size.width / 2, size.height) - 4;
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint band(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    if (info) {
      canvas.drawArc(rect, math.pi, math.pi, false, band(C.lineSoft));
    } else {
      canvas.drawArc(rect, math.pi, math.pi * 0.42, false, band(C.red.withValues(alpha: 0.7)));
      canvas.drawArc(rect, math.pi * 1.42, math.pi * 0.58, false, band(C.green.withValues(alpha: 0.7)));
    }
    final a = math.pi + math.pi * v.clamp(-0.05, 1.05);
    canvas.drawLine(
        c,
        c + Offset(math.cos(a), math.sin(a)) * (r - 4),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.v != v;
}
