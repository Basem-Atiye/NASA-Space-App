/// The Moon's surface in side view: sky, Earth, the low Sun, three depth
/// layers that slide at different speeds, everything on the ground, Nova,
/// Pip and the particles (dust, sparks, venting air, storm protons).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/theme.dart';
import 'characters.dart';
import 'mission_theme.dart';
import 'world_art.dart';
import 'world_model.dart';

// How big the big things are drawn, relative to Nova.
const _landerScale = 1.6;
const _habScale = 1.4;
const _panelScale = 1.45;

/// Everything the story wants drawn. Built by the story controller.
class WorldLook {
  final int task;
  final bool showLander;
  final double landerTilt;
  final bool landerBay;
  final bool landerRepaired;
  final bool landerSparking;
  final bool landerVenting;
  final double habitat; // 0 none, 0..1 inflating
  final int bags;
  final bool sensors;
  final bool sensorAlarm;
  final bool habitatVent;
  final bool patch;
  final bool thermalFault;
  final bool battery;
  final double batteryLevel;
  final bool batteryFault;
  final bool cable;
  final bool cableBroken;
  final bool crate;
  final bool panels;
  final double panelDust;
  final bool antenna;
  final bool sites;
  final Set<String> visitedSites;
  final Set<String> pickups;
  final String? goal;
  final bool arrows;
  final double dust;
  final bool stormWarning;
  final bool alarm;
  final bool novaHidden;

  // 2.0 props
  final bool rover;
  final bool roverLights;
  final double greenhouse; // 0 none, otherwise plant growth 0..1
  final bool greenhouseWilting;
  final bool pad;
  final bool rocket;
  final bool drill;
  final bool drillRunning;
  final bool rim;
  final bool crater;

  /// Lunar night: no Sun, the base lights are on.
  final bool night;

  /// A moonquake: the ground keeps shaking.
  final bool quake;

  /// The mood of this mission: sky, light, what floats in the air, UI accent.
  MissionTheme get theme => themeFor(
        task: task,
        night: night,
        storm: stormWarning || dust > 0.45,
        quake: quake,
        alarm: alarm || landerVenting || habitatVent,
        launch: rocket,
        ice: drill || crater,
        garden: greenhouse > 0,
      );

  const WorldLook({
    this.task = 1,
    this.showLander = true,
    this.landerTilt = 0,
    this.landerBay = false,
    this.landerRepaired = false,
    this.landerSparking = false,
    this.landerVenting = false,
    this.habitat = 0,
    this.bags = 0,
    this.sensors = false,
    this.sensorAlarm = false,
    this.habitatVent = false,
    this.patch = false,
    this.thermalFault = false,
    this.battery = false,
    this.batteryLevel = 0.5,
    this.batteryFault = false,
    this.cable = false,
    this.cableBroken = false,
    this.crate = false,
    this.panels = false,
    this.panelDust = 0,
    this.antenna = false,
    this.sites = false,
    this.visitedSites = const {},
    this.pickups = const {},
    this.goal,
    this.arrows = true,
    this.dust = 0.05,
    this.stormWarning = false,
    this.alarm = false,
    this.novaHidden = false,
    this.rover = false,
    this.roverLights = false,
    this.greenhouse = 0,
    this.greenhouseWilting = false,
    this.pad = false,
    this.rocket = false,
    this.drill = false,
    this.drillRunning = false,
    this.rim = false,
    this.crater = false,
    this.night = false,
    this.quake = false,
  });

  /// Everything currently standing in the world, for scanning and tapping.
  Set<String> get present => {
        if (showLander) 'lander',
        if (habitat > 0) 'habitat',
        if (battery) 'battery',
        if (cable) 'cable',
        if (crate) 'crate',
        if (panels) 'panels',
        if (antenna) 'antenna',
        if (sites) ...['site:A', 'site:B', 'site:C'],
        if (rover) 'rover',
        if (greenhouse > 0) 'greenhouse',
        if (pad) 'pad',
        if (drill) 'drill',
        if (rim) 'site:A',
        if (crater) 'site:C',
        for (final p in pickups) 'pickup:$p',
      };
}

/// What the view needs from whoever drives it.
abstract class SurfaceDriver {
  WorldModel get world;
  WorldLook get look;
  NovaPose novaPose(double t);
  PipEye get pipEye;

  /// Object Pip is scanning right now (beam), if any.
  String? get pipScan;

  /// Called every frame with the time step (seconds).
  void frame(double dt);

  /// The player tapped the ground at world position [x] (metres).
  void tapWorld(double x);

  /// The player tapped the sky: 'earth', 'sun' or 'sky'.
  void tapSky(String what);

  /// Impact flashes to draw (world x), bumped by the driver.
  int get meteorCount;

  /// A short line Nova says out loud (speech bubble), if any.
  String? get bubble;
}

class _P {
  double x; // metres
  double y; // design units above (-) / below (+) the ground line
  double vx; // metres/s
  double vy; // units/s
  double life;
  final double max;
  final Color color;
  final double size;
  final int kind; // 0 dust, 1 spark, 2 gas, 3 ember
  _P(this.x, this.y, this.vx, this.vy, this.max, this.color, this.size, this.kind) : life = max;
}

class SurfaceView extends StatefulWidget {
  final SurfaceDriver driver;
  final bool paused;
  final bool reducedMotion;
  const SurfaceView({super.key, required this.driver, this.paused = false, this.reducedMotion = false});

  @override
  State<SurfaceView> createState() => SurfaceViewState();
}

