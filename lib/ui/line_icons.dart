/// The Figma design's line icons: 24-unit outlines, 2-unit round strokes
/// (the open-source Lucide style). Drawn from SVG path data, so they stay
/// sharp at any size and match the design exactly.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One icon: SVG path strings plus simple circles and rounded rectangles.
class LineIconData {
  final List<String> paths;
  final List<(double, double, double)> circles; // cx, cy, r
  final List<(double, double, double, double, double)> rects; // x, y, w, h, r
  final bool filled;
  const LineIconData(this.paths, {this.circles = const [], this.rects = const [], this.filled = false});
}

class Ln {
  Ln._();
  static const zap = LineIconData([
    'M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z',
  ]);
  static const wind = LineIconData(['M12.8 19.6A2 2 0 1 0 14 16H2', 'M17.5 8a2.5 2.5 0 1 1 2 4H2', 'M9.8 4.4A2 2 0 1 1 11 8H2']);
  static const droplet = LineIconData(['M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z']);
  static const sprout = LineIconData([
    'M7 20h10',
    'M10 20c5.5-2.5.8-6.4 3-10',
    'M9.5 9.4c1.1.8 1.8 2.2 2.3 3.7-2 .4-3.5.4-4.8-.3-1.2-.6-2.3-1.9-3-4.2 2.8-.5 4.4 0 5.5.8z',
    'M14.1 6a7 7 0 0 0-1.1 4c1.9-.1 3.3-.6 4.3-1.4 1-1 1.6-2.3 1.7-4.6-2.7.1-4 1-4.9 2z',
  ]);
  static const shield = LineIconData([
    'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z',
  ]);
  static const heart = LineIconData(['M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7z']);
  static const flask = LineIconData([
    'M10 2v7.527a2 2 0 0 1-.211.896L4.72 20.55a1 1 0 0 0 .9 1.45h12.76a1 1 0 0 0 .9-1.45l-5.069-10.127A2 2 0 0 1 14 9.527V2',
    'M8.5 2h7',
    'M7 16h10',
  ]);
  static const home = LineIconData([
    'M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8',
    'M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  ]);
  static const chart = LineIconData(['M3 3v18h18', 'M18 17V9', 'M13 17V5', 'M8 17v-3']);
  static const users = LineIconData(
    ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M22 21v-2a4 4 0 0 0-3-3.87', 'M16 3.13a4 4 0 0 1 0 7.75'],
    circles: [(9, 7, 4)],
  );
  static const book = LineIconData([
    'M12 7v14',
    'M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z',
  ]);
  static const alert = LineIconData(['M21.73 18l-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3', 'M12 9v4', 'M12 17h.01']);
  static const bulb = LineIconData([
    'M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5',
    'M9 18h6',
    'M10 22h4',
  ]);
  static const rocket = LineIconData([
    'M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z',
    'M12 15l-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z',
    'M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0',
    'M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5',
  ]);
  static const sun = LineIconData(
    ['M12 2v2', 'M12 20v2', 'M4.93 4.93l1.41 1.41', 'M17.66 17.66l1.41 1.41', 'M2 12h2', 'M20 12h2', 'M6.34 17.66l-1.41 1.41', 'M19.07 4.93l-1.41 1.41'],
    circles: [(12, 12, 4)],
  );
  static const lock = LineIconData(['M7 11V7a5 5 0 0 1 10 0v4'], rects: [(3, 11, 18, 11, 2)]);
  static const star = LineIconData([
    'M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z',
  ], filled: true);
  static const starLine = LineIconData([
    'M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z',
  ]);
  static const wrench = LineIconData([
    'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z',
  ]);
  static const pause = LineIconData([], rects: [(6, 4, 4, 16, 1.2), (14, 4, 4, 16, 1.2)], filled: true);
  static const play = LineIconData(['M7 4.5v15a1 1 0 0 0 1.5.86l12.4-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z'], filled: true);
  static const forward = LineIconData(['M13 19l9-7-9-7z', 'M2 19l9-7-9-7z'], filled: true);
  static const back = LineIconData(['M15 18l-6-6 6-6']);
  static const next = LineIconData(['M9 18l6-6-6-6']);
  static const calendar = LineIconData(['M16 2v4', 'M8 2v4', 'M3 10h18'], rects: [(3, 4, 18, 18, 2)]);
  static const up = LineIconData(['M5 12l7-7 7 7', 'M12 19V5']);
  static const down = LineIconData(['M12 5v14', 'M19 12l-7 7-7-7']);
  static const close = LineIconData(['M18 6L6 18', 'M6 6l12 12']);
  static const check = LineIconData(['M20 6L9 17l-5-5']);
  static const battery = LineIconData(['M22 14v-4', 'M6 14v-4', 'M10 14v-4'], rects: [(2, 6, 16, 12, 2)]);
  static const info = LineIconData(['M12 16v-4', 'M12 8h.01'], circles: [(12, 12, 10)]);
  static const clock = LineIconData(['M12 6v6l4 2'], circles: [(12, 12, 10)]);
  static const radiation = LineIconData([
    'M12 12h.01',
    'M7.5 4.2c-.3-.5-.9-.7-1.3-.4C3.9 5.5 2.3 8.1 2 11c-.1.5.4 1 1 1h5c0-1.5.8-2.8 2-3.4-1.1-1.9-2-3.5-2.5-4.4z',
    'M21 12c.6 0 1-.4 1-1-.3-2.9-1.8-5.5-4.1-7.1-.4-.3-1.1-.2-1.3.3-.6.9-1.5 2.5-2.6 4.3 1.2.7 2 2 2 3.5h5z',
    'M7.5 19.8c-.3.5-.1 1.1.4 1.3 2.6 1.2 5.6 1.2 8.2 0 .5-.2.7-.8.4-1.3-.5-.9-1.4-2.5-2.5-4.3-1.2.7-2.8.7-4 0-1.1 1.8-2 3.4-2.5 4.3z',
  ]);
  static const thermometer = LineIconData(['M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0z']);
  static const award = LineIconData(['M15.477 12.89l1.515 8.526a.5.5 0 0 1-.81.47l-3.58-2.687a1 1 0 0 0-1.197 0l-3.586 2.686a.5.5 0 0 1-.81-.469l1.514-8.526'], circles: [(12, 8, 6)]);
  static const settings = LineIconData([
    'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z',
  ], circles: [(12, 12, 3)]);
  static const user = LineIconData(['M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'], circles: [(12, 7, 4)]);
  static const map = LineIconData([
    'M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z',
    'M15 5.764v15',
    'M9 3.236v15',
  ]);
  static const sparkles = LineIconData([
    'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z',
  ]);
  static const radio = LineIconData([
    'M4.9 19.1C1 15.2 1 8.8 4.9 4.9',
    'M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5',
    'M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5',
    'M19.1 4.9C23 8.8 23 15.1 19.1 19',
  ], circles: [(12, 12, 2)]);
  static const door = LineIconData(['M13 4h3a2 2 0 0 1 2 2v14', 'M2 20h3', 'M13 20h9', 'M10 12v.01', 'M13 4.562v16.157a1 1 0 0 1-1.242.97L5 20V5.562a2 2 0 0 1 1.515-1.94l4-1A2 2 0 0 1 13 4.561z']);
  static const hourglass = LineIconData(['M5 22h14', 'M5 2h14', 'M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22', 'M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2']);
  static const music = LineIconData(['M9 18V5l12-2v13'], circles: [(6, 18, 3), (18, 16, 3)]);
  static const refresh = LineIconData(['M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8', 'M3 3v5h5']);
  static const package = LineIconData([
    'M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z',
    'M12 22V12',
    'M3.29 7L12 12l8.71-5',
    'M7.5 4.27l9 5.15',
  ]);
  static const satellite = LineIconData(['M4 10a7.31 7.31 0 0 0 10 10z', 'M9 15l3-3', 'M17 13a6 6 0 0 0-6-6', 'M21 13A10 10 0 0 0 11 3']);
}

/// Draws a [LineIconData] at [size] in [color].
class LineIcon extends StatelessWidget {
  final LineIconData icon;
  final double size;
  final Color color;
  final double stroke;
  const LineIcon(this.icon, {super.key, this.size = 22, this.color = Colors.white, this.stroke = 2});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: LineIconPainter(icon, color, stroke)));
}

