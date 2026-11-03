/// The things standing on the Moon, drawn in code: lander, habitat, power
/// system, gear. Every function draws with its origin at the object's base
/// centre, in design units (1 unit = 1 px on a 390-wide phone).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

Paint _f(Color c) => Paint()..color = c;
Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

const foilA = Color(0xFFF0C766);
const foilB = Color(0xFFD6A443);
const foilC = Color(0xFFA87B26);
const metal = Color(0xFFB7BCC4);
const metalDark = Color(0xFF8F949C);
const white = Color(0xFFF2F1EC);
const whiteShade = Color(0xFFD7D5CD);

/// A long soft shadow cast away from the low Sun (which is on the left).
void castShadow(Canvas c, double width, double length, {double opacity = 0.32}) {
  final r = Rect.fromLTWH(-width * 0.45, -3, width * 0.5 + length, 7);
  c.drawOval(
    r,
    Paint()
      ..shader = LinearGradient(colors: [Colors.black.withValues(alpha: opacity), Colors.black.withValues(alpha: 0)]).createShader(r),
  );
}

/// The two-stage lander. [tilt] radians (crash), [bayOpen] shows the
/// maintenance bay, [ascentOnly] draws only the top stage (for lift-off).
void paintLander(Canvas c, double t, {double tilt = 0, bool bayOpen = false, bool repaired = false, bool descentOnly = false}) {
  castShadow(c, 150, 120);
  c.save();
  c.rotate(tilt);
  // legs and footpads
  final leg = _s(metal, 3.2);
  for (final sgn in [-1.0, 1.0]) {
    c.drawLine(Offset(sgn * 40, -46), Offset(sgn * 66, -4), leg);
    c.drawLine(Offset(sgn * 30, -40), Offset(sgn * 42, -4), _s(metalDark, 2.6));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sgn * 66, -2), width: 20, height: 5), const Radius.circular(2.5)), _f(metalDark));
  }
  // engine bell
  c.drawPath(Path()..moveTo(-14, -26)..lineTo(14, -26)..lineTo(10, -14)..lineTo(-10, -14)..close(), _f(const Color(0xFF3B3E44)));
  // descent stage: gold foil
  final body = Path()
    ..moveTo(-44, -66)
    ..lineTo(44, -66)
    ..lineTo(40, -26)
    ..lineTo(-40, -26)
    ..close();
  c.drawPath(body, Paint()..shader = const LinearGradient(colors: [foilA, foilB, foilC], stops: [0, 0.55, 1]).createShader(const Rect.fromLTWH(-44, -66, 88, 40)));
  c.drawPath(Path()..moveTo(-44, -66)..lineTo(44, -66)..lineTo(43, -58)..lineTo(-43, -58)..close(), _f(const Color(0xFFF7D98A)));
  final crinkle = _s(foilC.withValues(alpha: 0.55), 0.9);
  for (final x in [-30.0, -12.0, 8.0, 26.0]) {
    c.drawLine(Offset(x, -56), Offset(x + 2, -28), crinkle);
  }
  c.drawLine(const Offset(-38, -44), const Offset(-20, -40), crinkle);
  c.drawLine(const Offset(10, -36), const Offset(32, -40), crinkle);
  if (bayOpen) {
    // the maintenance bay: an open hatch with wiring inside
    final bay = RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -54, 30, 22), const Radius.circular(2));
    c.drawRRect(bay, _f(const Color(0xFF1C1F27)));
    final w = [const Color(0xFFFF7A59), C.cyan, const Color(0xFFFFD27A), const Color(0xFFEDEDED)];
    for (var i = 0; i < 4; i++) {
      c.drawPath(
        Path()
          ..moveTo(-3, -50 + i * 5.0)
          ..quadraticBezierTo(8, -46 + i * 4.0 + math.sin(t * 2 + i) * 0.6, 21, -50 + i * 5.0),
        _s(w[i], 1.3),
      );
    }
    // the hatch door hanging open
    c.drawPath(Path()..moveTo(24, -54)..lineTo(36, -50)..lineTo(36, -28)..lineTo(24, -32)..close(), _f(foilB));
    c.drawPath(Path()..moveTo(24, -54)..lineTo(36, -50)..lineTo(36, -28)..lineTo(24, -32)..close(), _s(foilC, 0.8));
  }
  if (!descentOnly) _ascentStage(c, t, repaired: repaired);
  c.restore();
}

