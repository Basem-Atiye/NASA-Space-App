/// Nova and Pip, drawn in code so they can animate smoothly at any size.
///
/// Both are drawn in a 100-unit tall box with the origin at Nova's feet,
/// facing right; callers translate and scale (negative x scale to face left).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

enum NovaAction { idle, walk, work, kneel, cheer, scared, wave, carry, sit }

enum NovaMood { calm, happy, worried, scared, tired }

class NovaPose {
  final NovaAction action;
  final NovaMood mood;

  /// Walk cycle phase (radians-ish, any growing number).
  final double phase;

  /// Seconds, for breathing and idle motion.
  final double t;

  /// Visor up shows her face (inside the base, or when she lifts it).
  final bool visorUp;

  /// 0..1 how strongly the action is applied (for blending).
  final double blend;

  /// Talking: the head nods gently.
  final bool talking;

  /// In the air (bounding or jumping): legs held in a long stride.
  final bool air;

  /// Bounding: leaning forward into the run.
  final bool sprint;

  /// 0..1 just after landing: knees soak up the impact.
  final double land;

  /// Vertical speed in m/s. Positive is rising, negative is falling.
  final double rise;

  const NovaPose({
    this.action = NovaAction.idle,
    this.mood = NovaMood.calm,
    this.phase = 0,
    this.t = 0,
    this.visorUp = false,
    this.blend = 1,
    this.talking = false,
    this.air = false,
    this.sprint = false,
    this.land = 0,
    this.rise = 0,
  });
}

// palette for the suit (real objects keep real colours)
// The Figma astronaut's colours: mint-white suit, grey-green details,
// orange gloves and boots, a deep blue visor.
const _suit = Color(0xFFF2FFF8);
const _suitShade = Color(0xFFDCEDE6);
const _suitDeep = Color(0xFFB9CBC6);
const _joint = Color(0xFFB9CBC6);
const _boot = Color(0xFFFF8A3D);
const _glove = Color(0xFFFF8A3D);
const _gloveFar = Color(0xFFE0782F);
const _skin = Color(0xFFC99872);
const _hair = Color(0xFF2B1D16);
const _goldA = Color(0xFF4A63F2); // the visor (blue in the design)
const _goldB = Color(0xFF2E3FB8);
const _goldC = Color(0xFF1C2580);

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Draws a two-segment limb from [a] through a bent joint to [b].
void _limb(Canvas c, Offset a, Offset b, double bend, double w, Color color, {Color? band, double bandAt = 0.72}) {
  final mid = Offset.lerp(a, b, 0.5)!;
  final dir = b - a;
  final len = dir.distance;
  final n = len == 0 ? Offset.zero : Offset(-dir.dy, dir.dx) / len;
  final knee = mid + n * bend;
  final p = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(knee.dx, knee.dy)
    ..lineTo(b.dx, b.dy);
  c.drawPath(p, _stroke(color, w));
  // soft shading along the back of the limb
  c.drawPath(p.shift(Offset(-w * 0.18, 0)), _stroke(Colors.black.withValues(alpha: 0.06), w * 0.35));
  // a soft sheen on the lit side of the fabric
  c.drawPath(p.shift(Offset(w * 0.2, -w * 0.06)), _stroke(Colors.white.withValues(alpha: 0.22), w * 0.18));
  // the suit's fabric bunches into folds at the knee or elbow
  if (bend.abs() > 1.5 && len > 0) {
    final along = dir / len;
    final crease = _stroke(Colors.black.withValues(alpha: 0.13), 0.9);
    for (final k in const [-2.6, 2.6]) {
      final q = knee + along * k;
      c.drawLine(q - n * w * 0.36, q + n * w * 0.22, crease);
    }
  }
  if (band != null) {
    final bp = Offset.lerp(knee, b, bandAt - 0.5 < 0 ? 0.3 : (bandAt - 0.5) * 2)!;
    final d2 = (b - knee);
    final l2 = d2.distance == 0 ? 1.0 : d2.distance;
    final u = d2 / l2;
    c.drawLine(bp - u * 2.6, bp + u * 2.6, _stroke(band, w + 0.6)..strokeCap = StrokeCap.butt);
  }
}