class SurfaceViewState extends State<SurfaceView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  double? _cam;
  Offset _pip = const Offset(0, -110);
  final List<_P> _ps = [];
  final List<(double, int)> _prints = [];
  int _seenSteps = 0;
  int _seenLandings = 0;
  int _seenMeteors = 0;
  double _impact = 0; // seconds since the last meteor impact
  final _rnd = math.Random(42);
  final _repaint = ValueNotifier<int>(0);
  double _shake = 0;

  /// The theme on screen eases to the story's theme over about 1.5 s.
  MissionTheme _theme = themeDawn;
  MissionTheme _themeFrom = themeDawn;
  MissionTheme? _themeTo;
  double _themeK = 1;
  MissionTheme get theme => _theme;

  double ppm(Size s) => s.width / 14;

  @override
  void initState() {
    super.initState();
    _seenMeteors = widget.driver.meteorCount;
    _impact = 99;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// A short screen shake (crash, impact).
  void shake([double strength = 1]) {
    if (!widget.reducedMotion) _shake = math.max(_shake, 0.5 * strength);
  }

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60;
    if (widget.paused) return;
    _t += dt;
    final d = widget.driver;
    d.frame(dt);
    final w = d.world;
    final look = d.look;
    final want0 = look.theme;
    if (_themeTo == null) {
      _theme = _themeFrom = want0;
      _themeTo = want0;
    } else if (want0.id != _themeTo!.id) {
      _themeFrom = _theme;
      _themeTo = want0;
      _themeK = 0;
    }
    if (_themeK < 1) {
      _themeK = math.min(1, _themeK + dt / 1.5);
      _theme = _themeK >= 1 ? _themeTo! : lerpTheme(_themeFrom, _themeTo!, _themeK);
    }

    // camera eases after Nova, looking further ahead the faster she goes
    final want = w.novaX + w.facing * (1.4 + w.velocity.abs() * 0.28) + w.velocity * 0.35;
    _cam ??= want;
    _cam = _cam! + (want - _cam!) * (1 - math.exp(-dt * 2.2));

    // Pip floats behind Nova's shoulder, or flies over to scan something
    final scan = d.pipScan;
    final pipWantX = scan != null ? WorldModel.xOf(scan) - 0.9 : w.novaX - w.facing * 1.25;
    final pipWantY = scan != null ? -96.0 : -112.0 + math.sin(_t * 2.1) * 4;
    _pip = Offset(_pip.dx + (pipWantX - _pip.dx) * (1 - math.exp(-dt * 2.6)), _pip.dy + (pipWantY - _pip.dy) * (1 - math.exp(-dt * 3)));
    if (_pip.dx == 0) _pip = Offset(pipWantX, pipWantY);

    // gear that just disappeared was picked up: a sparkle where it was
    final nowPickups = d.look.pickups;
    final gone = [
      for (final p in _lastPickups)
        if (!nowPickups.contains(p)) p,
    ];
    // one at a time means Nova picked it up (many at once is just a new level)
    if (gone.length == 1) _burst(WorldModel.xOf(gone.first), 4, 1, count: 14);
    _lastPickups = {...nowPickups};
    _tapRings.removeWhere((r) => _t - r.$2 > 0.6);

    // footsteps: a boot print and a few grains of dust on clean Moon arcs
    if (w.steps != _seenSteps) {
      final n = w.steps - _seenSteps;
      _seenSteps = w.steps;
      final landed = w.landings != _seenLandings;
      _seenLandings = w.landings;
      final hard = landed ? (w.lastLandSpeed / WorldModel.boundSpeed).clamp(0.8, 2.2).toDouble() : 0.6;
      if (n > 0 && !w.airborne) {
        _prints.add((w.novaX + w.facing * 0.12, w.facing));
        if (landed) _prints.add((w.novaX - w.facing * 0.18, w.facing));
        while (_prints.length > 160) {
          _prints.removeAt(0);
        }
        final grains = (landed ? 10 : 4) * (widget.reducedMotion ? 0.5 : 1);
        for (var i = 0; i < grains; i++) {
          // no air: every grain flies on its own parabola and lands, no cloud
          final up = (22 + _rnd.nextDouble() * 34) * hard;
          final side = (-w.facing * (0.25 + _rnd.nextDouble() * 0.9) + w.velocity * 0.15) * (0.6 + hard * 0.4);
          _ps.add(_P(w.novaX + (_rnd.nextDouble() - 0.5) * 0.35, 14, side, -up, 3.2, const Color(0xFFD6D0C4), 1.3 + _rnd.nextDouble() * 1.4, 0));
        }
        if (landed && w.sprinting) shake(0.16);
      }
    }
    // sparks and gas
    if (look.landerSparking && _rnd.nextDouble() < dt * 10) _burst(WorldModel.xOf('lander') + 0.4, -46, 1);
    if (look.cableBroken && _rnd.nextDouble() < dt * 12) _burst(WorldModel.xOf('cable'), -6, 1);
    if (look.landerVenting && _rnd.nextDouble() < dt * 18) {
      _ps.add(_P(WorldModel.xOf('lander') - 1.2, -84, -0.6 - _rnd.nextDouble() * 0.8, -6 - _rnd.nextDouble() * 10, 1.3, const Color(0xFFE8F4FF), 3 + _rnd.nextDouble() * 4, 2));
    }
    if (look.habitatVent && look.habitat > 0.5 && _rnd.nextDouble() < dt * 18) {
      _ps.add(_P(WorldModel.xOf('habitat') - 1.2, -86, -0.5 - _rnd.nextDouble() * 0.6, -12 - _rnd.nextDouble() * 10, 1.2, const Color(0xFFE8F4FF), 3 + _rnd.nextDouble() * 4, 2));
    }
    // a dust storm drifts across
    if (look.dust > 0.2 && _rnd.nextDouble() < dt * 60 * look.dust) {
      final x = (_cam ?? 50) - 8 + _rnd.nextDouble() * 16;
      _ps.add(_P(x, -240 + _rnd.nextDouble() * 200, 0.6 + _rnd.nextDouble() * 0.6, 8 + _rnd.nextDouble() * 6, 5, const Color(0xFFCDBFA6), 1.2 + _rnd.nextDouble() * 1.4, 0));
    }
    // moonquake: a steady rumble and dust shaken loose
    if (look.quake) {
      shake(0.45);
      if (_rnd.nextDouble() < dt * 20) {
        final x = (_cam ?? 50) - 7 + _rnd.nextDouble() * 14;
        _ps.add(_P(x, -2, (_rnd.nextDouble() - 0.5) * 1.2, -20 - _rnd.nextDouble() * 20, 1.4, const Color(0xFFCDBFA6), 1.4, 0));
      }
    }
    // meteor impact
    if (d.meteorCount != _seenMeteors) {
      _seenMeteors = d.meteorCount;
      _impact = 0;
      shake(1.2);
      for (var i = 0; i < 26; i++) {
        _burst(WorldModel.xOf('habitat') + 1.6, -70, 1, count: 1);
      }
    }
    _impact += dt;

    for (final p in _ps) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.kind == 0 || p.kind == 1) p.vy += 45 * dt; // 1.62 m/s² × 27.9 design units per metre
      if (p.kind == 2) {
        p.vx *= 1 - dt * 0.6;
        p.vy *= 1 - dt * 0.6;
      }
      if (p.kind == 0 && p.y > 16 && p.vy > 0) p.life = 0;
    }
    _ps.removeWhere((p) => p.life <= 0);
    if (_ps.length > 400) _ps.removeRange(0, _ps.length - 400);
    _shake = math.max(0, _shake - dt);
    _repaint.value++;
  }

  /// Tap feedback rings: (where, when, in the sky). Ground rings store world x.
  final List<(Offset, double, bool)> _tapRings = [];
  Set<String> _lastPickups = {};

  double _ppmFor(Size s) => ppm(s);
  Offset earthCentre(Size size, double cam) => Offset(size.width * 0.76 - (cam - 50) * _ppmFor(size) * 0.02, size.height * 0.74 * 0.36);
  Offset sunCentre(Size size, double cam) => Offset(size.width * 0.02 - (cam - 50) * _ppmFor(size) * 0.004, size.height * 0.74 - 96 * size.width / 390);

  void _burst(double x, double y, int kind, {int count = 6}) {
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 2.4;
      final sp = 30 + _rnd.nextDouble() * 60;
      _ps.add(_P(x, y, math.cos(a) * sp / 28, math.sin(a) * sp, 0.4 + _rnd.nextDouble() * 0.4, _rnd.nextBool() ? const Color(0xFFFFD27A) : const Color(0xFFFFF4C8), 1.4, kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) {
            final cam = _cam ?? widget.driver.world.novaX;
            final pos = e.localPosition;
            final x = cam + (pos.dx - size.width / 2) / ppm(size);
            final groundY = size.height * 0.74;
            if (pos.dy < groundY - 140 * size.width / 390) {
              final u = size.width / 390;
              final earth = earthCentre(size, cam);
              final sun = sunCentre(size, cam);
              final what = (pos - earth).distance < 52 * u ? 'earth' : ((pos - sun).distance < 70 * u ? 'sun' : 'sky');
              _tapRings.add((pos, _t, true));
              widget.driver.tapSky(what);
              return;
            }
            // a little ring and puff where the finger touched the dust
            _tapRings.add((Offset(x, 0), _t, false));
            for (var i = 0; i < 6; i++) {
              final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 1.8;
              final sp = 18 + _rnd.nextDouble() * 22;
              _ps.add(_P(x, 14, math.cos(a) * sp / 40, math.sin(a) * sp, 2.0, const Color(0xFFD6D0C4), 1.1 + _rnd.nextDouble(), 0));
            }
            widget.driver.tapWorld(x);
          },
          child: RepaintBoundary(
            child: CustomPaint(size: size, painter: _SurfacePainter(this, _repaint)),
          ),
        );
      },
    );
  }
}