void _ascentStage(Canvas c, double t, {bool repaired = false}) {
  // cabin
  final cabin = Path()
    ..moveTo(-30, -66)
    ..cubicTo(-30, -112, 30, -112, 30, -66)
    ..close();
  c.drawPath(cabin, Paint()..shader = const LinearGradient(colors: [whiteShade, white, white, whiteShade], stops: [0, 0.3, 0.7, 1]).createShader(const Rect.fromLTWH(-30, -112, 60, 46)));
  c.drawPath(Path()..moveTo(-30, -66)..cubicTo(-30, -80, -26, -88, -19, -94)..lineTo(-19, -66)..close(), _f(whiteShade.withValues(alpha: 0.7)));
  // window
  final win = RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -95, 22, 15), const Radius.circular(5));
  c.drawRRect(win, _f(const Color(0xFF1B2A44)));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -93, 8, 5), const Radius.circular(2)), _f(C.cyan.withValues(alpha: 0.55)));
  // sapphire band
  c.drawRect(const Rect.fromLTWH(-31, -72, 62, 5), _f(C.sapphire));
  // antenna dish
  c.drawLine(const Offset(28, -86), const Offset(44, -96), _s(const Color(0xFFC9CCD2), 2));
  c.drawCircle(const Offset(46, -97), 4.5, _f(const Color(0xFFE7E8EA)));
  // RCS thrusters
  c.drawRect(const Rect.fromLTWH(-36, -86, 6, 4), _f(metalDark));
  c.drawRect(const Rect.fromLTWH(30, -80, 6, 4), _f(metalDark));
  // status light
  final on = (t * 1.2) % 1 < 0.5;
  c.drawCircle(const Offset(0, -106), 2, _f(repaired ? (on ? C.cyan : C.cyan.withValues(alpha: 0.3)) : (on ? const Color(0xFFFF5A5F) : const Color(0x55FF5A5F))));
}

/// The ascent stage alone, for the launch (origin at its base).
void paintAscentStage(Canvas c, double t) {
  c.drawPath(Path()..moveTo(-12, -67)..lineTo(12, -67)..lineTo(9, -61)..lineTo(-9, -61)..close(), _f(const Color(0xFF3B3E44)));
  // the lower skirt that sat inside the descent stage
  c.drawPath(Path()..moveTo(-30, -66)..lineTo(30, -66)..lineTo(24, -60)..lineTo(-24, -60)..close(), _f(whiteShade));
  _ascentStage(c, t, repaired: true);
}

