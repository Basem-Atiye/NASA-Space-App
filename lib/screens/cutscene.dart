/// Letterboxed cutscenes: the crash landing that opens the story and the
/// lift-off that ends it. Animated layers, live numbers, subtitles, Skip.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';
import '../world/world_art.dart';

class _Sub {
  final double at;
  final String who;
  final String text;
  const _Sub(this.at, this.who, this.text);
}

enum CutsceneKind { arrival, launch }

class Cutscene extends StatefulWidget {
  final CutsceneKind kind;
  final VoidCallback onDone;
  final bool reducedMotion;
  const Cutscene({super.key, required this.kind, required this.onDone, this.reducedMotion = false});

  @override
  State<Cutscene> createState() => _CutsceneState();
}

class _CutsceneState extends State<Cutscene> with SingleTickerProviderStateMixin {
  late final double _length = widget.kind == CutsceneKind.arrival ? 13.5 : 10.5;
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: (_length * 1000).round()));
  bool _done = false;
  bool _shook = false;

  static const _arrival = [
    _Sub(0.6, 'CAPCOM', 'Nova, you are GO for landing. Shackleton rim in sight.'),
    _Sub(3.6, 'CAPCOM', 'Nova, we’re seeing a warning on landing radar. Hold steady…'),
    _Sub(6.4, 'NOVA', 'Radar’s gone! I’m landing by eye!'),
    _Sub(8.6, 'ARIA', 'Hard landing. Cabin leak detected. Suit oxygen 55%.'),
    _Sub(11.0, 'CAPCOM', 'Nova? Nova, do you read? …Signal lost.'),
  ];

  static const _launch = [
    _Sub(0.4, 'ARIA', 'Ascent engine armed. Gateway in position.'),
    _Sub(2.2, 'CAPCOM', 'Lift-off! Nova Haddad is going home.'),
    _Sub(5.2, 'NOVA', 'Goodbye, Shackleton. Thank you, Pip. Thank you, team.'),
    _Sub(8.0, 'CAPCOM', 'Orbit insertion good. Welcome back, Commander.'),
  ];

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward();
  }

  void _onTick() {
    final t = _c.value * _length;
    if (widget.kind == CutsceneKind.arrival && t > 8.0 && !_shook) {
      _shook = true;
      HapticFeedback.heavyImpact();
    }
    if (_c.isCompleted) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subs = widget.kind == CutsceneKind.arrival ? _arrival : _launch;
    return Material(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * _length;
          _Sub? sub;
          for (final s in subs) {
            if (t >= s.at) sub = s;
          }
          final bars = (t / 0.35).clamp(0.0, 1.0);
          final fadeOut = ((t - (_length - 0.6)) / 0.6).clamp(0.0, 1.0);
          return Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: widget.kind == CutsceneKind.arrival ? _ArrivalPainter(t, widget.reducedMotion) : _LaunchPainter(t, widget.reducedMotion)),
            // film bars slide in
            Positioned(top: 0, left: 0, right: 0, height: 64 * Curves.easeOut.transform(bars), child: const ColoredBox(color: Colors.black)),
            Positioned(bottom: 0, left: 0, right: 0, height: 64 * Curves.easeOut.transform(bars), child: const ColoredBox(color: Colors.black)),
            SafeArea(
              child: Stack(children: [
                Positioned(left: 24, top: 40, right: 100, child: _header(t)),
                Positioned(
                  right: 16,
                  top: 8,
                  child: GestureDetector(
                    onTap: _finish,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        GameText('Skip', style: T.h3.copyWith(fontSize: 13)),
                        const SizedBox(width: 6),
                        const Icon(Icons.fast_forward_rounded, size: 16, color: C.frozen),
                      ]),
                    ),
                  ),
                ),
                if (sub != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 80,
                    child: AnimatedSwitcher(
                      duration: Motion.normal,
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a), child: c)),
                      child: Container(
                        key: ValueKey(sub.text),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(color: C.indigo.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${sub.who}: ', style: T.h3.copyWith(color: sub.who == 'NOVA' ? C.frozen : C.cyan, fontSize: 14)),
                            TextSpan(text: sub.text),
                          ]),
                          style: T.body,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            if (fadeOut > 0) IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: fadeOut))),
          ]);
        },
      ),
    );
  }

  Widget _header(double t) {
    if (widget.kind == CutsceneKind.arrival) {
      final k = (t / 8.0).clamp(0.0, 1.0);
      final alt = (1240 * math.pow(1 - k, 1.6)).round();
      final vs = t < 8 ? (-18 - 6 * k) : 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GameText('DAY 1 · POWERED DESCENT', style: T.label.copyWith(letterSpacing: 3)),
        const SizedBox(height: 4),
        GameText(t < 8 ? 'Touchdown in ${math.max(0, (8 - t) * 11).round()} s' : 'Contact', style: T.h1.copyWith(fontFamily: F.display, fontSize: 24, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          const GameText('ALT ', style: T.bodySmall),
          GameText('${_thousands(alt)} m', style: T.h3.copyWith(fontSize: 13, color: Colors.white)),
          const SizedBox(width: 14),
          const GameText('V/S ', style: T.bodySmall),
          GameText('${vs.toStringAsFixed(0)} m/s', style: T.h3.copyWith(fontSize: 13, color: t > 3.6 && t < 8 ? C.red : C.cyan)),
          if (t > 3.6 && t < 8) ...[
            const SizedBox(width: 14),
            GameText('RADAR FAULT', style: T.label.copyWith(color: C.red)),
          ],
        ]),
      ]);
    }
    final alt = t < 2 ? 0 : (0.5 * 9 * math.pow(t - 2, 2.2)).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GameText('DAY 12 · LIFT-OFF', style: T.label.copyWith(letterSpacing: 3)),
      const SizedBox(height: 4),
      GameText('Going home', style: T.h1.copyWith(fontSize: 26)),
      const SizedBox(height: 8),
      Row(children: [
        const GameText('ALT ', style: T.bodySmall),
        GameText('${_thousands(alt)} m', style: T.h3.copyWith(fontSize: 13, color: Colors.white)),
        const SizedBox(width: 14),
        const GameText('TO GATEWAY ', style: T.bodySmall),
        GameText('GO', style: T.h3.copyWith(fontSize: 13, color: C.cyan)),
      ]),
    ]);
  }

  static String _thousands(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

// ---------------------------------------------------------------- shared sky

void _sky(Canvas c, Size s, double t, {double earthY = 0.24, double drift = 0}) {
  final r = Offset.zero & s;
  c.drawRect(r, Paint()..shader = const RadialGradient(center: Alignment(-0.6, -0.7), radius: 1.4, colors: [Color(0xFF2A2752), Color(0xFF0A1331)]).createShader(r));
  final rnd = math.Random(5);
  final p = Paint()..color = Colors.white;
  for (var i = 0; i < 70; i++) {
    final x = rnd.nextDouble() * s.width;
    final y = (rnd.nextDouble() * s.height * 0.75 + drift * (0.3 + rnd.nextDouble() * 0.4)) % (s.height * 0.8);
    p.color = Colors.white.withValues(alpha: 0.4 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 + i)));
    c.drawCircle(Offset(x, y), i % 9 == 0 ? 1.3 : 0.8, p);
  }
  // the Sun low on the right, with a soft halo
  final sun = Offset(s.width * 0.97, s.height * 0.56 + drift * 0.3);
  c.drawCircle(sun, s.width * 0.3, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFF6DD).withValues(alpha: 0.55), const Color(0xFFD9FCED).withValues(alpha: 0.18), const Color(0x00D9FCED)], stops: const [0, 0.3, 1]).createShader(Rect.fromCircle(center: sun, radius: s.width * 0.3)));
  c.drawCircle(sun, s.width * 0.055, Paint()..color = const Color(0xFFFFFBEF));
  // Earth
  final e = Offset(s.width * 0.8, s.height * earthY + drift * 0.15);
  final er = s.width * 0.09;
  c.drawCircle(e, er * 1.2, Paint()..shader = RadialGradient(colors: [const Color(0xFF7FC8FF).withValues(alpha: 0.3), const Color(0x007FC8FF)]).createShader(Rect.fromCircle(center: e, radius: er * 1.2)));
  c.drawCircle(e, er, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFF5CBCFF), Color(0xFF0E3A86)]).createShader(Rect.fromCircle(center: e, radius: er)));
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: e, radius: er)));
  c.drawPath(
    Path()
      ..moveTo(e.dx - er * 0.45, e.dy - er * 0.4)
      ..cubicTo(e.dx - er * 0.1, e.dy - er * 0.7, e.dx + er * 0.3, e.dy - er * 0.2, e.dx + er * 0.1, e.dy + er * 0.1)
      ..cubicTo(e.dx - er * 0.1, e.dy + er * 0.3, e.dx - er * 0.5, e.dy, e.dx - er * 0.45, e.dy - er * 0.4),
    Paint()..color = const Color(0xFF4F9F55),
  );
  c.drawCircle(e + Offset(-er * 0.7, 0), er * 1.02, Paint()..color = const Color(0xFF020510).withValues(alpha: 0.7));
  c.restore();
}

