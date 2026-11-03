/// The home screen's living Moon: Nova walks around the base with the same
/// low-gravity physics as the game, Pip follows her, dust flies from her
/// boots and the light matches your next mission.
///
/// Touch it: tap the ground and Nova walks there, tap Nova and she jumps,
/// tap Earth and it spins (with a fact), tap the sky for a shooting star,
/// drag sideways to look around.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/audio.dart';
import '../world/characters.dart';
import '../world/mission_theme.dart';
import '../world/world_art.dart';
import '../world/world_model.dart';

class HomeScene extends StatefulWidget {
  final MissionTheme theme;
  final Audio? audio;
  final bool reducedMotion;
  const HomeScene({super.key, required this.theme, this.audio, this.reducedMotion = false});

  @override
  State<HomeScene> createState() => _HomeSceneState();
}

class _Grain {
  double x, y, vx, vy, life;
  final double max, size;
  _Grain(this.x, this.y, this.vx, this.vy, this.max, this.size) : life = max;
}

class _HomeSceneState extends State<HomeScene> with SingleTickerProviderStateMixin {
  // the scene is 30 m wide around the base; Nova uses the real world model
  static const _left = 52.0, _right = 84.0;
  final WorldModel _w = WorldModel(novaX: 62);
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _t = 0;
  double _cam = 66;
  double _pan = 0; // extra look-around from dragging
  double _wander = 2.5;
  double _earthSpin = 0;
  double _earthBoost = 0;
  final _rnd = math.Random(7);
  final List<_Grain> _dust = [];
  final List<(double, int)> _prints = [];
  final List<(Offset, double)> _stars = []; // shooting stars: start, born
  final List<(double, double)> _rings = []; // tap rings: world x, born
  int _seenSteps = 0;
  String? _bubble;
  double _bubbleLeft = 0;
  Offset _pip = const Offset(60, -110);
  int _facts = 0;

  static const _earthFacts = [
    'That\'s home! Earth is 384,400 km away.',
    'Radio to Earth takes 1.3 seconds.',
    'From here, Earth never sets!',
    'Earth looks 4 times bigger than the Moon does from Earth.',
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (!widget.reducedMotion) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  double get ppm => _size.width / 13;
  Size _size = const Size(390, 300);
  double get groundY => _size.height * 0.8;

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60;
    _t += dt;
    final events = _w.update(dt);

    // when she has nothing to do, Nova wanders: to the panels, to look at Earth, back home
    if (!_w.walking && _w.walkX == null && !_w.airborne) {
      _wander -= dt;
      if (_wander <= 0) {
        _wander = 3 + _rnd.nextDouble() * 4;
        final x = _left + 3 + _rnd.nextDouble() * (_right - _left - 6);
        _w.walkToX(x);
      }
    }
    _w.novaX = _w.novaX.clamp(_left + 1, _right - 1).toDouble();

    for (final e in events) {
      if (e.type == 'land') widget.audio?.footstep(hard: true);
    }
    if (_w.steps != _seenSteps) {
      _seenSteps = _w.steps;
      if (!_w.airborne) {
        _prints.add((_w.novaX + _w.facing * 0.1, _w.facing));
        if (_prints.length > 40) _prints.removeAt(0);
        for (var k = 0; k < 4; k++) {
          _dust
              .add(_Grain(_w.novaX + (_rnd.nextDouble() - 0.5) * 0.3, 0, -_w.facing * (0.2 + _rnd.nextDouble() * 0.5), -(20 + _rnd.nextDouble() * 30), 2.6, 1 + _rnd.nextDouble()));
        }
      }
    }
    for (final g in _dust) {
      g.vy += 45 * dt; // Moon gravity in screen units
      g.x += g.vx * dt;
      g.y += g.vy * dt;
      g.life -= dt;
    }
    _dust.removeWhere((g) => g.life <= 0 || (g.y > 2 && g.vy > 0));

    // the camera follows Nova softly, plus where the player dragged
    final want = (_w.novaX + _w.facing * 1.2 + _pan).clamp(_left + 5, _right - 5).toDouble();
    _cam += (want - _cam) * (1 - math.exp(-dt * 1.6));
    _pan *= math.exp(-dt * 0.25);

    // Pip floats behind her shoulder
    final px = _w.novaX - _w.facing * 1.2, py = -110 + math.sin(_t * 2.1) * 4 - _w.novaY * 40;
    _pip = Offset(_pip.dx + (px - _pip.dx) * (1 - math.exp(-dt * 2.4)), _pip.dy + (py - _pip.dy) * (1 - math.exp(-dt * 3)));

    _earthBoost = math.max(0, _earthBoost - dt * 0.8);
    _earthSpin += dt * (1 + _earthBoost * 40);
    if (_bubbleLeft > 0) {
      _bubbleLeft -= dt;
      if (_bubbleLeft <= 0) _bubble = null;
    }
    _stars.removeWhere((s) => _t - s.$2 > 1.2);
    _rings.removeWhere((r) => _t - r.$2 > 0.6);
    // now and then a shooting star on its own
    if (_rnd.nextDouble() < dt * 0.08) _stars.add((Offset(_size.width * (0.2 + _rnd.nextDouble() * 0.7), _size.height * (0.05 + _rnd.nextDouble() * 0.25)), _t));
    _repaint.value++;
  }

