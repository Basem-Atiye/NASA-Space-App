import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/audio.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';
import 'story_logic.dart';
import 'hands_on.dart';
import 'new_games.dart';
import 'story_model.dart';
import 'wow_games.dart';

typedef GameDone = void Function(GameResult r);

/// Picks the right mini-game widget for a spec.
Widget buildMiniGame(GameSpec spec, GameDone onDone, Audio audio, {String stepId = ''}) {
  switch (spec.kind) {
    case GameKind.order:
      return TriageGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.probe:
      return ProbeGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.hold:
      return HoldGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.allocate:
      return stepId == 't4_rations' ? TankGame(spec: spec, onDone: onDone, audio: audio) : CargoGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.wire:
      return WireGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.tune:
      return TuneGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.rules:
      return RulesGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.cascade:
      return CascadeGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.checklist:
      return ChecklistGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.sort:
      return SortGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.jump:
      return JumpGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.drive:
      return DriveGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.fitness:
      return FitnessGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.draw:
      return DrawGame(spec: spec, onDone: onDone, audio: audio);
    case GameKind.sim:
      return SimGame(spec: spec, onDone: onDone, audio: audio);
  }
}

/// Mode and hint hook for the mini-games, provided by the story screen.
class GameContext extends InheritedWidget {
  final AgeMode mode;
  final VoidCallback onHint;
  const GameContext({super.key, required this.mode, required this.onHint, required super.child});

  static GameContext? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GameContext>();

  @override
  bool updateShouldNotify(GameContext old) => old.mode != mode;
}

/// The frame every mini-game sits in: title, instructions, hint, the
/// puzzle itself, a status line and the confirm button. Fills the screen.
class GameFrame extends StatefulWidget {
  final GameSpec spec;
  final int mistakes;
  final Widget child;
  final Widget? footer;
  final String? status;
  final Color statusColor;

  /// When false the child is not wrapped in a scroll view (it sizes itself).
  final bool scroll;
  const GameFrame({super.key, required this.spec, required this.mistakes, required this.child, this.footer, this.status, this.statusColor = C.muted, this.scroll = true});

  @override
  State<GameFrame> createState() => _GameFrameState();
}

class _GameFrameState extends State<GameFrame> with SingleTickerProviderStateMixin {
  bool? _hint;
  int _lastMistakes = 0;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(covariant GameFrame old) {
    super.didUpdateWidget(old);
    // a mistake gives the panel a gentle side shake (never a red flash)
    if (widget.mistakes > _lastMistakes) _shake.forward(from: 0);
    _lastMistakes = widget.mistakes;
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final gc = GameContext.of(context);
    final cadet = gc?.mode == AgeMode.cadet;
    // Cadets get the hint open from the start, read by Pip
    final hintOpen = _hint ?? (cadet && s.hint.isNotEmpty);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 7 * (1 - _shake.value), 0), child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.engineering_rounded, color: C.cyan, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_titleCase(s.title), style: T.h2.copyWith(fontSize: 21))),
            if (s.hint.isNotEmpty)
              Pressable(
                onTap: () {
                  final opening = !hintOpen;
                  setState(() => _hint = opening);
                  if (opening) gc?.onHint();
                },
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: hintOpen ? C.cyan.withValues(alpha: 0.18) : Colors.transparent,
                    border: Border.all(color: C.cyan.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: C.cyan, size: 16),
                    const SizedBox(width: 5),
                    Text('HINT', style: T.label.copyWith(color: C.cyan, fontSize: 11)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text(s.instructions, style: T.body.copyWith(color: C.muted, fontSize: 14)),
          if (widget.mistakes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Mistakes: ${widget.mistakes}', style: T.label.copyWith(color: C.amber, letterSpacing: 1)),
            ),
          AnimatedSize(
            duration: Motion.fast,
            curve: Motion.curve,
            child: hintOpen
                ? Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(color: C.cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cyan.withValues(alpha: 0.35))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const PipFigure(size: 34, eye: PipEye.thinking),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text.rich(TextSpan(children: [TextSpan(text: 'PIP: ', style: T.h3.copyWith(color: C.cyan, fontSize: 13)), TextSpan(text: s.hint)]),
                              style: T.body.copyWith(fontSize: 13.5))),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          Expanded(child: widget.scroll ? SingleChildScrollView(child: widget.child) : widget.child),
          if (widget.status != null) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Container(
                key: ValueKey(widget.status),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: widget.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.statusColor.withValues(alpha: 0.4))),
                child: Text(widget.status!, style: T.body.copyWith(color: widget.statusColor == C.muted ? C.text : widget.statusColor, fontSize: 13.5)),
              ),
            ),
          ],
          if (widget.footer != null) ...[const SizedBox(height: 12), widget.footer!],
        ],
      ),
    );
  }
}

