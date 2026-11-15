import 'package:flutter/material.dart';

/// Vector portrait matching the app logo: pale helmet, blue visor, orange antenna.
/// Drawn directly so the silhouette stays sharp and the antenna is never cropped.
class HelperFace extends StatelessWidget {
  final double size;
  const HelperFace({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.square(size), painter: const _HelmetPainter()),
  );
}

class _HelmetPainter extends CustomPainter {
  const _HelmetPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final shell = Rect.fromCircle(center: const Offset(48, 55), radius: 39);
    final shadow = Path()..addOval(shell);
    canvas.drawShadow(shadow, const Color(0xAA071329), 5, true);
    // Antenna is inside the portrait bounds rather than clipped by an image crop.
    canvas.drawLine(const Offset(76, 27), const Offset(77, 10),
      Paint()..color = const Color(0xFFA8C6C1)..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(77, 9), 5, Paint()..color = const Color(0xFFFF913D));
    canvas.drawCircle(const Offset(76, 7.5), 1.7, Paint()..color = const Color(0xFFFFD4A3));
    canvas.drawOval(shell, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFE8FFF5), Color(0xFFBBD4CE)],
    ).createShader(shell));
    canvas.drawOval(shell.deflate(1), Paint()..color = const Color(0xFFABC8BD)..style = PaintingStyle.stroke..strokeWidth = 2);
    final visor = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 37, 57, 40), const Radius.circular(19));
    canvas.drawRRect(visor.inflate(2), Paint()..color = const Color(0xFFEFFFF8));
    canvas.drawRRect(visor, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF516CFF), Color(0xFF343FAF), Color(0xFF18245C)],
    ).createShader(visor.outerRect));
    final shine = Path()..moveTo(29, 47)..quadraticBezierTo(32, 41, 43, 41);
    canvas.drawPath(shine, Paint()..color = const Color(0xFFC8DEFF)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(67, 66), 3, Paint()..color = const Color(0xFF8FA7DE));
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _HelmetPainter oldDelegate) => false;
}