/// Commander Nova Haddad in her suit. Origin at her feet, 100 units tall.
void paintNova(Canvas c, NovaPose p) {
  final t = p.t;
  final walking = p.action == NovaAction.walk;
  final cyc = p.phase * math.pi * 2;
  // 0 on each footfall, 1 at the top of the hop. The same curve drives
  // the feet, the lean and the arms, so nothing pops between poses.
  final stride = walking ? math.sin((p.phase % 1.0) * math.pi) : 0.0;
  final compress = walking ? (1 - stride) * (p.sprint ? 4.2 : 2.6) + p.land * 2.5 : 0.0;
  final packLag = walking ? math.sin(cyc - 1.0) * (p.sprint ? 1.8 : 1.2) : math.sin(t * 1.9) * 0.25;
  final breathe = math.sin(t * (p.sprint ? 2.6 : 1.9)) * 0.9;
  var lean = 0.0;
  if (walking) lean = (p.sprint ? 0.08 : 0.04) + stride * (p.sprint ? 0.1 : 0.045);
  var crouch = walking ? 0.0 : p.land * 9;
  var hop = 0.0;
  switch (p.action) {
    case NovaAction.kneel:
    case NovaAction.work:
      crouch = p.action == NovaAction.kneel ? 14 : 4;
      lean = 0.12;
      break;
    case NovaAction.scared:
      lean = -0.12 + math.sin(t * 30) * 0.01;
      break;
    case NovaAction.cheer:
      hop = -(math.sin(t * 6).abs()) * 7;
      break;
    case NovaAction.sit:
      crouch = 20;
      break;
    default:
      break;
  }
  final body = compress + hop + crouch * p.blend;

  // ---- shadow is drawn by the caller (it stays on the ground)

  // legs
  final hip = Offset(0, -37 + body);
  // A walk alternates feet. A sprint is a two-footed kangaroo bound:
  // tuck on the way up, reach for the dust on the way down.
  Offset gaitFoot(double side) {
    if (p.action == NovaAction.kneel) return side < 0 ? const Offset(-9, 0) : const Offset(12, -2);
    if (p.action == NovaAction.sit) return Offset(10 + side * 3, 0);
    if (!walking) return Offset(side * 3.5, hop < 0 ? hop * 0.8 : 0);
    // Positive x is the way she faces. Both gaits are a sine, so the feet
    // ease from one step into the next instead of jumping.
    if (p.sprint) {
      return Offset(6 + stride * 10 + side * 1.6, -1 - stride * 9);
    }
    final swing = math.sin(cyc + (side > 0 ? 0.0 : math.pi));
    return Offset(4 + swing * (8 + stride * 5), -1 - math.max(0.0, swing) * stride * 8);
  }

  final farFoot = gaitFoot(-1);
  final nearFoot = gaitFoot(1);
  final kneeBend = p.action == NovaAction.kneel || p.action == NovaAction.sit
      ? 9.0
      : walking
          ? 2.2 + stride * (p.sprint ? 6.0 : 4.0)
          : 1.5;
  _limb(c, hip + const Offset(-3, 0), farFoot + const Offset(0, -5), -kneeBend, 12.5, _suitShade, band: C.sapphire);
  _boot_(c, farFoot, darker: true);
  // backpack (behind the body)
  final torsoTop = -67.0 + body + breathe * 0.3;
  final pack = RRect.fromRectAndRadius(Rect.fromLTWH(-25, torsoTop + 2 + packLag, 15, 33), const Radius.circular(5));
  c.drawRRect(pack, _fill(const Color(0xFFE4E6EA)));
  c.drawRRect(pack.deflate(0.1), _stroke(_suitDeep, 1.2));
  c.drawCircle(Offset(-18, torsoTop + 22 + packLag), 1.6, _fill(C.cyan));
  c.drawCircle(Offset(-18, torsoTop + 27 + packLag), 1.6, _fill(C.cyan));
  // radio antenna with the red tip: it whips a little with every step
  final whip = walking ? math.sin(cyc * 2 - 1.8) * 2.6 : math.sin(t * 2.2) * 0.8;
  final antTip = Offset(-26 + whip - lean * 30, torsoTop - 22 + packLag * 0.5);
  c.drawLine(Offset(-21, torsoTop + 3 + packLag), antTip, _stroke(const Color(0xFFB9BEC6), 1.3));
  c.drawCircle(antTip, 2.4, _fill(_glove));

  c.save();
  c.translate(0, -37 + body);
  c.rotate(lean);
  c.translate(0, 37 - body);

  // far arm
  final shoulderFar = Offset(-4, torsoTop + 10);
  // Walking arms oppose the legs. A bound swings both arms together,
  // back on the push and forward as the boots come down.
  final armSwing = !walking ? 0.0 : (p.sprint ? math.sin(cyc) * 11 : -math.sin(cyc) * (8 + stride * 3));
  Offset handFar;
  switch (p.action) {
    case NovaAction.cheer:
      handFar = shoulderFar + Offset(-6, -28 + math.sin(t * 6) * 2);
      break;
    case NovaAction.work:
    case NovaAction.kneel:
      handFar = shoulderFar + const Offset(16, 14);
      break;
    case NovaAction.carry:
      handFar = shoulderFar + const Offset(14, 10);
      break;
    case NovaAction.scared:
      handFar = shoulderFar + const Offset(10, -12);
      break;
    default:
      handFar = shoulderFar + Offset(p.sprint ? armSwing * 0.5 : armSwing * 0.55, 22 - stride * (p.sprint ? 8 : 3));
  }
  _limb(c, shoulderFar, handFar, -3, 10.5, _suitShade, band: C.sapphire, bandAt: 0.85);
  c.drawCircle(handFar, 5.4, _fill(_gloveFar));

  // torso
  final torso = RRect.fromRectAndCorners(
    Rect.fromLTWH(-14, torsoTop, 29, 34 + breathe * 0.4),
    topLeft: const Radius.circular(11),
    topRight: const Radius.circular(11),
    bottomLeft: const Radius.circular(9),
    bottomRight: const Radius.circular(9),
  );
  c.drawRRect(torso, Paint()..shader = const LinearGradient(colors: [_suitShade, _suit, _suit, _suitShade], stops: [0, 0.35, 0.7, 1]).createShader(torso.outerRect));
  // shoulder yoke
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-12, torsoTop - 3, 25, 7), const Radius.circular(4)), _fill(_joint));
  // chest control box
  final box = RRect.fromRectAndRadius(Rect.fromLTWH(1, torsoTop + 9, 13, 9), const Radius.circular(2.5));
  // the design's chest panel: indigo with three lights
  c.drawRRect(box, _fill(const Color(0xFF4A4378)));
  c.drawCircle(Offset(4, torsoTop + 13.5), 1.5, _fill(C.cyan));
  c.drawCircle(Offset(7.6, torsoTop + 13.5), 1.5, _fill(_glove));
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9.8, torsoTop + 12, 2.8, 2.8), const Radius.circular(0.6)), _fill(C.green));
  // mission patch: navy disc with a cyan star
  c.drawCircle(Offset(-5, torsoTop + 18), 4.2, _fill(C.sapphire));
  c.drawCircle(Offset(-5, torsoTop + 18), 3.2, _fill(const Color(0xFF0E1B33)));
  c.drawPath(_miniStar(Offset(-5, torsoTop + 18), 2.2), _fill(C.cyan));
  // waist band
  c.drawRect(Rect.fromLTWH(-14, torsoTop + 26, 29, 4.2), _fill(C.sapphire));

  // near leg is drawn over the torso bottom
  c.restore();
  _limb(c, hip + const Offset(4, 0), nearFoot + const Offset(1, -5), -kneeBend, 13, _suit, band: C.sapphire);
  _boot_(c, nearFoot);
  c.save();
  c.translate(0, -37 + body);
  c.rotate(lean);
  c.translate(0, 37 - body);

  // helmet
  final nod = p.talking ? math.sin(t * 9) * 0.8 : 0.0;
  final hc = Offset(3, torsoTop - 15 + nod + breathe * 0.2);
  const hr = 17.5;
  // standing still she looks around: up at Earth now and then, then back
  var look = 0.0;
  if (p.action == NovaAction.idle && !p.talking) {
    final k = t % 7.5;
    if (k < 2.6) look = -0.2 * math.pow(math.sin(math.pi * k / 2.6), 2).toDouble();
    look += 0.03 * math.sin(t * 0.7);
  }
  c.save();
  final neck = hc + const Offset(-1, 13);
  c.translate(neck.dx, neck.dy);
  c.rotate(look);
  c.translate(-neck.dx, -neck.dy);
  // neck ring
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hc + const Offset(-1, 14), width: 22, height: 6), const Radius.circular(3)), _fill(C.sapphire));
  // shell
  c.drawCircle(
    hc,
    hr,
    Paint()
      ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), radius: 1.0, colors: [Colors.white, _suit, _suitShade]).createShader(Rect.fromCircle(center: hc, radius: hr)),
  );
  c.drawCircle(hc, hr, _stroke(_suitDeep.withValues(alpha: 0.6), 0.8));
  // headlamp
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hc + const Offset(-12, -2), width: 6, height: 9), const Radius.circular(2)), _fill(const Color(0xFFE2E2DC)));
  c.drawCircle(hc + const Offset(-12, -2), 2.1, _fill(const Color(0xFFFFF4C8)));

  final visorC = hc + const Offset(4.5, 1.5);
  final visorR = Rect.fromCenter(center: visorC, width: 24, height: 21);
  if (p.visorUp) {
    // her face, framed by the helmet opening
    c.drawOval(visorR.inflate(0.5), _fill(const Color(0xFF1A1420)));
    c.save();
    c.clipPath(Path()..addOval(visorR));
    c.drawOval(visorR.deflate(1.5), _fill(_skin));
    // hair
    c.drawPath(
      Path()
        ..moveTo(visorR.left, visorR.top + 8)
        ..quadraticBezierTo(visorC.dx - 2, visorR.top - 4, visorR.right + 2, visorR.top + 6)
        ..lineTo(visorR.right, visorR.top)
        ..lineTo(visorR.left, visorR.top)
        ..close(),
      _fill(_hair),
    );
    _face(c, visorC + const Offset(2, 2), p.mood, t);
    c.restore();
    // the raised gold visor
    c.drawArc(Rect.fromCircle(center: hc, radius: hr - 2), -math.pi * 0.95, math.pi * 0.85, false, _stroke(_goldB, 4.2)..strokeCap = StrokeCap.butt);
  } else {
    c.drawOval(visorR, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_goldA, _goldB, _goldC]).createShader(visorR));
    // reflections: a sky band and a tiny Earth
    c.save();
    c.clipPath(Path()..addOval(visorR));
    c.drawArc(Rect.fromCenter(center: visorC + const Offset(-1, 7), width: 26, height: 16), math.pi * 0.1, math.pi * 0.8, false, _stroke(const Color(0x55101850), 1.4));
    c.drawCircle(visorC + const Offset(5, -3), 3.2, _fill(const Color(0xFF6FB6E9)));
    c.drawCircle(visorC + const Offset(5.6, -3.2), 1.2, _fill(const Color(0xFF4F9F55)));
    c.drawOval(Rect.fromCenter(center: visorC + const Offset(-5, -6), width: 9, height: 4), _fill(Colors.white.withValues(alpha: 0.45)));
    // a shine sweeps across the gold every few seconds
    final g = (t % 4.2) / 0.9;
    if (g < 1) {
      final gx = visorR.left - 8 + g * (visorR.width + 16);
      c.drawPath(
        Path()
          ..moveTo(gx, visorR.top - 2)
          ..lineTo(gx + 5, visorR.top - 2)
          ..lineTo(gx - 3, visorR.bottom + 2)
          ..lineTo(gx - 8, visorR.bottom + 2)
          ..close(),
        _fill(Colors.white.withValues(alpha: 0.38 * math.sin(math.pi * g))),
      );
    }
    c.restore();
    // a hint of the mood through the visor: a smile line glints when happy
    if (p.mood == NovaMood.happy) {
      c.drawArc(Rect.fromCenter(center: visorC + const Offset(1, 3), width: 10, height: 6), 0.3, math.pi - 0.6, false, _stroke(const Color(0x66FFF3D0), 1.2));
    }
  }

  c.restore(); // head turn

  // near arm, in front of everything
  final shoulderNear = Offset(7, torsoTop + 10);
  Offset handNear;
  switch (p.action) {
    case NovaAction.cheer:
      handNear = shoulderNear + Offset(8, -30 + math.cos(t * 6) * 2);
      break;
    case NovaAction.wave:
      handNear = shoulderNear + Offset(10 + math.sin(t * 8) * 4, -26);
      break;
    case NovaAction.work:
    case NovaAction.kneel:
      handNear = shoulderNear + Offset(22 + math.sin(t * 7) * 2.5, 10 + math.cos(t * 7) * 1.5);
      break;
    case NovaAction.carry:
      handNear = shoulderNear + const Offset(18, 8);
      break;
    case NovaAction.scared:
      handNear = shoulderNear + const Offset(14, -14);
      break;
    default:
      handNear = shoulderNear + Offset(p.sprint ? armSwing * 0.5 : -armSwing * 0.55 + 2, 22 - stride * (p.sprint ? 8 : 3));
  }
  _limb(c, shoulderNear, handNear, 3, 11, _suit, band: C.sapphire, bandAt: 0.85);
  c.drawCircle(handNear, 5.9, _fill(_glove));
  c.drawCircle(shoulderNear, 5, _fill(_joint));
  if (p.action == NovaAction.work || p.action == NovaAction.kneel) {
    // a small tool with a spark
    final tip = handNear + const Offset(7, 2);
    c.drawLine(handNear, tip, _stroke(const Color(0xFF6B7280), 2.2));
    if ((t * 6).floor().isEven) {
      for (var i = 0; i < 4; i++) {
        final a = i * 1.4 + t * 9;
        c.drawLine(tip, tip + Offset(math.cos(a), math.sin(a)) * 4.5, _stroke(const Color(0xFFFFD27A), 0.9));
      }
    }
  }
  c.restore();
}

