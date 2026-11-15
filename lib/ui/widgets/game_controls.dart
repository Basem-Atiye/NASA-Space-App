/// The in-game controls for 2.0: a floating joystick, small ring meters and
/// the round action button. They sit over the Moon instead of in a panel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../game_helper.dart';

import '../theme.dart';

const _low = Color(0xFFFFB347);

/// A small ring meter (oxygen, health, power). Pulses orange when low.
class RingMeter extends StatefulWidget {
  final double value; // 0..1
  final String label;
  final String text;
  final IconData? icon;
  final Color color;
  final bool low;
  const RingMeter({super.key, required this.value, required this.label, required this.text, this.icon, this.color = C.cyan, this.low = false});

  @override
  State<RingMeter> createState() => _RingMeterState();
}

class _RingMeterState extends State<RingMeter> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.low) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant RingMeter old) {
    super.didUpdateWidget(old);
    if (widget.low && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.low && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.low ? _low : widget.color;
    return Semantics(
      label: '${widget.label} ${widget.text}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Transform.scale(
              scale: 1 + _pulse.value * 0.06,
              child: SizedBox(
                width: 28,
                height: 28,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.value.clamp(0, 1).toDouble()),
                  duration: Motion.normal,
                  builder: (context, v, _) => CustomPaint(
                    painter: _RingPainter(v, col),
                    child: Center(
                      child: widget.icon != null
                          ? Icon(widget.icon, size: 15, color: col)
                          : GameText(
                              widget.text,
                              style: T.mono.copyWith(fontSize: widget.text.length > 2 ? 9 : 10.5, fontWeight: FontWeight.w700, color: C.frozen),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GameText(
            widget.label,
            style: T.label.copyWith(fontSize: 7, height: 1, letterSpacing: 0.4, color: C.muted),
            textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color c;
  _RingPainter(this.v, this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 2.5);
    canvas.drawCircle(r.center, r.width / 2 + 2, Paint()..color = C.bg.withValues(alpha: 0.55));
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = C.frozen.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.c != c;
}

/// A joystick that appears where the thumb lands in its area. Reports -1..1;
/// pushing it to the edge means sprint ([onSprint]).
class FloatingStick extends StatefulWidget {
  final ValueChanged<double> onChanged;
  final ValueChanged<bool>? onSprint;
  final VoidCallback? onSwipeUp;
  final bool enabled;
  final bool sprinting;
  const FloatingStick({super.key, required this.onChanged, this.onSprint, this.onSwipeUp, this.enabled = true, this.sprinting = false});

  @override
  State<FloatingStick> createState() => _FloatingStickState();
}

class _FloatingStickState extends State<FloatingStick> {
  static const _radius = 42.0;
  Offset? _origin;
  Offset _knob = Offset.zero;
  bool _edge = false;
  Offset _startUp = Offset.zero;

  void _start(Offset p) {
    setState(() {
      _origin = p;
      _knob = Offset.zero;
      _startUp = p;
    });
  }

  void _move(Offset p) {
    final o = _origin;
    if (o == null) return;
    var d = p - o;
    if (d.distance > _radius) d = d / d.distance * _radius;
    final x = d.dx / _radius;
    final edge = x.abs() >= 0.93;
    setState(() => _knob = d);
    widget.onChanged(x.abs() < 0.14 ? 0 : x.clamp(-1.0, 1.0).toDouble());
    if (edge != _edge) {
      _edge = edge;
      widget.onSprint?.call(edge);
    }
    // a quick flick upward is a jump
    if (_startUp.dy - p.dy > 70 && (p.dx - _startUp.dx).abs() < 60) {
      _startUp = Offset(_startUp.dx, -9999);
      widget.onSwipeUp?.call();
    }
  }

  void _end() {
    setState(() {
      _origin = null;
      _knob = Offset.zero;
    });
    widget.onChanged(0);
    if (_edge) widget.onSprint?.call(false);
    _edge = false;
  }

  @override
  void didUpdateWidget(covariant FloatingStick old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _origin != null) {
      _origin = null;
      _knob = Offset.zero;
      _edge = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final rest = Offset(70, box.maxHeight - 72);
        final at = _origin ?? rest;
        final active = _origin != null;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: widget.enabled ? (e) => _start(e.localPosition) : null,
          onPanUpdate: widget.enabled ? (e) => _move(e.localPosition) : null,
          onPanEnd: widget.enabled ? (_) => _end() : null,
          onPanCancel: widget.enabled ? _end : null,
          child: Stack(
            children: [
              Positioned(
                left: at.dx - 56,
                top: at.dy - 56,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: !widget.enabled ? 0.25 : (active ? 1 : 0.55),
                    child: SizedBox(width: 112, height: 112, child: CustomPaint(painter: _StickPainter(_knob, active, widget.sprinting || _edge))),
                  ),
                ),
              ),
              if (_edge || widget.sprinting)
                Positioned(
                  left: at.dx - 40,
                  top: at.dy - 84,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(8)),
                      child: GameText('SPRINT', style: T.label.copyWith(color: C.frozen, fontSize: 10, letterSpacing: 1.4)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StickPainter extends CustomPainter {
  final Offset knob;
  final bool active;
  final bool sprint;
  _StickPainter(this.knob, this.active, this.sprint);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 54, Paint()..color = C.indigo.withValues(alpha: active ? 0.32 : 0.22));
    canvas.drawCircle(
      c,
      54,
      Paint()
        ..color = C.frozen.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // left and right chevrons
    final ch = Paint()
      ..color = C.frozen.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      final x = c.dx + s * 40;
      canvas.drawPath(
        Path()
          ..moveTo(x - s * 4, c.dy - 6)
          ..lineTo(x + s * 2, c.dy)
          ..lineTo(x - s * 4, c.dy + 6),
        ch,
      );
    }
    final k = c + knob;
    final col = sprint ? C.sapphire : C.cyan;
    canvas.drawCircle(k, 30, Paint()..color = col.withValues(alpha: 0.25));
    canvas.drawCircle(k, 25, Paint()..color = col.withValues(alpha: active ? 0.9 : 0.6));
  }

  @override
  bool shouldRepaint(covariant _StickPainter old) => old.knob != knob || old.active != active || old.sprint != sprint;
}

/// The big round thumb button. Its word changes with what Nova can do.
class ActionDisc extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  const ActionDisc({super.key, required this.label, this.onTap, this.color = C.sapphire, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    final words = label.split(' ');
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? C.panelDeep.withValues(alpha: 0.6) : color,
            border: Border.all(color: C.frozen.withValues(alpha: onTap == null ? 0.15 : 0.35), width: 1.5),
            boxShadow: onTap == null ? null : [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 26)],
          ),
          child: GameText(
            words.length > 1 && label.length > 7 ? words.join('\n') : label,
            textAlign: TextAlign.center,
            style: T.button.copyWith(fontSize: label.length > 7 ? 12 : 13.5, height: 1.15, letterSpacing: 1, color: onTap == null ? C.dim : textColor),
          ),
        ),
      ),
    );
  }
}

/// The small round tool buttons (scan, hint) next to the action button.
class ToolDisc extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  const ToolDisc({super.key, required this.icon, required this.tooltip, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? C.cyan.withValues(alpha: 0.3) : C.bg.withValues(alpha: 0.5),
          border: Border.all(color: C.cyan.withValues(alpha: onTap == null ? 0.25 : 0.7), width: 1.5),
        ),
        child: Icon(icon, size: 20, color: onTap == null ? C.dim : C.cyan),
      ),
    ),
  );
}
