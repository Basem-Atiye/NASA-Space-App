import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../game_helper.dart';
import 'package:flutter/services.dart';

import '../kit.dart';
import '../line_icons.dart';
import '../theme.dart';

/// A design card (Twilight Indigo, round corners). Kept under its old name
/// so every older screen takes the Figma look.
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
    this.radius = 22,
    this.brackets = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? C.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? Colors.transparent, width: borderColor == null ? 0 : 1.5),
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

/// The one main action on a screen: the design's chunky cyan button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final double height;
  const PrimaryButton({super.key, required this.label, this.icon, this.onTap, this.color = C.cyan, this.textColor = C.ink, this.height = 58});

  @override
  Widget build(BuildContext context) => KitButton(
        label,
        onTap: onTap,
        materialIcon: icon,
        height: height,
        style: color == C.red ? KitButtonStyle.danger : (color == C.raised || color == C.panel || color == C.indigo ? KitButtonStyle.secondary : KitButtonStyle.primary),
      );
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
    final fg = solid ? (c == C.cyan || c == C.frozen || c == C.yellow || c == C.green ? C.ink : Colors.white) : (c == C.cyan ? C.frozen : c);
    return Pressable(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: Motion.fast,
          constraints: BoxConstraints(minHeight: compact ? 40 : 48, minWidth: compact ? 40 : 48),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: solid ? c : C.raised,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(color: solid ? c : C.line, width: 1.5),
            boxShadow: [BoxShadow(color: solid ? Color.lerp(c, Colors.black, 0.4)! : C.raisedEdge, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) Icon(icon, size: compact ? 17 : 19, color: fg),
            if (icon != null && label.isNotEmpty) const SizedBox(width: 8),
            if (label.isNotEmpty) Flexible(child: GameText(label, style: T.h3.copyWith(color: fg, fontSize: compact ? 14 : 16.5), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(8)),
              child: GameText(badge!, style: T.monoSmall.copyWith(color: Colors.white, fontSize: 10)),
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
  const SparkleStar({super.key, this.size = 16, this.color = C.yellow});

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

/// The design's night sky behind every menu screen (navy, stars, sparkles).
class AuroraBackground extends StatelessWidget {
  final Widget? child;
  final double intensity;
  final bool hill;
  final Color? glow;
  const AuroraBackground({super.key, this.child, this.intensity = 1, this.hill = false, this.glow});

  @override
  Widget build(BuildContext context) => SpaceBackground(hill: hill, glow: glow, child: child);
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
          GameText(label.toUpperCase(), style: T.label.copyWith(fontSize: 10, letterSpacing: 1.2, color: color)),
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
            GameText(value, style: T.h3.copyWith(fontSize: 12.5)),
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
          child: LineIcon(Ln.star, size: size, color: i < stars ? C.yellow : C.line),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SectionLabel(this.text, {super.key, this.color = C.muted});

  @override
  Widget build(BuildContext context) => GameText(text.toUpperCase(), style: T.label.copyWith(color: color));
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
