/// Earth, the Moon and small space props for the menu screens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Earth behind the Moon at the real size ratio (Earth is 3.67 times wider),
/// with a thin orbit and a tiny ship. [t] animates the clouds and the ship;
/// [intro] 0..1 drifts everything into place.
class EarthMoonPainter extends CustomPainter {
  final double t;
  final double intro;
  EarthMoonPainter(this.t, {this.intro = 1});

  @override
  void paint(Canvas canvas, Size s) {
    final k = Curves.easeOutCubic.transform(intro.clamp(0.0, 1.0));
    final er = s.width * 0.33;
    final e = Offset(s.width * 0.6 + (1 - k) * 30, s.height * 0.4 - (1 - k) * 20);
    paintEarth(canvas, e, er, t, opacity: k);
    // orbit and ship
    final orbit = Rect.fromCenter(center: e + Offset(-er * 0.15, er * 0.5), width: er * 2.7, height: er * 0.62);
    canvas.save();
    canvas.translate(orbit.center.dx, orbit.center.dy);
    canvas.rotate(-0.28);
    canvas.translate(-orbit.center.dx, -orbit.center.dy);
    canvas.drawOval(orbit, Paint()
      ..color = C.cyan.withValues(alpha: 0.35 * k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    final a = t * 0.25;
    final ship = Offset(orbit.center.dx + math.cos(a) * orbit.width / 2, orbit.center.dy + math.sin(a) * orbit.height / 2);
    canvas.save();
    canvas.translate(ship.dx, ship.dy);
    canvas.rotate(math.atan2(math.cos(a) * orbit.height, -math.sin(a) * orbit.width));
    final body = Path()..moveTo(14, 0)..quadraticBezierTo(4, -6, -10, -4)..lineTo(-10, 4)..quadraticBezierTo(4, 6, 14, 0)..close();
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: k));
    canvas.drawCircle(const Offset(2, 0), 2, Paint()..color = C.cyan.withValues(alpha: k));
    canvas.drawPath(Path()..moveTo(-10, -4)..lineTo(-15, -8)..lineTo(-12, 0)..lineTo(-15, 8)..lineTo(-10, 4)..close(), Paint()..color = C.sapphire.withValues(alpha: k));
    canvas.restore();
    canvas.restore();
    // the Moon, in front, lower left
    final mr = er / 3.67 * 1.9; // a little larger than true scale so it reads, still clearly smaller
    final m = Offset(s.width * 0.27 - (1 - k) * 30, s.height * 0.73 + (1 - k) * 24);
    paintMoon(canvas, m, mr, opacity: k);
    // the landing site glows at the south pole
    final site = m + Offset(0, mr * 0.95);
    final pulse = 0.5 + 0.5 * math.sin(t * 2.4);
    canvas.drawCircle(site, 10 + pulse * 6, Paint()..color = C.cyan.withValues(alpha: 0.25 * k));
    canvas.drawCircle(site, 4, Paint()..color = C.cyan.withValues(alpha: k));
  }

  @override
  bool shouldRepaint(covariant EarthMoonPainter old) => old.t != t || old.intro != intro;
}

