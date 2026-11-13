import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../ui/theme.dart';
import 'minigames.dart';
import 'story_logic.dart';
import 'story_model.dart';

// =================================================================== RULES
//
// Task 5's "wow" feature: the player programs a real control loop, then
// watches four simulated tests run live on charts.

class RulesGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const RulesGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<RulesGame> createState() => _RulesGameState();
}

class _RulesGameState extends State<RulesGame> with SingleTickerProviderStateMixin {
  final r = ControllerRules();
  List<TestRun>? _runs;
  late final AnimationController _play = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  int _mistakes = 0;
  int _attempts = 0;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _play.addStatusListener((s) {
      if (s != AnimationStatus.completed || _runs == null) return;
      final ok = _runs!.every((t) => t.passed);
      if (ok) {
        widget.audio.play(Sfx.success);
        setState(() => _passed = true);
      } else {
        widget.audio.play(Sfx.fail, volume: 0.6);
        // only the first two failed runs count, so kids can experiment freely
        setState(() => _mistakes = math.min(2, _attempts));
      }
    });
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  void _run() {
    widget.audio.tap();
    setState(() {
      _attempts++;
      _runs = runAllTests(r);
      _passed = false;
    });
    _play.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final running = _play.isAnimating;
    final failed = _runs != null && !running && !_passed;
    return GameFrame(
      spec: widget.spec,
      mistakes: _mistakes,
      status: _passed ? 'All four tests passed. The controller can run the habitat while Nova sleeps.' : (failed ? 'Some tests failed. Read the red lines, adjust the rules, run again.' : null),
      statusColor: _passed ? C.green : C.amber,
      footer: _passed
          ? confirmButton('Activate controller', () => widget.onDone(GameResult(mistakes: _mistakes)))
          : confirmButton(running ? 'Running…' : 'Run 4 tests', running ? null : _run, icon: Icons.play_arrow_rounded),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _rules(running || _passed),
        const SizedBox(height: 8),
        Text('SIMULATION · 2 HOURS PER TEST', style: T.label.copyWith(color: C.muted)),
        const SizedBox(height: 8),
        _charts(),
      ]),
    );
  }

  Widget _rules(bool locked) {
    Widget rule(String title, String actuator, String text, Widget slider, Color c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          decoration: BoxDecoration(color: C.panelSolid, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.45))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: T.label.copyWith(color: c)),
              const Spacer(),
              Text(actuator, style: T.monoSmall.copyWith(fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            Text(text, style: T.mono.copyWith(fontSize: 12.5)),
            SizedBox(height: 36, child: slider),
          ]),
        );
    return Column(children: [
      rule(
        'O2 SENSOR',
        '→ O2 VALVE',
        'IF O2 < ${r.o2On.toStringAsFixed(1)}% OPEN · > ${r.o2Off.toStringAsFixed(1)}% CLOSE',
        RangeSlider(
          values: RangeValues(r.o2On, r.o2Off),
          min: 17,
          max: 23,
          divisions: 60,
          onChanged: locked ? null : (v) => setState(() {
            r.o2On = v.start;
            r.o2Off = v.end;
          }),
        ),
        C.cyan,
      ),
      rule(
        'PRESSURE',
        '→ REPRESS VALVE',
        'IF P < ${r.pOn.toStringAsFixed(0)} kPa ON · > ${r.pOff.toStringAsFixed(0)} kPa OFF',
        RangeSlider(
          values: RangeValues(r.pOn, r.pOff),
          min: 78,
          max: 104,
          divisions: 26,
          onChanged: locked ? null : (v) => setState(() {
            r.pOn = v.start;
            r.pOff = v.end;
          }),
        ),
        C.sapphire,
      ),
      rule(
        'TEMPERATURE',
        '→ HEATER',
        'IF T < ${r.heatOn.toStringAsFixed(0)} °C HEATER ON (off +2 °C)',
        Slider(value: r.heatOn, min: 8, max: 24, divisions: 16, onChanged: locked ? null : (v) => setState(() => r.heatOn = v)),
        const Color(0xFFFFB86B),
      ),
      rule(
        'TEMPERATURE',
        '→ FAN',
        'IF T > ${r.fanOn.toStringAsFixed(0)} °C FAN ON (off −2 °C)',
        Slider(value: r.fanOn, min: 20, max: 36, divisions: 16, onChanged: locked ? null : (v) => setState(() => r.fanOn = v)),
        C.violet,
      ),
    ]);
  }

  Widget _charts() {
    final runs = _runs;
    if (runs == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.lineSoft)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Set your rules above, then run the tests.\nEach test simulates 2 hours of habitat life.', style: T.bodySmall, textAlign: TextAlign.center),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) => Column(children: [
        for (final t in runs) _chart(t, _play.value),
      ]),
    );
  }

  Widget _chart(TestRun t, double p) {
    final done = p >= 1;
    final c = !done ? C.cyan : (t.passed ? C.green : C.red);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.title, style: T.h3.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
          if (done) Icon(t.passed ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c, size: 16),
        ]),
        const SizedBox(height: 3),
        SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: _ChartPainter(t, p))),
        if (done) Text(t.verdict, style: T.bodySmall.copyWith(fontSize: 12, color: t.passed ? C.muted : C.red)),
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final TestRun t;
  final double p;
  _ChartPainter(this.t, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final safe = t.safe;
    final lo = math.min(safe.low - (safe.high - safe.low) * 0.25, t.values.reduce(math.min));
    final hi = math.max(safe.high + (safe.high - safe.low) * 0.25, t.values.reduce(math.max));
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));
    // safe band
    canvas.drawRect(Rect.fromLTRB(0, y(safe.high), size.width, y(safe.low)), Paint()..color = C.green.withValues(alpha: 0.08));
    final dash = Paint()
      ..color = C.green.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(safe.high)), Offset(size.width, y(safe.high)), dash);
    canvas.drawLine(Offset(0, y(safe.low)), Offset(size.width, y(safe.low)), dash);
    final n = (t.values.length * p).clamp(1, t.values.length).toInt();
    // actuator ON shading
    final dx = size.width / t.values.length;
    final onPaint = Paint()..color = C.amber.withValues(alpha: 0.18);
    for (var i = 0; i < n; i++) {
      if (t.actuator[i]) canvas.drawRect(Rect.fromLTWH(i * dx, size.height - 4, dx + 0.5, 4), onPaint..color = C.amber.withValues(alpha: 0.8));
    }
    // the value
    final path = Path();
    for (var i = 0; i < n; i++) {
      final pt = Offset(i * dx, y(t.values[i]));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    final v = t.values[n - 1];
    final out = v < safe.low || v > safe.high;
    canvas.drawPath(path, Paint()
      ..color = out ? C.red : C.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);
    canvas.drawCircle(Offset((n - 1) * dx, y(v)), 3, Paint()..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(text: '${v.toStringAsFixed(1)} ${safe.unit}', style: T.monoSmall.copyWith(fontSize: 9.5, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(math.min(size.width - tp.width, (n - 1) * dx + 5), math.max(0, y(v) - tp.height)));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.p != p || old.t != t;
}

// =================================================================== CASCADE
//
// Task 9's "wow" feature: a live system-dependency diagram. Failure spreads
// along the arrows in real time; the player predicts, finds the root cause
// and restores systems in priority order.

enum _CPhase { predict, spreading, root, restore, done }

class CascadeGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const CascadeGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<CascadeGame> createState() => _CascadeGameState();
}

class _CascadeGameState extends State<CascadeGame> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  final waves = cascadeWaves(cascadeRoot);
  _CPhase _phase = _CPhase.predict;
  int _wave = 1; // how many waves have failed so far (root first)
  final Set<String> _restored = {};
  int _mistakes = 0;
  String _status = 'The battery-to-bus cable just failed. PREDICT: which part fails next? Tap it.';
  Color _statusColor = C.amber;
  String? _flash;
  Timer? _spread;

  @override
  void dispose() {
    _pulse.dispose();
    _spread?.cancel();
    super.dispose();
  }

  Set<String> get _failed => {for (var i = 0; i < _wave; i++) ...waves[i]}..removeAll(_restored);

  void _tapNode(String id) {
    switch (_phase) {
      case _CPhase.predict:
        final right = waves[1].contains(id);
        widget.audio.play(right ? Sfx.success : Sfx.message, volume: 0.5);
        setState(() {
          _status = right
              ? 'Correct prediction: the main bus loses its only power feed. Watch it spread…'
              : 'Not quite: ${sysNode(id).label} does not depend on the cable directly. Watch…';
          _statusColor = right ? C.green : C.amber;
          _phase = _CPhase.spreading;
        });
        _spread = Timer.periodic(const Duration(milliseconds: 1100), (t) {
          if (_wave >= waves.length) {
            t.cancel();
            setState(() {
              _phase = _CPhase.root;
              _status = 'Everything downstream is down. Now tap the ROOT CAUSE: where did it start?';
              _statusColor = C.cyan;
            });
            return;
          }
          widget.audio.play(Sfx.alert, volume: 0.45);
          setState(() => _wave++);
        });
        break;
      case _CPhase.root:
        if (id == cascadeRoot) {
          widget.audio.play(Sfx.success);
          setState(() {
            _phase = _CPhase.restore;
            _restored.add(cascadeRoot);
            _restored.add('bus');
            _status = 'Root cause found and bypassed. Bus power is back. Restore the systems in order of importance.';
            _statusColor = C.green;
          });
        } else {
          widget.audio.play(Sfx.fail, volume: 0.6);
          final n = sysNode(id);
          setState(() {
            _mistakes++;
            _flash = id;
            _status = _failed.contains(id) && n.dependsOn.isNotEmpty
                ? '${n.label} failed because ${sysNode(n.dependsOn.first).label} failed. That is a symptom. Look upstream.'
                : '${n.label} is still working. The root cause must be a part that failed.';
            _statusColor = C.red;
          });
        }
        break;
      case _CPhase.restore:
        if (!restoreOrder.contains(id) || _restored.contains(id)) return;
        final want = restoreOrder.firstWhere((x) => !_restored.contains(x));
        if (id == want) {
          widget.audio.play(Sfx.success, volume: 0.5);
          setState(() {
            _restored.add(id);
            _status = '${sysNode(id).label} restored.';
            _statusColor = C.green;
          });
          if (restoreOrder.every(_restored.contains)) {
            setState(() {
              _phase = _CPhase.done;
              _status = 'All systems restored. Life support came back first, as it must.';
            });
            Timer(const Duration(milliseconds: 1400), () => widget.onDone(GameResult(mistakes: _mistakes)));
          }
        } else {
          widget.audio.play(Sfx.fail, volume: 0.6);
          setState(() {
            _mistakes++;
            _flash = id;
            _status = 'Power is limited: ${sysNode(want).label} is more urgent than ${sysNode(id).label}.';
            _statusColor = C.red;
          });
        }
        break;
      case _CPhase.spreading:
      case _CPhase.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      spec: widget.spec,
      mistakes: _mistakes,
      status: _status,
      statusColor: _statusColor,
      scroll: false,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = math.max(320.0, box.maxHeight);
        // the flow runs top to bottom on a phone: power in at the top,
        // the systems that need it at the bottom
        return SizedBox(
          width: w,
          height: h,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _GraphPainter(failed: _failed, restored: _restored, t: _pulse.value))),
              for (final n in systemGraph)
                Positioned(
                  left: _nodeX(n, w),
                  top: _nodeY(n, h),
                  child: _node(n, _nodeW(n, w)),
                ),
            ]),
          ),
        );
      }),
    );
  }

  static const _nodeH = 52.0;
  static bool _isLeaf(SysNode n) => n.x > 0.8;
  static double _nodeY(SysNode n, double h) => ((n.x - 0.06) / 0.195).round().clamp(0, 4) / 4 * (h - _nodeH);
  static double _nodeW(SysNode n, double w) => _isLeaf(n) ? (w - 18) / 4 : math.min(190, w * 0.55);

  /// The bottom row (four systems) spreads across; the chain above is centred.
  static double _nodeX(SysNode n, double w) {
    final nw = _nodeW(n, w);
    if (_isLeaf(n)) return ((n.y - 0.14) / 0.24).round() * (nw + 6);
    return (w - nw) / 2;
  }

  Widget _node(SysNode n, double width) {
    final failed = _failed.contains(n.id);
    final restored = _restored.contains(n.id);
    final c = failed ? C.red : (restored ? C.green : C.cyan);
    final pulse = failed ? 0.5 + 0.5 * math.sin(_pulse.value * math.pi * 2) : 0.0;
    return GestureDetector(
      onTap: () {
        _tapNode(n.id);
        Timer(const Duration(milliseconds: 600), () {
          if (mounted && _flash == n.id) setState(() => _flash = null);
        });
      },
      child: Container(
        width: width,
        height: _nodeH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: 0.14 + pulse * 0.15), C.panelDeep),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _flash == n.id ? Colors.white : c, width: _flash == n.id ? 2.5 : 1.4),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.25 + pulse * 0.3), blurRadius: 10 + pulse * 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(failed ? Icons.power_off_rounded : Icons.bolt_rounded, size: 14, color: c),
          const SizedBox(width: 4),
          Flexible(child: Text(n.label, style: T.h3.copyWith(fontSize: 11.5), textAlign: TextAlign.center, maxLines: 2)),
        ]),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final Set<String> failed;
  final Set<String> restored;
  final double t;
  _GraphPainter({required this.failed, required this.restored, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const nh = _CascadeGameState._nodeH;
    Offset top(SysNode n) => Offset(_CascadeGameState._nodeX(n, size.width) + _CascadeGameState._nodeW(n, size.width) / 2, _CascadeGameState._nodeY(n, size.height));
    Offset bottom(SysNode n) => top(n) + const Offset(0, nh);
    for (final n in systemGraph) {
      for (final d in n.dependsOn) {
        final from = sysNode(d);
        final a = bottom(from), b = top(n);
        final dead = failed.contains(d) || failed.contains(n.id);
        final c = dead ? C.red : C.cyan;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, a.dy + 26, b.dx, b.dy - 26, b.dx, b.dy);
        canvas.drawPath(path, Paint()
          ..color = c.withValues(alpha: dead ? 0.35 : 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        // energy flowing along live links
        if (!dead) {
          for (final m in path.computeMetrics()) {
            for (var k = 0; k < 2; k++) {
              final tan = m.getTangentForOffset(m.length * ((t + k / 2) % 1));
              if (tan != null) canvas.drawCircle(tan.position, 2.6, Paint()..color = Colors.white);
            }
          }
        }
        // arrow head pointing down into the node
        final ah = Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(b.dx - 5, b.dy - 8)
          ..lineTo(b.dx + 5, b.dy - 8)
          ..close();
        canvas.drawPath(ah, Paint()..color = c);
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}