class _SurfacePainter extends CustomPainter {
  final SurfaceViewState v;
  static final _cache = _PaintCache();
  static final _starPaint = Paint();
  _SurfacePainter(this.v, Listenable repaint) : super(repaint: repaint);

  static final _stars = List.generate(120, (i) {
    final r = math.Random(i * 31 + 7);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final d = v.widget.driver;
    final w = d.world;
    final look = d.look;
    final t = v._t;
    final u = size.width / 390;
    final ppm = v.ppm(size);
    final cam = v._cam ?? w.novaX;
    final groundY = size.height * 0.74;
    double sx(double wx) => (wx - cam) * ppm + size.width / 2;

    canvas.save();
    if (v._shake > 0) {
      final k = v._shake * 9 * u;
      canvas.translate(math.sin(t * 61) * k, math.cos(t * 47) * k * 0.6);
    }

    // ---- sky: one smooth fall from black to a cool horizon, no green bands
    final th = v.theme;
    canvas.drawRect((Offset.zero & size).inflate(12), _cache.sky(th, size));
    final sunC = Offset(size.width * 0.02 - (cam - 50) * ppm * 0.004, groundY - 96 * u);
    if (th.sunGlow > 0) {
      canvas.save();
      canvas.translate(sunC.dx, sunC.dy);
      canvas.drawCircle(Offset.zero, 260 * u, _cache.glow(th, 260 * u));
      canvas.restore();
    }
    final starPaint = _starPaint;
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final x = ((s.$1 * size.width * 1.3 - cam * ppm * 0.01) % (size.width * 1.3));
      final y = s.$2 * groundY * 0.9;
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * (0.8 + s.$3) + i));
      starPaint.color = Colors.white.withValues(alpha: 0.75 * tw * (look.dust > 0.3 ? 0.4 : 1));
      canvas.drawCircle(Offset(x, y), (i % 11 == 0 ? 1.3 : 0.75) * u, starPaint);
    }

    if (th.sunGlow > 0) canvas.drawCircle(sunC, 22 * u, Paint()..color = Color.lerp(th.sun, Colors.white, 0.6)!);
    if (th.ambient == Ambient.aurora) _aurora(canvas, size, groundY, u, t);
    final earthC = Offset(size.width * 0.76 - (cam - 50) * ppm * 0.02, groundY * 0.36);
    _earth(canvas, earthC, 32 * u, t);

    // ---- storm warning: protons streak across the sky
    if (look.stormWarning) {
      final p = Paint()
        ..color = const Color(0xFFB9A8FF).withValues(alpha: 0.55)
        ..strokeWidth = 1.2 * u
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 26; i++) {
        final k = ((t * 0.9 + i * 0.137) % 1);
        final x = size.width * ((i * 0.381) % 1.2) - k * 140 * u;
        final y = k * groundY;
        canvas.drawLine(Offset(x, y), Offset(x - 12 * u, y - 20 * u), p);
      }
    }

    // ---- the far wall of Shackleton crater (slowest), far mountains, mid hills, ground
    _ridge(canvas, size, u, cam * ppm * 0.07, groundY - 34 * u, 150 * u, 3, th.ridgeDark[0], th.ridgeLit[0], 0.2);
    // a soft veil, so the far wall sits back in the distance (a gradient: no costly blur)
    final veil = Rect.fromLTWH(-20, groundY - 150 * u, size.width + 40, 150 * u);
    canvas.drawRect(veil, _cache.veil(th, veil));
    _ridge(canvas, size, u, cam * ppm * 0.18, groundY - 10 * u, 120 * u, 5, th.ridgeDark[1], th.ridgeLit[1], 0.35);
    _ridge(canvas, size, u, cam * ppm * 0.45, groundY - 2 * u, 70 * u, 9, th.ridgeDark[2], th.ridgeLit[2], 0.55);
    final ground = Rect.fromLTWH(-20, groundY - 18 * u, size.width + 40, size.height - groundY + 40 * u);
    canvas.drawRect(ground, _cache.ground(th, ground));
    // a soft horizon line where the ground meets the hills
    canvas.drawRect(Rect.fromLTWH(-20, groundY - 18 * u, size.width + 40, 3 * u), Paint()..color = const Color(0x22000000));

    // craters and rocks scroll with the ground
    _groundDetail(canvas, size, u, cam, ppm, groundY);
    _regolith(canvas, size, u, cam, ppm, groundY);

    // footprints
    final fp = Paint()..color = const Color(0x33000000);
    for (final (x, f) in v._prints) {
      final px = sx(x);
      if (px < -20 || px > size.width + 20) continue;
      canvas.drawOval(Rect.fromCenter(center: Offset(px + f * 3 * u, groundY + 16 * u), width: 9 * u, height: 3 * u), fp);
    }

    // ---- objects, back to front
    void at(double wx, double dy, void Function() draw, {double scale = 1}) {
      final px = sx(wx);
      if (px < -260 * u || px > size.width + 260 * u) return;
      canvas.save();
      canvas.translate(px, groundY + dy * u);
      canvas.scale(u * scale);
      draw();
      canvas.restore();
    }

    if (look.sites) {
      at(WorldModel.xOf('site:A'), 2, () => paintRim(canvas));
      at(WorldModel.xOf('site:C'), 8, () => paintShadowCrater(canvas, t));
      for (final s in ['site:A', 'site:B', 'site:C']) {
        at(WorldModel.xOf(s), s == 'site:A' ? -40 : 4, () => paintSiteFlag(canvas, t, s.substring(5), visited: look.visitedSites.contains(s)));
      }
    }
    if (look.rim && !look.sites) at(WorldModel.xOf('site:A'), 2, () => paintRim(canvas));
    if (look.crater && !look.sites) at(WorldModel.xOf('site:C'), 8, () => paintShadowCrater(canvas, t));
    if (look.pad) at(WorldModel.xOf('pad'), 4, () => paintPad(canvas, t, rocket: look.rocket, lightsOn: look.night || look.rocket), scale: 1.2);
    if (look.drill) at(WorldModel.xOf('drill'), 4, () => paintDrill(canvas, t, running: look.drillRunning), scale: 1.25);
    if (look.greenhouse > 0) at(WorldModel.xOf('greenhouse'), 4, () => paintGreenhouse(canvas, t, growth: look.greenhouse, wilting: look.greenhouseWilting), scale: 1.3);
    if (look.rover) at(WorldModel.xOf('rover'), 4, () => paintRover(canvas, t, lights: look.roverLights || look.night), scale: 1.3);
    if (look.panels) at(WorldModel.xOf('panels'), 2, () => paintPanels(canvas, t, dust: look.panelDust), scale: _panelScale);
    if (look.antenna) at(WorldModel.xOf('antenna'), 2, () => paintAntenna(canvas, t), scale: 1.35);
    if (look.habitat > 0) {
      at(
        WorldModel.xOf('habitat'),
        4,
        () => paintHabitat(
          canvas,
          t,
          inflate: look.habitat,
          bags: look.bags,
          sensors: look.sensors,
          sensorAlarm: look.sensorAlarm,
          patch: look.patch,
          thermalFault: look.thermalFault,
        ),
        scale: _habScale,
      );
    }
    if (look.cable) {
      // from the battery to the habitat's airlock
      final a = WorldModel.xOf('battery'), b = WorldModel.xOf('habitat') - (196 / 2 + 14) * _habScale * u / ppm;
      at(a, 6, () => paintCable(canvas, 0, (b - a) * ppm / u, t, broken: look.cableBroken));
    }
    if (look.battery) at(WorldModel.xOf('battery'), 6, () => paintBattery(canvas, t, look.batteryLevel, fault: look.batteryFault), scale: 1.15);
    if (look.crate) at(WorldModel.xOf('crate'), 6, () => paintCrate(canvas), scale: 1.15);
    if (look.showLander) {
      at(
        WorldModel.xOf('lander'),
        4,
        () => paintLander(canvas, t, tilt: look.landerTilt, bayOpen: look.landerBay, repaired: look.landerRepaired),
        scale: _landerScale,
      );
    }

    // the goal ring (under Nova)
    final goal = look.goal;
    if (goal != null && look.arrows) {
      final gx = WorldModel.xOf(goal);
      final isPickup = goal.startsWith('pickup:');
      final ringW = switch (goal) {
        'lander' => 200.0,
        'habitat' => 240.0,
        'panels' => 120.0,
        'rover' || 'greenhouse' => 170.0,
        'pad' || 'rocket' => 230.0,
        _ => isPickup ? 54.0 : 90.0,
      };
      at(gx, isPickup ? 18 : 10, () => paintGoalRing(canvas, t, ringW));
    }

    // gear on the ground in front
    for (final p in look.pickups) {
      at(WorldModel.xOf(p), 18, () => paintPickup(canvas, t, p, glow: look.arrows));
    }

    // ---- tap rings: a flat ring on the dust, a soft circle in the sky
    for (final (pos, born, sky) in v._tapRings) {
      final k = ((t - born) / 0.6).clamp(0.0, 1.0);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * u * (1 - k)
        ..color = (sky ? C.cyan : const Color(0xFFFFFFFF)).withValues(alpha: 0.7 * (1 - k));
      if (sky) {
        canvas.drawCircle(pos, (10 + 30 * k) * u, ring);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(sx(pos.dx), groundY + 16 * u), width: (14 + 50 * k) * u, height: (4 + 12 * k) * u), ring);
      }
    }

    // ---- particles behind Nova
    _particles(canvas, sx, groundY, u, front: false);

    // ---- Nova
    if (!look.novaHidden) {
      final nx = sx(w.novaX);
      final lift = w.novaY * ppm;
      final far = (1 - w.novaY / 1.6).clamp(0.35, 1.0).toDouble();
      canvas.save();
      canvas.translate(nx, groundY + 16 * u);
      // contact shadow plus a long shadow away from the Sun; both shrink as she rises
      canvas.drawOval(
        Rect.fromLTWH(-16 * u + lift * 0.6, -3 * u, 110 * u * far, 7 * u),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.32 * far),
              Colors.black.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(-16 * u, -3 * u, 110 * u, 7 * u)),
      );
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 46 * u * far, height: 7 * u * far), Paint()..color = Colors.black.withValues(alpha: 0.25 * far));
      canvas.translate(0, -lift);
      final s = 1.32 * u;
      final box = Rect.fromLTWH(-60 * s, -125 * s, 120 * s, 135 * s);
      canvas.saveLayer(box, Paint());
      canvas.save();
      canvas.scale(w.facing * s, s);
      paintNova(canvas, d.novaPose(t));
      canvas.restore();
      // the low Sun is on the left: a warm rim on that side, shade on the other
      if (!look.night) {
        canvas.drawRect(
          box,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..shader = LinearGradient(
              colors: [th.rim, th.rim.withValues(alpha: th.rim.a * 0.3), const Color(0x00000000), th.shade.withValues(alpha: th.shade.a * 0.45), th.shade],
              stops: const [0.3, 0.42, 0.5, 0.6, 0.75],
            ).createShader(box),
        );
      } else {
        canvas.drawRect(
          box,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..color = const Color(0x2A0A1530),
        );
      }
      canvas.restore();
      canvas.restore();
    }

    // ---- Pip, with a scan beam when scanning
    final pipPos = Offset(sx(v._pip.dx), groundY + v._pip.dy * u);
    canvas.save();
    canvas.translate(pipPos.dx, pipPos.dy);
    canvas.scale(1.25 * u);
    Offset? beam;
    final scan = d.pipScan;
    if (scan != null) {
      final tx = sx(WorldModel.xOf(scan));
      beam = Offset((tx - pipPos.dx) / (1.25 * u), (groundY + 10 * u - pipPos.dy) / (1.25 * u));
    }
    paintPipGlow(canvas, t, beamTo: beam);
    paintPip(canvas, t, eye: d.pipEye, tilt: (w.velocity * 0.05).clamp(-0.25, 0.25));
    canvas.restore();

    // Nova's speech bubble
    final say = d.bubble;
    if (say != null && !look.novaHidden) {
      final tp = TextPainter(
        text: TextSpan(
          text: say,
          style: TextStyle(fontFamily: F.body, fontWeight: FontWeight.w700, fontSize: 13 * u, color: C.evergreen, height: 1.25),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: 190 * u);
      final nx = sx(w.novaX);
      final bw = tp.width + 22 * u, bh = tp.height + 16 * u;
      final left = (nx - bw / 2 + 20 * u).clamp(10 * u, size.width - bw - 10 * u).toDouble();
      final top = groundY + 16 * u - 158 * u - bh;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, bw, bh), Radius.circular(14 * u));
      canvas.drawRRect(r.shift(Offset(0, 3 * u)), Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawRRect(r, Paint()..color = C.frozen);
      final tail = Path()
        ..moveTo(nx - 6 * u, top + bh - 1)
        ..lineTo(nx + 6 * u, top + bh - 1)
        ..lineTo(nx + 2 * u, top + bh + 9 * u)
        ..close();
      canvas.drawPath(tail, Paint()..color = C.frozen);
      tp.paint(canvas, Offset(left + 11 * u, top + 8 * u));
    }

    // the goal arrow floats above everything (until Nova gets there)
    if (goal != null && look.arrows && w.near != goal) {
      final gx = WorldModel.xOf(goal);
      final isPickup = goal.startsWith('pickup:');
      final h = switch (goal) {
        'lander' => -122.0 * _landerScale - 14,
        'habitat' || 'site:B' => look.habitat > 0.5 ? -170.0 * _habScale : -90.0,
        'panels' => -142.0 * _panelScale,
        'site:A' => -126.0,
        'battery' || 'crate' => -66.0,
        'rover' => -140.0,
        'greenhouse' => -100.0,
        'pad' || 'rocket' => look.rocket ? -230.0 : -50.0,
        'drill' => -126.0,
        _ => isPickup ? -40.0 : -70.0,
      };
      at(gx, h, () => paintGoalArrow(canvas, t));
      // a small edge arrow points the way when the goal is off screen
      final gpx = sx(gx);
      final margin = 26 * u;
      if (gpx < -10 * u || gpx > size.width + 10 * u) {
        final right = gpx > size.width;
        final ax = right ? size.width - margin : margin;
        final ay = groundY - 120 * u;
        final pulse = 0.75 + 0.25 * math.sin(t * 5);
        final dist = (gx - w.novaX).abs().round();
        canvas.save();
        canvas.translate(ax + (right ? 1 : -1) * 3 * u * math.sin(t * 5), ay);
        final chev = Path()
          ..moveTo(right ? -7 * u : 7 * u, -11 * u)
          ..lineTo(right ? 6 * u : -6 * u, 0)
          ..lineTo(right ? -7 * u : 7 * u, 11 * u);
        canvas.drawCircle(Offset.zero, 17 * u, Paint()..color = C.evergreen.withValues(alpha: 0.65));
        canvas.drawCircle(
          Offset.zero,
          17 * u,
          Paint()
            ..color = C.cyan.withValues(alpha: pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * u,
        );
        canvas.drawPath(
          chev,
          Paint()
            ..color = C.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * u
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '$dist m',
            style: TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: 10.5 * u, color: C.frozen),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, 21 * u));
        canvas.restore();
      }
    }

    _particles(canvas, sx, groundY, u, front: true);

    // meteor streak and flash
    if (v._impact < 0.9) {
      final hx = sx(WorldModel.xOf('habitat') + 1.6);
      final hy = groundY - 70 * u;
      final k = (v._impact / 0.25).clamp(0.0, 1.0);
      if (k < 1) {
        final from = Offset(hx + 260 * u, hy - 380 * u);
        canvas.drawLine(
          Offset.lerp(from, Offset(hx, hy), k * 0.6)!,
          Offset.lerp(from, Offset(hx, hy), k)!,
          Paint()
            ..color = const Color(0xFFFFF4C8)
            ..strokeWidth = 2.4 * u
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final a = 1 - (v._impact - 0.25) / 0.65;
        canvas.drawCircle(Offset(hx, hy), 40 * u * (1.4 - a), Paint()..color = const Color(0xFFFFF4C8).withValues(alpha: 0.6 * a));
      }
    }

    // what floats in the air in this mission
    _ambient(canvas, size, th, groundY, u, cam, ppm, t, sx(w.novaX), w.facing.toDouble());

    // dust haze
    if (look.dust > 0.2) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFBBAA8C).withValues(alpha: 0.18 * look.dust));
    }
    // lunar night: everything darkens except the pool of Nova's helmet lamp
    if (look.night) {
      final lamp = Offset(sx(w.novaX) + w.facing * 60 * u, groundY);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment((lamp.dx / size.width) * 2 - 1, (lamp.dy / size.height) * 2 - 1),
            radius: 0.55,
            colors: [const Color(0xFF02060F).withValues(alpha: 0.18), const Color(0xFF02060F).withValues(alpha: 0.62)],
          ).createShader(Offset.zero & size),
      );
      // the helmet lamp: a soft cone of light on the dust ahead of Nova
      if (!look.novaHidden) {
        final hx = sx(w.novaX) + w.facing * 8 * u, hy = groundY + 16 * u - (118 + w.novaY * 40) * u;
        final f = w.facing.toDouble();
        final cone = Path()
          ..moveTo(hx, hy)
          ..lineTo(hx + f * 230 * u, groundY + 4 * u)
          ..lineTo(hx + f * 230 * u, groundY + 58 * u)
          ..lineTo(hx + f * 40 * u, groundY + 40 * u)
          ..close();
        final b = cone.getBounds();
        canvas.drawPath(
          cone,
          Paint()
            ..shader = LinearGradient(
              begin: f > 0 ? Alignment.centerLeft : Alignment.centerRight,
              end: f > 0 ? Alignment.centerRight : Alignment.centerLeft,
              colors: const [Color(0x40FFF1C8), Color(0x18FFF1C8), Color(0x00FFF1C8)],
            ).createShader(b),
        );
      }
    }
    canvas.restore();

    // alarm: a soft red wash at the edges (never a harsh flash)
    if (look.alarm) {
      final a = 0.16 + 0.14 * (0.5 + 0.5 * math.sin(t * 4.5));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [
              Colors.transparent,
              const Color(0xFFFF4D5A).withValues(alpha: a),
            ],
            stops: const [0.55, 1],
          ).createShader(Offset.zero & size),
      );
    } else if (look.stormWarning) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [Colors.transparent, const Color(0xFF8F7BFF).withValues(alpha: 0.22)],
            stops: const [0.5, 1],
          ).createShader(Offset.zero & size),
      );
    }
  }

  // ------------------------------------------------------------------ mission ambience

  void _aurora(Canvas canvas, Size size, double groundY, double u, double t) {
    // slow curtains of violet and green light high in the storm sky
    for (var k = 0; k < 3; k++) {
      final path = Path();
      final top = groundY * (0.12 + k * 0.07);
      final h = groundY * (0.22 + k * 0.04);
      path.moveTo(-10, top);
      for (var x = 0.0; x <= size.width + 20; x += 24 * u) {
        path.lineTo(x, top + math.sin(x / (70 * u) + t * (0.4 + k * 0.17) + k * 2) * 18 * u);
      }
      path.lineTo(size.width + 20, top + h);
      for (var x = size.width + 20; x >= -10; x -= 24 * u) {
        path.lineTo(x, top + h + math.sin(x / (90 * u) + t * 0.3 + k) * 12 * u);
      }
      path.close();
      final c = k == 1 ? const Color(0xFF5BE3B0) : const Color(0xFFA48CFF);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: 0), c.withValues(alpha: 0.13 + 0.05 * math.sin(t + k)), c.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, top - 20 * u, size.width, h + 40 * u)),
      );
    }
  }

  static final _ambPaint = Paint();
  static final _amb = List.generate(36, (i) {
    final r = math.Random(i * 53 + 11);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });

  void _ambient(Canvas canvas, Size size, MissionTheme th, double groundY, double u, double cam, double ppm, double t, double novaPx, double facing) {
    final p = _ambPaint;
    switch (th.ambient) {
      case Ambient.frost:
        // frost glints that flash on the ground as the light catches them
        for (var i = 0; i < _amb.length; i++) {
          final (a, b, c) = _amb[i];
          var x = (a * 30 - cam * 1.0) % 30;
          if (x < 0) x += 30;
          final px = x * ppm - ppm * 8;
          if (px < -8 || px > size.width + 8) continue;
          final py = groundY + (8 + b * b * 150) * u;
          final tw = math.pow(0.5 + 0.5 * math.sin(t * (1.5 + c * 2) + i * 1.7), 6).toDouble();
          if (tw < 0.05) continue;
          final r = (1.5 + b * 3) * u * tw;
          p.color = const Color(0xFFE6F8FF).withValues(alpha: 0.9 * tw);
          p.strokeWidth = 1.1 * u;
          canvas.drawLine(Offset(px - r * 2, py), Offset(px + r * 2, py), p);
          canvas.drawLine(Offset(px, py - r * 2), Offset(px, py + r * 2), p);
          canvas.drawCircle(Offset(px, py), r * 0.6, p);
        }
        // cold mist lying in the crater
        final mist = Rect.fromLTWH(-20, groundY - 30 * u, size.width + 40, 70 * u);
        canvas.drawRect(mist, _cache.mist(mist, const Color(0xFFBFE6FF), 0.16 + 0.04 * math.sin(t * 0.6)));
      case Ambient.spores:
        // the greenhouse's grow lights catch drifting dust like tiny green fireflies
        for (var i = 0; i < 22; i++) {
          final (a, b, c) = _amb[i];
          final px = (a * size.width + math.sin(t * 0.4 + i) * 30 * u - cam * ppm * 0.6) % size.width;
          final py = groundY - (20 + ((b * 200 + t * (6 + c * 10)) % 200)) * u;
          final glow = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + i));
          p.color = const Color(0xFF8CFFB0).withValues(alpha: 0.22 * glow);
          canvas.drawCircle(Offset(px, py), 4 * u, p);
          p.color = const Color(0xFFD8FFE4).withValues(alpha: 0.8 * glow);
          canvas.drawCircle(Offset(px, py), 1.3 * u, p);
        }
      case Ambient.embers:
        // sparks from the launch pad rise and fade
        for (var i = 0; i < 26; i++) {
          final (a, b, c) = _amb[i];
          final life = (t * (0.18 + c * 0.2) + b) % 1;
          final px = (a * size.width + math.sin(t + i) * 12 * u + life * 40 * u) % size.width;
          final py = groundY - life * 260 * u;
          p.color = Color.lerp(const Color(0xFFFFE08A), const Color(0xFFFF6A3D), life)!.withValues(alpha: 0.8 * (1 - life));
          canvas.drawCircle(Offset(px, py), (1.8 - life) * u, p);
        }
      case Ambient.quakeDust:
      case Ambient.dustDrift:
        // fine dust drifting slowly in the low light (very faint)
        final strong = th.ambient == Ambient.quakeDust;
        for (var i = 0; i < (strong ? 30 : 14); i++) {
          final (a, b, c) = _amb[i];
          final px = (a * size.width * 1.2 + t * (8 + c * 10) * u - cam * ppm * 0.3) % (size.width * 1.2) - size.width * 0.1;
          final py = groundY - (b * 180 + math.sin(t * 0.7 + i) * 8) * u;
          p.color = const Color(0xFFE8DCC4).withValues(alpha: strong ? 0.35 : 0.16);
          canvas.drawCircle(Offset(px, py), (0.8 + c * 1.2) * u, p);
        }
      case Ambient.alarm:
        // a rotating warning beacon sweeps over the scene
        final ang = t * 3.2;
        final sweep = Offset(math.cos(ang), math.sin(ang) * 0.35);
        final from = Offset(size.width * 0.5, groundY - 200 * u);
        final beam = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(from.dx + (sweep.dx * 600 - sweep.dy * 120) * u, from.dy + (sweep.dy * 600 + sweep.dx * 40) * u)
          ..lineTo(from.dx + (sweep.dx * 600 + sweep.dy * 120) * u, from.dy + (sweep.dy * 600 - sweep.dx * 40) * u)
          ..close();
        p.color = const Color(0xFFFF4D5A).withValues(alpha: 0.05 + 0.03 * math.cos(ang).abs());
        canvas.drawPath(beam, p);
      case Ambient.night:
      case Ambient.aurora:
      case Ambient.none:
        break;
    }
  }

  void _particles(Canvas canvas, double Function(double) sx, double groundY, double u, {required bool front}) {
    final p = Paint();
    for (final q in v._ps) {
      final isFront = q.kind == 1 || q.kind == 3;
      if (isFront != front) continue;
      final a = (q.life / q.max).clamp(0.0, 1.0);
      final pos = Offset(sx(q.x), groundY + q.y * u);
      switch (q.kind) {
        case 1:
          p.color = q.color.withValues(alpha: a);
          p.strokeWidth = 1.4 * u;
          p.strokeCap = StrokeCap.round;
          canvas.drawLine(pos, pos - Offset(q.vx * 0.06 * 28, q.vy * 0.03) * u, p);
          break;
        case 2:
          p.color = q.color.withValues(alpha: 0.4 * a);
          canvas.drawCircle(pos, q.size * u * (2 - a), p);
          break;
        default:
          p.color = q.color.withValues(alpha: 0.7 * a);
          canvas.drawCircle(pos, q.size * u, p);
      }
    }
  }

  void _earth(Canvas canvas, Offset c, double r, double t) {
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF7FC8FF).withValues(alpha: 0.28), const Color(0x007FC8FF)]).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), radius: 1.0, colors: [Color(0xFF5CBCFF), Color(0xFF1F63C4), Color(0xFF0E3A86)]).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    // continents drift slowly as Earth turns
    final drift = (t * 0.6) % (r * 4);
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
      canvas.drawOval(Rect.fromCenter(center: o + Offset(r * 1.3, r * 0.35), width: r * 0.7, height: r * 0.45), land..color = const Color(0xFF8C7E52));
      land.color = const Color(0xFF4F9F55);
    }
    // clouds
    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c + Offset(0, -r * 0.2), radius: r * 0.9), math.pi * 1.15, 0.9, false, cloud);
    canvas.drawArc(Rect.fromCircle(center: c + Offset(r * 0.1, r * 0.4), radius: r * 0.8), math.pi * 0.1, 0.8, false, cloud);
    // night side: Earth is lit from the left like the Moon around it
    // the terminator: soft, lit from the low Sun on the left
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0x00020510), const Color(0x00020510), const Color(0xFF020510).withValues(alpha: 0.78)],
          stops: const [0, 0.5, 0.82],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawCircle(
      c,
      r + 1.5,
      Paint()
        ..color = const Color(0xFF7FC8FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _ridge(Canvas canvas, Size size, double u, double scroll, double baseY, double height, int seed, Color dark, Color lit, double jag) {
    // a repeating jagged ridge, lit from the low Sun on the left. The shape is
    // built once per screen size and theme, then only moved (fast).
    final r = _cache.ridge(size, u, baseY, height, seed, dark, lit, jag);
    final period = r.period;
    final off = -(scroll % period);
    for (var rep = 0; rep < 3; rep++) {
      final ox = off + rep * period;
      if (ox > size.width) break;
      canvas.save();
      canvas.translate(ox, 0);
      canvas.drawPath(r.body, r.darkPaint);
      for (final (path, paint) in r.faces) {
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  // little stones and grains: the ground looks like dust, not paint
  static final _grains = List.generate(160, (i) {
    final r = math.Random(i * 31 + 7);
    return (r.nextDouble() * 44, r.nextDouble(), r.nextDouble());
  });

  static final _grainPaint = Paint();
  static final _grainDark = Paint()..color = const Color(0x40000000);
  static final _grainLit = Paint()..color = const Color(0x66FFFFFF);

  void _regolith(Canvas canvas, Size size, double u, double cam, double ppm, double groundY) {
    final dark = _grainDark;
    final lit = _grainLit;
    const span = 44.0;
    for (final (x, depth, k) in _grains) {
      // nearer grains are bigger, lower and move faster (parallax inside the ground)
      final par = 0.85 + depth * 0.5;
      var wx = (x - cam * par) % span;
      if (wx < 0) wx += span;
      final px = wx * ppm - ppm * 8;
      if (px < -10 || px > size.width + 10) continue;
      final y = groundY + (2 + depth * depth * (size.height - groundY - 4 * u) / u) * u;
      final r = (0.6 + depth * 2.4 * (0.4 + k)) * u;
      canvas.drawOval(Rect.fromCenter(center: Offset(px + r * 0.6, y + r * 0.3), width: r * 3.2, height: r * 0.9), dark);
      _grainPaint.color = Color.lerp(const Color(0xFF8C8880), const Color(0xFFB5B1A9), k)!;
      canvas.drawCircle(Offset(px, y), r, _grainPaint);
      canvas.drawCircle(Offset(px - r * 0.35, y - r * 0.35), r * 0.45, lit);
    }
  }

  static final _craters = List.generate(40, (i) {
    final r = math.Random(i * 97 + 5);
    return (i * 3.1 + r.nextDouble() * 2.5, 0.4 + r.nextDouble() * 1.2, r.nextDouble());
  });

  static final _crBowl = Paint()..color = const Color(0xFF8E8A82).withValues(alpha: 0.55);
  static final _crShade = Paint()..color = const Color(0xFF6F6B64).withValues(alpha: 0.55);
  static final _crLit = Paint()
    ..color = const Color(0xFFEAE6DE).withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke;
  static final _crInnerLit = Paint()..color = const Color(0xFFD9D4CA).withValues(alpha: 0.45);
  static final _rock = Paint()..color = const Color(0xFF9C988F);
  static final _rockTop = Paint()..color = const Color(0xFFC9C5BD);
  static final _rockShadow = Paint()
    ..shader = LinearGradient(colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0)]).createShader(const Rect.fromLTWH(0, 0, 50, 5));

  void _groundDetail(Canvas canvas, Size size, double u, double cam, double ppm, double groundY) {
    _crLit.strokeWidth = 1.4 * u;
    for (final (x, sz, depth) in _craters) {
      final px = (x - cam) * ppm + size.width / 2;
      if (px < -100 * u || px > size.width + 100 * u) continue;
      final y = groundY + (6 + depth * 60) * u;
      final rw = sz * 46 * u * (0.7 + depth * 0.6), rh = rw * 0.22;
      final rect = Rect.fromCenter(center: Offset(px, y), width: rw, height: rh);
      canvas.drawOval(rect, _crBowl);
      // the Sun is low on the left: the left inner wall is in shadow, the right one is lit
      canvas.drawOval(Rect.fromLTWH(rect.left + rw * 0.06, rect.top + rh * 0.2, rw * 0.62, rh * 0.75), _crShade);
      canvas.drawOval(Rect.fromLTWH(rect.left + rw * 0.62, rect.top + rh * 0.3, rw * 0.3, rh * 0.6), _crInnerLit);
      // lit far rim
      canvas.drawArc(rect, math.pi * 1.05, math.pi * 0.9, false, _crLit);
      // a rock with a long shadow every few craters
      if (depth > 0.6) {
        final rx = px + rw * 0.8, ry = y + 2 * u;
        canvas.save();
        canvas.translate(rx, ry - 2 * u);
        canvas.scale(u);
        canvas.drawOval(const Rect.fromLTWH(0, 0, 50, 5), _rockShadow);
        canvas.restore();
        canvas.drawOval(Rect.fromCenter(center: Offset(rx, ry - 3 * u), width: 18 * u, height: 10 * u), _rock);
        canvas.drawOval(Rect.fromCenter(center: Offset(rx - 2 * u, ry - 5 * u), width: 10 * u, height: 4 * u), _rockTop);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter old) => false;
}

/// Shaders and shapes that only change with the screen size or the theme.
/// Building them once (instead of every frame) keeps the game at 60 fps on
/// school phones.
class _PaintCache {
  String? _skyKey, _groundKey, _veilKey, _glowKey, _mistKey;
  late Paint _sky, _ground, _veil, _glow, _mist;
  final Map<String, _Ridge> _ridges = {};

  Paint sky(MissionTheme th, Size size) {
    final key = '${th.id}|${size.width}x${size.height}';
    if (key != _skyKey) {
      _skyKey = key;
      final rect = Offset.zero & size;
      _sky = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (var i = 0; i < 32; i++) th.skyAt(i / 31)],
        ).createShader(rect);
    }
    return _sky;
  }

  Paint glow(MissionTheme th, double radius) {
    final key = '${th.id}|$radius';
    if (key != _glowKey) {
      _glowKey = key;
      const n = 16;
      final s = th.sunGlow.clamp(0.0, 1.5);
      _glow = Paint()
        ..shader = RadialGradient(
          colors: [
            for (var i = 0; i < n; i++) th.sun.withValues(alpha: i == n - 1 ? 0 : (0.3 * s * math.exp(-math.pow(i / (n - 1), 2) * 4.8)).clamp(0.0, 1.0)),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    }
    return _glow;
  }

  Paint ground(MissionTheme th, Rect r) {
    final key = '${th.id}|$r';
    if (key != _groundKey) {
      _groundKey = key;
      _ground = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.groundTop, th.groundMid, th.groundLow],
          stops: const [0, 0.45, 1],
        ).createShader(r);
    }
    return _ground;
  }

  Paint veil(MissionTheme th, Rect r) {
    final key = '${th.id}|$r';
    if (key != _veilKey) {
      _veilKey = key;
      _veil = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.skyLow.withValues(alpha: 0), th.skyLow.withValues(alpha: 0.45), th.skyLow.withValues(alpha: 0.2)],
          stops: const [0, 0.7, 1],
        ).createShader(r);
    }
    return _veil;
  }

  Paint mist(Rect r, Color c, double a) {
    final key = '$r|${(a * 50).round()}';
    if (key != _mistKey) {
      _mistKey = key;
      _mist = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: 0), c.withValues(alpha: a), c.withValues(alpha: 0)],
        ).createShader(r);
    }
    return _mist;
  }

  _Ridge ridge(Size size, double u, double baseY, double height, int seed, Color dark, Color lit, double jag) {
    final key = '$seed|${size.width}x${size.height}|${dark.toARGB32()}|${lit.toARGB32()}';
    final hit = _ridges[key];
    if (hit != null) return hit;
    if (_ridges.length > 9) _ridges.clear();
    final period = size.width * 1.6;
    final rnd = math.Random(seed);
    final pts = <Offset>[];
    const n = 9;
    for (var i = 0; i <= n; i++) {
      final x = i / n * period;
      final hh = i == 0 || i == n ? 0.35 : 0.25 + rnd.nextDouble() * 0.75;
      pts.add(Offset(x, baseY - height * hh));
    }
    pts[n] = Offset(period, pts[0].dy);
    final body = Path()..moveTo(0, baseY + 30 * u);
    for (final p in pts) {
      body.lineTo(p.dx, p.dy);
    }
    body
      ..lineTo(period, baseY + 30 * u)
      ..close();
    final faces = <(Path, Paint)>[];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if (b.dy < a.dy) {
        final face = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx + (b.dx - a.dx) * jag * 0.4, baseY + 30 * u)
          ..lineTo(a.dx, baseY + 30 * u)
          ..close();
        faces.add((
          face,
          Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [lit, Color.lerp(lit, dark, 0.6)!]).createShader(face.getBounds()),
        ));
      }
    }
    return _ridges[key] = _Ridge(period, body, Paint()..color = dark, faces);
  }
}

class _Ridge {
  final double period;
  final Path body;
  final Paint darkPaint;
  final List<(Path, Paint)> faces;
  _Ridge(this.period, this.body, this.darkPaint, this.faces);
}
