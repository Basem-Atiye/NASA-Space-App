/// The design's astronaut (Figma "Junior Astronaut Mission Trainer"): a
/// friendly round helmet with a deep blue visor, a mint-white suit, orange
/// gloves and boots, a blue collar and a chest panel with three lights.
///
/// [paintAstronaut] draws the whole body (splash, results, cutscenes);
/// [paintAstroHead] draws just the helmet (crew list, portraits);
/// [AstronautFigure] is an animated widget (floats, waves, blinks lights).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AstroColors {
  AstroColors._();
  static const suit = Color(0xFFF2FFF8);
  static const suitShade = Color(0xFFDCEDE6);
  static const grey = Color(0xFFB9CBC6); // helmet ring, backpack, belt
  static const visorTop = Color(0xFF4A63F2);
  static const visorBottom = Color(0xFF1C2580);
  static const collar = Color(0xFF405FFA);
  static const panel = Color(0xFF4A4378);
  static const orange = Color(0xFFFF8A3D);
  static const cyan = Color(0xFF0ABCCA);
  static const green = Color(0xFF3DDC97);
}

Paint _p(Color c) => Paint()..color = c;

void _capsule(Canvas c, Offset a, Offset b, double w, Color color) {
  c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round,
  );
}

/// The whole astronaut, upright, centred on its chest, about 300 units tall
/// (helmet top at −205, boots at +245). [wave] 0..1 lifts the left arm,
/// [kick] −1..1 swings the legs, [lights] 0..1 pulses the chest lights,
/// [look] turns the visor shine.
void paintAstronaut(Canvas c, {double wave = 1, double kick = 0, double lights = 1, double look = 0, Color? suitTint}) {
  final suit = suitTint ?? AstroColors.suit;
  // backpack (behind everything, peeking out on the right)
  c.drawRRect(RRect.fromLTRBR(-70, -12, 122, 152, const Radius.circular(42)), _p(AstroColors.grey));

  // far (right) arm, resting
  final shoulderR = const Offset(78, 22);
  final handR = Offset(132, 96 + kick * 4);
  _capsule(c, shoulderR, handR, 58, suit);
  c.drawCircle(handR + const Offset(6, 4), 25, _p(AstroColors.orange));

  // legs and boots (kick swings them in opposite directions)
  final lk = kick * 10, rk = -kick * 10;
  c.save();
  c.translate(-30, 120);
  c.rotate(lk * 0.012);
  c.drawRRect(RRect.fromLTRBR(-25, 0, 25, 100, const Radius.circular(16)), _p(suit));
  c.drawRRect(RRect.fromLTRBR(-34, 80, 36, 124, const Radius.circular(16)), _p(AstroColors.orange));
  c.restore();
  c.save();
  c.translate(40, 112);
  c.rotate(rk * 0.012);
  c.drawRRect(RRect.fromLTRBR(-25, 0, 25, 92, const Radius.circular(16)), _p(suit));
  c.drawRRect(RRect.fromLTRBR(-30, 72, 40, 116, const Radius.circular(16)), _p(AstroColors.orange));
  c.restore();

  // torso
  c.drawRRect(RRect.fromLTRBR(-86, -14, 96, 146, const Radius.circular(52)), _p(suit));
  // belt
  c.save();
  c.translate(10, 104);
  c.rotate(-0.06);
  c.drawRRect(RRect.fromLTRBR(-80, -10, 80, 10, const Radius.circular(10)), _p(AstroColors.grey));
  c.restore();
  // chest panel with three lights
  c.drawRRect(RRect.fromLTRBR(-28, 16, 56, 70, const Radius.circular(12)), _p(AstroColors.panel));
  final glow = 0.75 + 0.25 * lights;
  c.drawCircle(const Offset(-6, 44), 8.5, _p(AstroColors.cyan.withValues(alpha: glow)));
  c.drawCircle(const Offset(16, 42), 8.5, _p(AstroColors.orange.withValues(alpha: 0.75 + 0.25 * (1 - lights))));
  c.drawRRect(RRect.fromLTRBR(30, 32, 46, 48, const Radius.circular(4)), _p(AstroColors.green.withValues(alpha: glow)));

  // near (left) arm: swings on the outer side only, from down-left (0) to raised up-left (1),
  // so the hand never passes behind the helmet
  final shoulderL = const Offset(-66, 16);
  final w = wave.clamp(0.0, 1.0);
  final ang = -3.7 + w * 1.2;
  final handL = shoulderL + Offset(math.cos(ang), math.sin(ang)) * 96;
  _capsule(c, shoulderL, handL, 56, suit);
  c.drawCircle(handL + Offset(math.cos(ang) * 6, math.sin(ang) * 6), 27, _p(AstroColors.orange));

  // collar
  c.save();
  c.translate(6, 0);
  c.rotate(-0.05);
  c.drawRRect(RRect.fromLTRBR(-62, -10, 62, 10, const Radius.circular(10)), _p(AstroColors.collar));
  c.restore();

  // antenna
  c.drawLine(const Offset(58, -182), const Offset(64, -214), Paint()
    ..color = AstroColors.grey
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round);
  c.drawCircle(const Offset(64, -216), 11, _p(AstroColors.orange));

  paintAstroHelmet(c, const Offset(0, -98), 108, look: look);
}