/// The inflatable habitat. [inflate] 0..1, [bags] regolith shielding bags.
void paintHabitat(Canvas c, double t, {double inflate = 1, int bags = 0, bool sensors = false, bool sensorAlarm = false, bool patch = false, bool thermalFault = false}) {
  final k = inflate.clamp(0.08, 1.0);
  castShadow(c, 200, 150);
  const w = 196.0;
  final h = 124.0 * k;
  final dome = Path()
    ..moveTo(-w / 2, 0)
    ..cubicTo(-w / 2, -h * 1.32, w / 2, -h * 1.32, w / 2, 0)
    ..close();
  c.drawPath(
    dome,
    Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFFFFFFF), white, Color(0xFFCFCCC4)], stops: [0, 0.45, 1]).createShader(Rect.fromLTWH(-w / 2, -h, w, h)),
  );
  // fabric ribs
  final rib = _s(const Color(0xFFB9B6AE).withValues(alpha: 0.7), 1);
  for (final f in [-0.62, -0.3, 0.0, 0.3, 0.62]) {
    c.drawPath(Path()..moveTo(f * w / 2, 0)..quadraticBezierTo(f * w / 2 * 0.9, -h * 0.9, 0, -h * 0.99), rib);
  }
  c.drawPath(Path()..moveTo(-w / 2 + 6, -h * 0.42)..quadraticBezierTo(0, -h * 0.52, w / 2 - 6, -h * 0.42), _s(C.sapphire, 3.5));
  if (k > 0.6) {
    // window strip
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(26, -h * 0.66), width: 36, height: 10), const Radius.circular(5)), _f(const Color(0xFF1B2A44)));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(20, -h * 0.66), width: 12, height: 4), const Radius.circular(2)), _f(const Color(0xFFFFE7A8).withValues(alpha: 0.75)));
    // airlock
    final al = RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2 - 14, -54, 34, 54), const Radius.circular(10));
    c.drawRRect(al, _f(const Color(0xFFE4E2DB)));
    c.drawRRect(al, _s(const Color(0xFFB9B6AE), 1));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2 - 8, -46, 22, 40), const Radius.circular(7)), _f(const Color(0xFF59606C)));
    c.drawCircle(const Offset(-w / 2 + 10, -26), 2.2, _f(C.cyan));
  }
  if (patch) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-34, -h * 0.72), width: 18, height: 14), const Radius.circular(3)), _f(const Color(0xFF9AA0AA)));
    c.drawLine(Offset(-42, -h * 0.72), Offset(-26, -h * 0.72), _s(const Color(0xFF6B717C), 1));
  }
  if (thermalFault) {
    final pulse = 0.5 + 0.5 * math.sin(t * 5);
    c.drawCircle(Offset(56, -h * 0.4), 9 + pulse * 3, _f(C.sapphire.withValues(alpha: 0.25 + 0.2 * pulse)));
  }
  if (sensors && k > 0.6) {
    for (var i = 0; i < 3; i++) {
      final p = Offset(-30.0 + i * 30, -h * 1.0 + (i == 1 ? -3 : 4));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 10, height: 7), const Radius.circular(2)), _f(const Color(0xFF3A3F4A)));
      final blink = ((t * 1.5 + i * 0.3) % 1) < 0.5;
      final col = sensorAlarm ? const Color(0xFFFF5A5F) : C.cyan;
      c.drawCircle(p + const Offset(0, -5), 1.6, _f(blink ? col : col.withValues(alpha: 0.3)));
    }
  }
  // regolith shielding bags around the base
  if (bags > 0 && k > 0.6) {
    final rnd = math.Random(7);
    var placed = 0;
    for (var row = 0; row < 2 && placed < bags; row++) {
      final per = row == 0 ? 6 : 4;
      for (var i = 0; i < per && placed < bags; i++) {
        final x = (row == 0 ? 20.0 : 34.0) + i * 22.0 - (row == 0 ? 0 : 0);
        final pos = Offset(x + rnd.nextDouble() * 2, -7 - row * 11);
        final r = Rect.fromCenter(center: pos, width: 24, height: 13);
        c.drawOval(r, _f(const Color(0xFF8E8A82)));
        c.drawOval(Rect.fromLTWH(r.left + 3, r.top + 1.5, r.width - 8, 4), _f(const Color(0xFFB2AEA6)));
        placed++;
      }
    }
  }
}

/// The battery bank with its charge shown as a bar.
void paintBattery(Canvas c, double t, double level, {bool fault = false}) {
  castShadow(c, 50, 40);
  final r = RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -36, 48, 36), const Radius.circular(5));
  c.drawRRect(r, _f(const Color(0xFF353A45)));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -36, 48, 8), const Radius.circular(5)), _f(const Color(0xFF4A505D)));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -22, 34, 9), const Radius.circular(2)), _f(const Color(0xFF151820)));
  final col = level < 0.25 ? const Color(0xFFFF5A5F) : C.cyan;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-16, -21, 32 * level.clamp(0.0, 1.0), 7), const Radius.circular(1.5)), _f(col));
  c.drawRect(const Rect.fromLTWH(-8, -40, 5, 4), _f(metalDark));
  c.drawRect(const Rect.fromLTWH(3, -40, 5, 4), _f(metalDark));
  final on = (t * 1.6) % 1 < 0.5;
  c.drawCircle(const Offset(17, -31), 1.8, _f(fault ? (on ? const Color(0xFFFF5A5F) : const Color(0x44FF5A5F)) : C.cyan));
}

/// The cable from the battery along the ground. [broken] shows the crushed bit.
void paintCable(Canvas c, double fromX, double toX, double t, {bool broken = false}) {
  final p = Path()..moveTo(fromX, -4);
  final mid = (fromX + toX) / 2;
  p.quadraticBezierTo(mid, 3, toX, -4);
  c.drawPath(p, _s(const Color(0xFF2A2E36), 3.2));
  c.drawPath(p, _s(broken ? const Color(0xFF6B717C) : C.sapphire.withValues(alpha: 0.7), 1.2));
  if (broken) {
    // the boulder that crushed it
    c.drawOval(Rect.fromCenter(center: Offset(mid, -8), width: 26, height: 18), _f(const Color(0xFF8E8A82)));
    c.drawOval(Rect.fromCenter(center: Offset(mid - 4, -12), width: 12, height: 6), _f(const Color(0xFFB4B0A8)));
  }
}