String _titleCase(String s) {
  final words = s.toLowerCase().split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      words[i].isEmpty ? '' : (i > 0 && const {'the', 'of', 'a', 'for', 'and', 'to'}.contains(words[i]) ? words[i] : words[i][0].toUpperCase() + words[i].substring(1))
  ].join(' ').replaceAll('O2', 'O₂').replaceAll('Kg', 'kg');
}

/// A full-width confirm button for the bottom of a mini-game.
Widget confirmButton(String label, VoidCallback? onTap, {IconData icon = Icons.check_rounded, Color color = C.sapphire}) =>
    PrimaryButton(label: label, icon: icon, onTap: onTap, color: color, height: 54);

/// Deterministic shuffle so the same task always looks the same.
List<int> shuffled(int n, int seed) {
  final l = List<int>.generate(n, (i) => i);
  final r = math.Random(seed);
  for (var i = n - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final t = l[i];
    l[i] = l[j];
    l[j] = t;
  }
  // never show the answer already in order
  if (n > 1 && List.generate(n, (i) => l[i] == i).every((b) => b)) l.insert(0, l.removeLast());
  return l;
}

// =================================================================== ORDER

// =================================================================== PROBE

class ProbeGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const ProbeGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<ProbeGame> createState() => _ProbeGameState();
}

class _ProbeGameState extends State<ProbeGame> {
  final Set<int> _probed = {};
  final Set<int> _marked = {};
  int? _current;
  bool _checked = false;
  int _mistakes = 0;
  String? _status;

  void _probe(int i) {
    if (_checked) return;
    widget.audio.tap();
    setState(() {
      _probed.add(i);
      _current = i;
    });
  }

  void _toggleMark(int i) {
    if (_checked) return;
    widget.audio.tap();
    setState(() => _marked.contains(i) ? _marked.remove(i) : _marked.add(i));
  }

  void _confirm() {
    final m = scoreProbe(faulty: widget.spec.faulty, marked: _marked, probesUsed: _probed.length, probesAllowed: widget.spec.probes);
    setState(() {
      _checked = true;
      _mistakes = m;
      final allFound = widget.spec.faulty.difference(_marked).isEmpty && _marked.difference(widget.spec.faulty).isEmpty;
      _status = allFound ? (m == 0 ? 'Found it. Exactly right.' : 'Found it, but you used more probes than needed.') : 'Not quite: the green ones were the real faults.';
    });
    widget.audio.play(m == 0 ? Sfx.success : Sfx.fail, volume: 0.6);
    Timer(const Duration(milliseconds: 2200), () => widget.onDone(GameResult(mistakes: m)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final cur = _current;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status ?? 'Probes used ${_probed.length} / ${s.probes}  ·  marked ${_marked.length}',
      statusColor: _checked ? (_mistakes == 0 ? C.green : C.amber) : C.muted,
      footer: confirmButton(_marked.isEmpty ? 'Mark the faulty parts' : 'Confirm diagnosis', _marked.isEmpty || _checked ? null : _confirm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // the multimeter
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2E2A52), Color(0xFF1D1B38)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.line),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('MULTIMETER', style: T.label),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF0C1A12), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.cyan.withValues(alpha: 0.3))),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      cur == null ? '— — —' : s.readings[cur],
                      key: ValueKey(cur),
                      style: T.mono.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: cur == null ? C.dim : C.frozen),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(cur == null ? 'Tap a part to test it' : s.items[cur], style: T.bodySmall),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 64, height: 64, child: CustomPaint(painter: _ProbeIcon(cur != null))),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Probes used ${_probed.length} of ${s.probes}', style: T.label.copyWith(color: C.muted, letterSpacing: 1)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          final cw = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < s.items.length; i++) SizedBox(width: cw, child: _probeCard(i)),
          ]);
        }),
      ]),
    );
  }

  Widget _probeCard(int i) {
    final s = widget.spec;
    final marked = _marked.contains(i);
    Color c = C.cyan;
    if (_checked) {
      if (s.faulty.contains(i)) {
        c = C.green;
      } else if (marked) {
        c = C.red;
      } else {
        c = C.dim;
      }
    } else if (marked) {
      c = C.red;
    }
    return GestureDetector(
      onTap: () => _probe(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _current == i ? C.cyan.withValues(alpha: 0.14) : C.panelSolid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.8), width: marked ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_probed.contains(i) ? Icons.sensors_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: c),
            const SizedBox(width: 6),
            Expanded(child: Text(s.items[i], style: T.h3.copyWith(fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          if (_probed.contains(i))
            GestureDetector(
              onTap: () => _toggleMark(i),
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: marked ? C.red.withValues(alpha: 0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (marked ? C.red : C.muted).withValues(alpha: 0.7)),
                ),
                child: Text(marked ? 'FAULTY ✓' : 'MARK FAULTY', style: T.label.copyWith(color: marked ? C.red : C.muted, fontSize: 11)),
              ),
            )
          else
            SizedBox(height: 34, child: Align(alignment: Alignment.centerLeft, child: Text('Tap to test', style: T.bodySmall.copyWith(color: C.dim)))),
        ]),
      ),
    );
  }
}