void _limb(Canvas c, Size s, double top, double t) {
  final r = Rect.fromCenter(center: Offset(s.width / 2, top + s.width * 1.45), width: s.width * 2.9, height: s.width * 2.9);
  c.drawOval(r, Paint()..shader = const RadialGradient(center: Alignment(0, -1), radius: 1.0, colors: [Color(0xFFEBE8E1), Color(0xFFAAA69E), Color(0xFF4D4A46), Color(0xFF121110)], stops: [0, 0.18, 0.5, 1]).createShader(r));
  final p = Paint()..color = const Color(0xFF6B6762).withValues(alpha: 0.55);
  final hi = Paint()..color = const Color(0xFFDDD8CF).withValues(alpha: 0.55);
  for (final (x, y, w) in [(0.2, 0.06, 0.2), (0.72, 0.08, 0.17), (0.44, 0.15, 0.28), (0.85, 0.2, 0.13)]) {
    final cr = Rect.fromCenter(center: Offset(s.width * x, top + s.width * y), width: s.width * w, height: s.width * w * 0.25);
    c.drawOval(cr, p);
    c.drawOval(Rect.fromLTWH(cr.left, cr.top - 1, cr.width, cr.height * 0.35), hi);
  }
}

void _plume(Canvas c, Offset nozzle, double scale, double t, double strength) {
  if (strength <= 0) return;
  final flick = 0.85 + 0.15 * math.sin(t * 40);
  final h = 70 * scale * strength * flick;
  final w = 26 * scale;
  final r = Rect.fromLTWH(nozzle.dx - w, nozzle.dy, w * 2, h);
  c.drawPath(
    Path()
      ..moveTo(nozzle.dx - w * 0.5, nozzle.dy)
      ..cubicTo(nozzle.dx - w * 0.9, nozzle.dy + h * 1.25, nozzle.dx + w * 0.9, nozzle.dy + h * 1.25, nozzle.dx + w * 0.5, nozzle.dy)
      ..close(),
    Paint()..shader = const RadialGradient(center: Alignment(0, -1), radius: 1.0, colors: [Colors.white, Color(0xFFFFE2A8), Color(0x99FF9A3C), Color(0x00405FFA)], stops: [0, 0.25, 0.6, 1]).createShader(r),
  );
  c.drawPath(
    Path()
      ..moveTo(nozzle.dx - w * 0.22, nozzle.dy)
      ..cubicTo(nozzle.dx - w * 0.3, nozzle.dy + h * 0.7, nozzle.dx + w * 0.3, nozzle.dy + h * 0.7, nozzle.dx + w * 0.22, nozzle.dy)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );
}