/// The solar panel crate (Level 3, before unpacking).
void paintCrate(Canvas c) {
  castShadow(c, 56, 50);
  final r = RRect.fromRectAndRadius(const Rect.fromLTWH(-28, -40, 56, 40), const Radius.circular(3));
  c.drawRRect(r, _f(const Color(0xFFC9CDD4)));
  c.drawRRect(r, _s(const Color(0xFF8F949C), 2));
  c.drawLine(const Offset(-28, -40), const Offset(28, 0), _s(const Color(0xFF9FA5AE), 1.5));
  c.drawLine(const Offset(28, -40), const Offset(-28, 0), _s(const Color(0xFF9FA5AE), 1.5));
  c.drawRect(const Rect.fromLTWH(-28, -26, 56, 6), _f(C.sapphire));
}

/// Tall vertical solar panels, the way they stand at the south pole.
void paintPanels(Canvas c, double t, {double dust = 0, double deploy = 1}) {
  castShadow(c, 90, 160, opacity: 0.4);
  c.drawRect(const Rect.fromLTWH(-2.5, -132, 5, 132), _f(metalDark));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -6, 24, 6), const Radius.circular(2)), _f(metal));
  for (final side in [-1.0, 1.0]) {
    final w = 34.0 * deploy;
    final rect = Rect.fromLTWH(side < 0 ? -4 - w : 4, -128, w, 96);
    c.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E4FA8), Color(0xFF1A2F6B), Color(0xFF0F1D45)]).createShader(rect));
    final grid = _s(const Color(0xFF6E89D8).withValues(alpha: 0.45), 0.7);
    for (var i = 1; i < 6; i++) {
      c.drawLine(Offset(rect.left, rect.top + i * 16), Offset(rect.right, rect.top + i * 16), grid);
    }
    c.drawLine(Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), grid);
    c.drawRect(rect, _s(const Color(0xFFB7BCC4), 1.2));
    // a glint sliding down the cells
    final gy = rect.top + ((t * 0.18 + (side > 0 ? 0.4 : 0)) % 1) * rect.height;
    c.drawRect(Rect.fromLTWH(rect.left, gy, rect.width, 3), _f(C.cyan.withValues(alpha: 0.35)));
    if (dust > 0) c.drawRect(rect, _f(const Color(0xFFB8A98E).withValues(alpha: dust * 0.6)));
  }
}

/// Comms antenna pointing at Earth.
void paintAntenna(Canvas c, double t) {
  castShadow(c, 30, 70);
  c.drawLine(const Offset(0, 0), const Offset(0, -70), _s(metal, 3));
  c.drawLine(const Offset(-10, 0), const Offset(0, -30), _s(metalDark, 2));
  c.drawLine(const Offset(10, 0), const Offset(0, -30), _s(metalDark, 2));
  c.save();
  c.translate(2, -72);
  c.rotate(-0.6);
  c.drawOval(const Rect.fromLTWH(-16, -6, 32, 12), _f(const Color(0xFFE7E8EA)));
  c.drawOval(const Rect.fromLTWH(-12, -3.5, 24, 7), _f(const Color(0xFFC9CCD2)));
  c.drawLine(Offset.zero, const Offset(0, -12), _s(metalDark, 1.5));
  c.restore();
  if ((t * 0.9) % 1 < 0.3) c.drawCircle(const Offset(0, -70), 2.4, _f(C.cyan));
}

/// A survey flag for a candidate habitat site.
void paintSiteFlag(Canvas c, double t, String letter, {bool visited = false, bool chosen = false}) {
  final col = chosen ? C.cyan : (visited ? C.frozen : const Color(0xFFFFD27A));
  c.drawLine(const Offset(0, 0), const Offset(0, -64), _s(const Color(0xFFDDDDDD), 2));
  final wave = math.sin(t * 2) * 1.5; // a stiff flag: no wind on the Moon, just a wire frame
  final flag = Path()..moveTo(1, -64)..lineTo(30, -60 + wave * 0.2)..lineTo(30, -44)..lineTo(1, -46)..close();
  c.drawPath(flag, _f(col));
  final tp = TextPainter(text: TextSpan(text: letter, style: const TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 12, color: C.evergreen)), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, Offset(15 - tp.width / 2, -60));
  if (visited) c.drawCircle(const Offset(0, -68), 3, _f(col));
}