/// The helmet alone at [center] with outer radius [r] (ring, white shell,
/// tilted deep-blue visor with its shine).
void paintAstroHelmet(Canvas c, Offset center, double r, {double look = 0}) {
  c.drawCircle(center, r, _p(AstroColors.grey));
  c.drawCircle(center + Offset(-r * 0.03, r * 0.03), r * 0.9, _p(AstroColors.suit));
  c.save();
  c.translate(center.dx + r * 0.02 + look * r * 0.06, center.dy + r * 0.08);
  c.rotate(-0.09);
  final visor = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.02), Radius.circular(r * 0.46));
  c.drawRRect(
    visor,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.9, -1),
        end: Alignment(0.9, 1),
        colors: [AstroColors.visorTop, Color(0xFF2E3FB8), AstroColors.visorBottom],
        stops: [0, 0.5, 1],
      ).createShader(visor.outerRect),
  );
  // the shine: a soft curved stroke top-left and a little dot bottom-right
  final shine = Path()
    ..moveTo(-r * 0.5, -r * 0.12)
    ..quadraticBezierTo(-r * 0.46, -r * 0.34, -r * 0.18, -r * 0.38);
  c.drawPath(
    shine,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round,
  );
  c.drawCircle(Offset(r * 0.5, r * 0.2), r * 0.075, _p(Colors.white.withValues(alpha: 0.5)));
  c.restore();
}

/// A crew portrait: the helmet filling a [size] square.
void paintAstroHead(Canvas c, Size size, {double look = 0}) {
  final r = size.shortestSide / 2;
  paintAstroHelmet(c, size.center(Offset.zero), r * 0.96, look: look);
}

class AstroHeadPainter extends CustomPainter {
  final double look;
  AstroHeadPainter({this.look = 0});
  @override
  void paint(Canvas canvas, Size size) => paintAstroHead(canvas, size, look: look);
  @override
  bool shouldRepaint(covariant AstroHeadPainter old) => old.look != look;
}

/// The animated astronaut: floats gently, waves, the chest lights pulse.
class AstronautFigure extends StatefulWidget {
  final double size; // height
  final bool waving;
  final bool floating;
  final double tilt;
  final bool animate;
  const AstronautFigure({super.key, this.size = 260, this.waving = true, this.floating = true, this.tilt = -0.2, this.animate = true});

  @override
  State<AstronautFigure> createState() => _AstronautFigureState();
}

class _AstronautFigureState extends State<AstronautFigure> with SingleTickerProviderStateMixin {
  // Calm loop: float + one friendly wave.
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant AstronautFigure old) {
    super.didUpdateWidget(old);
    if (widget.animate != old.animate) _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-assert after inherited ticker mode / media-query settles.
    _syncTicker();
  }

  void _syncTicker() {
    final allow = widget.animate && TickerMode.of(context);
    if (allow) {
      if (!_a.isAnimating) _a.repeat();
    } else if (_a.isAnimating) {
      _a.stop();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size(widget.size * 0.95, widget.size),
          // Listenable repaint — more reliable on Flutter web than rebuild-only.
          painter: _AstroPainter(_a, widget),
        ),
      );
}

/// Shared idle motion used by [AstronautFigure] and the welcome stage.
void paintAstronautIdle(Canvas canvas, Size size, double t, {required double tilt, required bool waving, required bool floating}) {
  final a = t * math.pi * 2;
  final s = size.height / 480;
  canvas.save();
  // Soft zero-g bob — slow and small so it never looks frantic.
  final bob = floating ? math.sin(a) * 9 * s : 0.0;
  final drift = floating ? math.sin(a * 0.5 + 0.8) * 3 * s : 0.0;
  canvas.translate(size.width / 2 + drift, size.height * 0.52 + bob);
  final breath = floating ? 1 + math.sin(a) * 0.008 : 1.0;
  canvas.scale(s * breath);
  canvas.rotate(tilt + (floating ? math.sin(a + 0.6) * 0.022 : 0));
  paintAstronaut(
    canvas,
    // Keep the waving arm in the raised “hello” zone (never collapsed into the hip).
    wave: waving ? astronautWave(t) : 0.62 + 0.04 * math.sin(a),
    kick: floating ? math.sin(a) * 0.22 : 0,
    lights: 0.55 + 0.45 * math.sin(a * 2),
    look: math.sin(a * 0.7) * 0.35,
  );
  canvas.restore();
}

/// One calm greeting per loop. Wave stays in ~0.6–1.0 so the hand reads as a hello, not a flail.
double astronautWave(double t) {
  final k = t % 1.0;
  if (k < 0.18) {
    return 0.62 + 0.38 * Curves.easeOutCubic.transform(k / 0.18);
  }
  if (k < 0.48) {
    final wiggle = (k - 0.18) / 0.3;
    return 0.87 + 0.13 * math.cos(wiggle * math.pi * 4);
  }
  if (k < 0.62) {
    return 1.0 - 0.32 * Curves.easeInOut.transform((k - 0.48) / 0.14);
  }
  return 0.68 + 0.04 * math.sin(t * math.pi * 2);
}

class _AstroPainter extends CustomPainter {
  final Animation<double> animation;
  final AstronautFigure w;
  _AstroPainter(this.animation, this.w) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    paintAstronautIdle(canvas, size, animation.value, tilt: w.tilt, waving: w.waving, floating: w.floating);
  }

  @override
  bool shouldRepaint(covariant _AstroPainter old) => old.animation != animation || old.w != w;
}
