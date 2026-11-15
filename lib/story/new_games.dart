/// The 2.0 mini-games: sort, jump, drive, fitness, draw and the engineering SIM.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/audio.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';
import 'game_physics.dart';
import 'minigames.dart';
import 'hands_on.dart';
import 'sims.dart';
import 'story_model.dart';

// =================================================================== SORT

class SortGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const SortGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<SortGame> createState() => _SortGameState();
}

class _SortGameState extends State<SortGame> {
  late final List<int> _queue = shuffled(widget.spec.items.length, widget.spec.title.hashCode);
  final Map<int, int> _placed = {};
  int _mistakes = 0;
  int? _wrongBin;
  String? _status;
  bool _done = false;

  int? get _current => _placed.length < _queue.length ? _queue[_placed.length] : null;

  void _drop(int bin) {
    final item = _current;
    if (item == null || _done) return;
    final s = widget.spec;
    if (s.answer[item] == bin) {
      widget.audio.tap();
      setState(() {
        _placed[item] = bin;
        _wrongBin = null;
        _status = '"${s.items[item]}" → ${s.bins[bin]}';
      });
      if (_placed.length == s.items.length) {
        _done = true;
        widget.audio.play(Sfx.success, volume: 0.6);
        setState(() => _status = 'Everything sorted!');
        Timer(const Duration(milliseconds: 900), () => widget.onDone(GameResult(mistakes: _mistakes)));
      }
    } else {
      widget.audio.play(Sfx.fail, volume: 0.5);
      widget.audio.haptic();
      setState(() {
        _mistakes++;
        _wrongBin = bin;
        _status = s.wrong.isNotEmpty ? s.wrong.replaceAll('{item}', s.items[item]) : 'Think again: does "${s.items[item]}" really go in "${s.bins[bin]}"?';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final item = _current;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status,
      statusColor: _wrongBin != null ? C.amber : C.green,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GameText(s.label.isEmpty ? 'WHERE DOES IT GO?' : s.label, style: T.label),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: Motion.normal,
          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: Container(
            key: ValueKey(item),
            height: 96,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: C.panelSolid,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.cyan.withValues(alpha: 0.7), width: 1.4),
              boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: 0.12), blurRadius: 24)],
            ),
            child: GameText(item == null ? 'Done!' : s.items[item], style: T.h2.copyWith(fontSize: 21), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 8),
        GameText('${_placed.length} of ${s.items.length} sorted', style: T.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var b = 0; b < s.bins.length; b++) ...[
            if (b > 0) const SizedBox(width: 8),
            Expanded(child: _bin(b)),
          ],
        ]),
      ]),
    );
  }

  Widget _bin(int b) {
    final s = widget.spec;
    final inBin = [
      for (final e in _placed.entries)
        if (e.value == b) s.items[e.key]
    ];
    final wrong = _wrongBin == b;
    final palette = [C.cyan, C.violet, C.frozen, C.sapphire];
    final c = palette[b % palette.length];
    return Pressable(
      onTap: _current == null ? null : () => _drop(b),
      child: AnimatedContainer(
        duration: Motion.fast,
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (wrong ? C.red : c).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: (wrong ? C.red : c).withValues(alpha: 0.75), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.move_to_inbox_rounded, color: c, size: 26),
          const SizedBox(height: 4),
          GameText(s.bins[b], style: T.h3.copyWith(fontSize: 13.5, color: c), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (final t in inBin)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GameText('• $t', style: T.bodySmall.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ]),
      ),
    );
  }
}

// =================================================================== JUMP

class JumpGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const JumpGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<JumpGame> createState() => _JumpGameState();
}