/// A rocky rise (Site A on the crater rim).
void paintRim(Canvas c) {
  final p = Path()
    ..moveTo(-110, 4)
    ..lineTo(-70, -30)
    ..lineTo(-30, -46)
    ..lineTo(10, -40)
    ..lineTo(60, -18)
    ..lineTo(100, 4)
    ..close();
  c.drawPath(p, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE2DED6), Color(0xFF9C988F), Color(0xFF6E6A63)]).createShader(const Rect.fromLTWH(-110, -46, 210, 50)));
  final rnd = math.Random(3);
  for (var i = 0; i < 6; i++) {
    final x = -80 + rnd.nextDouble() * 150;
    c.drawOval(Rect.fromCenter(center: Offset(x, -10 - rnd.nextDouble() * 18), width: 14, height: 9), _f(const Color(0xFF8A867E)));
  }
}

/// The permanently shadowed crater floor (Site C): dark and icy.
void paintShadowCrater(Canvas c, double t) {
  final r = const Rect.fromLTWH(-150, -16, 300, 40);
  c.drawOval(r, _f(const Color(0xFF15171C)));
  c.drawOval(r.deflate(14), _f(const Color(0xFF0B0D12)));
  final rnd = math.Random(11);
  for (var i = 0; i < 14; i++) {
    final x = -120 + rnd.nextDouble() * 240;
    final y = -4 + rnd.nextDouble() * 16;
    final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 + i));
    c.drawCircle(Offset(x, y), 1.2, _f(const Color(0xFFBFE8FF).withValues(alpha: 0.5 * tw)));
  }
}

