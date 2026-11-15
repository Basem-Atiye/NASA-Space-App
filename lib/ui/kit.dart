/// The Figma component kit: every screen is built from these pieces so the
/// whole app looks like the design (Junior Astronaut Mission Trainer).
///
/// Sizes are the design's own (a 390 × 844 phone frame): 24 side margins,
/// 60-high buttons with a 5-unit 3D edge, 20–24 corner radii, 44 back
/// buttons, 105 × 130 stat tiles, a 90-high tab bar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'game_helper.dart';
import 'package:flutter/services.dart';

import 'line_icons.dart';
import 'theme.dart';

/// A colour laid over a card at [a] (the design's tinted chips and icon boxes).
Color tint(Color c, [double a = 0.2, Color on = C.panel]) => Color.alphaBlend(c.withValues(alpha: a), on);

// ======================================================================= BACKGROUND

/// The night sky behind every screen: deep navy, soft stars, a few coloured
/// sparkles, and (optionally) the purple Moon hill at the bottom and a mood
/// glow at the top (red when a mission failed, orange in a solar storm...).
class SpaceBackground extends StatefulWidget {
  final Widget? child;
  final bool hill;
  final Color? glow;
  final bool animate;
  const SpaceBackground({super.key, this.child, this.hill = false, this.glow, this.animate = true});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12));

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
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: SkyPainter(_c.value, hill: widget.hill, glow: widget.glow)),
        ),
      ),
      if (widget.child != null) widget.child!,
    ]);
  }
}

class SkyPainter extends CustomPainter {
  final double t;
  final bool hill;
  final Color? glow;
  SkyPainter(this.t, {this.hill = false, this.glow});

  static final _stars = List.generate(70, (i) {
    final r = math.Random(i * 7919 + 13);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });
  static const _sparkles = [(0.6, 0.06, C.yellow, 9.0), (0.8, 0.42, C.yellow, 8.0), (0.04, 0.46, C.orange, 3.0), (0.94, 0.7, C.orange, 3.0), (0.42, 0.9, C.yellow, 6.0)];
  static String? _key;
  static Paint? _sky;

  @override
  void paint(Canvas canvas, Size s) {
    final key = '$s';
    if (_key != key) {
      _key = key;
      _sky = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.bg, Color(0xFF111843), C.bgSoft, Color(0xFF231F4E)],
          stops: [0, 0.4, 0.75, 1],
        ).createShader(Offset.zero & s);
    }
    canvas.drawRect(Offset.zero & s, _sky!);
    final g = glow;
    if (g != null) {
      final c = Offset(s.width / 2, s.height * 0.08);
      canvas.drawCircle(
        c,
        s.width * 0.95,
        Paint()..shader = RadialGradient(colors: [g.withValues(alpha: 0.35), g.withValues(alpha: 0.1), g.withValues(alpha: 0)], stops: const [0, 0.45, 1]).createShader(Rect.fromCircle(center: c, radius: s.width * 0.95)),
      );
    }
    final p = Paint();
    final a = t * math.pi * 2;
    for (var i = 0; i < _stars.length; i++) {
      final (x, y, k) = _stars[i];
      p.color = Colors.white.withValues(alpha: 0.25 + 0.5 * (0.5 + 0.5 * math.sin(a + i * 1.9)) * k);
      canvas.drawCircle(Offset(x * s.width, y * s.height), i % 11 == 0 ? 1.3 : 0.9, p);
    }
    for (final (x, y, c, r) in _sparkles) {
      final tw = 0.75 + 0.25 * math.sin(a * 2 + x * 10);
      paintSparkle(canvas, Offset(x * s.width, y * s.height), r * tw, c);
    }
    if (hill) {
      final top = s.height * 0.8;
      final path = Path()
        ..moveTo(0, top + 20)
        ..quadraticBezierTo(s.width * 0.5, top - 30, s.width, top + 10)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();
      canvas.drawPath(path, Paint()..color = C.raised);
      // two quiet craters on the hill
      final cr = Paint()..color = const Color(0xFF423B6E);
      canvas.drawOval(Rect.fromCenter(center: Offset(s.width * 0.22, top + 40), width: 60, height: 14), cr);
      canvas.drawOval(Rect.fromCenter(center: Offset(s.width * 0.78, top + 70), width: 40, height: 10), cr);
    }
  }

  @override
  bool shouldRepaint(covariant SkyPainter old) => old.t != t || old.hill != hill || old.glow != glow;
}