void _boot_(Canvas c, Offset f, {bool darker = false}) {
  final r = RRect.fromRectAndRadius(Rect.fromLTWH(f.dx - 7, f.dy - 7, 16, 7.5), const Radius.circular(3.5));
  c.drawRRect(r, _fill(darker ? const Color(0xFFE0782F) : _boot));
  c.drawRect(Rect.fromLTWH(f.dx - 7, f.dy - 1.6, 16, 1.6), _fill(const Color(0xFFB85A1F)));
}

Path _miniStar(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

void _face(Canvas c, Offset f, NovaMood mood, double t) {
  final blink = (t % 3.7) < 0.12;
  final eyeY = f.dy - 1.5;
  final white = _fill(Colors.white);
  final dark = _fill(const Color(0xFF1B1210));
  for (final dx in [-4.2, 3.4]) {
    final e = Offset(f.dx + dx, eyeY);
    if (blink) {
      c.drawLine(e - const Offset(1.8, 0), e + const Offset(1.8, 0), _stroke(const Color(0xFF1B1210), 0.9));
    } else {
      c.drawOval(Rect.fromCenter(center: e, width: mood == NovaMood.scared ? 4.6 : 4, height: mood == NovaMood.scared ? 5 : 4.2), white);
      c.drawCircle(e + const Offset(0.5, 0.3), 1.35, dark);
    }
  }
  // brows
  final browPaint = _stroke(const Color(0xFF2B1D16), 0.9);
  final worried = mood == NovaMood.worried || mood == NovaMood.scared;
  c.drawLine(Offset(f.dx - 6, eyeY - (worried ? 3.0 : 3.8)), Offset(f.dx - 2.4, eyeY - (worried ? 4.2 : 3.6)), browPaint);
  c.drawLine(Offset(f.dx + 1.6, eyeY - (worried ? 4.2 : 3.6)), Offset(f.dx + 5.2, eyeY - (worried ? 3.0 : 3.8)), browPaint);
  // cheeks
  if (mood == NovaMood.happy) {
    c.drawCircle(Offset(f.dx - 6.5, f.dy + 2.5), 1.8, _fill(const Color(0x55FF7A7A)));
    c.drawCircle(Offset(f.dx + 6, f.dy + 2.5), 1.8, _fill(const Color(0x55FF7A7A)));
  }
  // mouth
  final m = Offset(f.dx - 0.3, f.dy + 4.2);
  switch (mood) {
    case NovaMood.happy:
      c.drawPath(
        Path()
          ..moveTo(m.dx - 3.4, m.dy - 0.6)
          ..quadraticBezierTo(m.dx, m.dy + 3.6, m.dx + 3.4, m.dy - 0.6)
          ..close(),
        _fill(const Color(0xFF7A2E2A)),
      );
      break;
    case NovaMood.worried:
    case NovaMood.tired:
      c.drawArc(Rect.fromCenter(center: m + const Offset(0, 1.8), width: 6, height: 3.4), math.pi * 1.1, math.pi * 0.8, false, _stroke(const Color(0xFF6B2A24), 0.9));
      break;
    case NovaMood.scared:
      c.drawOval(Rect.fromCenter(center: m + const Offset(0, 0.6), width: 2.8, height: 3.6), _fill(const Color(0xFF6B2A24)));
      break;
    case NovaMood.calm:
      c.drawArc(Rect.fromCenter(center: m - const Offset(0, 0.8), width: 5, height: 2.6), 0.2, math.pi - 0.4, false, _stroke(const Color(0xFF6B2A24), 0.9));
      break;
  }
}

// =================================================================== PIP

enum PipEye { happy, alarm, thinking, scanning, normal }

/// Pip, the helper drone. Origin at its centre, radius about 12 units.
void paintPip(Canvas c, double t, {PipEye eye = PipEye.normal, double tilt = 0, double spin = 0}) {
  c.save();
  c.rotate(tilt);
  // thrusters
  final flick = 0.75 + 0.25 * math.sin(t * 31);
  for (final dx in [-5.0, 5.0]) {
    final r = Rect.fromCenter(center: Offset(dx, 13.5), width: 4.6, height: 7 * flick);
    c.drawOval(r, _fill(C.cyan.withValues(alpha: 0.55)));
    c.drawOval(r.deflate(1.2), _fill(Colors.white.withValues(alpha: 0.6)));
  }
  // side fins
  final fin = _fill(const Color(0xFF9AA3AF));
  c.drawPath(
    Path()
      ..moveTo(-12, -4)
      ..lineTo(-18, -10)
      ..lineTo(-17, 5)
      ..close(),
    fin,
  );
  c.drawPath(
    Path()
      ..moveTo(12, -4)
      ..lineTo(18, -10)
      ..lineTo(17, 5)
      ..close(),
    fin,
  );
  // antenna
  c.drawLine(const Offset(0, -12), const Offset(0, -18), _stroke(const Color(0xFFB8BEC8), 1.2));
  c.drawCircle(const Offset(0, -19), 2, _fill(C.cyan));
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -12.5), width: 8, height: 4), const Radius.circular(2)), _fill(C.sapphire));
  // body
  const body = Rect.fromLTWH(-12.5, -12.5, 25, 25);
  c.drawOval(
    body,
    Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.45), radius: 0.95, colors: [Colors.white, Color(0xFFE3E7EC), Color(0xFFA9B2BE)]).createShader(body),
  );
  // eye
  final look = Offset(math.sin(t * 0.7 + spin) * 1.2 + 1, math.cos(t * 0.9) * 0.6);
  c.drawCircle(look, 7.2, _fill(const Color(0xFF0B1A2C)));
  switch (eye) {
    case PipEye.happy:
      c.drawArc(Rect.fromCircle(center: look + const Offset(0, 1.5), radius: 3.6), math.pi * 1.1, math.pi * 0.8, false, _stroke(C.cyan, 1.8));
      break;
    case PipEye.alarm:
      final pulse = 0.7 + 0.3 * math.sin(t * 10);
      c.drawCircle(look, 3.6 * pulse + 0.6, _fill(const Color(0xFFFF5A5F)));
      break;
    case PipEye.thinking:
      c.drawLine(look - const Offset(3.4, 0), look + const Offset(3.4, 0), _stroke(C.cyan, 1.8));
      break;
    case PipEye.scanning:
      c.drawCircle(look, 4.6, _stroke(C.cyan, 1.4));
      c.drawCircle(look, 1.8, _fill(C.cyan));
      break;
    case PipEye.normal:
      final blink = (t % 4.3) < 0.12;
      if (blink) {
        c.drawLine(look - const Offset(3.4, 0), look + const Offset(3.4, 0), _stroke(C.cyan, 1.6));
      } else {
        c.drawCircle(look, 4.6, _fill(C.cyan));
        c.drawCircle(look + const Offset(1.6, -1.6), 1.5, _fill(Colors.white));
      }
  }
  c.restore();
}

