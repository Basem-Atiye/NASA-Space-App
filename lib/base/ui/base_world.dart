/// The Base Commander base as a side-scrolling 2D world (like the story
/// levels): the Figma buildings stand along the ground and Nova walks, bounds
/// and jumps between them with the same floating joystick.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/figma_art.dart';
import '../../ui/kit.dart';
import '../../ui/line_icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/game_controls.dart';
import '../../world/characters.dart';
import '../base_strip.dart';

BaseModule moduleOf(Spot s) => switch (s) {
      Spot.power => BaseModule.power,
      Spot.greenhouse => BaseModule.greenhouse,
      Spot.habitat => BaseModule.habitat,
      Spot.recycler => BaseModule.recycler,
      Spot.lab => BaseModule.lab,
    };

/// How a building from the Figma picture is placed on the strip: its middle
/// and its foot in the picture's units, its top, and a size factor.
class _Art {
  final double cx, foot, top, size;
  const _Art(this.cx, this.foot, this.top, this.size);
}

const _art = <Spot, _Art>{
  Spot.power: _Art(66.5, 138, 39, 0.78),
  Spot.greenhouse: _Art(87, 233, 186, 1),
  Spot.habitat: _Art(195, 164, 100, 1),
  Spot.recycler: _Art(296, 233, 176, 1),
  Spot.lab: _Art(326, 156, 62, 0.8),
};

/// Sizes for one frame. Everything scales with the card's height.
class StripGeo {
  final Size size;
  final double cam;
  StripGeo(this.size, this.cam);

  double get u => size.height / 340;
  double get ppm => 26 * u; // pixels per metre
  double get groundY => size.height * 0.8;
  double get novaScale => 1.0 * u; // Nova is about 100 px tall at 340 px
  double get artScale => 1.9 * u;
  double get viewMetres => size.width / ppm;

  double sx(double m) => (m - cam) * ppm + size.width / 2;
  double mAt(double px) => cam + (px - size.width / 2) / ppm;

  /// Where a building is drawn on screen.
  Rect artRect(Spot s) {
    final a = _art[s]!;
    final k = artScale * a.size;
    final w = (_halfUnits(s) * 2) * k;
    final h = (a.foot - a.top) * k;
    final x = sx(spotX[s]!);
    final foot = groundY - 10 * u;
    return Rect.fromLTWH(x - w / 2, foot - h, w, h);
  }

  static double _halfUnits(Spot s) => switch (s) {
        Spot.power => 48.5,
        Spot.greenhouse => 49,
        Spot.habitat => 61,
        Spot.recycler => 44,
        Spot.lab => 44,
      };

  /// Nova's feet on screen.
  Offset feet(BaseStrip st) => Offset(sx(st.x), groundY - st.world.novaY * ppm * 0.8);

  /// The box around Nova (for taps).
  Rect novaBox(BaseStrip st) {
    final f = feet(st);
    final s = novaScale;
    return Rect.fromLTRB(f.dx - 30 * s, f.dy - 104 * s, f.dx + 30 * s, f.dy + 4);
  }
}

Paint _p(Color c) => Paint()..color = c;