class _ProbeIcon extends CustomPainter {
  final bool active;
  _ProbeIcon(this.active);
  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.2, 0, s.width * 0.6, s.height * 0.8), const Radius.circular(8));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFD27A));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.28, s.height * 0.08, s.width * 0.44, s.height * 0.24), const Radius.circular(3)),
        Paint()..color = const Color(0xFF0C1A12));
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.55), s.width * 0.13, Paint()..color = const Color(0xFF3B3E44));
    final lead = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.8), Offset(s.width * 0.25, s.height), lead..color = const Color(0xFFE5484D));
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.8), Offset(s.width * 0.75, s.height), lead..color = const Color(0xFF1B1B1B));
    if (active) canvas.drawCircle(Offset(s.width * 0.66, s.height * 0.2), 2.5, Paint()..color = C.cyan);
  }

  @override
  bool shouldRepaint(_ProbeIcon old) => old.active != active;
}

// =================================================================== HOLD

class HoldGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const HoldGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<HoldGame> createState() => _HoldGameState();
}

class _HoldGameState extends State<HoldGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _v = 0;
  bool _holding = false;
  bool _done = false;
  int _mistakes = 0;
  String? _status;
  Color _statusColor = C.muted;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration t) {
    final dt = math.min(0.05, (t - _last).inMicroseconds / 1e6);
    _last = t;
    if (!_holding || _done) return;
    final s = widget.spec;
    // speeds up as it fills, like a pump working against rising pressure
    setState(() => _v = math.min(s.max, _v + s.rate * dt * (0.6 + 0.9 * _v / s.max)));
    if (_v >= s.max) _release();
  }

  void _press() {
    if (_done) return;
    setState(() {
      _holding = true;
      _status = null;
    });
    widget.audio.haptic(light: true);
  }

  void _release() {
    if (!_holding || _done) return;
    _holding = false;
    final s = widget.spec;
    switch (holdVerdict(_v, s.low, s.high)) {
      case HoldVerdict.under:
        setState(() {
          _status = 'Not enough yet: ${_v.toStringAsFixed(1)} ${s.unit}. Hold again to add more.';
          _statusColor = C.amber;
        });
        break;
      case HoldVerdict.over:
        widget.audio.play(Sfx.fail, volume: 0.6);
        widget.audio.haptic(heavy: true);
        setState(() {
          _mistakes++;
          _status = 'Too far: ${_v.toStringAsFixed(1)} ${s.unit}! Reset and try again.';
          _statusColor = C.red;
          _v = 0;
        });
        break;
      case HoldVerdict.good:
        widget.audio.play(Sfx.success, volume: 0.6);
        setState(() {
          _done = true;
          _status = 'Perfect: ${_v.toStringAsFixed(1)} ${s.unit}.';
          _statusColor = C.green;
        });
        Timer(const Duration(milliseconds: 1000), () => widget.onDone(GameResult(mistakes: _mistakes)));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status,
      statusColor: _statusColor,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 280,
          height: 190,
          child: CustomPaint(painter: _DialGauge(value: _v, max: s.max, low: s.low, high: s.high, unit: s.unit)),
        ),
        const SizedBox(height: 8),
        Text('Release inside the band: ${s.low.toStringAsFixed(s.low % 1 == 0 ? 0 : 1)}–${s.high.toStringAsFixed(s.high % 1 == 0 ? 0 : 1)} ${s.unit}', style: T.bodySmall),
        const SizedBox(height: 22),
        GestureDetector(
          onTapDown: (_) => _press(),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _holding ? C.sapphire : C.sapphire.withValues(alpha: 0.18),
              border: Border.all(color: C.sapphire, width: 2),
              boxShadow: [BoxShadow(color: C.sapphire.withValues(alpha: _holding ? 0.6 : 0.25), blurRadius: _holding ? 40 : 16)],
            ),
            alignment: Alignment.center,
            child: Text(_done ? 'DONE' : 'HOLD', style: T.button.copyWith(fontSize: 22, letterSpacing: 4)),
          ),
        ),
        const SizedBox(height: 10),
        Text('Press and hold', style: T.bodySmall.copyWith(color: C.dim)),
      ]),
    );
  }
}