/// The design's four-point sparkle.
void paintSparkle(Canvas canvas, Offset c, double r, Color color) {
  final i = r * 0.18;
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + i, c.dy - i, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + i, c.dy + i, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - i, c.dy + i, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - i, c.dy - i, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

// ======================================================================= BUTTONS

enum KitButtonStyle { primary, secondary, danger, ghost }

/// The design's chunky button: a solid face on a darker 3D edge that sinks
/// when pressed. Primary is Strong Cyan with navy text; secondary is the
/// raised purple with light text.
class KitButton extends StatefulWidget {
  final String label;
  final String? sub;
  final LineIconData? icon;
  final IconData? materialIcon;
  final VoidCallback? onTap;
  final KitButtonStyle style;
  final double height;
  final double fontSize;
  final bool expand;
  const KitButton(
    this.label, {
    super.key,
    this.onTap,
    this.sub,
    this.icon,
    this.materialIcon,
    this.style = KitButtonStyle.primary,
    this.height = 60,
    this.fontSize = 20,
    this.expand = true,
  });

  @override
  State<KitButton> createState() => _KitButtonState();
}

class _KitButtonState extends State<KitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final (face, edge, fg, border) = switch (widget.style) {
      KitButtonStyle.primary => (C.cyan, C.cyanEdge, C.ink, null),
      KitButtonStyle.secondary => (C.raised, C.raisedEdge, C.frozen, C.line),
      KitButtonStyle.danger => (C.red, const Color(0xFFA8324A), Colors.white, null),
      KitButtonStyle.ghost => (Colors.transparent, Colors.transparent, C.frozen, C.line),
    };
    const depth = 5.0;
    final sink = _down ? 3.0 : 0.0;
    final f = enabled ? face : (widget.style == KitButtonStyle.ghost ? Colors.transparent : const Color(0xFF34305C));
    final e = enabled ? edge : const Color(0xFF26234A);
    final t = enabled ? fg : C.dim;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
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
        child: SizedBox(
          height: widget.height + depth,
          width: widget.expand ? double.infinity : null,
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: depth,
              bottom: 0,
              child: DecoratedBox(decoration: BoxDecoration(color: e, borderRadius: BorderRadius.circular(20))),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: sink,
              height: widget.height,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: f,
                  borderRadius: BorderRadius.circular(20),
                  border: border == null ? null : Border.all(color: border, width: 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[LineIcon(widget.icon!, size: 20, color: t), const SizedBox(width: 10)],
                    if (widget.materialIcon != null) ...[Icon(widget.materialIcon, size: 21, color: t), const SizedBox(width: 10)],
                    Flexible(
                      child: GameText(widget.label, style: T.button.copyWith(color: t, fontSize: widget.fontSize), overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                  ]),
                  if (widget.sub != null) GameText(widget.sub!, style: T.bodySmall.copyWith(color: t.withValues(alpha: 0.8), fontSize: 13, height: 1.1)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The round back (or close) button at the top left of every screen.
class RoundButton extends StatelessWidget {
  final LineIconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color iconColor;
  final String tooltip;
  const RoundButton({super.key, this.icon = Ln.back, this.onTap, this.size = 44, this.color = C.raised, this.iconColor = C.frozen, this.tooltip = 'Back'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: TapScale(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: LineIcon(icon, size: size * 0.45, color: iconColor, stroke: 2.4),
        ),
      ),
    );
  }
}

/// Shrinks a little when pressed, with a light tick.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const TapScale({super.key, required this.child, this.onTap, this.scale = 0.95});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTap: on
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 90), child: widget.child),
    );
  }
}

// ======================================================================= TEXT BITS

/// Small spaced capitals: "STARTING SUPPLIES", "MISSION 02 · BRIEFING".
class Overline extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const Overline(this.text, {super.key, this.color = C.muted, this.size = 12});

  @override
  Widget build(BuildContext context) => GameText(text.toUpperCase(), style: T.label.copyWith(color: color, fontSize: size));
}