class _JumpGameState extends State<JumpGame> with SingleTickerProviderStateMixin {
  late final double _g = widget.spec.best > 0 ? widget.spec.best : moonG;
  late final JumpRunner _r = JumpRunner(g: _g);
  late final List<(double, double)> _craters = jumpCourse(math.max(1, widget.spec.count), seed: widget.spec.title.length);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _cleared = 0;
  int _mistakes = 0;
  double _stun = 0;
  double _t = 0;
  String? _status;
  bool _done = false;
  bool _started = false;
  double _peak = 0;
  double _air = 0;
  double _lastHang = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _ticker.start();
    setState(() => _status = 'Tap JUMP just before each crater.');
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _t += dt;
    if (_done) return;
    if (_stun > 0) {
      _stun -= dt;
      setState(() {});
      return;
    }
    final wasAir = _r.airborne;
    _r.step(dt);
    if (_r.airborne) {
      _air += dt;
      _peak = math.max(_peak, _r.y);
    }
    if (wasAir && !_r.airborne) _lastHang = _air;
    // fell into a crater?
    if (!_r.airborne) {
      for (var i = _cleared; i < _craters.length; i++) {
        final (a, b) = _craters[i];
        if (_r.x > a + 0.2 && _r.x < b - 0.2) {
          _mistakes++;
          _stun = 1.1;
          _r.x = b + 0.3;
          widget.audio.play(Sfx.fail, volume: 0.5);
          widget.audio.haptic();
          _status = 'Bump! Nova slid into the crater and climbed out. Jump a little earlier.';
          break;
        }
      }
    }
    while (_cleared < _craters.length && _r.x > _craters[_cleared].$2 && !_r.airborne) {
      _cleared++;
      if (_stun <= 0) {
        widget.audio.play(Sfx.star, volume: 0.45);
        _status = 'Cleared! Height ${_peak.toStringAsFixed(1)} m, ${_lastHang.toStringAsFixed(1)} s in the air.';
      }
      _peak = 0;
      _air = 0;
    }
    if (_cleared >= _craters.length && !_done) {
      _done = true;
      _status = 'All craters cleared! On Earth the same jump is only ${(jumpHeight(_r.v0, earthG) * 100).round()} cm high.';
      widget.audio.play(Sfx.success, volume: 0.6);
      Timer(const Duration(milliseconds: 1400), () {
        if (mounted) widget.onDone(GameResult(mistakes: _mistakes, data: {'height': jumpHeight(_r.v0, _g)}));
      });
    }
    setState(() {});
  }

  void _jump() {
    if (!_started) {
      _start();
      return;
    }
    if (_stun > 0 || _done) return;
    if (_r.jump()) {
      _air = 0;
      _peak = 0;
      widget.audio.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final h = jumpHeight(_r.v0, _g), hang = hangTime(_r.v0, _g);
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status ?? 'Gravity here: ${_g.toStringAsFixed(2)} m/s². A jump goes ${h.toStringAsFixed(1)} m up and lasts ${hang.toStringAsFixed(1)} s.',
      statusColor: _status != null && _status!.startsWith('Bump') ? C.amber : C.cyan,
      scroll: false,
      footer: confirmButton(_started ? 'JUMP' : 'Start running', _done ? null : _jump, icon: Icons.keyboard_double_arrow_up_rounded),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _jump(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: _JumpPainter(runner: _r, craters: _craters, t: _t, cleared: _cleared, stun: _stun),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: GameText('$_cleared/${_craters.length}', style: T.mono.copyWith(fontSize: 16, color: C.frozen)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpPainter extends CustomPainter {
  final JumpRunner runner;
  final List<(double, double)> craters;
  final double t;
  final int cleared;
  final double stun;
  _JumpPainter({required this.runner, required this.craters, required this.t, required this.cleared, required this.stun});

  @override
  void paint(Canvas c, Size size) {
    final ppm = size.width / 9; // 9 m visible
    final ground = size.height * 0.72;
    final camX = runner.x - 2.2;
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader =
              const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF020705), Color(0xFF0E1A1F)]).createShader(Offset.zero & size));
    final star = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (var i = 0; i < 40; i++) {
      final x = ((i * 97.3) - camX * ppm * 0.05) % size.width;
      c.drawCircle(Offset(x, (i * 53.1) % (ground * 0.8)), i % 7 == 0 ? 1.3 : 0.7, star);
    }
    // Earth
    c.drawCircle(Offset(size.width * 0.82, size.height * 0.2), 16, Paint()..color = const Color(0xFF3D7BD9));
    c.drawCircle(Offset(size.width * 0.82 + 5, size.height * 0.2 - 3), 6, Paint()..color = const Color(0xFF5BBF6A));
    // ground with craters
    final groundPaint = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD8D4CC), Color(0xFF8F8B84)])
          .createShader(Rect.fromLTWH(0, ground, size.width, size.height - ground));
    c.drawRect(Rect.fromLTWH(0, ground, size.width, size.height - ground), groundPaint);
    for (final (a, b) in craters) {
      final sa = (a - camX) * ppm, sb = (b - camX) * ppm;
      if (sb < -20 || sa > size.width + 20) continue;
      final r = Rect.fromLTRB(sa, ground - 10, sb, ground + (sb - sa) * 0.45);
      c.drawOval(r, Paint()..color = const Color(0xFF3A3834));
      c.drawArc(
          r,
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFEDEAE2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    // Nova
    final nx = (runner.x - camX) * ppm;
    final ny = ground - runner.y * ppm;
    c.save();
    c.translate(nx, ny + 4);
    final s = size.height / 300;
    c.scale(s, s);
    final phase = runner.airborne ? 0.0 : runner.x * 2.6;
    paintNova(c, NovaPose(t: t, phase: phase, action: runner.airborne ? NovaAction.cheer : (stun > 0 ? NovaAction.scared : NovaAction.walk)));
    c.restore();
    // dust puff when landing
    if (!runner.airborne && runner.y == 0) {
      final p = Paint()..color = const Color(0x55D8D4CC);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(nx - 10 - i * 6.0, ground + 2), 2.0 + (t * 6 + i) % 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =================================================================== DRIVE

class DriveGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const DriveGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<DriveGame> createState() => _DriveGameState();
}

class _Rock {
  int lane;
  double y; // 0 top .. 1 bottom
  bool hit = false;
  _Rock(this.lane, this.y);
}

class _DriveGameState extends State<DriveGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  StreamSubscription<AccelerometerEvent>? _tilt;
  bool _tiltOn = false;
  Duration _last = Duration.zero;
  double _steer = 0; // -1..1
  double _target = 0;
  final List<_Rock> _rocks = [];
  final _rnd = math.Random(11);
  double _spawn = 0.4;
  int _passed = 0;
  int _mistakes = 0;
  double _battery = 100;
  double _t = 0;
  bool _done = false;
  bool _started = false;
  String? _status;

  int get _goal => math.max(4, widget.spec.count);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tilt?.cancel();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _ticker.start();
    setState(() => _status = 'Steer around the boulders. Each bump costs battery.');
  }

  void _toggleTilt() {
    if (_tiltOn) {
      _tilt?.cancel();
      _tilt = null;
      setState(() => _tiltOn = false);
      return;
    }
    try {
      _tilt = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) => _target = (-e.x / 4.5).clamp(-1.0, 1.0).toDouble(),
        onError: (Object _) {
          if (mounted) setState(() => _tiltOn = false);
        },
        cancelOnError: true,
      );
      setState(() => _tiltOn = true);
    } catch (_) {
      setState(() => _status = 'This phone has no tilt sensor: use the arrows.');
    }
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _t += dt;
    if (_done) return;
    _steer += (_target - _steer) * (1 - math.exp(-dt * 8));
    _battery = math.max(0, _battery - dt * 0.9);
    _spawn -= dt;
    if (_spawn <= 0 && _passed + _rocks.length < _goal) {
      _rocks.add(_Rock(_rnd.nextInt(3), -0.1));
      _spawn = 1.1 + _rnd.nextDouble() * 0.6;
    }
    final lane = laneFor(_steer);
    for (final r in _rocks) {
      r.y += dt * 0.42;
      if (!r.hit && r.y > 0.78 && r.y < 0.9 && r.lane == lane) {
        r.hit = true;
        _mistakes++;
        _battery = math.max(0, _battery - 8);
        widget.audio.play(Sfx.fail, volume: 0.5);
        widget.audio.haptic(heavy: true);
        _status = 'Bump! A boulder scraped the wheel: −8% battery.';
      }
    }
    final gone = _rocks.where((r) => r.y > 1.05).toList();
    for (final r in gone) {
      _rocks.remove(r);
      _passed++;
      if (!r.hit) widget.audio.play(Sfx.tap, volume: 0.3);
    }
    if (_passed >= _goal && !_done) {
      _done = true;
      _status = 'Arrived with ${_battery.round()}% battery.';
      widget.audio.play(Sfx.success, volume: 0.6);
      Timer(const Duration(milliseconds: 1100), () {
        if (mounted) widget.onDone(GameResult(mistakes: _mistakes, data: {'battery': _battery}));
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status ?? 'Drive to the target. Tilt the phone or use the arrows.',
      statusColor: _status != null && _status!.startsWith('Bump') ? C.amber : C.cyan,
      scroll: false,
      footer: !_started
          ? confirmButton('Start driving', _start, icon: Icons.play_arrow_rounded)
          : Row(children: [
              Expanded(child: _arrow(Icons.arrow_back_rounded, -1)),
              const SizedBox(width: 10),
              Expanded(child: HudButton(label: _tiltOn ? 'TILT ON' : 'TILT', icon: Icons.screen_rotation_rounded, filled: _tiltOn, onTap: _toggleTilt)),
              const SizedBox(width: 10),
              Expanded(child: _arrow(Icons.arrow_forward_rounded, 1)),
            ]),
      child: Column(children: [
        Row(children: [
          Expanded(child: GaugeBar(label: 'BATTERY', value: '${_battery.round()}%', frac: _battery / 100, color: _battery < 30 ? C.red : C.cyan)),
          const SizedBox(width: 12),
          GameText('${math.min(_passed, _goal)}/$_goal', style: T.mono.copyWith(fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => _target = (_target + d.delta.dx / 90).clamp(-1.0, 1.0).toDouble(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(painter: _DrivePainter(steer: _steer, rocks: _rocks, t: _t), size: Size.infinite),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _arrow(IconData icon, double dir) => Listener(
        onPointerDown: (_) {
          if (_tiltOn) _toggleTilt();
          _target = dir;
        },
        onPointerUp: (_) => _target = 0,
        onPointerCancel: (_) => _target = 0,
        child: Container(
          height: 50,
          decoration: BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );
}

class _DrivePainter extends CustomPainter {
  final double steer;
  final List<_Rock> rocks;
  final double t;
  _DrivePainter({required this.steer, required this.rocks, required this.t});

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFB9B5AD));
    // track marks scrolling down
    final mark = Paint()..color = const Color(0x22000000);
    for (var i = 0; i < 14; i++) {
      final y = ((i / 14 + t * 0.42) % 1) * size.height;
      c.drawCircle(Offset((i * 73.0) % size.width, y), 3 + (i % 3) * 3.0, mark);
    }
    final laneW = size.width / 3;
    final dash = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 2;
    for (var l = 1; l < 3; l++) {
      for (var y = -20.0 + (t * 0.42 * size.height) % 40; y < size.height; y += 40) {
        c.drawLine(Offset(l * laneW, y), Offset(l * laneW, y + 18), dash);
      }
    }
    for (final r in rocks) {
      final cx = (r.lane + 0.5) * laneW, cy = r.y * size.height;
      c.drawOval(Rect.fromCenter(center: Offset(cx + 6, cy + 10), width: laneW * 0.5, height: 14), Paint()..color = const Color(0x33000000));
      c.drawPath(
        Path()
          ..moveTo(cx - laneW * 0.22, cy + 8)
          ..lineTo(cx - laneW * 0.16, cy - 12)
          ..lineTo(cx + 2, cy - 20)
          ..lineTo(cx + laneW * 0.2, cy - 6)
          ..lineTo(cx + laneW * 0.22, cy + 8)
          ..close(),
        Paint()..color = r.hit ? const Color(0xFF8E5A5A) : const Color(0xFF6E6A66),
      );
    }
    // the rover, top view
    final rx = size.width / 2 + steer * laneW, ry = size.height * 0.84;
    c.save();
    c.translate(rx, ry);
    c.rotate(steer * 0.18);
    final wheel = Paint()..color = const Color(0xFF2A2D33);
    for (final dx in [-26.0, 26.0]) {
      for (final dy in [-24.0, 0.0, 24.0]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(dx, dy), width: 10, height: 16), const Radius.circular(3)), wheel);
      }
    }
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 46, height: 70), const Radius.circular(10)), Paint()..color = const Color(0xFFF2F1EC));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -20), width: 34, height: 16), const Radius.circular(5)), Paint()..color = const Color(0xFF2E6C80));
    c.drawRect(Rect.fromCenter(center: const Offset(0, 10), width: 46, height: 4), Paint()..color = C.sapphire);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =================================================================== FITNESS

class FitnessGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const FitnessGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<FitnessGame> createState() => _FitnessGameState();
}

class _FitnessGameState extends State<FitnessGame> with SingleTickerProviderStateMixin {
  int _exercise = 0;
  int _reps = 0;
  bool _motion = false;
  StreamSubscription<UserAccelerometerEvent>? _sub;
  RepCounter _counter = RepCounter();
  late final AnimationController _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  bool _done = false;
  String? _status;

  List<String> get _list => widget.spec.items.isEmpty ? const ['Squats', 'Jumping jacks', 'Arm circles'] : widget.spec.items;
  int get _target => math.max(3, widget.spec.count);

  @override
  void dispose() {
    _sub?.cancel();
    _beat.dispose();
    super.dispose();
  }

  void _rep() {
    if (_done) return;
    widget.audio.tap();
    setState(() => _reps++);
    if (_reps >= _target) {
      if (_exercise < _list.length - 1) {
        widget.audio.play(Sfx.star, volume: 0.5);
        setState(() {
          _status = '${_list[_exercise]} done! Next: ${_list[_exercise + 1]}.';
          _exercise++;
          _reps = 0;
          _counter = RepCounter();
        });
      } else {
        _done = true;
        _sub?.cancel();
        widget.audio.play(Sfx.success, volume: 0.6);
        setState(() => _status = 'Workout complete! Astronauts on the ISS train about 2 hours every day.');
        Timer(const Duration(milliseconds: 1400), () {
          if (mounted) widget.onDone(const GameResult(mistakes: 0));
        });
      }
    }
  }