class _DialGauge extends CustomPainter {
  final double value, max, low, high;
  final String unit;
  _DialGauge({required this.value, required this.max, required this.low, required this.high, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.78);
    final r = math.min(size.width / 2, size.height * 0.78) - 6;
    const start = math.pi, sweep = math.pi;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = C.indigo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    canvas.drawArc(
        rect,
        start + sweep * low / max,
        sweep * (high - low) / max,
        false,
        Paint()
          ..color = C.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    canvas.drawArc(
        rect,
        start + sweep * high / max,
        sweep * (1 - high / max),
        false,
        Paint()
          ..color = C.red.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    final a = start + sweep * (value / max).clamp(0.0, 1.0);
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r - 4);
    canvas.drawLine(
        c,
        tip,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 6, Paint()..color = C.cyan);
    final tp = TextPainter(
      text: TextSpan(text: '${value.toStringAsFixed(1)} $unit', style: T.mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, 10));
  }

  @override
  bool shouldRepaint(_DialGauge old) => old.value != value;
}

// =================================================================== ALLOCATE

// =================================================================== WIRE

class WireGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const WireGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<WireGame> createState() => _WireGameState();
}

class _WireGameState extends State<WireGame> with SingleTickerProviderStateMixin {
  int? _left;
  final List<Wire> _wires = [];
  Wire? _spark;
  int _mistakes = 0;
  String? _status;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool _leftDone(int i) => _wires.any((w) => w.left == i);
  bool _rightDone(int j) => _wires.any((w) => w.right == j);

  void _tapLeft(int i) {
    if (_leftDone(i)) return;
    widget.audio.tap();
    setState(() => _left = i);
  }