class _ArrivalPainter extends CustomPainter {
  final double t;
  final bool reduced;
  _ArrivalPainter(this.t, this.reduced);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 390;
    final landed = t >= 8.0;
    final shake = !reduced && t > 8.0 && t < 8.7 ? (8.7 - t) * 14 * u : 0.0;
    c.save();
    c.translate(math.sin(t * 70) * shake, math.cos(t * 53) * shake * 0.6);
    _sky(c, s, t);
    final groundTop = s.height * 0.73;
    _limb(c, s, groundTop, t);

    // the lander drops from above with its engine burning
    final k = (t / 8.0).clamp(0.0, 1.0);
    final ease = 1 - math.pow(1 - k, 2.2).toDouble();
    final y = -s.height * 0.1 + (groundTop + 20 * u + s.height * 0.1) * ease;
    final sway = landed ? 0.0 : math.sin(t * 1.7) * 0.04 + (t > 3.6 ? math.sin(t * 5) * 0.05 : 0);
    final tilt = landed ? -0.12 * Curves.easeOutBack.transform(((t - 8) / 0.5).clamp(0.0, 1.0)) : sway;
    final scale = 1.25 * u;
    // dust blown out as the engine nears the ground
    final near = ((t - 5.5) / 2.5).clamp(0.0, 1.0);
    if (near > 0 && !landed) {
      final dr = Rect.fromCenter(center: Offset(s.width / 2, groundTop + 26 * u), width: 300 * u * near, height: 40 * u * near);
      c.drawOval(dr, Paint()..shader = RadialGradient(colors: [const Color(0xFFD8D1C3).withValues(alpha: 0.7), const Color(0x00D8D1C3)]).createShader(dr));
    }
    c.save();
    c.translate(s.width / 2, y);
    c.rotate(tilt);
    c.scale(scale);
    if (!landed) _plume(c, const Offset(0, -14), 1, t, 1 - near * 0.3);
    paintLander(c, t, tilt: 0);
    c.restore();
    // touchdown: a burst of dust and sparks
    if (landed) {
      final a = (1 - (t - 8) / 2.5).clamp(0.0, 1.0);
      final dr = Rect.fromCenter(center: Offset(s.width / 2, groundTop + 22 * u), width: 380 * u * (1.3 - a * 0.3), height: 70 * u);
      c.drawOval(dr, Paint()..shader = RadialGradient(colors: [const Color(0xFFD8D1C3).withValues(alpha: 0.8 * a), const Color(0x00D8D1C3)]).createShader(dr));
      final rnd = math.Random(3);
      final sp = Paint()
        ..color = const Color(0xFFFFD59A).withValues(alpha: a)
        ..strokeWidth = 1.6 * u
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 14; i++) {
        final ang = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 2.6;
        final d = (t - 8) * (90 + rnd.nextDouble() * 120) * u;
        final o = Offset(s.width / 2 + 10 * u, groundTop - 50 * u) + Offset(math.cos(ang), math.sin(ang)) * d;
        c.drawLine(o, o + Offset(math.cos(ang), math.sin(ang)) * 8 * u, sp);
      }
      if (t < 8.25) c.drawRect(Offset.zero & s, Paint()..color = Colors.white.withValues(alpha: (8.25 - t) * 2.4));
    }
    c.restore();
    // the alarm wash after the hard landing
    if (t > 8.4) {
      final a = 0.12 + 0.1 * (0.5 + 0.5 * math.sin(t * 5));
      c.drawRect(Offset.zero & s, Paint()..shader = RadialGradient(radius: 0.95, colors: [Colors.transparent, const Color(0xFFFF4D5A).withValues(alpha: a)], stops: const [0.55, 1]).createShader(Offset.zero & s));
    }
  }

  @override
  bool shouldRepaint(covariant _ArrivalPainter old) => old.t != t;
}