/// Small gear lying on the ground, with a soft cyan ring under it.
void paintPickup(Canvas c, double t, String id, {bool glow = true}) {
  final bob = math.sin(t * 2.4 + id.length) * 1.5;
  if (glow) {
    final pulse = 0.6 + 0.4 * math.sin(t * 3);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: 50, height: 12), _s(C.cyan.withValues(alpha: 0.85 * pulse), 2));
    c.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: 46, height: 10), _f(C.cyan.withValues(alpha: 0.12)));
  }
  c.save();
  c.translate(0, -4 + bob);
  switch (id) {
    case 'kit':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -16, 26, 16), const Radius.circular(3)), _f(C.sapphire));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -20, 12, 5), const Radius.circular(2)), _s(const Color(0xFF2B3C9B), 2));
      c.drawRect(const Rect.fromLTWH(-13, -10, 26, 2), _f(const Color(0xFF2B3C9B)));
      break;
    case 'o2':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -28, 12, 28), const Radius.circular(5)), _f(white));
      c.drawRect(const Rect.fromLTWH(-6, -18, 12, 4), _f(C.cyan));
      c.drawRect(const Rect.fromLTWH(-2.5, -32, 5, 5), _f(metalDark));
      break;
    case 'aid':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 24, 18), const Radius.circular(3)), _f(white));
      c.drawRect(const Rect.fromLTWH(-12, -18, 24, 4), _f(C.cyan));
      c.drawRect(const Rect.fromLTWH(-1.8, -12, 3.6, 9), _f(const Color(0xFFE5484D)));
      c.drawRect(const Rect.fromLTWH(-4.5, -9.3, 9, 3.6), _f(const Color(0xFFE5484D)));
      break;
    case 'radio':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -22, 18, 22), const Radius.circular(3)), _f(const Color(0xFF3A3F4A)));
      c.drawLine(const Offset(5, -22), const Offset(8, -34), _s(metal, 1.5));
      c.drawCircle(const Offset(-3, -15), 3, _f(const Color(0xFF1F232B)));
      c.drawCircle(const Offset(4, -8), 1.6, _f(((t * 2) % 1) < 0.5 ? C.cyan : C.cyan.withValues(alpha: 0.3)));
      break;
    case 'tools':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -14, 28, 14), const Radius.circular(5)), _f(const Color(0xFF59606C)));
      c.drawArc(const Rect.fromLTWH(-7, -21, 14, 12), math.pi, math.pi, false, _s(const Color(0xFF3A3F4A), 2));
      c.drawLine(const Offset(-6, -7), const Offset(6, -7), _s(const Color(0xFFFFD27A), 2));
      break;
    case 'helmet':
      c.drawCircle(const Offset(0, -12), 12, _f(white));
      c.drawArc(Rect.fromCenter(center: const Offset(2, -12), width: 18, height: 14), -1.2, 2.4, true, _f(foilA));
      c.drawRect(const Rect.fromLTWH(-10, -2, 20, 3), _f(metalDark));
      break;
    case 'gloves':
      for (final s in [-1.0, 1.0]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * 7 - 6, -18, 12, 16), const Radius.circular(5)), _f(white));
        c.drawRect(Rect.fromLTWH(s * 7 - 6, -6, 12, 4), _f(C.sapphire));
      }
      break;
    case 'boots':
      for (final s in [-1.0, 1.0]) {
        c.drawPath(Path()..moveTo(s * 8 - 5, -18)..lineTo(s * 8 + 5, -18)..lineTo(s * 8 + 5, -6)..lineTo(s * 8 + 10, -2)..lineTo(s * 8 - 5, -2)..close(), _f(whiteShade));
        c.drawRect(Rect.fromLTWH(s * 8 - 5, -4, 15, 2.5), _f(const Color(0xFF3A3F4A)));
      }
      break;
    case 'pack':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -24, 22, 24), const Radius.circular(4)), _f(white));
      c.drawRect(const Rect.fromLTWH(-11, -16, 22, 3), _f(C.cyan));
      c.drawCircle(const Offset(0, -7), 3, _f(metalDark));
      break;
    case 'rock1':
    case 'rock2':
    case 'rock3':
      final rc = id == 'rock1' ? const Color(0xFF6E6A66) : (id == 'rock2' ? const Color(0xFFB9B3A6) : const Color(0xFF4A4F57));
      c.drawPath(Path()..moveTo(-12, 0)..lineTo(-9, -10)..lineTo(-2, -15)..lineTo(8, -12)..lineTo(13, -3)..lineTo(10, 0)..close(), _f(rc));
      c.drawCircle(const Offset(-3, -8), 1.4, _f(Colors.white.withValues(alpha: 0.35)));
      break;
    case 'ice':
      c.drawPath(Path()..moveTo(-10, 0)..lineTo(-6, -16)..lineTo(4, -20)..lineTo(11, -8)..lineTo(8, 0)..close(), _f(const Color(0xFFBFE9FF)));
      c.drawLine(const Offset(-4, -12), const Offset(3, -16), _s(Colors.white, 1.6));
      break;
    case 'seed':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -18, 20, 18), const Radius.circular(3)), _f(const Color(0xFFE6D3A3)));
      c.drawOval(Rect.fromCenter(center: const Offset(0, -9), width: 9, height: 6), _f(const Color(0xFF4CC163)));
      break;
    case 'filter':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 24, 18), const Radius.circular(9)), _f(white));
      for (var i = 0; i < 4; i++) {
        c.drawLine(Offset(-7 + i * 4.6, -15), Offset(-7 + i * 4.6, -3), _s(C.cyan, 1.4));
      }
      break;
    case 'camera':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -16, 24, 15), const Radius.circular(3)), _f(const Color(0xFF3A3F4A)));
      c.drawCircle(const Offset(1, -8.5), 5, _f(const Color(0xFF1F232B)));
      c.drawCircle(const Offset(1, -8.5), 2.4, _f(C.cyan));
      break;
    case 'flag':
      c.drawLine(const Offset(-6, 0), const Offset(-6, -34), _s(metal, 2));
      c.drawRect(const Rect.fromLTWH(-6, -34, 22, 13), _f(C.sapphire));
      c.drawCircle(const Offset(5, -27.5), 3, _f(white));
      break;
    case 'food':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -16, 24, 16), const Radius.circular(3)), _f(const Color(0xFFE9E3D3)));
      c.drawRect(const Rect.fromLTWH(-12, -10, 24, 4), _f(const Color(0xFFFFB347)));
      break;
    case 'water':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -24, 16, 24), const Radius.circular(6)), _f(const Color(0xFF9AD8F5)));
      c.drawRect(const Rect.fromLTWH(-3, -28, 6, 4), _f(white));
      break;
    case 'sensor':
      c.drawLine(const Offset(0, 0), const Offset(0, -22), _s(metal, 2));
      c.drawCircle(const Offset(0, -24), 5, _f(white));
      c.drawCircle(const Offset(0, -24), 2, _f(((t * 2) % 1) < 0.5 ? C.cyan : C.cyan.withValues(alpha: 0.3)));
      break;
    case 'part':
      c.drawCircle(const Offset(0, -10), 9, _f(metal));
      c.drawCircle(const Offset(0, -10), 4, _f(const Color(0xFF55595F)));
      for (var i = 0; i < 6; i++) {
        final a = i / 6 * math.pi * 2;
        c.drawRect(Rect.fromCenter(center: Offset(math.cos(a) * 10, -10 + math.sin(a) * 10), width: 4, height: 4), _f(metal));
      }
      break;
    case 'battpack':
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 24, 18), const Radius.circular(3)), _f(const Color(0xFF2B3C9B)));
      c.drawRect(const Rect.fromLTWH(-4, -21, 8, 3), _f(metal));
      c.drawPath(Path()..moveTo(1, -15)..lineTo(-4, -8)..lineTo(0, -8)..lineTo(-2, -2)..lineTo(5, -10)..lineTo(1, -10)..close(), _f(const Color(0xFFFFD27A)));
      break;
  }
  c.restore();
}