  void _toggleMotion() {
    if (_motion) {
      _sub?.cancel();
      _sub = null;
      setState(() => _motion = false);
      return;
    }
    try {
      _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) {
          if (_counter.sample(e.x, e.y, e.z, DateTime.now().millisecondsSinceEpoch)) _rep();
        },
        onError: (Object _) {
          if (mounted) setState(() => _motion = false);
        },
        cancelOnError: true,
      );
      setState(() {
        _motion = true;
        _status = 'Hold the phone firmly with both hands and move. Each move counts.';
      });
    } catch (_) {
      setState(() => _status = 'No motion sensor here: tap the button for each one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return GameFrame(
      spec: s,
      mistakes: 0,
      status: _status ?? 'Do each move $_target times. Tap the big button after each one, or switch on motion counting.',
      statusColor: C.cyan,
      scroll: false,
      footer: Row(children: [
        Expanded(child: HudButton(label: _motion ? 'MOTION ON' : 'COUNT WITH MOTION', icon: Icons.sensors_rounded, filled: _motion, onTap: _done ? null : _toggleMotion)),
      ]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _list.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i < _exercise || _done ? C.cyan.withValues(alpha: 0.25) : (i == _exercise ? C.sapphire : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: GameText(_list[i], style: T.label.copyWith(color: C.frozen, fontSize: 10, letterSpacing: 0.5)),
            ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _beat,
              builder: (context, _) {
                final k = 0.5 + 0.5 * math.sin(_beat.value * math.pi * 2);
                return Pressable(
                  onTap: _motion || _done ? null : _rep,
                  scale: 0.92,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.sapphire.withValues(alpha: 0.18 + 0.1 * k),
                      border: Border.all(color: C.cyan.withValues(alpha: 0.5 + 0.4 * k), width: 3),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                        width: 70,
                        height: 90,
                        child: CustomPaint(
                          painter: _NovaExercise(t: _beat.value, move: _exercise),
                        ),
                      ),
                      GameText('${math.min(_reps, _target)} / $_target', style: T.mono.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
                      GameText(_done ? 'DONE' : _list[_exercise].toUpperCase(), style: T.label.copyWith(fontSize: 10)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _NovaExercise extends CustomPainter {
  final double t;
  final int move;
  _NovaExercise({required this.t, required this.move});

  @override
  void paint(Canvas c, Size size) {
    c.translate(size.width / 2, size.height);
    final s = size.height / 170;
    c.scale(s, s);
    final k = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final action = switch (move % 3) { 0 => NovaAction.kneel, 1 => NovaAction.cheer, _ => NovaAction.wave };
    paintNova(c, NovaPose(t: t * 4, action: k > 0.5 ? action : NovaAction.idle, mood: NovaMood.happy, visorUp: true));
  }

  @override
  bool shouldRepaint(covariant _NovaExercise old) => old.t != t || old.move != move;
}

// =================================================================== DRAW

class DrawGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const DrawGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<DrawGame> createState() => _DrawGameState();
}

class _DrawGameState extends State<DrawGame> with SingleTickerProviderStateMixin {
  int _next = 0;
  int _mistakes = 0;
  int? _wrong;
  bool _done = false;
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  List<Offset> get _dots {
    final p = widget.spec.points;
    return [for (var i = 0; i + 1 < p.length; i += 2) Offset(p[i], p[i + 1])];
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _tapAt(Offset local, Size size) {
    if (_done) return;
    final dots = _dots;
    int? hit;
    var best = 34.0;
    for (var i = 0; i < dots.length; i++) {
      final d = (Offset(dots[i].dx * size.width, dots[i].dy * size.height) - local).distance;
      if (d < best) {
        best = d;
        hit = i;
      }
    }
    if (hit == null) return;
    if (hit == _next) {
      widget.audio.tap();
      setState(() {
        _next++;
        _wrong = null;
      });
      if (_next >= dots.length) {
        _done = true;
        widget.audio.play(Sfx.success, volume: 0.6);
        Timer(const Duration(milliseconds: 1400), () {
          if (mounted) widget.onDone(GameResult(mistakes: _mistakes));
        });
      }
    } else if (hit >= _next) {
      widget.audio.play(Sfx.fail, volume: 0.4);
      setState(() {
        _mistakes++;
        _wrong = hit;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final dots = _dots;
    final name = s.items.isEmpty ? 'the picture' : s.items.first;
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _done ? 'You drew $name! Sending it home...' : (_wrong != null ? 'Find dot ${_next + 1} next.' : 'Tap dot ${_next + 1}.'),
      statusColor: _done ? C.green : (_wrong != null ? C.amber : C.cyan),
      scroll: false,
      child: LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          onTapDown: (d) => _tapAt(d.localPosition, size),
          child: Container(
            decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, _) => CustomPaint(size: size, painter: _DotsPainter(dots: dots, next: _next, wrong: _wrong, done: _done, glow: _glow.value)),
            ),
          ),
        );
      }),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final List<Offset> dots;
  final int next;
  final int? wrong;
  final bool done;
  final double glow;
  _DotsPainter({required this.dots, required this.next, this.wrong, required this.done, required this.glow});

  @override
  void paint(Canvas c, Size size) {
    Offset p(int i) => Offset(dots[i].dx * size.width, dots[i].dy * size.height);
    final line = Paint()
      ..color = C.cyan
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (done && dots.length > 2) {
      final path = Path()..moveTo(p(0).dx, p(0).dy);
      for (var i = 1; i < dots.length; i++) {
        path.lineTo(p(i).dx, p(i).dy);
      }
      c.drawPath(
          path,
          Paint()
            ..color = C.cyan.withValues(alpha: 0.25 + 0.2 * math.sin(glow * math.pi * 2))
            ..strokeWidth = 14
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    for (var i = 1; i < next && i < dots.length; i++) {
      c.drawLine(p(i - 1), p(i), line);
    }
    for (var i = 0; i < dots.length; i++) {
      final done0 = i < next;
      final isNext = i == next;
      final col = i == wrong ? C.red : (done0 ? C.cyan : (isNext ? C.frozen : C.dim));
      c.drawCircle(p(i), isNext ? 13 + 3 * math.sin(glow * math.pi * 4) : 11, Paint()..color = col.withValues(alpha: done0 ? 1 : 0.9));
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: 11, color: done0 || isNext ? C.ink : C.bg)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, p(i) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => true;
}

// =================================================================== SIM

class SimGame extends StatefulWidget {
  final GameSpec spec;
  final GameDone onDone;
  final Audio audio;
  const SimGame({super.key, required this.spec, required this.onDone, required this.audio});

  @override
  State<SimGame> createState() => _SimGameState();
}

class _SimGameState extends State<SimGame> {
  late final SimModel? _m = simModel(widget.spec.sim);
  late final List<double> _v = _m?.start ?? const [];
  int _mistakes = 0;
  bool _done = false;
  bool _showFormula = false;
  String? _status;

  void _run() {
    final m = _m;
    if (m == null || _done) return;
    final bad = m.compute(_v).where((o) => o.ok == false).toList();
    if (bad.isEmpty) {
      _done = true;
      widget.audio.play(Sfx.success, volume: 0.6);
      setState(() => _status = 'Every number is in the safe range. Design approved!');
      Timer(const Duration(milliseconds: 1000), () {
        if (mounted) widget.onDone(GameResult(mistakes: _mistakes, data: {for (var i = 0; i < _v.length; i++) 's$i': _v[i]}));
      });
    } else {
      widget.audio.play(Sfx.fail, volume: 0.5);
      setState(() {
        _mistakes = math.min(3, _mistakes + 1);
        _status = 'Not safe yet: ${bad.map((o) => '${o.label} must be ${o.need}').join('; ')}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final s = widget.spec;
    if (m == null) {
      return GameFrame(spec: s, mistakes: 0, footer: confirmButton('Continue', () => widget.onDone(const GameResult(mistakes: 0))), child: const SizedBox.shrink());
    }
    final gc = GameContext.of(context);
    final engineer = gc?.mode == AgeMode.engineer;
    final outs = m.compute(_v);
    return GameFrame(
      spec: s,
      mistakes: _mistakes,
      status: _status,
      statusColor: _done ? C.green : C.amber,
      scroll: false,
      footer: confirmButton('Run the numbers', _done ? null : _run, icon: Icons.calculate_rounded),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GameText(m.title.toUpperCase(), style: T.label),
        const SizedBox(height: 8),
        // twist the dials; the needles show at once if the design is safe
        Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 4, runSpacing: 10, children: [
          for (var i = 0; i < m.sliders.length; i++)
            SizedBox(
              width: 132,
              child: Knob(
                value: _v[i].clamp(m.sliders[i].min, m.sliders[i].max).toDouble(),
                min: m.sliders[i].min,
                max: m.sliders[i].max,
                step: m.sliders[i].step,
                size: 112,
                label: m.sliders[i].label,
                text: '${_fmt(_v[i], m.sliders[i].step)} ${m.sliders[i].unit}',
                color: const [C.cyan, C.violet, Color(0xFFFFC857), C.green][i % 4],
                onClick: widget.audio.typeClick,
                onChanged: _done ? null : (x) => setState(() => _v[i] = x),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          child: Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 8, runSpacing: 10, children: [
            for (final o in outs) Gauge(label: o.label, text: '${o.text} ${o.unit}', ok: o.ok),
          ]),
        ),
        const SizedBox(height: 8),
        if (engineer || _showFormula)
          Container(
            padding: const EdgeInsets.all(12),
            decoration:
                BoxDecoration(color: C.sapphire.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.sapphire.withValues(alpha: 0.4))),
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'HOW ENGINEERS CALCULATE IT  ', style: T.label.copyWith(color: C.violet, fontSize: 10)),
                  TextSpan(text: m.formula),
                ]),
                style: T.bodySmall.copyWith(color: C.text)),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showFormula = true),
              icon: const Icon(Icons.functions_rounded, size: 18),
              label: const GameText('Show the formula'),
            ),
          ),
      ]),
      ),
    );
  }

  static String _fmt(double v, double step) => step >= 1 ? v.round().toString() : v.toStringAsFixed(step >= 0.1 ? 1 : 2);
}