class _LaunchPainter extends CustomPainter {
  final double t;
  final bool reduced;
  _LaunchPainter(this.t, this.reduced);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 390;
    final rise = t < 2 ? 0.0 : 9 * math.pow(t - 2, 2.1).toDouble(); // design units
    // the camera follows the ascent stage, so the ground slides away
    final cam = math.min(rise * u * 0.85, s.height * 1.4);
    final shake = !reduced && t > 1.8 && t < 3.6 ? (3.6 - t) * 4 * u : 0.0;
    c.save();
    c.translate(math.sin(t * 70) * shake, 0);
    _sky(c, s, t, earthY: 0.2, drift: cam * 0.12);
    final groundTop = s.height * 0.73 + cam;
    c.save();
    _limb(c, s, groundTop, t);
    // the base far away to the left
    c.save();
    c.translate(s.width * 0.16, groundTop + 6 * u);
    c.scale(0.5 * u);
    paintHabitat(c, t, bags: 6, sensors: true);
    c.restore();
    c.save();
    c.translate(s.width * 0.32, groundTop + 2 * u);
    c.scale(0.45 * u);
    paintPanels(c, t);
    c.restore();
    // the flame first, so the descent stage (the launch pad) stays in front of it
    final ay = groundTop + 22 * u - rise * u;
    if (t > 1.6) {
      c.save();
      c.translate(s.width / 2, ay);
      c.scale(1.25 * u);
      _plume(c, const Offset(0, -61), 0.8, t, ((t - 1.6) / 0.4).clamp(0.0, 1.0) * (1 + math.min(1.0, (t - 2) / 3)));
      c.restore();
    }
    c.save();
    c.translate(s.width / 2, groundTop + 22 * u);
    c.scale(1.25 * u);
    paintLander(c, t, descentOnly: true, repaired: true);
    c.restore();
    c.restore();
    // ascent stage
    c.save();
    c.translate(s.width / 2, ay);
    c.scale(1.25 * u);
    paintAscentStage(c, t);
    c.restore();
    // dust blast at lift-off
    if (t > 1.8 && t < 5) {
      final a = (1 - (t - 1.8) / 3.2).clamp(0.0, 1.0);
      final dr = Rect.fromCenter(center: Offset(s.width / 2, groundTop + 20 * u), width: 420 * u * (1.4 - a * 0.4), height: 70 * u);
      c.drawOval(dr, Paint()..shader = RadialGradient(colors: [const Color(0xFFD8D1C3).withValues(alpha: 0.75 * a), const Color(0x00D8D1C3)]).createShader(dr));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _LaunchPainter old) => old.t != t;
}