  void _say(String s) {
    _bubble = s;
    _bubbleLeft = 3.2;
  }

  double _sx(double wx) => (wx - _cam) * ppm + _size.width / 2;
  Offset get _earthC => Offset(_size.width * 0.78 - (_cam - 66) * ppm * 0.03, _size.height * 0.24);

  void _tap(Offset p) {
    final u = _size.width / 390;
    final nova = Offset(_sx(_w.novaX), groundY - 60 * u - _w.novaY * ppm);
    if ((p - _earthC).distance < 46 * u) {
      _earthBoost = 1;
      _say(_earthFacts[_facts++ % _earthFacts.length]);
      widget.audio?.play(Sfx.boop, volume: 0.3);
      return;
    }
    if ((p - nova).distance < 55 * u) {
      if (_w.jump()) {
        widget.audio?.play(Sfx.boop, volume: 0.35);
        widget.audio?.haptic(light: true);
        _say(_facts.isEven ? 'Wheee! Moon jumps are 6 times higher!' : 'I float for 2.5 seconds up here!');
        _facts++;
      }
      return;
    }
    if (p.dy < groundY - 90 * u) {
      _stars.add((p, _t));
      widget.audio?.play(Sfx.sparkle, volume: 0.25);
      return;
    }
    final x = (_cam + (p.dx - _size.width / 2) / ppm).clamp(_left + 1, _right - 1).toDouble();
    _rings.add((x, _t));
    _w.walkToX(x);
    _wander = 4;
    widget.audio?.play(Sfx.boop, volume: 0.15);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _tap(d.localPosition),
        onHorizontalDragUpdate: (d) => _pan = (_pan - d.delta.dx / ppm).clamp(-8.0, 8.0),
        child: RepaintBoundary(
          child: CustomPaint(size: _size, painter: _HomePainter(this, _repaint)),
        ),
      );
    });
  }
}

class _HomePainter extends CustomPainter {
  final _HomeSceneState s;
  _HomePainter(this.s, Listenable repaint) : super(repaint: repaint);

  static final _starsBg = List.generate(110, (i) {
    final r = math.Random(i * 13 + 3);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });
  static final _rocks = List.generate(26, (i) {
    final r = math.Random(i * 29 + 1);
    return (50 + r.nextDouble() * 38, r.nextDouble(), r.nextDouble());
  });
  static String? _key;
  static late Paint _sky, _ground, _glow;
  static late Path _far, _mid;