class LineIconPainter extends CustomPainter {
  final LineIconData icon;
  final Color color;
  final double stroke;
  LineIconPainter(this.icon, this.color, this.stroke);

  static final Map<String, Path> _cache = {};

  static Path pathOf(String d) => _cache[d] ??= parseSvgPath(d);

  @override
  void paint(Canvas canvas, Size size) {
    paintLineIcon(canvas, icon, Offset.zero, size.shortestSide, color, stroke: stroke);
  }

  @override
  bool shouldRepaint(covariant LineIconPainter old) => old.icon != icon || old.color != color || old.stroke != stroke;
}

/// Paints an icon into a square at [at] of side [size] (for painters).
void paintLineIcon(Canvas canvas, LineIconData icon, Offset at, double size, Color color, {double stroke = 2}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(size / 24);
  final p = Paint()
    ..color = color
    ..isAntiAlias = true;
  if (icon.filled) {
    p.style = PaintingStyle.fill;
  } else {
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }
  for (final d in icon.paths) {
    canvas.drawPath(LineIconPainter.pathOf(d), p);
  }
  for (final (cx, cy, r) in icon.circles) {
    canvas.drawCircle(Offset(cx, cy), r, p);
  }
  for (final (x, y, w, h, r) in icon.rects) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);
  }
  canvas.restore();
}

