/// Survival mode: the base as a three-floor cut-away (command, life support,
/// greenhouse and bunks), with Nova moving between rooms to carry out the
/// orders the player gives, and the weather outside (night, storms, dust).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/theme.dart';
import 'characters.dart';
import 'world_art.dart';

class BaseView extends StatefulWidget {
  /// The game controller's view map.
  final Map<String, Object?> Function() view;
  final void Function(String area) onTap;
  final bool paused;
  const BaseView({super.key, required this.view, required this.onTap, this.paused = false});

  @override
  State<BaseView> createState() => _BaseViewState();
}

class _BaseViewState extends State<BaseView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  Offset? _nova; // fractions of the habitat box
  double _walk = 0;
  int _facing = 1;
  final _repaint = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60;
    _t += dt;
    final want = _novaTarget(widget.view());
    _nova ??= want;
    final d = want - _nova!;
    if (d.distance > 0.004) {
      final step = math.min(d.distance, dt * 0.32);
      _nova = _nova! + d / d.distance * step;
      if (d.dx.abs() > 0.002) _facing = d.dx > 0 ? 1 : -1;
      _walk += dt * 1.6;
    }
    _repaint.value++;
  }

  /// Where Nova stands for her current job (fractions of the habitat box:
  /// x across, y = the floor line of her room).
  static Offset _novaTarget(Map<String, Object?> v) {
    final nova = (v['nova'] as Map?) ?? const {};
    final goal = '${nova['goal'] ?? 'bench'}';
    const top = 0.335, mid = 0.64, low = 0.95;
    switch (goal) {
      case 'repair_electrolyzer':
        return const Offset(0.42, mid);
      case 'repair_recycler':
        return const Offset(0.6, mid);
      case 'repair_greenhouse':
      case 'greenhouse':
        return const Offset(0.36, low);
      case 'gym':
        return const Offset(0.52, low);
      case 'lab':
        return const Offset(0.7, top);
      case 'shelter':
        return const Offset(0.8, low);
      case 'panels':
      case 'airlock':
        return const Offset(0.95, low);
      default:
        return const Offset(0.36, top);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (e) => widget.onTap(_area(e.localPosition, size)),
        child: RepaintBoundary(child: CustomPaint(size: size, painter: _BasePainter(this, _repaint))),
      );
    });
  }

  static Rect habitatRect(Size s) {
    final w = math.min(s.width * 0.7, s.height * 0.68);
    final h = math.min(s.height * 0.86, w * 1.18);
    return Rect.fromLTWH((s.width - w) / 2, s.height * 0.94 - h, w, h);
  }

  String _area(Offset p, Size s) {
    final r = habitatRect(s);
    if (!r.contains(p)) return p.dy > r.bottom - r.height * 0.3 && p.dx > r.right ? 'airlock' : 'outside';
    final f = (p.dy - r.top) / r.height;
    if (f < 0.36) return 'command';
    if (f < 0.66) return 'life';
    return 'greenhouse';
  }
}