/// Paints the whole strip for one frame.
void paintBaseStrip(
  Canvas c,
  Size size,
  BaseStrip st,
  BaseLook look, {
  required Set<Spot> built,
  Spot? alert,
  String? alertLabel,
  Spot? near,
  bool reducedMotion = false,
}) {
  final g = StripGeo(size, st.cam);
  final u = g.u;
  final t = look.t;
  final mars = look.mars;
  final gy = g.groundY;
  c.save();
  c.clipRect(Offset.zero & size);

  // ---- sky
  final skyTop = look.night ? const Color(0xFF050A1E) : (mars ? const Color(0xFF1B1030) : const Color(0xFF0A1331));
  final skyLow = look.night ? const Color(0xFF0B1030) : (mars ? const Color(0xFF3A2040) : const Color(0xFF1B1D4A));
  c.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skyTop, skyLow]).createShader(Offset.zero & size));
  final rnd = math.Random(11);
  final starShift = st.cam * g.ppm * 0.04;
  for (var i = 0; i < 46; i++) {
    final x = (rnd.nextDouble() * size.width * 1.6 - starShift) % (size.width * 1.6);
    final y = rnd.nextDouble() * gy * 0.62;
    final a = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(t * (0.8 + rnd.nextDouble()) + i));
    c.drawCircle(Offset(x, y), (0.7 + rnd.nextDouble() * 0.9) * u, _p(Colors.white.withValues(alpha: a)));
  }
  if (!mars) {
    paintEarthBall(c, Offset(size.width - 34 * u, gy * 0.33), 14 * u);
  } else {
    c.drawCircle(Offset(size.width - 34 * u, gy * 0.33), 2.2 * u, _p(const Color(0xFF8FB8FF)));
  }
  if (look.storm) {
    final o = Offset(size.width * 0.5, -size.height * 0.2);
    final r = size.width;
    c.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [const Color(0xFFFF8A3D).withValues(alpha: 0.32 + 0.08 * math.sin(t * 3)), const Color(0x00FF8A3D)]).createShader(Rect.fromCircle(center: o, radius: r)));
  }

  // ---- hills, far then near (they slide slower than the ground)
  final far = mars ? const Color(0xFF5A2E3A) : const Color(0xFF3A3266);
  final mid = mars ? const Color(0xFF6A3434) : const Color(0xFF433C72);
  void ridge(double base, double amp, double shift, double f1, Color col) {
    final p = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      final w = (x + shift) / u;
      final y = base - amp * (0.55 + 0.25 * math.sin(w * f1) + 0.2 * math.sin(w * f1 * 2.7 + 1.3));
      p.lineTo(x, y);
    }
    p
      ..lineTo(size.width, size.height)
      ..close();
    c.drawPath(p, _p(col));
  }

  ridge(gy - 74 * u, 46 * u, st.cam * g.ppm * 0.18, 0.012, far);
  ridge(gy - 34 * u, 26 * u, st.cam * g.ppm * 0.45, 0.02, mid);

  // ---- the ground
  final ground = mars ? const Color(0xFF7A3E3A) : const Color(0xFF4A4378);
  final groundLow = mars ? const Color(0xFF5E3030) : const Color(0xFF3B3468);
  final top = gy - 30 * u;
  final gr = Rect.fromLTRB(0, top, size.width, size.height);
  c.drawRect(gr, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ground, groundLow]).createShader(gr));
  c.drawRect(Rect.fromLTWH(0, top, size.width, 2 * u), _p(Colors.white.withValues(alpha: 0.05)));
  // craters and stones, fixed to the ground
  final crater = mars ? const Color(0xFF64302F) : const Color(0xFF3E3768);
  for (var m = -2.0; m < stripLength + 2; m += 2.6) {
    final h = _hash(m);
    final x = g.sx(m + h * 1.8);
    if (x < -60 || x > size.width + 60) continue;
    final y = top + 12 * u + _hash(m + 7) * (size.height - top - 18 * u);
    final w = (14 + 36 * _hash(m + 3)) * u;
    if (_hash(m + 5) > 0.35) {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.26), _p(crater));
      c.drawArc(Rect.fromCenter(center: Offset(x, y + 1 * u), width: w, height: w * 0.26), 0.2, math.pi - 0.4, false, Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * u);
    } else {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * 0.3, height: w * 0.16), _p(mars ? const Color(0xFF8A4A42) : const Color(0xFF5A5290)));
    }
  }

  // ---- a pipe joins the buildings
  final order = Spot.values.where(built.contains).toList();
  if (order.length > 1) {
    final y = gy - 16 * u;
    c.drawLine(Offset(g.sx(spotX[order.first]!), y), Offset(g.sx(spotX[order.last]!), y), Paint()
      ..color = const Color(0xFFB9CBC6)
      ..strokeWidth = 7 * u
      ..strokeCap = StrokeCap.round);
    c.drawLine(Offset(g.sx(spotX[order.first]!), y - 2 * u), Offset(g.sx(spotX[order.last]!), y - 2 * u), Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5 * u);
  }

  // ---- the buildings (ones not built yet show as a faint blueprint)
  for (final s in Spot.values) {
    final r = g.artRect(s);
    if (r.right < -40 || r.left > size.width + 40) continue;
    final isBuilt = built.contains(s);
    final a = _art[s]!;
    final k = g.artScale * a.size;
    // a soft glow on the ground under the building Nova can use
    if (near == s && isBuilt) {
      final glow = Rect.fromCenter(center: Offset(r.center.dx, gy - 8 * u), width: r.width * 1.05, height: 26 * u);
      c.drawOval(glow, Paint()..shader = RadialGradient(colors: [moduleColor(moduleOf(s)).withValues(alpha: 0.45), moduleColor(moduleOf(s)).withValues(alpha: 0)]).createShader(glow));
    }
    c.save();
    if (!isBuilt) c.saveLayer(r.inflate(30 * u), _p(Colors.white.withValues(alpha: 0.16)));
    c.translate(r.center.dx - a.cx * k, r.bottom - a.foot * k);
    c.scale(k);
    final l = BaseLook(
      t: t,
      power: look.power,
      greenhouse: look.greenhouse,
      water: look.water,
      air: look.air,
      shield: look.shield,
      dust: look.dust,
      night: look.night,
      storm: look.storm,
      leak: look.leak,
      mars: mars,
    );
    switch (s) {
      case Spot.power:
        paintPowerModule(c, l);
      case Spot.greenhouse:
        paintGreenhouseModule(c, l);
      case Spot.habitat:
        paintHabitatModule(c, l);
      case Spot.recycler:
        paintRecyclerModule(c, l);
      case Spot.lab:
        paintLabModule(c, l);
    }
    if (!isBuilt) c.restore();
    c.restore();
    // the radiation shield: a clear glowing bubble over the habitat
    if (s == Spot.habitat && isBuilt && look.shield > 0.05) {
      final dome = Rect.fromCenter(center: Offset(r.center.dx, r.bottom), width: r.width * 1.22, height: r.height * 2.5);
      final k2 = look.shield.clamp(0.0, 1.0);
      c.drawArc(dome, math.pi, math.pi, true, _p(C.yellow.withValues(alpha: 0.07 + 0.06 * k2)));
      c.drawArc(dome, math.pi, math.pi, false, Paint()
        ..color = C.yellow.withValues(alpha: 0.35 + 0.35 * k2 + 0.1 * math.sin(t * 2.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * u);
      // a moving shimmer on the bubble
      final a0 = math.pi + ((t * 0.35) % 1.0) * math.pi;
      c.drawArc(dome.deflate(3 * u), a0, 0.35, false, Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * k2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6 * u);
    }
    if (!isBuilt) {
      // orange cones: built in a later mission
      for (final dx in [-0.32, 0.32]) {
        final cx = r.center.dx + r.width * dx, by = gy - 8 * u;
        c.drawPath(Path()..moveTo(cx - 6 * u, by)..lineTo(cx, by - 16 * u)..lineTo(cx + 6 * u, by)..close(), _p(C.orange));
        c.drawRect(Rect.fromLTRB(cx - 3.6 * u, by - 9 * u, cx + 3.6 * u, by - 6.5 * u), _p(Colors.white));
      }
    }
  }

  if (look.night) c.drawRect(Offset.zero & size, _p(const Color(0x40050A1E)));

  // ---- boot prints and dust grains
  final dust = mars ? const Color(0xFF4E2526) : const Color(0xFF2F2958);
  for (final (x, dir, age) in st.prints) {
    final px = g.sx(x);
    if (px < -10 || px > size.width + 10) continue;
    final a = (1 - age / 14).clamp(0.0, 1.0) * 0.6;
    c.drawOval(Rect.fromCenter(center: Offset(px + dir * 2 * u, gy + 3 * u), width: 9 * u, height: 3.2 * u), _p(dust.withValues(alpha: a)));
  }
  final grainCol = mars ? const Color(0xFFD9A08A) : const Color(0xFFD6D0E8);
  for (final gr in st.grains) {
    c.drawCircle(Offset(g.sx(gr.x), gy - gr.y * g.ppm * 0.45), gr.size * 1.3 * u, _p(grainCol.withValues(alpha: (gr.life / 1.4).clamp(0.0, 1.0) * 0.8)));
  }

  // ---- markers over the buildings, and the alert label
  for (final s in Spot.values) {
    final r = g.artRect(s);
    if (r.right < -40 || r.left > size.width + 40) continue;
    final isBuilt = built.contains(s);
    final m = moduleOf(s);
    final col = isBuilt ? moduleColor(m) : C.dim;
    final o = Offset(r.center.dx, r.top - 22 * u);
    final pulse = alert == s ? 1 + 0.12 * math.sin(t * 6) : (near == s ? 1.08 : 1.0);
    final rad = 15 * u * pulse;
    c.drawCircle(o, rad, _p(Color.alphaBlend(col.withValues(alpha: 0.22), const Color(0xFF16194A))));
    c.drawCircle(o, rad, Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = (near == s ? 3 : 2) * u);
    paintLineIcon(c, isBuilt ? moduleIcon(m) : Ln.lock, o - Offset(8 * u, 8 * u), 16 * u, col, stroke: 2.2);
    if (alert == s && alertLabel != null) {
      final tp = TextPainter(
        text: TextSpan(text: alertLabel, style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 14 * u, color: C.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + 40 * u, h = 30 * u;
      final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: o - Offset(0, rad + 22 * u), width: w, height: h), Radius.circular(h / 2));
      c.drawRRect(pill, _p(C.yellow));
      c.drawPath(
        Path()
          ..moveTo(o.dx - 6 * u, pill.bottom - 1)
          ..lineTo(o.dx, pill.bottom + 6 * u)
          ..lineTo(o.dx + 6 * u, pill.bottom - 1)
          ..close(),
        _p(C.yellow),
      );
      paintLineIcon(c, Ln.alert, Offset(pill.left + 10 * u, pill.center.dy - 8 * u), 16 * u, C.ink, stroke: 2.4);
      tp.paint(c, Offset(pill.left + 30 * u, pill.center.dy - tp.height / 2));
    }
  }

  // ---- Nova
  if (st.visible > 0.02) {
    final f = g.feet(st);
    final s = g.novaScale;
    final lift = st.world.novaY * g.ppm * 0.8;
    final air = (lift / (60 * u)).clamp(0.0, 1.0);
    c.drawOval(Rect.fromCenter(center: Offset(f.dx, gy + 1 * u), width: 46 * s * (1 - 0.45 * air), height: 8 * s * (1 - 0.45 * air)), _p(Colors.black.withValues(alpha: 0.3 * st.visible * (1 - 0.5 * air))));
    if (look.night) {
      final head = f - Offset(0, 86 * s);
      final dir = st.world.facing.toDouble();
      final beam = Path()
        ..moveTo(head.dx + dir * 8 * s, head.dy)
        ..lineTo(head.dx + dir * 170 * u, head.dy + 50 * u)
        ..lineTo(head.dx + dir * 170 * u, head.dy + 110 * u)
        ..close();
      c.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: dir > 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: [const Color(0xFFFFF3C4).withValues(alpha: 0.3 * st.visible), const Color(0x00FFF3C4)],
          ).createShader(beam.getBounds()),
      );
    }
    c.save();
    c.translate(f.dx, f.dy);
    if (st.visible < 1) c.saveLayer(Rect.fromLTRB(-70 * s, -120 * s, 70 * s, 10 * s), _p(Colors.white.withValues(alpha: st.visible)));
    c.scale(st.world.facing * s, s);
    paintNova(c, _pose(st, t, worried: alert != null));
    if (st.visible < 1) c.restore();
    c.restore();
  }

  // ---- a few stones in front of everything, for depth
  for (var m = 1.3; m < stripLength; m += 9.7) {
    final x = g.sx(m);
    if (x < -40 || x > size.width + 40) continue;
    final w = (16 + 14 * _hash(m)) * u;
    final y = size.height - (6 + 10 * _hash(m + 2)) * u;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.45), _p(mars ? const Color(0xFF8A4A42) : const Color(0xFF5E5690)));
    c.drawOval(Rect.fromCenter(center: Offset(x - w * 0.12, y - w * 0.08), width: w * 0.5, height: w * 0.16), _p(Colors.white.withValues(alpha: 0.12)));
  }

  // ---- what Nova says
  final line = st.saying;
  if (line != null && st.visible > 0.5) {
    final head = g.feet(st) - Offset(0, 112 * g.novaScale);
    final at = Offset(head.dx.clamp(100.0, size.width - 100), math.max(head.dy, 70 * u));
    paintBubble(c, at, line, st.sayAge, st.sayFor, maxWidth: math.min(230, size.width - 40));
  }
  c.restore();
}