/// A small SVG path parser (M L H V C S Q T A Z, absolute and relative).
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  var lcx = 0.0, lcy = 0.0; // last control point (for S and T)
  var lastCmd = '';
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cx = sx;
        cy = sy;
        lastCmd = cmd;
        continue;
      }
    }
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        cx = ox + n();
        cy = oy + n();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        cmd = rel ? 'l' : 'L'; // extra pairs after M are lines
      case 'L':
        cx = ox + n();
        cy = oy + n();
        path.lineTo(cx, cy);
      case 'H':
        cx = (rel ? cx : 0) + n();
        path.lineTo(cx, cy);
      case 'V':
        cy = (rel ? cy : 0) + n();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n(), x = ox + n(), y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lcx = x2;
        lcy = y2;
        cx = x;
        cy = y;
      case 'S':
        final reflect = 'CcSs'.contains(lastCmd);
        final x1 = reflect ? 2 * cx - lcx : cx, y1 = reflect ? 2 * cy - lcy : cy;
        final x2 = ox + n(), y2 = oy + n(), x = ox + n(), y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lcx = x2;
        lcy = y2;
        cx = x;
        cy = y;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n(), x = ox + n(), y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        lcx = x1;
        lcy = y1;
        cx = x;
        cy = y;
      case 'T':
        final reflect = 'QqTt'.contains(lastCmd);
        final x1 = reflect ? 2 * cx - lcx : cx, y1 = reflect ? 2 * cy - lcy : cy;
        final x = ox + n(), y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        lcx = x1;
        lcy = y1;
        cx = x;
        cy = y;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        final x = ox + n(), y = oy + n();
        path.arcToPoint(Offset(x, y), radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        cx = x;
        cy = y;
      default:
        i++;
    }
    lastCmd = cmd;
  }
  return path;
}

/// For tests and tools: the angle in degrees between two offsets.
double angleBetween(Offset a, Offset b) => math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