class _BasePainter extends CustomPainter {
  final _BaseViewState v;
  _BasePainter(this.v, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size s) {
    final view = v.widget.view();
    final t = v._t;
    final sun = view['sun'] != false;
    final power = ((view['power'] as num?) ?? 1).toDouble();
    final brownout = view['brownout'] == true;
    final alarm = view['alarm'] == true;
    final storm = '${view['storm'] ?? 'none'}';
    final dust = ((view['dust'] as num?) ?? 0).toDouble();
    final greenhouse = view['greenhouse'] == true;
    final ghOn = view['greenhouseOn'] == true;
    final berm = view['berm'] == true;
    final extraPanel = view['panelInstalled'] == true;
    final broken = ((view['broken'] as List?) ?? const []).map((e) => '$e').toSet();
    final eva = view['eva'];
    final evaP = ((view['evaProgress'] as num?) ?? 0).toDouble();
    final nova = (view['nova'] as Map?) ?? const {};
    final action = '${nova['action'] ?? 'idle'}';
    final u = s.width / 390;

    // ---- sky and ground
    final sky = Offset.zero & s;
    canvas.drawRect(sky, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sun ? const [Color(0xFF04120A), Color(0xFF0A1C14)] : const [Color(0xFF010403), Color(0xFF040A08)]).createShader(sky));
    final rnd = math.Random(4);
    for (var i = 0; i < 50; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.8), i % 8 == 0 ? 1.2 : 0.7, Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.4 * (0.5 + 0.5 * math.sin(t * 1.5 + i))));
    }
    final ec = Offset(s.width * 0.84, s.height * 0.08);
    canvas.drawCircle(ec, 22 * u, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFF5CBCFF), Color(0xFF0E3A86)]).createShader(Rect.fromCircle(center: ec, radius: 22 * u)));
    canvas.drawCircle(ec + Offset(12 * u, 0), 22 * u, Paint()..color = const Color(0xFF020510).withValues(alpha: 0.75));
    final gy = s.height * 0.94;
    final ground = Rect.fromLTWH(0, gy, s.width, s.height - gy);
    canvas.drawRect(ground, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBFBBB3), Color(0xFF6F6B65)]).createShader(ground));

    final r = _BaseViewState.habitatRect(s);

    // ---- outside: solar panels on the left, extra panel on the right
    canvas.save();
    canvas.translate(r.left * 0.5, gy);
    canvas.scale(0.55 * u);
    paintPanels(canvas, t, dust: dust.clamp(0.0, 1.0).toDouble() * 0.8);
    canvas.restore();
    if (extraPanel) {
      canvas.save();
      canvas.translate(r.right + (s.width - r.right) * 0.5, gy);
      canvas.scale(0.45 * u);
      paintPanels(canvas, t, dust: dust.clamp(0.0, 1.0).toDouble() * 0.8);
      canvas.restore();
    }
    if (!sun) {
      canvas.drawRect(Rect.fromLTWH(0, 0, r.left, gy), Paint()..color = Colors.black.withValues(alpha: 0.35));
    }

    // ---- habitat shell
    final shell = RRect.fromRectAndCorners(r, topLeft: Radius.circular(r.width * 0.42), topRight: Radius.circular(r.width * 0.42), bottomLeft: const Radius.circular(6), bottomRight: const Radius.circular(6));
    canvas.drawRRect(shell.shift(Offset(10 * u, 6 * u)), Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(shell, Paint()..color = const Color(0xFFEDEBE5));
    final inner = shell.deflate(10 * u);
    canvas.save();
    canvas.clipRRect(inner);
    final floorH = inner.height;
    final f1 = inner.top + floorH * 0.36, f2 = inner.top + floorH * 0.66;
    // three rooms
    canvas.drawRect(Rect.fromLTRB(inner.left, inner.top, inner.right, f1), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3F66), Color(0xFF1D2340)]).createShader(Rect.fromLTRB(inner.left, inner.top, inner.right, f1)));
    canvas.drawRect(Rect.fromLTRB(inner.left, f1, inner.right, f2), Paint()..color = const Color(0xFF1C2A3E));
    canvas.drawRect(Rect.fromLTRB(inner.left, f2, inner.right, inner.bottom), Paint()..color = const Color(0xFF16242C));
    final floorPaint = Paint()..color = const Color(0xFFD5D3CC);
    canvas.drawRect(Rect.fromLTRB(inner.left, f1 - 5 * u, inner.right, f1 + 3 * u), floorPaint);
    canvas.drawRect(Rect.fromLTRB(inner.left, f2 - 5 * u, inner.right, f2 + 3 * u), floorPaint);

    final w = inner.width;
    final x0 = inner.left;
    TextPainter label(String txt) => TextPainter(text: TextSpan(text: txt, style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w700, fontSize: 10.5 * u, letterSpacing: 2.2 * u, color: C.muted)), textDirection: TextDirection.ltr)..layout();

    // COMMAND: screens with a live chart, Earth on a monitor, a locker
    final scr1 = RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.22, inner.top + floorH * 0.14, w * 0.3, floorH * 0.12), Radius.circular(6 * u));
    canvas.drawRRect(scr1, Paint()..color = const Color(0xFF13203A));
    canvas.drawRRect(scr1, Paint()
      ..color = C.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u);
    final chart = Path();
    for (var i = 0; i <= 20; i++) {
      final px = scr1.left + 8 * u + (scr1.width - 16 * u) * i / 20;
      final py = scr1.center.dy + math.sin(i * 0.7 + t * 1.6) * scr1.height * 0.22;
      i == 0 ? chart.moveTo(px, py) : chart.lineTo(px, py);
    }
    canvas.drawPath(chart, Paint()
      ..color = C.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u);
    final scr2 = RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.56, inner.top + floorH * 0.14, w * 0.17, floorH * 0.12), Radius.circular(6 * u));
    canvas.drawRRect(scr2, Paint()..color = const Color(0xFF13203A));
    canvas.drawRRect(scr2, Paint()
      ..color = C.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u);
    canvas.drawCircle(scr2.center, scr2.height * 0.3, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFF5CBCFF), Color(0xFF0E3A86)]).createShader(Rect.fromCircle(center: scr2.center, radius: scr2.height * 0.3)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.04, inner.top + floorH * 0.12, w * 0.12, floorH * 0.2), Radius.circular(6 * u)), Paint()..color = const Color(0xFF2A3050));
    canvas.drawRect(Rect.fromLTWH(x0 + w * 0.055, inner.top + floorH * 0.15, w * 0.09, 3 * u), Paint()..color = C.sapphire);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.78, inner.top + floorH * 0.12, w * 0.16, floorH * 0.2), Radius.circular(6 * u)), Paint()
      ..color = C.cyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * u);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(x0 + w * 0.81, inner.top + floorH * (0.16 + i * 0.045), w * 0.1, 2.5 * u), Paint()..color = C.cyan);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.22, inner.top + floorH * 0.28, w * 0.5, 7 * u), Radius.circular(4 * u)), Paint()..color = const Color(0xFF4A5070));
    label('COMMAND').paint(canvas, Offset(x0 + w * 0.22, f1 - 22 * u));

    // LIFE SUPPORT: oxygen generator and water recycler, with pipes
    final pipe = Paint()
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final px = x0 + w * i / 12;
      canvas.drawLine(Offset(px, f1 + floorH * 0.12), Offset(px + w / 24, f1 + floorH * 0.12), pipe..color = C.cyan.withValues(alpha: 0.7));
      canvas.drawLine(Offset(px, f2 - floorH * 0.05), Offset(px + w / 24, f2 - floorH * 0.05), pipe..color = C.sapphire.withValues(alpha: 0.8));
    }
    void machine(double fx, String title, String value, bool isBroken, {double level = -1, bool bubbles = false}) {
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * fx, f1 + floorH * 0.04, w * 0.24, floorH * 0.22), Radius.circular(8 * u));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFFE9EBEF));
      final screen = RRect.fromRectAndRadius(Rect.fromLTWH(rr.left + 8 * u, rr.top + 8 * u, rr.width - 16 * u, rr.height * 0.24), Radius.circular(4 * u));
      canvas.drawRRect(screen, Paint()..color = const Color(0xFF13203A));
      final tp = TextPainter(text: TextSpan(text: value, style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w700, fontSize: (value.length > 7 ? 9.5 : 11.5) * u, color: isBroken ? C.red : C.cyan)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: screen.width);
      tp.paint(canvas, Offset(screen.center.dx - tp.width / 2, screen.center.dy - tp.height / 2));
      if (level >= 0) {
        final tank = RRect.fromRectAndRadius(Rect.fromLTWH(rr.left + 14 * u, rr.top + rr.height * 0.42, rr.width - 28 * u, rr.height * 0.5), Radius.circular(6 * u));
        canvas.drawRRect(tank, Paint()..color = const Color(0xFFCDD3DD));
        final lv = tank.height * level.clamp(0.0, 1.0);
        canvas.save();
        canvas.clipRRect(tank);
        canvas.drawRect(Rect.fromLTWH(tank.left, tank.bottom - lv, tank.width, lv), Paint()..color = C.sapphire);
        final wave = Path()..moveTo(tank.left, tank.bottom - lv);
        for (var i = 0; i <= 10; i++) {
          wave.lineTo(tank.left + tank.width * i / 10, tank.bottom - lv + math.sin(i * 0.9 + t * 3) * 2 * u);
        }
        canvas.drawPath(wave, Paint()
          ..color = C.frozen.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * u);
        canvas.restore();
      }
      if (bubbles) {
        canvas.drawCircle(Offset(rr.left + rr.width * 0.3, rr.top + rr.height * 0.6), 9 * u, Paint()..color = const Color(0xFF9FD3FF));
        canvas.drawCircle(Offset(rr.left + rr.width * 0.72, rr.top + rr.height * 0.6), 6 * u, Paint()..color = Colors.white);
        if (!isBroken) {
          for (var i = 0; i < 3; i++) {
            final k = ((t * 0.6 + i / 3) % 1);
            canvas.drawCircle(Offset(rr.left + rr.width * (0.3 + 0.05 * math.sin(t * 4 + i)), rr.top + rr.height * (0.95 - k * 0.3)), 2.2 * u * (1 - k), Paint()..color = Colors.white.withValues(alpha: 1 - k));
          }
        }
      }
      if (isBroken) {
        final on = (t * 2) % 1 < 0.5;
        canvas.drawRRect(rr, Paint()
          ..color = C.red.withValues(alpha: on ? 0.9 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * u);
        // sparks
        final sp = Paint()
          ..color = const Color(0xFFFFD27A)
          ..strokeWidth = 1.4 * u
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 5; i++) {
          final a = i * 1.3 + t * 11;
          final o = Offset(rr.right - 6 * u, rr.top + 10 * u);
          canvas.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * 7 * u, sp);
        }
      }
      label(title).paint(canvas, Offset(rr.left, rr.bottom + 4 * u));
    }

    machine(0.06, '', broken.contains('electrolyzer') ? 'FAULT' : 'O₂ ON', broken.contains('electrolyzer'), bubbles: true);
    machine(0.7, '', broken.contains('recycler') ? 'LEAK' : 'H₂O 98%', broken.contains('recycler'), level: broken.contains('recycler') ? 0.35 : 0.7);
    label('LIFE SUPPORT').paint(canvas, Offset(x0 + w * 0.08, f2 - 22 * u));

    // GREENHOUSE · BUNKS
    if (greenhouse) {
      final lightOn = ghOn && !brownout;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.05, f2 + floorH * 0.035, w * 0.6, 6 * u), Radius.circular(3 * u)), Paint()..color = lightOn ? C.sapphire : const Color(0xFF2A3050));
      if (lightOn) {
        canvas.drawRect(Rect.fromLTWH(x0 + w * 0.05, f2 + floorH * 0.05, w * 0.6, floorH * 0.22), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.sapphire.withValues(alpha: 0.18), C.sapphire.withValues(alpha: 0)]).createShader(Rect.fromLTWH(x0 + w * 0.05, f2 + floorH * 0.05, w * 0.6, floorH * 0.22)));
      }
      for (var row = 0; row < 2; row++) {
        final ty = f2 + floorH * (0.16 + row * 0.1);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.05, ty, w * 0.6, floorH * 0.035), Radius.circular(4 * u)), Paint()..color = const Color(0xFF3E2D22));
        for (var i = 0; i < 6; i++) {
          final px = x0 + w * (0.09 + i * 0.1);
          final sway = math.sin(t * 1.4 + i + row) * 0.12;
          final grow = broken.contains('greenhouse') ? 0.6 : 1.0;
          canvas.save();
          canvas.translate(px, ty);
          canvas.rotate(sway);
          canvas.drawOval(Rect.fromLTWH(-4 * u, -16 * u * grow, 9 * u, 15 * u * grow), Paint()..color = broken.contains('greenhouse') ? const Color(0xFF8A9A5B) : const Color(0xFF3FB866));
          if ((i + row) % 3 == 1) canvas.drawCircle(Offset(5 * u, -12 * u * grow), 3 * u, Paint()..color = const Color(0xFFFF5A5F));
          canvas.restore();
        }
      }
      if (broken.contains('greenhouse')) {
        final on = (t * 2) % 1 < 0.5;
        canvas.drawRect(Rect.fromLTWH(x0 + w * 0.04, f2 + floorH * 0.04, w * 0.62, floorH * 0.28), Paint()
          ..color = C.red.withValues(alpha: on ? 0.8 : 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * u);
      }
    }
    // bunks (they double as the storm shelter, walled with water bags)
    for (var i = 0; i < 2; i++) {
      final b = RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w * 0.7, f2 + floorH * (0.09 + i * 0.11), w * 0.26, floorH * 0.07), Radius.circular(6 * u));
      canvas.drawRRect(b, Paint()..color = const Color(0xFF242E52));
      canvas.drawRRect(b.deflate(4 * u).shift(Offset(0, -2 * u)), Paint()..color = const Color(0xFF5170D8));
    }
    label(greenhouse ? 'GREENHOUSE · BUNKS' : 'BUNKS · STORAGE').paint(canvas, Offset(x0 + w * 0.06, f2 + 8 * u));

    // the airlock on the right wall, bottom floor
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(inner.right - 10 * u, f2 + floorH * 0.12, 10 * u, floorH * 0.2), Radius.circular(3 * u)), Paint()..color = const Color(0xFFCDD3DD));
    canvas.drawCircle(Offset(inner.right - 5 * u, f2 + floorH * 0.22), 3 * u, Paint()..color = C.cyan);

    // ---- Nova inside
    final np = v._nova ?? const Offset(0.36, 0.335);
    final hidden = eva != null || action == 'hidden' && np.dy > 0.9;
    if (!hidden && np.dx < 0.93) {
      final pos = Offset(inner.left + inner.width * np.dx, inner.top + floorH * np.dy - 6 * u);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 40 * u, height: 6 * u), Paint()..color = Colors.black.withValues(alpha: 0.3));
      final sc = floorH * 0.0034;
      canvas.scale(v._facing * sc, sc);
      final moving = (v._novaTarget2(view) - np).distance > 0.01;
      final na = moving
          ? NovaAction.walk
          : switch (action) {
              'repair' => NovaAction.work,
              'work' => NovaAction.work,
              'exercise' => NovaAction.cheer,
              'clean' => NovaAction.work,
              'rest' => NovaAction.sit,
              _ => NovaAction.idle,
            };
      paintNova(canvas, NovaPose(action: na, phase: v._walk, t: t, visorUp: true, mood: alarm ? NovaMood.worried : (action == 'rest' ? NovaMood.tired : NovaMood.calm)));
      canvas.restore();
    } else if (action == 'hidden' && eva == null) {
      // asleep in the bunk
      final z = TextPainter(text: TextSpan(text: 'z z', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 14 * u, color: C.frozen.withValues(alpha: 0.5 + 0.5 * math.sin(t * 2)))), textDirection: TextDirection.ltr)..layout();
      z.paint(canvas, Offset(x0 + w * 0.8, f2 + floorH * 0.02 - math.sin(t) * 3 * u));
    }

    // brownout: the lights dim and flicker
    if (brownout || power < 0.08) {
      final flick = 0.55 + 0.1 * math.sin(t * 23) + 0.05 * math.sin(t * 7);
      canvas.drawRect(inner.outerRect, Paint()..color = Colors.black.withValues(alpha: flick));
    } else if (!sun) {
      canvas.drawRect(inner.outerRect, Paint()..color = const Color(0xFF000814).withValues(alpha: 0.18));
    }
    canvas.restore();
    // window ring and seams on the shell
    canvas.drawRRect(inner, Paint()
      ..color = const Color(0xFFBDBAB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u);

    // shielding bags piled against the walls
    if (berm) {
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          final cx = side < 0 ? r.left - 4 * u : r.right + 4 * u;
          final cy = gy - 9 * u - i * 15 * u;
          final bag = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 50 * u, height: 16 * u), Radius.circular(6 * u));
          canvas.drawRRect(bag, Paint()..color = const Color(0xFF8E8A82));
          canvas.drawRRect(bag, Paint()
            ..color = const Color(0xFF5E5B55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 * u);
        }
      }
    }

    // ---- Nova outside on an EVA: she walks out from the airlock and back
    if (eva != null) {
      final out = evaP < 0.5 ? evaP * 2 : (1 - evaP) * 2;
      final ex = r.right + 18 * u + out * (s.width - r.right - 30 * u);
      canvas.save();
      canvas.translate(ex.clamp(0.0, s.width - 14 * u).toDouble(), gy + 6 * u);
      final sc = 0.55 * u;
      canvas.scale((evaP < 0.5 ? 1 : -1) * sc, sc);
      paintNova(canvas, NovaPose(action: NovaAction.walk, phase: t * 1.2, t: t));
      canvas.restore();
    }

    // ---- weather and alarms
    if (storm != 'none') {
      final p = Paint()
        ..color = const Color(0xFFB9A8FF).withValues(alpha: storm == 'active' ? 0.75 : 0.45)
        ..strokeWidth = 1.3 * u
        ..strokeCap = StrokeCap.round;
      final n = storm == 'active' ? 36 : 16;
      for (var i = 0; i < n; i++) {
        final k = ((t * 0.8 + i * 0.137) % 1);
        final x = s.width * ((i * 0.381) % 1.2) - k * 120 * u;
        final y = k * gy;
        canvas.drawLine(Offset(x, y), Offset(x - 10 * u, y - 18 * u), p);
      }
      canvas.drawRect(sky, Paint()..shader = RadialGradient(radius: 0.95, colors: [Colors.transparent, const Color(0xFF8F7BFF).withValues(alpha: storm == 'active' ? 0.3 : 0.18)], stops: const [0.55, 1]).createShader(sky));
    }
    if (dust > 0.35) canvas.drawRect(sky, Paint()..color = const Color(0xFFBBAA8C).withValues(alpha: 0.12 * dust));
    if (alarm) {
      final a = 0.14 + 0.14 * (0.5 + 0.5 * math.sin(t * 4.5));
      canvas.drawRect(sky, Paint()..shader = RadialGradient(radius: 0.95, colors: [Colors.transparent, const Color(0xFFFF4D5A).withValues(alpha: a)], stops: const [0.55, 1]).createShader(sky));
    }
  }

  @override
  bool shouldRepaint(covariant _BasePainter old) => false;
}

extension on _BaseViewState {
  Offset _novaTarget2(Map<String, Object?> v) => _BaseViewState._novaTarget(v);
}