NovaPose _pose(BaseStrip st, double t, {bool worried = false}) {
  final w = st.world;
  var a = switch (st.emote) {
    StripEmote.work => NovaAction.work,
    StripEmote.kneel => NovaAction.kneel,
    StripEmote.cheer => NovaAction.cheer,
    StripEmote.wave => NovaAction.wave,
    null => w.idle > 7 ? NovaAction.wave : NovaAction.idle,
  };
  if (w.walking || w.airborne) a = NovaAction.walk;
  return NovaPose(
    action: a,
    mood: st.emote == StripEmote.cheer ? NovaMood.happy : (worried ? NovaMood.worried : NovaMood.calm),
    phase: w.walkPhase,
    t: t,
    air: w.airborne,
    sprint: w.sprinting,
    land: st.landLeft,
    rise: w.vy,
  );
}

double _hash(double v) {
  final s = math.sin(v * 12.9898 + 78.233) * 43758.5453;
  return s - s.floorToDouble();
}

/// A rounded speech bubble with a little tail, pointing down at [at].
void paintBubble(Canvas c, Offset at, String text, double life, double left, {double maxWidth = 220}) {
  final pop = Curves.easeOutBack.transform((life * 5).clamp(0.0, 1.0));
  final fade = math.min(life * 6, left * 4).clamp(0.0, 1.0);
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 14, height: 1.2, color: C.ink.withValues(alpha: fade))),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
  )..layout(maxWidth: maxWidth);
  final w = tp.width + 24, h = tp.height + 14;
  final r = Rect.fromCenter(center: at + Offset(0, -h / 2 - 9), width: w, height: h);
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(pop);
  c.translate(-at.dx, -at.dy);
  final paint = _p(C.frozen.withValues(alpha: fade));
  c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 3)), const Radius.circular(15)), _p(Colors.black.withValues(alpha: 0.2 * fade)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(15)), paint);
  c.drawPath(
    Path()
      ..moveTo(at.dx - 7, r.bottom - 1)
      ..lineTo(at.dx, at.dy)
      ..lineTo(at.dx + 7, r.bottom - 1)
      ..close(),
    paint,
  );
  tp.paint(c, Offset(r.center.dx - tp.width / 2, r.top + 7));
  c.restore();
}