/// The bouncing marker over the next goal.
void paintGoalArrow(Canvas c, double t, {Color color = C.cyan}) {
  final y = math.sin(t * 4) * 4;
  final p = Path()..moveTo(-8, y - 10)..lineTo(8, y - 10)..lineTo(0, y)..close();
  c.drawPath(p, _f(color));
  c.drawPath(p, _s(Colors.white.withValues(alpha: 0.6), 1));
}

/// The ground ring under the next goal.
void paintGoalRing(Canvas c, double t, double width) {
  final pulse = 0.5 + 0.5 * math.sin(t * 3.2);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: width + pulse * 10, height: 14 + pulse * 3), _s(C.cyan.withValues(alpha: 0.4 + 0.5 * pulse), 2));
}

// ============================================================ 2.0 props

/// The pressurised rover: six wheels, a cabin with windows, a mast camera.
void paintRover(Canvas c, double t, {bool lights = false, double wheelTurn = 0}) {
  castShadow(c, 130, 100);
  // chassis
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-62, -34, 124, 12), const Radius.circular(4)), _f(metalDark));
  // cabin
  final cab = Path()
    ..moveTo(-52, -34)
    ..lineTo(-46, -66)
    ..quadraticBezierTo(-40, -74, -26, -74)
    ..lineTo(38, -74)
    ..quadraticBezierTo(52, -74, 56, -60)
    ..lineTo(60, -34)
    ..close();
  c.drawPath(cab, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [white, whiteShade]).createShader(const Rect.fromLTWH(-52, -74, 112, 40)));
  c.drawPath(cab, _s(const Color(0x33000000), 1.2));
  // windows
  final glass = Paint()..shader = const LinearGradient(colors: [Color(0xFF1B3B4F), Color(0xFF2E6C80)]).createShader(const Rect.fromLTWH(20, -70, 34, 20));
  c.drawPath(Path()..moveTo(22, -68)..lineTo(44, -68)..quadraticBezierTo(52, -68, 54, -56)..lineTo(22, -56)..close(), glass);
  for (final x in [-36.0, -14.0]) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, -66, 16, 10), const Radius.circular(3)), glass);
  }
  // stripe and hatch
  c.drawRect(const Rect.fromLTWH(-50, -46, 108, 3), _f(C.sapphire));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-52, -60, 8, 22), const Radius.circular(2)), _f(metal));
  // mast camera
  c.drawLine(const Offset(-30, -74), const Offset(-30, -92), _s(metal, 2.2));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-37, -98, 14, 7), const Radius.circular(2)), _f(const Color(0xFF3A3F4A)));
  c.drawCircle(const Offset(-26, -94.5), 1.6, _f(((t * 1.5) % 1) < 0.5 ? C.cyan : C.cyan.withValues(alpha: 0.3)));
  // wheels
  for (final x in [-44.0, 0.0, 44.0]) {
    c.drawCircle(Offset(x, -12), 13, _f(const Color(0xFF2A2D33)));
    c.drawCircle(Offset(x, -12), 8, _f(metalDark));
    for (var k = 0; k < 3; k++) {
      final a = wheelTurn + k * math.pi / 3;
      c.drawLine(Offset(x + math.cos(a) * 7, -12 + math.sin(a) * 7), Offset(x - math.cos(a) * 7, -12 - math.sin(a) * 7), _s(const Color(0xFF55595F), 1.6));
    }
  }
  if (lights) {
    final beam = Path()..moveTo(60, -44)..lineTo(170, -60)..lineTo(170, -6)..close();
    c.drawPath(beam, Paint()..shader = LinearGradient(colors: [const Color(0xFFFFF4C8).withValues(alpha: 0.35), const Color(0x00FFF4C8)]).createShader(const Rect.fromLTWH(60, -60, 110, 54)));
    c.drawCircle(const Offset(60, -42), 3, _f(const Color(0xFFFFF4C8)));
  }
}