/// The top of a screen: back button, an optional cyan overline and the title.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? overline;
  final VoidCallback? onBack;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.overline, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Row(children: [
        if (onBack != null) ...[RoundButton(onTap: onBack), const SizedBox(width: 16)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (overline != null) ...[Overline(overline!, color: C.cyan, size: 11.5), const SizedBox(height: 2)],
            GameText(title, style: T.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ======================================================================= CARDS

/// A design card: Twilight Indigo, 22 corners, no hard outline unless it is
/// selected or carries a warning.
class KitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? border;
  final double borderWidth;
  final double radius;
  final VoidCallback? onTap;
  const KitCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = C.panel, this.border, this.borderWidth = 2, this.radius = 22, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!, width: borderWidth),
      ),
      child: child,
    );
    return onTap == null ? box : TapScale(onTap: onTap, scale: 0.97, child: box);
  }
}

/// A tinted square with a line icon: the design's icon boxes.
class IconBox extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final double size;
  final Color on;
  final double alpha;
  const IconBox(this.icon, {super.key, this.color = C.cyan, this.size = 44, this.on = C.panel, this.alpha = 0.2});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint(color, alpha, on), borderRadius: BorderRadius.circular(size * 0.3)),
        child: LineIcon(icon, size: size * 0.5, color: color),
      );
}

/// A tinted tag: "−20 Power", "Crew safe", "↑ +18%".
class TagChip extends StatelessWidget {
  final String text;
  final Color color;
  final LineIconData? icon;
  final Color on;
  final double size;
  const TagChip(this.text, {super.key, required this.color, this.icon, this.on = C.panel, this.size = 14});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.32),
        decoration: BoxDecoration(color: tint(color, 0.22, on), borderRadius: BorderRadius.circular(size)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[LineIcon(icon!, size: size, color: color, stroke: 2.4), SizedBox(width: size * 0.35)],
          GameText(text, style: T.body.copyWith(color: color, fontSize: size, fontWeight: FontWeight.w700, height: 1.2)),
        ]),
      );
}

/// A rounded progress bar on the dark navy track.
class KitBar extends StatelessWidget {
  final double frac;
  final Color color;
  final double height;
  final Color track;
  const KitBar({super.key, required this.frac, required this.color, this.height = 7, this.track = C.ink});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: track),
            TweenAnimationBuilder<double>(
              tween: Tween(end: frac.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
              ),
            ),
          ]),
        ),
      );
}

/// State colour for a 0..1 level (green fine, yellow low, red danger).
Color stateColor(double frac) => frac < 0.2 ? C.red : (frac < 0.4 ? C.yellow : C.green);

/// One supply tile on the base screen (OXYGEN 86% ▬▬▬). A low supply gets a
/// yellow frame and the word LOW; a dangerous one turns red.
class StatTile extends StatelessWidget {
  final LineIconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double frac;
  final String? note;
  final Color? state;
  final VoidCallback? onTap;

  /// What changed since yesterday (shown as a small +/− that fades away).
  final double? delta;
  final Object? deltaKey;

  /// A shorter tile for small phones.
  final bool compact;
  const StatTile({super.key, required this.icon, required this.iconColor, required this.label, required this.value, required this.frac, this.note, this.state, this.onTap, this.delta, this.deltaKey, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = state ?? stateColor(frac);
    final warn = s != C.green;
    return TapScale(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: compact ? 96 : 130,
        padding: compact ? const EdgeInsets.fromLTRB(10, 10, 10, 10) : const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warn ? s : Colors.transparent, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBox(icon, color: iconColor, size: 28),
            const SizedBox(width: 7),
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Overline(label, color: C.muted, size: 11.5))),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GameText(value, style: compact ? T.number.copyWith(fontSize: 24) : T.number))),
            if (delta != null && delta!.round() != 0)
              TweenAnimationBuilder<double>(
                key: ValueKey(deltaKey),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 2200),
                curve: const Interval(0.5, 1),
                builder: (context, v, _) => Opacity(
                  opacity: v,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: GameText('${delta! > 0 ? '+' : '−'}${delta!.abs().round()}', style: T.h3.copyWith(fontSize: 13, color: delta! > 0 ? C.green : C.red)),
                  ),
                ),
              ),
          ]),
          SizedBox(height: compact ? 7 : 10),
          KitBar(frac: frac, color: s, height: compact ? 6 : 7),
          if (note != null && !compact) ...[const SizedBox(height: 6), Overline(note!, color: s, size: 10.5)] else SizedBox(height: compact ? 0 : 4),
        ]),
      ),
    );
  }
}

