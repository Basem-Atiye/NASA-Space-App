/// Shared angular dial: twist around the center without getting stuck.
/// Used by [Knob] (SIM) and TuneGame (solar panels).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../game_helper.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

double normalizeDegrees(double a) => ((a % 360) + 360) % 360;

/// Shortest signed difference from [from] to [to] in degrees (−180..180].
double deltaDegrees(double from, double to) {
  var d = normalizeDegrees(to) - normalizeDegrees(from);
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Circular distance in degrees (0..180).
double circularDistanceDeg(double a, double b) => deltaDegrees(a, b).abs();

/// Twistable control. [value] maps across [min]..[max] over [sweepRadians]
/// of finger travel (relative mode), or as 0..360° heading (absoluteDegrees).
class RotaryDial extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onStep;
  final VoidCallback? onClamp;
  final double size;
  final Color color;
  final Widget? child;

  /// When true, value is degrees 0..360 and finger angle maps 1:1 to heading.
  final bool absoluteDegrees;

  /// Visual fraction override (0..1). If null, derived from value/min/max.
  final double? fraction;

  /// Radians of finger travel that span full min→max in relative mode.
  final double sweepRadians;

  const RotaryDial({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.step = 1,
    this.onChanged,
    this.onStep,
    this.onClamp,
    this.size = 112,
    this.color = C.cyan,
    this.child,
    this.absoluteDegrees = false,
    this.fraction,
    this.sweepRadians = math.pi * 1.5,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  double? _lastFingerAngle;
  double _accum = 0;
  bool _dragging = false;
  static const _deadZone = 14.0;
  static const _pad = 22.0;

  double get _range => widget.max - widget.min;

  double _snap(double v) {
    if (widget.step <= 0) return v.clamp(widget.min, widget.max).toDouble();
    final s = (v / widget.step).round() * widget.step;
    return s.clamp(widget.min, widget.max).toDouble();
  }

  void _emit(double raw, {bool snap = false}) {
    if (widget.onChanged == null) return;
    var v = raw;
    if (widget.absoluteDegrees) {
      v = normalizeDegrees(v);
      // keep within min/max if they aren't full circle
      if (widget.min != 0 || widget.max != 360) {
        v = v.clamp(widget.min, widget.max).toDouble();
      }
    } else {
      final atMin = widget.value <= widget.min + 1e-9;
      final atMax = widget.value >= widget.max - 1e-9;
      if (snap) v = _snap(v);
      v = v.clamp(widget.min, widget.max).toDouble();
      if ((atMin && v <= widget.min) || (atMax && v >= widget.max)) {
        // still at end — cue once per gesture edge via onClamp when newly clamped
      }
      if ((raw < widget.min && atMin) || (raw > widget.max && atMax)) {
        widget.onClamp?.call();
      }
    }
    if ((v - widget.value).abs() < 1e-9) return;
    final stepped = widget.step > 0 && !widget.absoluteDegrees
        ? (widget.value / widget.step).round() != (v / widget.step).round()
        : (widget.absoluteDegrees
            ? (widget.value.round() != v.round() && widget.step >= 1)
            : false);
    widget.onChanged!(v);
    if (stepped) widget.onStep?.call();
  }

  void _onPointer(Offset local, {required bool start}) {
    if (widget.onChanged == null) return;
    final c = Offset((widget.size + _pad * 2) / 2, (widget.size + _pad * 2) / 2);
    final dx = local.dx - c.dx;
    final dy = local.dy - c.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < _deadZone) {
      // ignore center — keep last angle so we don't jump when exiting dead zone
      return;
    }
    final a = math.atan2(dy, dx);
    if (start || _lastFingerAngle == null) {
      _lastFingerAngle = a;
      _accum = 0;
      return;
    }
    var da = a - _lastFingerAngle!;
    if (da > math.pi) da -= math.pi * 2;
    if (da < -math.pi) da += math.pi * 2;
    _lastFingerAngle = a;

    if (widget.absoluteDegrees) {
      // Finger angle: 0° at +X (east); convert to compass-like heading used by TuneGame
      // (0° at top / north, clockwise): heading = atan2(dx, -dy) in degrees
      final heading = normalizeDegrees(math.atan2(dx, -dy) * 180 / math.pi);
      _emit(heading);
      return;
    }

    // Relative: accumulate before step snap so small twists feel responsive
    final deltaValue = da / widget.sweepRadians * _range;
    _accum += deltaValue;
    if (widget.step > 0 && _accum.abs() < widget.step * 0.35 && !_dragging) {
      // still collecting
    }
    final next = widget.value + _accum;
    final snapped = _snap(next);
    if (snapped != widget.value) {
      _accum = next - snapped;
      _emit(snapped);
    } else if (widget.step <= 0) {
      _accum = 0;
      _emit(next);
    }
  }

  void _end() {
    if (!widget.absoluteDegrees && widget.step > 0 && _accum.abs() > 0) {
      _emit(widget.value + _accum, snap: true);
    }
    _lastFingerAngle = null;
    _accum = 0;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final hit = widget.size + _pad * 2;
    return SizedBox(
      width: hit,
      height: hit,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled
            ? (e) {
                _dragging = true;
                _onPointer(e.localPosition, start: true);
              }
            : null,
        onPointerMove: enabled ? (e) => _onPointer(e.localPosition, start: false) : null,
        onPointerUp: enabled ? (_) => _end() : null,
        onPointerCancel: enabled ? (_) => _end() : null,
        child: Center(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: widget.child ??
                CustomPaint(
                  painter: _DefaultKnobPainter(
                    fraction: widget.fraction ??
                        ((widget.value - widget.min) / (widget.max - widget.min == 0 ? 1 : widget.max - widget.min))
                            .clamp(0.0, 1.0),
                    color: widget.color,
                    enabled: enabled,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _DefaultKnobPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final bool enabled;
  _DefaultKnobPainter({required this.fraction, required this.color, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    final tick = Paint()
      ..color = C.dim
      ..strokeWidth = 1.2;
    for (var k = 0; k <= 20; k++) {
      final a = start + sweep * k / 20;
      final inner = k % 5 == 0 ? r - 9 : r - 6;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * inner, c + Offset(math.cos(a), math.sin(a)) * (r - 2), tick);
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 13),
      start,
      sweep,
      false,
      Paint()
        ..color = C.lineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 13),
      start,
      sweep * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final body = Rect.fromCircle(center: c, radius: r - 20);
    canvas.drawCircle(c + const Offset(0, 3), r - 20, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(
      c,
      r - 20,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFF5A5680), Color(0xFF2A2748), Color(0xFF1A1830)],
          stops: [0, 0.7, 1],
        ).createShader(body),
    );
    final a = start + sweep * fraction;
    final ridge = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5;
    for (var k = 0; k < 16; k++) {
      final b = a + k * math.pi / 8;
      canvas.drawLine(c + Offset(math.cos(b), math.sin(b)) * (r - 26), c + Offset(math.cos(b), math.sin(b)) * (r - 21), ridge);
    }
    canvas.drawLine(
      c + Offset(math.cos(a), math.sin(a)) * 6,
      c + Offset(math.cos(a), math.sin(a)) * (r - 25),
      Paint()
        ..color = enabled ? color : C.dim
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DefaultKnobPainter old) =>
      old.fraction != fraction || old.color != color || old.enabled != enabled;
}

/// Compact ± nudge for fine dial control.
class DialNudges extends StatelessWidget {
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? label;
  const DialNudges({super.key, this.onMinus, this.onPlus, this.label});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, VoidCallback? onTap) => PressableDial(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.panelDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.line),
            ),
            child: Icon(icon, color: onTap == null ? C.dim : C.cyan, size: 22),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(Icons.remove_rounded, onMinus),
        if (label != null) ...[
          const SizedBox(width: 12),
          GameText(label!, style: T.mono.copyWith(fontSize: 13, color: C.muted)),
          const SizedBox(width: 12),
        ] else
          const SizedBox(width: 16),
        chip(Icons.add_rounded, onPlus),
      ],
    );
  }
}

class PressableDial extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressableDial({super.key, required this.child, this.onTap});

  @override
  State<PressableDial> createState() => _PressableDialState();
}

class _PressableDialState extends State<PressableDial> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: widget.child,
    );
  }
}