/// A soft glow under Pip, plus an optional scan beam toward [beamTo]
/// (in Pip's local units).
void paintPipGlow(Canvas c, double t, {Offset? beamTo}) {
  c.drawCircle(
    Offset.zero,
    26,
    Paint()..shader = RadialGradient(colors: [C.cyan.withValues(alpha: 0.22), C.cyan.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset.zero, radius: 26)),
  );
  if (beamTo != null) {
    final perp = Offset(-(beamTo.dy), beamTo.dx);
    final n = perp.distance == 0 ? Offset.zero : perp / perp.distance;
    final spread = 9 + 2 * math.sin(t * 8);
    final path = Path()
      ..moveTo(0, 4)
      ..lineTo(beamTo.dx + n.dx * spread, beamTo.dy + n.dy * spread)
      ..lineTo(beamTo.dx - n.dx * spread, beamTo.dy - n.dy * spread)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.cyan.withValues(alpha: 0.55), C.cyan.withValues(alpha: 0.12)],
        ).createShader(path.getBounds()),
    );
  }
}

/// Convenience widgets for menus (rank cards, dialogue portraits).
class NovaFigure extends StatefulWidget {
  final double height;
  final NovaAction action;
  final NovaMood mood;
  final bool visorUp;
  final bool animate;
  final bool faceLeft;
  const NovaFigure({super.key, this.height = 120, this.action = NovaAction.idle, this.mood = NovaMood.calm, this.visorUp = false, this.animate = true, this.faceLeft = false});