/// The warning strip ("Water is running low · Tap the Water Recycler").
class WarnBanner extends StatelessWidget {
  final String title;
  final String? sub;
  final Color color;
  final LineIconData icon;
  final VoidCallback? onTap;
  const WarnBanner({super.key, required this.title, this.sub, this.color = C.yellow, this.icon = Ln.alert, this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: tint(color, 0.08, const Color(0xFF2A2934)), borderRadius: BorderRadius.circular(18), border: Border.all(color: color, width: 2)),
          child: Row(children: [
            IconBox(icon, color: color, size: 40, on: const Color(0xFF2A2934), alpha: 0.18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText(title, style: T.h3.copyWith(color: color, fontSize: 17)),
                if (sub != null) GameText(sub!, style: T.body.copyWith(fontSize: 13.5, height: 1.3)),
              ]),
            ),
          ]),
        ),
      );
}

/// "ENGINEER TIP", "LESSON", "REAL SCIENCE": a bulb and a short lesson.
class TipCard extends StatelessWidget {
  final String title;
  final String text;
  final LineIconData icon;
  final Color color;
  final Color iconColor;
  const TipCard({super.key, required this.title, required this.text, this.icon = Ln.bulb, this.color = const Color(0xFF535177), this.iconColor = C.frozen});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBox(icon, color: iconColor, size: 40, on: color, alpha: 0.14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(title, color: C.frozen, size: 11.5),
              const SizedBox(height: 4),
              GameText(text, style: T.body.copyWith(fontSize: 14.5, height: 1.4)),
            ]),
          ),
        ]),
      );
}

/// An A / B / C decision card with its costs and gains as chips.
class ChoiceCard extends StatelessWidget {
  final String letter;
  final String title;
  final List<Widget> chips;
  final bool selected;
  final VoidCallback? onTap;
  const ChoiceCard({super.key, required this.letter, required this.title, this.chips = const [], this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? C.raised : C.ink;
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? C.cyan : C.ink, width: 2.5)),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? C.cyan : C.raised, borderRadius: BorderRadius.circular(12)),
            child: GameText(letter, style: T.h3.copyWith(color: selected ? C.ink : C.frozen)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText(title, style: T.h3),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ======================================================================= CONTROLS

/// The design's switch: a 64 × 34 pill, cyan when on.
class KitToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const KitToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: GestureDetector(
          onTap: onChanged == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onChanged!(!value);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: value ? C.cyan : C.ink, borderRadius: BorderRadius.circular(17)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: C.frozen, shape: BoxShape.circle)),
            ),
          ),
        ),
      );
}

/// A row of options in a dark pill, the chosen one in cyan (text size A A A).
class SegmentPicker extends StatelessWidget {
  final List<String> labels;
  final int value;
  final ValueChanged<int> onChanged;
  final List<double>? sizes;
  const SegmentPicker({super.key, required this.labels, required this.value, required this.onChanged, this.sizes});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == value ? C.cyan : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: GameText(labels[i], style: T.h3.copyWith(fontSize: sizes?[i] ?? 15, color: i == value ? C.ink : C.frozen)),
              ),
            ),
        ]),
      );
}

/// The design's slider: a thick track in the module's colour and a round
/// Frozen Water thumb.
class KitSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final Color color;
  final Color? endColor;
  final int? divisions;
  const KitSlider({super.key, required this.value, this.onChanged, this.color = C.cyan, this.endColor, this.divisions});

  @override
  Widget build(BuildContext context) => SliderTheme(
        data: SliderThemeData(
          trackHeight: 10,
          activeTrackColor: color,
          inactiveTrackColor: C.ink,
          thumbColor: C.frozen,
          overlayColor: color.withValues(alpha: 0.15),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15, elevation: 0, pressedElevation: 0),
          trackShape: _GradientTrack(color, endColor ?? color),
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged, divisions: divisions),
      );
}