  void _build(Size size, MissionTheme th, double u) {
    final key = '${th.id}|$size';
    if (key == _key) return;
    _key = key;
    final rect = Offset.zero & size;
    _sky = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [for (var i = 0; i < 24; i++) th.skyAt(i / 23)]).createShader(rect);
    final gy = size.height * 0.8;
    final g = Rect.fromLTWH(0, gy - 8 * u, size.width, size.height - gy + 8 * u);
    _ground = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [th.groundTop, th.groundMid]).createShader(g);
    _glow = Paint()
      ..shader = RadialGradient(colors: [
        for (var i = 0; i < 12; i++) th.sun.withValues(alpha: i == 11 ? 0 : 0.32 * th.sunGlow.clamp(0.0, 1.3) * math.exp(-math.pow(i / 11, 2) * 4.5)),
      ]).createShader(Rect.fromCircle(center: Offset.zero, radius: 230 * u));
    Path ridge(int seed, double base, double h, double period) {
      final r = math.Random(seed);
      final p = Path()..moveTo(0, base + 40 * u);
      const n = 10;
      for (var i = 0; i <= n; i++) {
        final hh = i == 0 || i == n ? 0.4 : 0.25 + r.nextDouble() * 0.75;
        p.lineTo(i / n * period, base - h * hh);
      }
      p
        ..lineTo(period, base + 40 * u)
        ..close();
      return p;
    }

    _far = ridge(3, gy - 26 * u, 110 * u, size.width * 1.6);
    _mid = ridge(8, gy - 6 * u, 60 * u, size.width * 1.6);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final th = s.widget.theme;
    final u = size.width / 390;
    final t = s._t;
    final ppm = s.ppm;
    final gy = size.height * 0.8;
    _build(size, th, u);
    double sx(double wx) => s._sx(wx);
    final cam = s._cam;

    canvas.drawRect(Offset.zero & size, _sky);
    // stars twinkle and drift with the view
    final sp = Paint();
    for (var i = 0; i < _starsBg.length; i++) {
      final (a, b, c) = _starsBg[i];
      final x = (a * size.width * 1.2 - cam * ppm * 0.01) % (size.width * 1.2);
      sp.color = Colors.white.withValues(alpha: 0.35 + 0.45 * (0.5 + 0.5 * math.sin(t * (0.7 + c) + i)));
      canvas.drawCircle(Offset(x, b * gy * 0.85), (i % 9 == 0 ? 1.3 : 0.7) * u, sp);
    }
    for (final (p0, born) in s._stars) {
      final k = ((t - born) / 1.2).clamp(0.0, 1.0);
      final head = p0 + Offset(-160 * u * k, 70 * u * k);
      final tail = head + Offset(50 * u, -22 * u) * (1 - k * 0.5);
      canvas.drawLine(
          head,
          tail,
          Paint()
            ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 1 - k), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromPoints(head, tail))
            ..strokeWidth = 2 * u
            ..strokeCap = StrokeCap.round);
    }
    // the low Sun
    final sunC = Offset(-10 * u - (cam - 66) * ppm * 0.01, gy - 70 * u);
    if (th.sunGlow > 0) {
      canvas.save();
      canvas.translate(sunC.dx, sunC.dy);
      canvas.drawCircle(Offset.zero, 230 * u, _glow);
      canvas.restore();
      canvas.drawCircle(sunC, 18 * u, Paint()..color = Color.lerp(th.sun, Colors.white, 0.6)!);
    }
    _earth(canvas, s._earthC, 30 * u, s._earthSpin);

    // hills: two layers at different speeds
    void layer(Path p, double speed, Color col) {
      final period = size.width * 1.6;
      final off = -((cam * ppm * speed) % period);
      for (var k = 0; k < 2; k++) {
        canvas.save();
        canvas.translate(off + k * period, 0);
        canvas.drawPath(p, Paint()..color = col);
        canvas.restore();
      }
    }

    layer(_far, 0.1, th.ridgeDark[0]);
    layer(_mid, 0.3, Color.lerp(th.ridgeDark[1], th.ridgeLit[1], 0.5)!);
    canvas.drawRect(Rect.fromLTWH(0, gy - 8 * u, size.width, size.height - gy + 8 * u), _ground);

    // stones and craters
    for (final (x, d, k) in _rocks) {
      final px = sx(x);
      if (px < -40 || px > size.width + 40) continue;
      final y = gy + (2 + d * 30) * u;
      final w = (8 + d * 26) * u * (0.6 + k);
      canvas.drawOval(Rect.fromCenter(center: Offset(px, y), width: w, height: w * 0.22), Paint()..color = th.groundLow.withValues(alpha: 0.45));
      canvas.drawArc(
          Rect.fromCenter(center: Offset(px, y), width: w, height: w * 0.22),
          math.pi * 1.05,
          math.pi * 0.9,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * u);
    }

    // the base: antenna, habitat, lander, panels
    void prop(double wx, double dy, double scale, void Function() draw) {
      final px = sx(wx);
      if (px < -200 * u || px > size.width + 200 * u) return;
      canvas.save();
      canvas.translate(px, gy + dy * u);
      canvas.scale(u * scale);
      draw();
      canvas.restore();
    }

    prop(55, -2, 0.75, () => paintLander(canvas, t));
    prop(70, -2, 0.85, () => paintHabitat(canvas, t, bags: 6, sensors: true));
    prop(78, -2, 0.9, () => paintAntenna(canvas, t));
    prop(82.5, -2, 0.8, () => paintPanels(canvas, t));

    // footprints and tap rings
    final fp = Paint()..color = Colors.black.withValues(alpha: 0.2);
    for (final (x, f) in s._prints) {
      canvas.drawOval(Rect.fromCenter(center: Offset(sx(x) + f * 3 * u, gy + 8 * u), width: 8 * u, height: 2.6 * u), fp);
    }
    for (final (x, born) in s._rings) {
      final k = ((t - born) / 0.6).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(sx(x), gy + 8 * u), width: (12 + 44 * k) * u, height: (4 + 10 * k) * u),
        Paint()
          ..color = th.accent.withValues(alpha: 0.8 * (1 - k))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * u * (1 - k),
      );
    }

    // Nova with her shadow (it shrinks as she rises)
    final w = s._w;
    final nx = sx(w.novaX);
    final lift = w.novaY * ppm;
    final far = (1 - w.novaY / 1.6).clamp(0.35, 1.0).toDouble();
    canvas.drawOval(Rect.fromCenter(center: Offset(nx + 30 * u, gy + 8 * u), width: 80 * u * far, height: 5 * u), Paint()..color = Colors.black.withValues(alpha: 0.22 * far));
    canvas.save();
    canvas.translate(nx, gy + 8 * u - lift);
    final sc = 1.05 * u;
    final box = Rect.fromLTWH(-60 * sc, -125 * sc, 120 * sc, 135 * sc);
    canvas.saveLayer(box, Paint());
    canvas.save();
    canvas.scale(w.facing * sc, sc);
    paintNova(
      canvas,
      NovaPose(
        action: w.walking || w.airborne ? NovaAction.walk : (s._bubble != null ? NovaAction.wave : NovaAction.idle),
        phase: w.walkPhase,
        t: t,
        air: w.airborne,
        rise: w.vy,
      ),
    );
    canvas.restore();
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(colors: [th.rim, const Color(0x00000000), th.shade], stops: const [0.3, 0.5, 0.75]).createShader(box),
    );
    canvas.restore();
    canvas.restore();

    // dust from her boots
    final dp = Paint();
    for (final g in s._dust) {
      dp.color = th.groundTop.withValues(alpha: (g.life / g.max).clamp(0.0, 1.0) * 0.8);
      canvas.drawCircle(Offset(sx(g.x), gy + 8 * u + g.y * u), g.size * u, dp);
    }

    // Pip
    canvas.save();
    canvas.translate(sx(s._pip.dx), gy + s._pip.dy * u);
    canvas.scale(1.0 * u);
    paintPipGlow(canvas, t);
    paintPip(canvas, t, eye: s._bubble != null ? PipEye.happy : PipEye.normal, tilt: (w.velocity * 0.05).clamp(-0.25, 0.25));
    canvas.restore();

    // a speech bubble
    final say = s._bubble;
    if (say != null) {
      final tp = TextPainter(
        text: TextSpan(text: say, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5 * u, color: const Color(0xFF07240F))),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 200 * u);
      final bw = tp.width + 20 * u, bh = tp.height + 14 * u;
      final left = (nx - bw / 2).clamp(8 * u, size.width - bw - 8 * u).toDouble();
      final top = gy - 150 * u - lift - bh;
      final a = (s._bubbleLeft / 0.3).clamp(0.0, 1.0);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, bw, bh), Radius.circular(12 * u));
      canvas.drawRRect(r, Paint()..color = const Color(0xFFD9FCED).withValues(alpha: a));
      canvas.drawPath(
        Path()
          ..moveTo(nx - 5 * u, top + bh - 1)
          ..lineTo(nx + 5 * u, top + bh - 1)
          ..lineTo(nx, top + bh + 8 * u)
          ..close(),
        Paint()..color = const Color(0xFFD9FCED).withValues(alpha: a),
      );
      if (a > 0.5) tp.paint(canvas, Offset(left + 10 * u, top + 7 * u));
    }

    // fade into the page below, so the scene has no hard bottom edge
    final fade = Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14 + 1);
    canvas.drawRect(
        fade, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0004120A), Color(0xFF04120A)]).createShader(fade));
  }

  void _earth(Canvas canvas, Offset c, double r, double spin) {
    canvas.drawCircle(
        c,
        r * 1.4,
        Paint()
          ..shader = RadialGradient(colors: [const Color(0xFF7FC8FF).withValues(alpha: 0.3), const Color(0x007FC8FF)]).createShader(Rect.fromCircle(center: c, radius: r * 1.4)));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c, r, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFF5CBCFF), Color(0xFF1F63C4), Color(0xFF0E3A86)]).createShader(rect));
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final drift = (spin * 4) % (r * 4);
    final land = Paint()..color = const Color(0xFF4F9F55);
    for (var k = -1; k <= 1; k++) {
      final o = c + Offset(-r * 2 + drift + k * r * 4, 0);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - r * 0.5, o.dy - r * 0.4)
          ..cubicTo(o.dx - r * 0.1, o.dy - r * 0.75, o.dx + r * 0.4, o.dy - r * 0.3, o.dx + r * 0.1, o.dy + r * 0.05)
          ..cubicTo(o.dx - r * 0.1, o.dy + r * 0.5, o.dx - r * 0.5, o.dy + r * 0.1, o.dx - r * 0.5, o.dy - r * 0.4),
        land,
      );
      canvas.drawOval(Rect.fromCenter(center: o + Offset(r * 1.3, r * 0.35), width: r * 0.7, height: r * 0.45), Paint()..color = const Color(0xFF8C7E52));
    }
    canvas.drawArc(
        Rect.fromCircle(center: c + Offset(0, -r * 0.2), radius: r * 0.9),
        math.pi * 1.15,
        0.9,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..strokeCap = StrokeCap.round);
    // the night side
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(colors: [Color(0x00000000), Color(0x00000000), Color(0xB0000814)], stops: [0, 0.5, 0.85]).createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomePainter old) => false;
}