  @override
  State<NovaFigure> createState() => _NovaFigureState();
}

class _NovaFigureState extends State<NovaFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.height * 0.62,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _NovaPainter(_c.value * 60, widget.action, widget.mood, widget.visorUp, widget.faceLeft)),
        ),
      ),
    );
  }
}

class _NovaPainter extends CustomPainter {
  final double t;
  final NovaAction action;
  final NovaMood mood;
  final bool visorUp;
  final bool faceLeft;
  _NovaPainter(this.t, this.action, this.mood, this.visorUp, this.faceLeft);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 104;
    canvas.save();
    canvas.translate(size.width / 2, size.height - 2 * s);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 44 * s, height: 6 * s), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.scale(faceLeft ? -s : s, s);
    paintNova(canvas, NovaPose(action: action, mood: mood, t: t, phase: t * 1.4, visorUp: visorUp));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NovaPainter old) => true;
}

class PipFigure extends StatefulWidget {
  final double size;
  final PipEye eye;
  const PipFigure({super.key, this.size = 40, this.eye = PipEye.normal});

  @override
  State<PipFigure> createState() => _PipFigureState();
}

class _PipFigureState extends State<PipFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _PipPainter(_c.value * 60, widget.eye)),
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final double t;
  final PipEye eye;
  _PipPainter(this.t, this.eye);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 46;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + math.sin(t * 2.2) * 1.5 * s);
    canvas.scale(s);
    paintPipGlow(canvas, t);
    paintPip(canvas, t, eye: eye, tilt: math.sin(t * 1.3) * 0.06);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) => true;
}