// ======================================================================= THE WIDGET

/// The playable base: the picture, the joystick, the USE/JUMP button, a
/// mini-map and arrows to buildings that need you but are off screen.
class BaseWorldView extends StatelessWidget {
  final BaseStrip strip;
  final ValueNotifier<double> t;
  final BaseLook Function() look;
  final Set<Spot> built;
  final Spot? Function() alert;
  final String? alertLabel;
  final Widget? banner;
  final bool enabled;
  final bool showHint;
  final ValueChanged<Spot> onBuilding;
  final ValueChanged<Spot> onUse;
  final ValueChanged<Spot> onTravel;
  final ValueChanged<double> onGround;
  final VoidCallback onNova;
  final VoidCallback onJump;
  final ValueChanged<double> onSteer;
  final ValueChanged<bool> onSprint;
  final ValueChanged<Size>? onSize;

  const BaseWorldView({
    super.key,
    required this.strip,
    required this.t,
    required this.look,
    required this.built,
    required this.alert,
    required this.onBuilding,
    required this.onUse,
    required this.onTravel,
    required this.onGround,
    required this.onNova,
    required this.onJump,
    required this.onSteer,
    required this.onSprint,
    this.alertLabel,
    this.banner,
    this.enabled = true,
    this.showHint = false,
    this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      onSize?.call(size);
      final u = size.height / 340;
      return Stack(children: [
        // the world itself
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled
                ? (d) {
                    final g = StripGeo(size, strip.cam);
                    final p = d.localPosition;
                    if (strip.visible > 0.5 && g.novaBox(strip).inflate(8).contains(p)) return onNova();
                    for (final s in Spot.values) {
                      final r = g.artRect(s).inflate(6);
                      final marker = Rect.fromCircle(center: Offset(r.center.dx, r.top - 16 * u), radius: 22 * u);
                      if (r.contains(p) || marker.contains(p)) return built.contains(s) ? onBuilding(s) : onTravel(s);
                    }
                    onGround(g.mAt(p.dx));
                  }
                : null,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _StripPainter(strip, t, look, built, alert, alertLabel),
              ),
            ),
          ),
        ),
        // the joystick appears where the thumb lands (left side)
        Positioned(
          left: 0,
          bottom: 0,
          width: size.width * 0.55,
          height: math.min(200.0, size.height * 0.6),
          child: ValueListenableBuilder<double>(
            valueListenable: t,
            builder: (context, _, __) => FloatingStick(enabled: enabled && !strip.inside, sprinting: strip.world.sprinting, onChanged: onSteer, onSprint: onSprint, onSwipeUp: onJump),
          ),
        ),
        // top: the banner and the mini-map
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (banner != null) banner!,
            const SizedBox(height: 8),
            Center(
              child: ValueListenableBuilder<double>(
                valueListenable: t,
                builder: (context, _, __) => _MiniMap(strip: strip, built: built, alert: alert(), viewMetres: StripGeo(size, strip.cam).viewMetres, onTap: onTravel),
              ),
            ),
          ]),
        ),
        // per-frame bits: the USE / JUMP button, off-screen arrows, the hint
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: t,
            builder: (context, _, __) {
              final g = StripGeo(size, strip.cam);
              final near = strip.nearIn(built);
              final a = alert();
              final ax = a == null ? null : g.sx(spotX[a]!);
              final off = ax == null ? 0 : (ax < 0 ? -1 : (ax > size.width ? 1 : 0));
              return Stack(children: [
                if (off != 0)
                  Positioned(
                    left: off < 0 ? 10 : null,
                    right: off > 0 ? 10 : null,
                    top: g.groundY - 190 * u,
                    child: _EdgeArrow(label: alertLabel ?? 'Help', right: off > 0, onTap: () => onTravel(a!)),
                  ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: _UseButton(
                    spot: strip.inside ? null : near,
                    onTap: !enabled || strip.inside ? null : (near != null ? () => onUse(near) : onJump),
                  ),
                ),
                if (showHint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14)),
                          child: Text('Drag to walk · push far to sprint', style: T.bodySmall.copyWith(fontSize: 12, color: C.frozen)),
                        ),
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]);
    });
  }
}

