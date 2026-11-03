import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/messages.dart';
import '../theme.dart';

class FaceStyle {
  final Color skin;
  final Color hair;
  final bool longHair;
  const FaceStyle(this.skin, this.hair, {this.longHair = false});
}

const novaFace = FaceStyle(Color(0xFFC99A74), Color(0xFF2A1A12), longHair: true);
const junFace = FaceStyle(Color(0xFFE2BC93), Color(0xFF111111));
const tomasFace = FaceStyle(Color(0xFF8E5E3E), Color(0xFF1E140E));

/// Astronaut portrait in a helmet. Blinks, talks and changes expression.
class AstronautAvatar extends StatefulWidget {
  final Mood mood;
  final double size;
  final bool talking;
  final FaceStyle face;

  const AstronautAvatar({super.key, required this.mood, this.size = 64, this.talking = false, this.face = novaFace});

  @override
  State<AstronautAvatar> createState() => _AstronautAvatarState();
}

class _AstronautAvatarState extends State<AstronautAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final blink = t > 0.94 ? math.sin((t - 0.94) / 0.06 * math.pi) : 0.0;
          final mouth = widget.talking ? (math.sin(t * math.pi * 2 * 14) * 0.5 + 0.5) : 0.0;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _FacePainter(widget.mood, blink, mouth, widget.face, t),
          );
        },
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final Mood mood;
  final double blink; // 0 open .. 1 closed
  final double mouthOpen; // 0..1 while talking
  final FaceStyle face;
  final double t;

  _FacePainter(this.mood, this.blink, this.mouthOpen, this.face, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    // helmet shell
    final shell = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFC9CED6)], center: Alignment(-0.3, -0.4))
          .createShader(Rect.fromCircle(center: c, radius: s / 2));
    canvas.drawCircle(c, s * 0.49, shell);
    canvas.drawCircle(c, s * 0.49, Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02);
    // visor opening
    final visorRect = Rect.fromCenter(center: c.translate(0, s * 0.03), width: s * 0.74, height: s * 0.66);
    final visor = RRect.fromRectAndRadius(visorRect, Radius.circular(s * 0.3));
    canvas.save();
    canvas.clipRRect(visor);
    canvas.drawRect(visorRect, Paint()..color = const Color(0xFF0B1424));
    // face
    final fc = c.translate(0, s * 0.08);
    final skin = Paint()..color = face.skin;
    // hair behind
    final hair = Paint()..color = face.hair;
    if (face.longHair) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: fc.translate(0, s * 0.06), width: s * 0.5, height: s * 0.52), Radius.circular(s * 0.2)), hair);
    }
    canvas.drawOval(Rect.fromCenter(center: fc, width: s * 0.42, height: s * 0.5), skin);
    // hair top
    canvas.drawArc(Rect.fromCenter(center: fc.translate(0, -s * 0.06), width: s * 0.46, height: s * 0.44), math.pi, math.pi, true, hair);
    // comms cap band
    canvas.drawArc(Rect.fromCenter(center: fc.translate(0, -s * 0.04), width: s * 0.5, height: s * 0.5), math.pi * 1.05, math.pi * 0.9, false,
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035);

    final eyeY = fc.dy - s * 0.02;
    final ex = s * 0.085;
    final ink = Paint()..color = const Color(0xFF1A1110);
    final strokeInk = Paint()
      ..color = const Color(0xFF1A1110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    // eyebrows
    double browTilt = 0, browLift = 0;
    switch (mood) {
      case Mood.worried:
        browTilt = 0.35;
        browLift = 0.01;
        break;
      case Mood.scared:
        browTilt = 0.4;
        browLift = 0.035;
        break;
      case Mood.tired:
        browTilt = -0.1;
        browLift = -0.01;
        break;
      case Mood.happy:
        browLift = 0.02;
        break;
      case Mood.calm:
        break;
    }
    for (final side in [-1.0, 1.0]) {
      final bx = fc.dx + side * ex;
      final by = eyeY - s * 0.07 - s * browLift;
      final dx = s * 0.045;
      final dy = s * 0.03 * browTilt;
      canvas.drawLine(Offset(bx - dx, by + (side > 0 ? -dy : dy)), Offset(bx + dx, by + (side > 0 ? dy : -dy)), strokeInk);
    }

    // eyes
    final open = (1 - blink) * (mood == Mood.tired ? 0.45 : mood == Mood.scared ? 1.25 : 1.0);
    for (final side in [-1.0, 1.0]) {
      final e = Offset(fc.dx + side * ex, eyeY);
      if (mood == Mood.happy && blink < 0.5) {
        canvas.drawArc(Rect.fromCenter(center: e.translate(0, s * 0.01), width: s * 0.07, height: s * 0.06), math.pi * 1.1, math.pi * 0.8, false, strokeInk);
      } else {
        final h = math.max(s * 0.006, s * 0.05 * open);
        canvas.drawOval(Rect.fromCenter(center: e, width: s * 0.05, height: h), ink);
        if (open > 0.6) canvas.drawCircle(e.translate(s * 0.008, -s * 0.008), s * 0.008, Paint()..color = Colors.white);
      }
    }

    // mouth
    final my = fc.dy + s * 0.12;
    final mw = s * 0.11;
    final mouthPaint = Paint()..color = const Color(0xFF5A1E1E);
    if (mouthOpen > 0.15 || mood == Mood.scared) {
      final h = s * (0.02 + 0.05 * (mood == Mood.scared ? 0.9 : mouthOpen));
      canvas.drawOval(Rect.fromCenter(center: Offset(fc.dx, my), width: mw * 0.8, height: h), mouthPaint);
    } else {
      double curve = 0.02;
      switch (mood) {
        case Mood.happy:
          curve = 0.045;
          break;
        case Mood.calm:
          curve = 0.02;
          break;
        case Mood.tired:
          curve = -0.005;
          break;
        case Mood.worried:
          curve = -0.02;
          break;
        case Mood.scared:
          curve = -0.03;
          break;
      }
      final path = Path()
        ..moveTo(fc.dx - mw / 2, my)
        ..quadraticBezierTo(fc.dx, my + s * curve * 2, fc.dx + mw / 2, my);
      canvas.drawPath(path, strokeInk..strokeWidth = s * 0.02);
    }
    if (mood == Mood.happy) {
      final blush = Paint()..color = const Color(0x33FF6B6B);
      canvas.drawCircle(Offset(fc.dx - ex * 1.3, my - s * 0.04), s * 0.035, blush);
      canvas.drawCircle(Offset(fc.dx + ex * 1.3, my - s * 0.04), s * 0.035, blush);
    }
    if (mood == Mood.worried || mood == Mood.scared) {
      final drop = Paint()..color = const Color(0x8899DDFF);
      canvas.drawOval(Rect.fromCenter(center: Offset(fc.dx + s * 0.17, fc.dy - s * 0.1), width: s * 0.025, height: s * 0.04), drop);
    }

    // visor reflection
    final refl = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55E9B54A), Color(0x00E9B54A), Color(0x22FFFFFF)],
        stops: [0, 0.5, 1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(visorRect);
    canvas.drawRect(visorRect, refl);
    final glint = Path()
      ..moveTo(visorRect.left + s * 0.08, visorRect.top + s * 0.14)
      ..quadraticBezierTo(visorRect.left + s * 0.12, visorRect.top + s * 0.04, visorRect.left + s * 0.26, visorRect.top + s * 0.03);
    canvas.drawPath(glint, Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round);
    canvas.restore();
    canvas.drawRRect(visor, Paint()
      ..color = const Color(0xFF9AA3B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025);
    // helmet light
    final lampOn = (math.sin(t * math.pi * 2) > -0.2);
    canvas.drawCircle(Offset(c.dx - s * 0.3, c.dy - s * 0.3), s * 0.035, Paint()..color = lampOn ? C.cyan : const Color(0xFF2A4A55));
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => true;
}

/// Portrait for any speaker: astronauts get a face, others an icon badge.
class SpeakerAvatar extends StatelessWidget {
  final Speaker speaker;
  final Mood mood;
  final double size;
  final bool talking;

  const SpeakerAvatar({super.key, required this.speaker, this.mood = Mood.calm, this.size = 44, this.talking = false});

  @override
  Widget build(BuildContext context) {
    switch (speaker) {
      case Speaker.nova:
        return AstronautAvatar(mood: mood, size: size, talking: talking);
      case Speaker.jun:
        return AstronautAvatar(mood: mood, size: size, talking: talking, face: junFace);
      case Speaker.tomas:
        return AstronautAvatar(mood: mood, size: size, talking: talking, face: tomasFace);
      case Speaker.capcom:
        return _badge(Icons.headset_mic_rounded, C.cyan);
      case Speaker.lina:
        return _badge(Icons.medical_services_rounded, C.green);
      case Speaker.aria:
        return _badge(Icons.memory_rounded, C.amber);
      case Speaker.home:
        return _badge(Icons.favorite_rounded, C.violet);
    }
  }

  Widget _badge(IconData icon, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

Color speakerColor(Speaker s) {
  switch (s) {
    case Speaker.nova:
    case Speaker.jun:
    case Speaker.tomas:
      return C.text;
    case Speaker.capcom:
      return C.cyan;
    case Speaker.lina:
      return C.green;
    case Speaker.aria:
      return C.amber;
    case Speaker.home:
      return C.violet;
  }
}
