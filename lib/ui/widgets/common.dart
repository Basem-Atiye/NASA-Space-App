import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Twilight Indigo glass card with a thin Frozen Water edge.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final bool blur;
  final double radius;

  /// Kept for older call sites; brackets are no longer drawn.
  final bool brackets;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.color,
    this.blur = false,
    this.radius = 20,
    this.brackets = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? C.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? C.line, width: 1),
      ),
      child: child,
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: box),
    );
  }
}

/// Anything that shrinks a little when pressed, with a light vibration.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// The one main action on a screen: solid Electric Sapphire with a soft glow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final double height;
  const PrimaryButton({super.key, required this.label, this.icon, this.onTap, this.color = C.sapphire, this.textColor = Colors.white, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: enabled ? color : C.panelSolid,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? [BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 26, offset: const Offset(0, 8))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: enabled ? textColor : C.dim, size: 20), const SizedBox(width: 10)],
          Flexible(child: Text(label.toUpperCase(), style: T.button.copyWith(color: enabled ? textColor : C.dim), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

/// Second-level button: Strong Cyan outline, or a filled variant of any colour.
class HudButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final bool compact;
  final String? badge;

  const HudButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = C.cyan,
    this.filled = false,
    this.compact = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : C.dim;
    final solid = filled && enabled;
    final fg = solid ? (c == C.cyan || c == C.frozen ? C.evergreen : Colors.white) : c;
    return Pressable(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: Motion.fast,
          constraints: BoxConstraints(minHeight: compact ? 40 : 48, minWidth: compact ? 40 : 48),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: solid ? c : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(color: c.withValues(alpha: enabled ? (solid ? 1 : 0.6) : 0.3), width: 1.2),
            boxShadow: solid ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) Icon(icon, size: compact ? 17 : 19, color: fg),
            if (icon != null && label.isNotEmpty) const SizedBox(width: 8),
            if (label.isNotEmpty) Flexible(child: Text(label, style: T.h3.copyWith(color: fg, fontSize: compact ? 12.5 : 14, letterSpacing: 0.6), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(8)),
              child: Text(badge!, style: T.monoSmall.copyWith(color: Colors.white, fontSize: 10)),
            ),
          ),
      ]),
    );
  }
}

/// The four-point star from the palette: logo, sparkles and stars.
class SparkleStar extends StatelessWidget {
  final double size;
  final Color color;
  const SparkleStar({super.key, this.size = 16, this.color = C.cyan});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _SparklePainter(color)));
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter(this.color);
  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(sparklePath(s.center(Offset.zero), s.width / 2), Paint()..color = color);
  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

/// A four-point star centred on [c] with outer radius [r].
Path sparklePath(Offset c, double r) {
  final i = r * 0.22;
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + i * 0.4, c.dy - i * 0.4, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + i * 0.4, c.dy + i * 0.4, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - i * 0.4, c.dy + i * 0.4, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - i * 0.4, c.dy - i * 0.4, c.dx, c.dy - r)
    ..close();
}

/// Evergreen-black space with slowly drifting Indigo, Sapphire and Cyan
/// glows and twinkling stars: the background of every menu screen.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final double intensity;
  const AuroraBackground({super.key, this.child, this.intensity = 1});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: AuroraPainter(_c.value, widget.intensity)),
        ),
      ),
      if (widget.child != null) widget.child!,
    ]);
  }
}

class AuroraPainter extends CustomPainter {
  final double t; // 0..1 loop
  final double intensity;
  AuroraPainter(this.t, this.intensity);

  static final List<Offset> _stars = List.generate(90, (i) {
    final r = math.Random(i * 7919 + 13);
    return Offset(r.nextDouble(), r.nextDouble());
  });

  void _glow(Canvas canvas, Offset c, double r, Color color, double a) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: a * intensity), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = C.bg);
    final a = t * math.pi * 2;
    _glow(canvas, Offset(s.width * (0.82 + 0.06 * math.sin(a)), s.height * (0.16 + 0.03 * math.cos(a))), s.width * 0.8, C.sapphire, 0.5);
    _glow(canvas, Offset(s.width * (0.1 + 0.05 * math.cos(a)), s.height * 0.38), s.width * 0.75, C.indigo, 0.9);
    _glow(canvas, Offset(s.width * (0.5 + 0.08 * math.sin(a * 2)), s.height * (0.62 + 0.02 * math.sin(a))), s.width * 0.7, C.cyan, 0.3);
    final p = Paint()..color = C.frozen;
    for (var i = 0; i < _stars.length; i++) {
      final o = _stars.elementAt(i);
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(a * 3 + i * 1.7));
      p.color = C.frozen.withValues(alpha: tw * 0.8);
      canvas.drawCircle(Offset(o.dx * s.width, o.dy * s.height), i % 9 == 0 ? 1.4 : 0.8, p);
    }
  }

  @override
  bool shouldRepaint(covariant AuroraPainter old) => old.t != t;
}

/// A labelled bar gauge: label, thin bar, value.
class GaugeBar extends StatelessWidget {
  final String label;
  final String value;
  final double frac;
  final Color color;
  final bool pulse;
  const GaugeBar({super.key, required this.label, required this.value, required this.frac, this.color = C.cyan, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Pulse(
      active: pulse,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: T.label.copyWith(fontSize: 10, letterSpacing: 1.2, color: color)),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: frac.clamp(0.0, 1.0).toDouble()),
                  duration: Motion.slow,
                  curve: Motion.curve,
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: color, backgroundColor: C.lineSoft),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(value, style: T.h3.copyWith(fontSize: 12.5)),
          ]),
        ]),
      ),
    );
  }
}

/// Small ring gauge.
class RingGauge extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double size;
  final IconData icon;
  final bool pulse;

  const RingGauge({super.key, required this.value, required this.color, required this.icon, this.size = 34, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, color),
          child: Center(child: Icon(icon, size: size * 0.45, color: color)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  _RingPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 2.5;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = C.lineSoft
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

/// Soft pulsing glow used for gauges entering danger (never harsh flashing).
class Pulse extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;
  const Pulse({super.key, required this.child, required this.active, this.color = C.red});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _c.value > 0 ? [BoxShadow(color: widget.color.withValues(alpha: 0.35 * _c.value), blurRadius: 16)] : null,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow({super.key, required this.stars, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: i < stars ? SparkleStar(size: size, color: C.cyan) : SparkleStar(size: size, color: C.lineSoft),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SectionLabel(this.text, {super.key, this.color = C.cyan});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: T.label.copyWith(color: color));
}

/// Hairline divider.
class HudDivider extends StatelessWidget {
  const HudDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: C.lineSoft, margin: const EdgeInsets.symmetric(vertical: 10));
}

/// Fades and slides a child in once, after [delay]: used for staggered entrances.
class EnterAnim extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const EnterAnim({super.key, required this.child, this.delayMs = 0, this.dy = 18});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delayMs),
      curve: Interval(delayMs / (420 + delayMs), 1, curve: Motion.curve),
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, dy * (1 - v)), child: child)),
      child: child,
    );
  }
}