class _StripPainter extends CustomPainter {
  final BaseStrip strip;
  final ValueNotifier<double> t;
  final BaseLook Function() look;
  final Set<Spot> built;
  final Spot? Function() alert;
  final String? alertLabel;
  _StripPainter(this.strip, this.t, this.look, this.built, this.alert, this.alertLabel) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    paintBaseStrip(canvas, size, strip, look(), built: built, alert: alert(), alertLabel: alertLabel, near: strip.nearIn(built));
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) => true;
}

/// The round button: USE when Nova stands at a building, JUMP otherwise.
class _UseButton extends StatelessWidget {
  final Spot? spot;
  final VoidCallback? onTap;
  const _UseButton({this.spot, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = spot;
    final face = s == null ? C.raised : moduleColor(moduleOf(s));
    final edge = Color.lerp(face, Colors.black, 0.35)!;
    final fg = s == null ? C.frozen : C.ink;
    const d = 74.0;
    return Semantics(
      button: true,
      label: s == null ? 'Jump' : 'Use',
      child: TapScale(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: onTap == null ? 0.4 : 1,
          child: SizedBox(
            width: d,
            height: d + 5,
            child: Stack(children: [
              Positioned(left: 0, right: 0, bottom: 0, height: d, child: DecoratedBox(decoration: BoxDecoration(color: edge, shape: BoxShape.circle))),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: d,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  decoration: BoxDecoration(color: face, shape: BoxShape.circle, boxShadow: s == null ? null : [BoxShadow(color: face.withValues(alpha: 0.5), blurRadius: 18)]),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LineIcon(s == null ? Ln.up : moduleIcon(moduleOf(s)), size: 22, color: fg, stroke: 2.4),
                    const SizedBox(height: 2),
                    Text(s == null ? 'JUMP' : 'USE', style: T.button.copyWith(fontSize: 13, color: fg, letterSpacing: 1)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A pill at the screen edge pointing to a building that needs you.
class _EdgeArrow extends StatelessWidget {
  final String label;
  final bool right;
  final VoidCallback onTap;
  const _EdgeArrow({required this.label, required this.right, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final arrow = LineIcon(right ? Ln.next : Ln.back, size: 16, color: C.ink, stroke: 2.6);
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: C.yellow.withValues(alpha: 0.45), blurRadius: 14)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!right) ...[arrow, const SizedBox(width: 4)],
          Text(label, style: T.h3.copyWith(fontSize: 13.5, color: C.ink)),
          if (right) ...[const SizedBox(width: 4), arrow],
        ]),
      ),
    );
  }
}

/// A small map of the whole strip: the buildings, the part on screen and
/// Nova. Tap a building's dot to walk there.
class _MiniMap extends StatelessWidget {
  final BaseStrip strip;
  final Set<Spot> built;
  final Spot? alert;
  final double viewMetres;
  final ValueChanged<Spot> onTap;
  const _MiniMap({required this.strip, required this.built, required this.alert, required this.viewMetres, required this.onTap});

  static const w = 210.0, h = 26.0, pad = 14.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final m = (d.localPosition.dx - pad) / (w - pad * 2) * stripLength;
        Spot? best;
        var bd = 6.0;
        for (final s in Spot.values) {
          final dd = (spotX[s]! - m).abs();
          if (dd < bd) {
            bd = dd;
            best = s;
          }
        }
        if (best != null) onTap(best);
      },
      child: CustomPaint(size: const Size(w, h), painter: _MiniMapPainter(strip, built, alert, viewMetres)),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final BaseStrip strip;
  final Set<Spot> built;
  final Spot? alert;
  final double viewMetres;
  _MiniMapPainter(this.strip, this.built, this.alert, this.viewMetres);

  @override
  void paint(Canvas c, Size size) {
    const pad = _MiniMap.pad;
    final span = size.width - pad * 2;
    double x(double m) => pad + m / stripLength * span;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    c.drawRRect(r, _p(C.ink.withValues(alpha: 0.78)));
    // the part of the base on screen
    final a = x(strip.cam - viewMetres / 2), b = x(strip.cam + viewMetres / 2);
    c.drawRRect(RRect.fromLTRBR(a.clamp(3.0, size.width - 3), 4, b.clamp(3.0, size.width - 3), size.height - 4, const Radius.circular(9)), _p(Colors.white.withValues(alpha: 0.1)));
    c.drawLine(Offset(pad, size.height / 2), Offset(size.width - pad, size.height / 2), Paint()
      ..color = C.line
      ..strokeWidth = 2);
    for (final s in Spot.values) {
      final col = built.contains(s) ? moduleColor(moduleOf(s)) : C.dim;
      final o = Offset(x(spotX[s]!), size.height / 2);
      if (alert == s) c.drawCircle(o, 8, _p(C.yellow.withValues(alpha: 0.45)));
      c.drawCircle(o, 4.5, _p(col));
    }
    // Nova
    final n = Offset(x(strip.x), size.height / 2);
    c.drawCircle(n, 6, _p(C.frozen));
    c.drawCircle(n, 3.2, _p(C.sapphire));
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => true;
}