  void _tapRight(int j) {
    final l = _left;
    if (l == null || _rightDone(j)) return;
    final w = Wire(l, j);
    if (wireOk(widget.spec.answer, w)) {
      widget.audio.play(Sfx.message, volume: 0.5);
      setState(() {
        _wires.add(w);
        _left = null;
        _status = null;
      });
      if (_wires.length == widget.spec.items.length) {
        widget.audio.play(Sfx.success, volume: 0.6);
        setState(() => _status = 'All connected. Circuit OK.');
        Timer(const Duration(milliseconds: 1000), () => widget.onDone(GameResult(mistakes: _mistakes)));
      }
    } else {
      widget.audio.play(Sfx.fail, volume: 0.6);
      widget.audio.haptic(heavy: true);
      setState(() {
        _mistakes++;
        _spark = w;
        _left = null;
        _status = '${widget.spec.items[l]} does not go to ${widget.spec.right[j]}. ${widget.spec.title == 'POLARITY' ? 'Fuse blown! (−1 spare part)' : 'Disconnected.'}';
      });
      Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _spark = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final n = s.items.length;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status ?? (_left == null ? 'Tap a terminal on the left.' : 'Now tap where "${s.items[_left!]}" connects.'),
      statusColor: _status == null ? C.muted : (_spark != null || _status!.contains('not') ? C.red : C.green),
      child: LayoutBuilder(builder: (context, box) {
        final h = 62.0 * n;
        final colW = (box.maxWidth - 70) / 2;
        return SizedBox(
          height: h,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => CustomPaint(
              painter: _WirePainter(n: n, wires: _wires, spark: _spark, t: _anim.value, colW: colW),
              child: Row(children: [
                SizedBox(width: colW, child: _column(n, (i) => _terminal(s.items[i], selected: _left == i, done: _leftDone(i), onTap: () => _tapLeft(i), alignRight: true))),
                const Spacer(),
                SizedBox(width: colW, child: _column(n, (j) => _terminal(s.right[j], selected: false, done: _rightDone(j), onTap: () => _tapRight(j), alignRight: false))),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _column(int n, Widget Function(int) b) => Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [for (var i = 0; i < n; i++) b(i)]);

  Widget _terminal(String label, {required bool selected, required bool done, required VoidCallback onTap, required bool alignRight}) {
    final c = done ? C.frozen : (selected ? C.sapphire : C.cyan);
    final plus = label.contains('+'), minus = label.contains('−');
    final dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(shape: BoxShape.circle, color: plus ? const Color(0xFFE5484D) : (minus ? const Color(0xFF2B2B2B) : c), border: Border.all(color: c, width: 2)),
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? C.sapphire.withValues(alpha: 0.35) : C.panelSolid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.8), width: selected ? 2 : 1.2),
        ),
        child: Row(children: [
          if (!alignRight) ...[dot, const SizedBox(width: 8)],
          Expanded(child: Text(label, style: T.h3.copyWith(fontSize: 13), textAlign: alignRight ? TextAlign.right : TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (alignRight) ...[const SizedBox(width: 8), dot],
        ]),
      ),
    );
  }
}

class _WirePainter extends CustomPainter {
  final int n;
  final List<Wire> wires;
  final Wire? spark;
  final double t;
  final double colW;
  _WirePainter({required this.n, required this.wires, required this.spark, required this.t, required this.colW});

  Offset _l(Size s, int i) => Offset(colW, s.height * (i + 0.5) / n);
  Offset _r(Size s, int j) => Offset(s.width - colW, s.height * (j + 0.5) / n);

  void _cable(Canvas canvas, Offset a, Offset b, Color c, double w) {
    final p = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + 30, a.dy, b.dx - 30, b.dy, b.dx, b.dy);
    canvas.drawPath(
        p,
        Paint()
          ..color = c.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 6);
    canvas.drawPath(
        p,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round);
    // current flowing along the wire
    for (final m in p.computeMetrics()) {
      for (var k = 0; k < 3; k++) {
        final pos = m.getTangentForOffset(m.length * ((t + k / 3) % 1));
        if (pos != null) canvas.drawCircle(pos.position, 2.5, Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in wires) {
      _cable(canvas, _l(size, w.left), _r(size, w.right), C.cyan, 3);
    }
    final s = spark;
    if (s != null) {
      final a = _l(size, s.left), b = _r(size, s.right);
      _cable(canvas, a, b, C.red, 2.5);
      final mid = Offset.lerp(a, b, 0.5)!;
      final rnd = math.Random((t * 1000).toInt());
      for (var i = 0; i < 10; i++) {
        final ang = rnd.nextDouble() * math.pi * 2;
        final len = 6 + rnd.nextDouble() * 16;
        canvas.drawLine(
            mid,
            mid + Offset(math.cos(ang), math.sin(ang)) * len,
            Paint()
              ..color = C.amber
              ..strokeWidth = 1.6);
      }
    }
  }

  @override
  bool shouldRepaint(_WirePainter old) => true;
}

// =================================================================== TUNE

class TuneGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const TuneGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<TuneGame> createState() => _TuneGameState();
}

class _TuneGameState extends State<TuneGame> {
  double _angle = 20;
  int _mistakes = 0;
  bool _done = false;
  String? _status;

  void _lock() {
    final out = panelOutput(_angle, widget.spec.best);
    if (panelAimed(_angle, widget.spec.best)) {
      widget.audio.play(Sfx.success, volume: 0.6);
      setState(() {
        _done = true;
        _status = 'Locked at ${_angle.round()}°: ${(out * 100).round()}% of full power.';
      });
      Timer(const Duration(milliseconds: 1000), () => widget.onDone(GameResult(mistakes: _mistakes)));
    } else {
      widget.audio.play(Sfx.fail, volume: 0.5);
      setState(() {
        _mistakes = math.min(2, _mistakes + 1);
        _status = 'Only ${(out * 100).round()}% of full power. Keep turning to find the peak.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = panelOutput(_angle, widget.spec.best);
    return GameFrame(
      spec: widget.spec,
      mistakes: _mistakes,
      status: _status,
      statusColor: _done ? C.green : C.amber,
      footer: confirmButton('Lock panels', _done ? null : _lock, icon: Icons.lock_rounded),
      child: Column(children: [
        GestureDetector(
          onPanUpdate: _done ? null : (d) => setState(() => _angle = (_angle + d.delta.dx * 0.8 - d.delta.dy * 0.8) % 360),
          child: SizedBox(width: 210, height: 210, child: CustomPaint(painter: _SunDial(angle: _angle, best: widget.spec.best))),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Text('POWER OUTPUT', style: T.label),
          const Spacer(),
          Text('${(out * 1.2).toStringAsFixed(2)} kW', style: T.h3.copyWith(fontSize: 18)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: out, minHeight: 16, backgroundColor: C.lineSoft, color: out > 0.99 ? C.cyan : (out > 0.7 ? C.sapphire : C.red)),
        ),
        const SizedBox(height: 10),
        Slider(value: _angle, min: 0, max: 359, onChanged: _done ? null : (v) => setState(() => _angle = v)),
        Text('Panel heading ${_angle.round()}°  ·  output = cos(angle to the Sun)', style: T.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SunDial extends CustomPainter {
  final double angle;
  final double best;
  _SunDial({required this.angle, required this.best});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = C.panelSolid
          ..style = PaintingStyle.fill);
    // the low Sun on the rim of the dial
    final sa = best * math.pi / 180 - math.pi / 2;
    final sp = c + Offset(math.cos(sa), math.sin(sa)) * (r + 0.0);
    canvas.drawCircle(sp, 22,
        Paint()..shader = RadialGradient(colors: [const Color(0xFFFFF6DD).withValues(alpha: 0.7), const Color(0x00FFF6DD)]).createShader(Rect.fromCircle(center: sp, radius: 22)));
    canvas.drawCircle(sp, 7, Paint()..color = const Color(0xFFFFFBEF));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = C.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (var d = 0; d < 360; d += 30) {
      final a = d * math.pi / 180 - math.pi / 2;
      canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * (r - 8),
          c + Offset(math.cos(a), math.sin(a)) * r,
          Paint()
            ..color = C.dim
            ..strokeWidth = 1.5);
    }
    // panel
    final a = angle * math.pi / 180 - math.pi / 2;
    final dir = Offset(math.cos(a), math.sin(a));
    final perp = Offset(-dir.dy, dir.dx);
    canvas.drawLine(
        c - perp * (r * 0.55),
        c + perp * (r * 0.55),
        Paint()
          ..color = const Color(0xFF2D4C8A)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        c,
        c + dir * (r * 0.75),
        Paint()
          ..color = C.cyan
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c + dir * (r * 0.75), 4, Paint()..color = C.cyan);
  }

  @override
  bool shouldRepaint(_SunDial old) => old.angle != angle || old.best != best;
}

// =================================================================== CHECKLIST

class ChecklistGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const ChecklistGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<ChecklistGame> createState() => _ChecklistGameState();
}

class _ChecklistGameState extends State<ChecklistGame> {
  int _checked = 0;
  final Set<int> _fixed = {};
  int? _fixing;
  int _mistakes = 0;
  String? _status;
  bool _aborted = false;
  bool _done = false;

  bool get _blocked => _checked > 0 && widget.spec.faulty.contains(_checked - 1) && !_fixed.contains(_checked - 1);
  bool get _allGo => _checked == widget.spec.items.length && widget.spec.faulty.every(_fixed.contains);

  void _check() {
    if (_blocked || _checked >= widget.spec.items.length) return;
    final i = _checked;
    setState(() {
      _checked++;
      _aborted = false;
      _status = widget.spec.faulty.contains(i) ? '${widget.spec.items[i]} is NO-GO. Fix it before continuing.' : null;
    });
    widget.audio.play(widget.spec.faulty.contains(i) ? Sfx.alert : Sfx.message, volume: 0.5);
  }

  void _fix(int i) {
    setState(() => _fixing = i);
    widget.audio.tap();
    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() {
        _fixing = null;
        _fixed.add(i);
        _status = widget.spec.right.length > i && widget.spec.right[i].isNotEmpty
            ? '${widget.spec.items[i]}: ${widget.spec.right[i]}'
            : (i == 0 ? 'Propellant transferred from the descent tanks: 100%.' : 'Suit recharged: 100%.');
      });
      widget.audio.play(Sfx.success, volume: 0.5);
    });
  }

  void _launch() {
    if (_done) return;
    final s0 = widget.spec;
    if (!_allGo) {
      widget.audio.play(Sfx.fail, volume: 0.7);
      widget.audio.haptic(heavy: true);
      setState(() {
        _mistakes++;
        _aborted = true;
        _status = s0.label.isEmpty ? 'LAUNCH ABORT: not every item is GO. The computer stopped the countdown.' : 'Not every item is GO yet. Check and fix them all first.';
      });
      return;
    }
    setState(() {
      _done = true;
      _status = 'All items GO.';
    });
    widget.audio.play(Sfx.success);
    Timer(const Duration(milliseconds: 700), () => widget.onDone(GameResult(mistakes: _mistakes)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status,
      statusColor: _aborted ? C.red : (_allGo ? C.green : C.amber),
      footer: Row(children: [
        Expanded(child: HudButton(label: 'CHECK NEXT', icon: Icons.fact_check_rounded, onTap: _blocked || _checked >= s.items.length ? null : _check)),
        const SizedBox(width: 10),
        Expanded(
            child: PrimaryButton(
                label: s.label.isEmpty ? 'Launch' : s.label,
                icon: s.label.isEmpty ? Icons.rocket_launch_rounded : Icons.check_rounded,
                color: _allGo ? C.sapphire : C.red,
                onTap: _done ? null : _launch,
                height: 50)),
      ]),
      child: Column(children: [
        for (var i = 0; i < s.items.length; i++) _row(i),
      ]),
    );
  }

  Widget _row(int i) {
    final s = widget.spec;
    final seen = i < _checked;
    final bad = s.faulty.contains(i) && !_fixed.contains(i);
    final c = !seen ? C.dim : (bad ? C.red : C.cyan);
    final custom = s.right.length > i && s.right[i].isNotEmpty;
    final reading = !seen ? '—' : (s.faulty.contains(i) && _fixed.contains(i) ? (custom ? s.right[i] : (i == 0 ? 'Tanks 100% · GO' : 'Suit 100% · GO')) : s.readings[i]);
    return AnimatedContainer(
      duration: Motion.fast,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: seen ? c.withValues(alpha: 0.08) : C.panelSolid, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.6))),
      child: Row(children: [
        Icon(!seen ? Icons.radio_button_unchecked_rounded : (bad ? Icons.cancel_rounded : Icons.check_circle_rounded), color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.items[i], style: T.h3.copyWith(fontSize: 14)),
            Text(reading, style: T.bodySmall.copyWith(color: seen ? c : C.dim)),
          ]),
        ),
        if (seen && bad)
          _fixing == i
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.amber))
              : GestureDetector(
                  onTap: () => _fix(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(10)),
                    child: Text(s.right.isNotEmpty ? 'FIX' : (i == 0 ? 'TRANSFER' : 'RECHARGE'), style: T.label.copyWith(color: Colors.white, fontSize: 11)),
                  ),
                ),
      ]),
    );
  }
}