class _GradientTrack extends SliderTrackShape with BaseSliderTrackShape {
  final Color a, b;
  _GradientTrack(this.a, this.b);

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 2}) {
    final r = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    final c = context.canvas;
    final rad = Radius.circular(r.height);
    c.drawRRect(RRect.fromRectAndRadius(r, rad), Paint()..color = C.ink);
    final active = Rect.fromLTRB(r.left, r.top, thumbCenter.dx, r.bottom);
    c.drawRRect(RRect.fromRectAndRadius(active, rad), Paint()..shader = LinearGradient(colors: [b, a]).createShader(active));
  }
}

// ======================================================================= NAVIGATION

class TabItem {
  final LineIconData icon;
  final String label;
  const TabItem(this.icon, this.label);
}

/// The bottom tab bar (Base · Power · Crew · Log).
class BottomTabs extends StatelessWidget {
  final List<TabItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final List<bool>? dots;
  const BottomTabs({super.key, required this.items, required this.index, required this.onTap, this.dots});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(top: 10, bottom: math.max(bottom, 10)),
      decoration: const BoxDecoration(color: C.ink, border: Border(top: BorderSide(color: Color(0xFF1F2550), width: 1))),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == index ? const Color(0xFF0A2D48) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                    child: LineIcon(items[i].icon, size: 23, color: i == index ? C.cyan : C.frozen),
                  ),
                  if (dots != null && dots![i])
                    Positioned(right: 10, top: 2, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: C.yellow, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2)))),
                ]),
                const SizedBox(height: 4),
                GameText(items[i].label, style: T.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: i == index ? C.cyan : C.frozen)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= STARS & BADGES

/// Big yellow stars, the empty ones in quiet purple.
class KitStars extends StatelessWidget {
  final int stars;
  final int of;
  final double size;
  final bool animate;
  const KitStars({super.key, required this.stars, this.of = 3, this.size = 44, this.animate = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < of; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.12),
            child: animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 500 + i * 250),
                    curve: Interval(i * 0.25, 1, curve: Curves.elasticOut),
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: LineIcon(Ln.star, size: size, color: i < stars ? C.yellow : C.line),
                  )
                : LineIcon(Ln.star, size: size, color: i < stars ? C.yellow : C.line),
          ),
      ]);
}

/// A badge medal: a coloured ring and icon when earned, a lock when not.
class BadgeMedal extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final bool earned;
  final double size;
  const BadgeMedal({super.key, required this.icon, required this.color, required this.earned, this.size = 96});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: earned ? Color.alphaBlend(color.withValues(alpha: 0.18), C.ink) : C.panel,
          border: earned ? Border.all(color: color, width: size * 0.045) : null,
          boxShadow: earned ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 18)] : null,
        ),
        child: LineIcon(earned ? icon : Ln.lock, size: size * 0.4, color: earned ? color : C.frozen.withValues(alpha: 0.75)),
      );
}

/// The little grab handle on top of a bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(child: Container(width: 54, height: 6, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(3))));
}

/// A centred modal card (events, pause, cargo full) with an optional
/// coloured glow along its bottom edge.
class ModalCard extends StatelessWidget {
  final Widget child;
  final Color? edge;
  final EdgeInsetsGeometry padding;
  const ModalCard({super.key, required this.child, this.edge, this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 20)});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(30),
          border: edge == null ? null : Border(bottom: BorderSide(color: edge!, width: 6)),
          boxShadow: [
            const BoxShadow(color: Color(0x88000000), blurRadius: 40, offset: Offset(0, 16)),
            if (edge != null) BoxShadow(color: edge!.withValues(alpha: 0.35), blurRadius: 60, offset: const Offset(0, 10)),
          ],
        ),
        padding: padding,
        child: child,
      );
}

/// A round coloured disc with an icon (event and result headers).
class GlowDisc extends StatelessWidget {
  final LineIconData icon;
  final Color color;
  final double size;
  const GlowDisc({super.key, required this.icon, required this.color, this.size = 104});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(color.withValues(alpha: 0.28), C.panel),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 2.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 30)],
        ),
        child: LineIcon(icon, size: size * 0.42, color: color),
      );
}