/// A small greenhouse dome with plants under grow lights.
void paintGreenhouse(Canvas c, double t, {double growth = 1, bool lightsOn = true, bool wilting = false}) {
  castShadow(c, 120, 90);
  final base = RRect.fromRectAndRadius(const Rect.fromLTWH(-58, -16, 116, 16), const Radius.circular(4));
  c.drawRRect(base, _f(whiteShade));
  final dome = Rect.fromCenter(center: const Offset(0, -16), width: 112, height: 110);
  final glow = lightsOn ? const Color(0xFFE38BFF) : const Color(0xFF3A4A52);
  c.drawArc(dome, math.pi, math.pi, true, Paint()..color = glow.withValues(alpha: lightsOn ? 0.18 : 0.25));
  // plants
  final g = growth.clamp(0.0, 1.0);
  for (var i = 0; i < 7; i++) {
    final x = -42.0 + i * 14;
    final h = (18 + (i % 3) * 7) * g * (wilting ? 0.6 : 1);
    final stem = Offset(x, -16 - h);
    c.drawLine(Offset(x, -16), stem, _s(const Color(0xFF3B8F4A), 2));
    final leaf = wilting ? const Color(0xFF9C8F4A) : const Color(0xFF4CC163);
    c.drawOval(Rect.fromCenter(center: stem + Offset(-4, 3 + math.sin(t * 1.4 + i) * 0.6), width: 9 * g + 2, height: 5 * g + 1), _f(leaf));
    c.drawOval(Rect.fromCenter(center: stem + const Offset(4, 6), width: 8 * g + 2, height: 4.5 * g + 1), _f(leaf));
  }
  // glass ribs
  c.drawArc(dome, math.pi, math.pi, false, _s(white.withValues(alpha: 0.85), 2.4));
  for (final a in [0.25, 0.5, 0.75]) {
    final x = -56 + 112 * a;
    final y = -16 - math.sqrt(math.max(0, 1 - math.pow((x) / 56, 2))) * 55;
    c.drawLine(Offset(x, -16), Offset(x, y), _s(white.withValues(alpha: 0.35), 1.2));
  }
  if (lightsOn) c.drawLine(const Offset(-30, -60), const Offset(30, -60), _s(const Color(0xFFF2B8FF), 2));
}

/// The landing pad: a flat sintered ring with lights, optionally a rocket on it.
void paintPad(Canvas c, double t, {bool rocket = false, bool lightsOn = true}) {
  c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 200, height: 18), _f(const Color(0xFF8C8880)));
  c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 150, height: 12), _s(const Color(0xFFE8E4DA), 2));
  for (var i = 0; i < 6; i++) {
    final a = i / 6 * math.pi * 2;
    final on = lightsOn && ((t * 1.2 + i / 6) % 1) < 0.5;
    c.drawCircle(Offset(math.cos(a) * 92, -2 + math.sin(a) * 8), 2.4, _f(on ? const Color(0xFFFFC857) : const Color(0xFF6C6860)));
  }
  if (rocket) {
    castShadow(c, 60, 140);
    final body = Path()
      ..moveTo(-16, -8)
      ..lineTo(-16, -140)
      ..quadraticBezierTo(0, -178, 16, -140)
      ..lineTo(16, -8)
      ..close();
    c.drawPath(body, Paint()..shader = const LinearGradient(colors: [white, whiteShade]).createShader(const Rect.fromLTWH(-16, -178, 32, 170)));
    c.drawRect(const Rect.fromLTWH(-16, -60, 32, 6), _f(C.sapphire));
    c.drawCircle(const Offset(0, -112), 6, _f(const Color(0xFF2E6C80)));
    c.drawCircle(const Offset(0, -112), 6, _s(metal, 1.6));
    for (final s in [-1.0, 1.0]) {
      c.drawPath(Path()..moveTo(s * 16, -40)..lineTo(s * 30, -8)..lineTo(s * 16, -12)..close(), _f(C.sapphire));
    }
  }
}

/// The ice drill rig over the shadowed crater.
void paintDrill(Canvas c, double t, {bool running = false}) {
  castShadow(c, 70, 80);
  for (final s in [-1.0, 1.0]) {
    c.drawLine(Offset(s * 26, 0), const Offset(0, -86), _s(metal, 3));
  }
  c.drawLine(const Offset(-14, -40), const Offset(14, -40), _s(metalDark, 2));
  final y = running ? -60 + math.sin(t * 9) * 2 : -60.0;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-10, y, 20, 18), const Radius.circular(3)), _f(foilB));
  c.drawLine(Offset(0, y + 18), const Offset(0, 4), _s(const Color(0xFF55595F), 3));
  c.drawCircle(const Offset(0, -88), 3, _f(running ? C.cyan : metalDark));
}
