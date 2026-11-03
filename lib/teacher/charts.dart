/// Hand-drawn charts for the teacher dashboard and the player's skills map.
/// No chart package: everything is a CustomPainter in the app's palette.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Light palette for the teacher app (high contrast on white).
class TC {
  static const bg = Color(0xFFF2F8F5);
  static const card = Colors.white;
  static const ink = C.evergreen;
  static const sub = Color(0xFF4F6B5C);
  static const faint = Color(0xFF9DB3A8);
  static const line = Color(0xFFDDE8E2);
  static const blue = C.sapphire;
  static const teal = Color(0xFF07949E); // Strong Cyan, darkened for text on white
  static const indigo = C.indigo;
  static const warn = Color(0xFFD9822B);
  static const bad = Color(0xFFD64550);
  static const good = Color(0xFF168A55);
}

/// Six-axis skills radar. [values] 0..1; [compare] draws a second outline (class average).
class RadarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<double>? compare;
  final bool dark;
  const RadarChart({super.key, required this.labels, required this.values, this.compare, this.dark = false});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, k, _) => CustomPaint(painter: _RadarPainter(labels, values, compare, dark, k), size: Size.infinite),
      );
}

class _RadarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<double>? compare;
  final bool dark;
  final double k;
  _RadarPainter(this.labels, this.values, this.compare, this.dark, this.k);

  @override
  void paint(Canvas c, Size s) {
    final n = labels.length;
    if (n < 3) return;
    final center = Offset(s.width / 2, s.height / 2 + 4);
    final r = math.min(s.width, s.height) / 2 - 34;
    Offset at(int i, double f) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return center + Offset(math.cos(a), math.sin(a)) * r * f;
    }

    final grid = Paint()
      ..color = dark ? C.line : TC.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final p = Path()..moveTo(at(0, f).dx, at(0, f).dy);
      for (var i = 1; i < n; i++) {
        p.lineTo(at(i, f).dx, at(i, f).dy);
      }
      p.close();
      c.drawPath(p, grid);
    }
    for (var i = 0; i < n; i++) {
      c.drawLine(center, at(i, 1), grid);
    }
    Path shape(List<double> v) {
      final p = Path()..moveTo(at(0, v[0].clamp(0.02, 1) * k).dx, at(0, v[0].clamp(0.02, 1) * k).dy);
      for (var i = 1; i < n; i++) {
        final q = at(i, v[i].clamp(0.02, 1) * k);
        p.lineTo(q.dx, q.dy);
      }
      return p..close();
    }

    if (compare != null && compare!.length == n) {
      c.drawPath(shape(compare!), Paint()
        ..color = (dark ? C.frozen : TC.faint).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
    }
    final main = shape(values);
    final col = dark ? C.cyan : TC.blue;
    c.drawPath(main, Paint()..color = col.withValues(alpha: 0.25));
    c.drawPath(main, Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < n; i++) {
      c.drawCircle(at(i, values[i].clamp(0.02, 1) * k), 3.5, Paint()..color = col);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(fontFamily: F.body, fontWeight: FontWeight.w700, fontSize: 11.5, color: dark ? C.muted : TC.sub)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 90);
      final p = at(i, 1.16);
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.k != k || old.values != values || old.compare != compare;
}

/// A big progress ring with a number in the middle.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final String center;
  final String sub;
  final double size;
  final Color color;
  const ProgressRing({super.key, required this.value, required this.center, this.sub = '', this.size = 132, this.color = TC.blue});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v, color),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(center, style: TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: size * 0.24, color: TC.ink)),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 11.5, color: TC.sub), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  _RingPainter(this.v, this.color);

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 8);
    c.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = TC.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()
      ..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: [C.cyan, color]).createShader(r)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

/// One horizontal bar with a label and value; [mark] draws a target line.
class HBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final String text;
  final Color color;
  final double? mark;
  const HBar({super.key, required this.label, required this.value, required this.text, this.color = TC.blue, this.mark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 104, child: Text(label, style: const TextStyle(fontFamily: F.body, fontWeight: FontWeight.w700, fontSize: 12.5, color: TC.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: LayoutBuilder(builder: (context, b) {
              return Stack(clipBehavior: Clip.none, children: [
                Container(height: 12, decoration: BoxDecoration(color: TC.line, borderRadius: BorderRadius.circular(6))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(width: b.maxWidth * v, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                ),
                if (mark != null)
                  Positioned(
                    left: b.maxWidth * mark!.clamp(0, 1) - 1,
                    top: -3,
                    child: Container(width: 2, height: 18, color: TC.ink),
                  ),
              ]);
            }),
          ),
          SizedBox(width: 44, child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: 12.5, color: TC.ink))),
        ]),
      );
}

/// Before and after bars (Readiness Check), with the gain.
class GainBars extends StatelessWidget {
  final int? before;
  final int? after;
  const GainBars({super.key, this.before, this.after});

  @override
  Widget build(BuildContext context) {
    Widget bar(String label, int? v, Color c) => Expanded(
          child: Column(children: [
            SizedBox(
              height: 110,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (v ?? 0) / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, k, _) => Container(
                    width: 46,
                    height: 4 + 104 * k,
                    decoration: BoxDecoration(color: v == null ? TC.line : c, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(v == null ? '—' : '$v%', style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 20, color: TC.ink)),
            Text(label, style: const TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 12, color: TC.sub)),
          ]),
        );
    final gain = before != null && after != null ? after! - before! : null;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      bar('Before', before, TC.faint),
      bar('After', after, TC.blue),
      Expanded(
        child: Column(children: [
          Text(gain == null ? '—' : '${gain >= 0 ? '+' : ''}$gain', style: TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 40, color: gain == null ? TC.faint : (gain >= 0 ? TC.good : TC.bad))),
          const Text('points gained', style: TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 12, color: TC.sub)),
          const SizedBox(height: 22),
        ]),
      ),
    ]);
  }
}

/// How many students finished each level (a funnel as vertical bars).
class LevelBars extends StatelessWidget {
  final List<int> finished;
  final int students;
  final int? highlight;
  const LevelBars({super.key, required this.finished, required this.students, this.highlight});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < finished.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: students == 0 ? 0 : finished[i] / students),
                    duration: Duration(milliseconds: 500 + 40 * i),
                    curve: Curves.easeOutCubic,
                    builder: (context, k, _) => Container(
                      height: 4 + 86 * k,
                      decoration: BoxDecoration(color: highlight == i + 1 ? TC.warn : TC.blue.withValues(alpha: 0.35 + 0.65 * k), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${i + 1}', style: const TextStyle(fontFamily: F.mono, fontSize: 9.5, color: TC.sub)),
                ]),
              ),
            ),
        ]),
      );
}