void paintEarth(Canvas canvas, Offset c, double r, double t, {double opacity = 1}) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.saveLayer(rect.inflate(r * 0.3), Paint()..color = Colors.white.withValues(alpha: opacity));
  canvas.drawCircle(c, r * 1.12, Paint()..shader = RadialGradient(colors: [C.cyan.withValues(alpha: 0.35), C.cyan.withValues(alpha: 0)], stops: const [0.85, 1]).createShader(Rect.fromCircle(center: c, radius: r * 1.12)));
  canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.45), radius: 1.0, colors: [Color(0xFF6CC4FF), Color(0xFF2A6FD6), Color(0xFF123E8E)]).createShader(rect));
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  final land = Paint()..color = const Color(0xFF4F9F55);
  final drift = (t * r * 0.012) % (r * 2.4);
  for (var k = -1; k <= 1; k++) {
    final o = c + Offset(-r * 0.4 + drift + k * r * 2.4, -r * 0.1);
    canvas.drawPath(
      Path()
        ..moveTo(o.dx - r * 0.35, o.dy - r * 0.55)
        ..cubicTo(o.dx + r * 0.05, o.dy - r * 0.75, o.dx + r * 0.25, o.dy - r * 0.35, o.dx + r * 0.05, o.dy - r * 0.05)
        ..cubicTo(o.dx - r * 0.05, o.dy + r * 0.2, o.dx + r * 0.05, o.dy + r * 0.45, o.dx - r * 0.1, o.dy + r * 0.55)
        ..cubicTo(o.dx - r * 0.25, o.dy + r * 0.3, o.dx - r * 0.5, o.dy - r * 0.15, o.dx - r * 0.35, o.dy - r * 0.55),
      land,
    );
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + r * 0.65, o.dy - r * 0.4)
        ..cubicTo(o.dx + r * 0.9, o.dy - r * 0.55, o.dx + r * 1.25, o.dy - r * 0.35, o.dx + r * 1.2, o.dy - r * 0.1)
        ..cubicTo(o.dx + r * 1.05, o.dy + r * 0.05, o.dx + r * 0.7, o.dy, o.dx + r * 0.65, o.dy - r * 0.4),
      Paint()..color = const Color(0xFF8C7E52),
    );
  }
  final cloud = Paint()
    ..color = Colors.white.withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.045
    ..strokeCap = StrokeCap.round;
  final cd = (t * r * 0.02) % (r * 2);
  canvas.drawLine(c + Offset(-r * 0.9 + cd * 0.3, -r * 0.72), c + Offset(r * 0.2 + cd * 0.3, -r * 0.78), cloud);
  canvas.drawLine(c + Offset(-r * 0.6 - cd * 0.2, -r * 0.18), c + Offset(r * 0.6 - cd * 0.2, -r * 0.22), cloud);
  canvas.drawLine(c + Offset(-r * 0.3 + cd * 0.25, r * 0.45), c + Offset(r * 0.8 + cd * 0.25, r * 0.4), cloud);
  // night side on the lower right
  canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0x00020818), const Color(0x00020818), const Color(0xFF020818).withValues(alpha: 0.8)], stops: const [0, 0.5, 0.95]).createShader(rect));
  canvas.restore();
  canvas.restore();
}

void paintMoon(Canvas canvas, Offset c, double r, {double opacity = 1}) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.saveLayer(rect.inflate(4), Paint()..color = Colors.white.withValues(alpha: opacity));
  canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-0.45, -0.45), radius: 1.1, colors: [Color(0xFFF1F0EA), Color(0xFFC9C7BF), Color(0xFF8E8B84), Color(0xFF4A4843)], stops: [0, 0.4, 0.8, 1]).createShader(rect));
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  final mare = Paint()..color = const Color(0xFF9D9A93).withValues(alpha: 0.75);
  canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * 0.3, -r * 0.35), width: r * 0.85, height: r * 0.45), mare);
  canvas.drawOval(Rect.fromCenter(center: c + Offset(r * 0.25, r * 0.12), width: r * 0.65, height: r * 0.48), mare);
  for (final (dx, dy, cr) in [(-0.35, 0.35, 0.13), (0.42, -0.42, 0.09), (0.0, 0.72, 0.14), (-0.65, 0.0, 0.07)]) {
    final cc = c + Offset(r * dx, r * dy);
    canvas.drawCircle(cc, r * cr, Paint()..color = const Color(0xFFA5A29B));
    canvas.drawCircle(cc + Offset(r * cr * 0.15, r * cr * 0.15), r * cr * 0.7, Paint()..color = const Color(0xFF8E8B84));
  }
  canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0x0005070A), const Color(0x0005070A), const Color(0xFF05070A).withValues(alpha: 0.7)], stops: const [0, 0.55, 1]).createShader(rect));
  canvas.restore();
  canvas.restore();
}

/// The four-point star logo drawing itself in (the app start animation).
class StarLogoPainter extends CustomPainter {
  final double v;
  StarLogoPainter(this.v);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final i = r * 0.22;
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + i * 0.4, c.dy - i * 0.4, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + i * 0.4, c.dy + i * 0.4, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - i * 0.4, c.dy + i * 0.4, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - i * 0.4, c.dy - i * 0.4, c.dx, c.dy - r);
    for (final m in p.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * v.clamp(0.0, 1.0)), Paint()
        ..color = C.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }
    if (v > 0.7) canvas.drawPath(p..close(), Paint()..color = C.cyan.withValues(alpha: ((v - 0.7) / 0.3).clamp(0.0, 1.0)));
  }

  @override
  bool shouldRepaint(covariant StarLogoPainter old) => old.v != v;
}
