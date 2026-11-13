/// Space art in the Figma design's flat style: the Moon, Mars, Earth, the
/// supply rocket, asteroids, supply pods and the Moon base itself.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'line_icons.dart';

Paint _p(Color c) => Paint()..color = c;

// ======================================================================= PLANETS

/// The pale Moon with a soft shadow side and grey craters.
void paintMoonBall(Canvas c, Offset o, double r) {
  c.drawCircle(o, r, _p(const Color(0xFFD7E6E2)));
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
  // the shadow side (bottom right)
  c.drawPath(
    Path()
      ..addOval(Rect.fromCircle(center: o, radius: r))
      ..addOval(Rect.fromCircle(center: o + Offset(-r * 0.16, -r * 0.1), radius: r * 0.98))
      ..fillType = PathFillType.evenOdd,
    _p(const Color(0xFFB9CBC6)),
  );
  final crater = _p(const Color(0xFFB9CBC6));
  for (final (x, y, s) in const [(-0.35, -0.3, 0.22), (0.3, -0.35, 0.12), (0.25, 0.22, 0.28), (-0.38, 0.32, 0.12), (0.62, -0.05, 0.08)]) {
    c.drawCircle(o + Offset(x * r, y * r), s * r, crater);
  }
  c.restore();
}

/// Mars: rusty red with darker bands.
void paintMarsBall(Canvas c, Offset o, double r, {bool locked = false}) {
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
  c.drawCircle(o, r, _p(const Color(0xFFB4594A)));
  final band = _p(const Color(0xFF8E3F36));
  c.drawOval(Rect.fromCenter(center: o + Offset(-r * 0.1, -r * 0.45), width: r * 1.6, height: r * 0.28), band);
  c.drawOval(Rect.fromCenter(center: o + Offset(r * 0.2, r * 0.05), width: r * 1.8, height: r * 0.22), band);
  c.drawOval(Rect.fromCenter(center: o + Offset(-r * 0.2, r * 0.5), width: r * 1.4, height: r * 0.24), band);
  c.drawCircle(o + Offset(r * 0.35, -r * 0.15), r * 0.12, _p(const Color(0xFF7A362F)));
  c.drawPath(
    Path()
      ..addOval(Rect.fromCircle(center: o, radius: r))
      ..addOval(Rect.fromCircle(center: o + Offset(-r * 0.18, -r * 0.12), radius: r * 0.98))
      ..fillType = PathFillType.evenOdd,
    _p(const Color(0x55000000)),
  );
  if (locked) c.drawCircle(o, r, _p(const Color(0x553C3664)));
  c.restore();
}

/// Earth: sapphire seas, green continents, a thin bright edge.
void paintEarthBall(Canvas c, Offset o, double r, {double spin = 0}) {
  c.drawCircle(o, r * 1.06, _p(const Color(0xFF2B4FE0)));
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
  c.drawCircle(o, r, _p(const Color(0xFF405FFA)));
  final land = _p(const Color(0xFF3DDC97));
  final dx = (spin * r * 0.4) % (r * 2.4);
  for (final k in [-1, 0, 1]) {
    final ox = o.dx - r * 0.2 + dx + k * r * 2.4;
    c.drawPath(
      Path()
        ..moveTo(ox - r * 0.5, o.dy - r * 0.6)
        ..cubicTo(ox - r * 0.1, o.dy - r * 0.9, ox + r * 0.35, o.dy - r * 0.55, ox + r * 0.05, o.dy - r * 0.15)
        ..cubicTo(ox - r * 0.2, o.dy + r * 0.1, ox - r * 0.65, o.dy - r * 0.1, ox - r * 0.5, o.dy - r * 0.6),
      land,
    );
    c.drawPath(
      Path()
        ..moveTo(ox - r * 0.7, o.dy + r * 0.25)
        ..cubicTo(ox - r * 0.4, o.dy + r * 0.05, ox - r * 0.1, o.dy + r * 0.5, ox - r * 0.35, o.dy + r * 0.85)
        ..cubicTo(ox - r * 0.6, o.dy + r * 0.8, ox - r * 0.85, o.dy + r * 0.5, ox - r * 0.7, o.dy + r * 0.25),
      land,
    );
  }
  c.restore();
}

/// A purple asteroid with craters.
void paintAsteroid(Canvas c, Offset o, double r, {double spin = 0, int seed = 0}) {
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(spin);
  final rnd = math.Random(seed);
  final path = Path();
  const n = 9;
  for (var i = 0; i <= n; i++) {
    final a = i / n * math.pi * 2;
    final rr = r * (0.88 + rnd.nextDouble() * 0.14);
    final pt = Offset(math.cos(a) * rr, math.sin(a) * rr);
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  c.drawPath(path, _p(const Color(0xFF7E70B0)));
  c.save();
  c.clipPath(path);
  c.drawCircle(Offset(r * 0.35, r * 0.1), r * 0.85, _p(const Color(0xFF6A5D9C)));
  c.drawCircle(Offset(-r * 0.15, -r * 0.12), r * 0.78, _p(const Color(0xFF7E70B0)));
  c.restore();
  final crater = _p(const Color(0xFF5E5190));
  c.drawCircle(Offset(-r * 0.32, -r * 0.2), r * 0.17, crater);
  c.drawCircle(Offset(r * 0.25, r * 0.3), r * 0.12, crater);
  c.drawCircle(Offset(-r * 0.05, r * 0.42), r * 0.08, crater);
  c.restore();
}

// ======================================================================= ROCKET & PODS

/// The supply rocket pointing up, centred on its body. [flame] 0..1.
void paintRocket(Canvas c, Offset o, double h, {double flame = 1, double t = 0, double tilt = 0}) {
  final s = h / 130;
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(tilt);
  c.scale(s);
  // flame
  if (flame > 0) {
    final f = 1 + 0.15 * math.sin(t * 40) * flame;
    final fl = Path()
      ..moveTo(-12, 46)
      ..quadraticBezierTo(-10, 46 + 30 * f * flame, 0, 52 + 40 * f * flame)
      ..quadraticBezierTo(10, 46 + 30 * f * flame, 12, 46)
      ..close();
    c.drawPath(fl, _p(const Color(0xFFFF8A3D)));
    final inner = Path()
      ..moveTo(-6, 46)
      ..quadraticBezierTo(-5, 46 + 16 * f * flame, 0, 50 + 22 * f * flame)
      ..quadraticBezierTo(5, 46 + 16 * f * flame, 6, 46)
      ..close();
    c.drawPath(inner, _p(const Color(0xFFFFD23F)));
  }
  // fins
  final fin = _p(const Color(0xFFFF8A3D));
  c.drawPath(Path()..moveTo(-18, 14)..lineTo(-34, 40)..quadraticBezierTo(-34, 50, -24, 48)..lineTo(-16, 40)..close(), fin);
  c.drawPath(Path()..moveTo(18, 14)..lineTo(34, 40)..quadraticBezierTo(34, 50, 24, 48)..lineTo(16, 40)..close(), fin);
  // body
  final body = Path()
    ..moveTo(0, -62)
    ..cubicTo(22, -40, 24, 0, 18, 44)
    ..lineTo(-18, 44)
    ..cubicTo(-24, 0, -22, -40, 0, -62)
    ..close();
  c.drawPath(body, _p(const Color(0xFFF2FFF8)));
  c.save();
  c.clipPath(body);
  c.drawRect(const Rect.fromLTRB(6, -70, 30, 50), _p(const Color(0xFFDCEDE6)));
  // the coral nose
  c.drawRect(const Rect.fromLTRB(-30, -70, 30, -36), _p(const Color(0xFFFF5470)));
  c.restore();
  // engine skirt
  c.drawRRect(RRect.fromLTRBR(-14, 40, 14, 50, const Radius.circular(3)), _p(const Color(0xFF8A86B3)));
  // window
  c.drawCircle(const Offset(0, -12), 12, _p(const Color(0xFF405FFA)));
  c.drawCircle(const Offset(0, -12), 7.5, _p(const Color(0xFF0A1331)));
  c.drawCircle(const Offset(-2.5, -14.5), 2.5, _p(Colors.white.withValues(alpha: 0.7)));
  // a centre fin
  c.drawRRect(RRect.fromLTRBR(-2.5, 18, 2.5, 44, const Radius.circular(2.5)), _p(const Color(0xFF405FFA)));
  c.restore();
}

/// A supply pod: a dark disc with a coloured ring and the supply's icon.
void paintPod(Canvas c, Offset o, double r, Color color, LineIconData icon, {double glow = 1}) {
  c.drawCircle(o, r * 1.35, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.35 * glow), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * 1.35)));
  c.drawCircle(o, r, _p(Color.alphaBlend(color.withValues(alpha: 0.18), const Color(0xFF16194A))));
  c.drawCircle(
    o,
    r,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14,
  );
  c.drawCircle(o + Offset(-r * 0.45, -r * 0.5), r * 0.1, _p(Colors.white.withValues(alpha: 0.6)));
  paintLineIcon(c, icon, o - Offset(r * 0.5, r * 0.5), r, color, stroke: 2.2);
}

// ======================================================================= THE MOON BASE

/// Parts of the base the player can tap.
enum BaseModule { power, habitat, greenhouse, recycler, lab, shield }

/// How the base looks right now (levels 0..1; [alert] makes a module flash).
class BaseLook {
  final double t;
  final double power; // panel output
  final double greenhouse; // growth / production
  final double water; // recycler level
  final double air;
  final double shield;
  final double dust; // dust on the panels
  final bool night;
  final bool storm;
  final bool leak;
  final BaseModule? selected;
  final BaseModule? alert;
  final String? alertLabel;
  final Set<BaseModule> visible;
  final bool markers;
  final bool mars;
  const BaseLook({
    this.t = 0,
    this.power = 0.8,
    this.greenhouse = 0.6,
    this.water = 0.7,
    this.air = 0.8,
    this.shield = 0,
    this.dust = 0,
    this.night = false,
    this.storm = false,
    this.leak = false,
    this.selected,
    this.alert,
    this.alertLabel,
    this.visible = const {BaseModule.power, BaseModule.habitat, BaseModule.greenhouse, BaseModule.recycler, BaseModule.lab},
    this.markers = true,
    this.mars = false,
  });
}

/// The virtual size the base is drawn in (scaled to fit).
const baseSceneSize = Size(390, 280);

/// Where each module sits (for taps), in [baseSceneSize] units.
const baseHotspots = <BaseModule, Rect>{
  BaseModule.power: Rect.fromLTRB(10, 30, 120, 140),
  BaseModule.habitat: Rect.fromLTRB(132, 88, 262, 168),
  BaseModule.lab: Rect.fromLTRB(276, 70, 376, 160),
  BaseModule.greenhouse: Rect.fromLTRB(34, 172, 140, 238),
  BaseModule.recycler: Rect.fromLTRB(246, 170, 346, 236),
};

/// The marker spot (an icon disc) for each module.
const baseMarkers = <BaseModule, Offset>{
  BaseModule.power: Offset(33, 35),
  BaseModule.habitat: Offset(173, 96),
  BaseModule.lab: Offset(315, 118),
  BaseModule.greenhouse: Offset(45, 182),
};

LineIconData moduleIcon(BaseModule m) => switch (m) {
      BaseModule.power => Ln.sun,
      BaseModule.habitat => Ln.home,
      BaseModule.greenhouse => Ln.sprout,
      BaseModule.recycler => Ln.droplet,
      BaseModule.lab => Ln.flask,
      BaseModule.shield => Ln.shield,
    };

Color moduleColor(BaseModule m) => switch (m) {
      BaseModule.power => const Color(0xFFFF8A3D),
      BaseModule.habitat => const Color(0xFF0ABCCA),
      BaseModule.greenhouse => const Color(0xFF3DDC97),
      BaseModule.recycler => const Color(0xFF5B7BFF),
      BaseModule.lab => const Color(0xFFDAFCEE),
      BaseModule.shield => const Color(0xFFFFD23F),
    };

/// Paints the Moon base into [size] (it keeps its proportions, anchored to
/// the bottom). Returns the scale and offset used, for hit-testing.
/// How the base picture fits a box: it fills the width (zooming in only a
/// little when the box is tall) and sits on the bottom edge; extra room on
/// top is sky. Returns the scale and the offset.
(double, Offset) sceneFit(Size size) {
  final s = math.max(size.width / baseSceneSize.width, math.min(size.height / baseSceneSize.height, size.width / (baseSceneSize.width - 24)));
  return (s, Offset((size.width - baseSceneSize.width * s) / 2, size.height - baseSceneSize.height * s));
}

(double, Offset) paintMoonBase(Canvas c, Size size, BaseLook l, {bool sky = true}) {
  final (s, off) = sceneFit(size);
  c.save();
  c.clipRect(Offset.zero & size);
  if (sky) {
    c.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: l.night ? const [Color(0xFF050A1E), Color(0xFF0B1030)] : const [Color(0xFF0A1331), Color(0xFF1B1D4A)]).createShader(Offset.zero & size),
    );
    // stars
    final sp = Paint();
    final rnd = math.Random(4);
    for (var i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * size.width, y = rnd.nextDouble() * size.height * 0.45;
      sp.color = Colors.white.withValues(alpha: 0.4 + 0.4 * math.sin(l.t * 1.3 + i));
      c.drawCircle(Offset(x, y), 1.1, sp);
    }
    // spare sky above the base: Earth hangs low over the Moon's south pole
    if (!l.mars && off.dy > 46) {
      final r = math.min(20.0, off.dy * 0.26);
      paintEarthBall(c, Offset(size.width * 0.78, off.dy * 0.5 + 6), r);
    }
    if (l.storm) {
      final g = Offset(size.width * 0.5, -size.height * 0.1);
      c.drawCircle(g, size.width * 0.9, Paint()..shader = RadialGradient(colors: [const Color(0xFFFF8A3D).withValues(alpha: 0.35 + 0.1 * math.sin(l.t * 3)), const Color(0x00FF8A3D)]).createShader(Rect.fromCircle(center: g, radius: size.width * 0.9)));
    }
  }
  c.translate(off.dx, off.dy);
  c.scale(s);
  final t = l.t;
  final far = l.mars ? const Color(0xFF5A2E3A) : const Color(0xFF3A3266);
  final ground = l.mars ? const Color(0xFF7A3E3A) : const Color(0xFF4A4378);
  final groundLow = l.mars ? const Color(0xFF6A3434) : const Color(0xFF433C72);
  final crater = l.mars ? const Color(0xFF64302F) : const Color(0xFF3E3768);
  // far hill and ground
  c.drawPath(
    Path()
      ..moveTo(-40, 118)
      ..quadraticBezierTo(110, 88, 250, 110)
      ..quadraticBezierTo(330, 120, 430, 86)
      ..lineTo(430, 300)
      ..lineTo(-40, 300)
      ..close(),
    _p(far),
  );
  final gpath = Path()
    ..moveTo(-40, 142)
    ..quadraticBezierTo(190, 112, 430, 138)
    ..lineTo(430, 300)
    ..lineTo(-40, 300)
    ..close();
  c.drawPath(gpath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ground, groundLow]).createShader(const Rect.fromLTRB(0, 112, 390, 300)));
  for (final (x, y, w, h) in const [(240.0, 178.0, 46.0, 10.0), (200.0, 252.0, 86.0, 16.0), (334.0, 262.0, 60.0, 14.0), (52.0, 262.0, 70.0, 14.0), (150.0, 210.0, 30.0, 7.0)]) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), _p(crater));
  }

  void pipe(Offset a, Offset b, [Offset? ctrl]) {
    final path = Path()..moveTo(a.dx, a.dy);
    if (ctrl == null) {
      path.lineTo(b.dx, b.dy);
    } else {
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB9CBC6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  final v = l.visible;
  // pipes between the modules
  if (v.contains(BaseModule.power)) pipe(const Offset(104, 128), const Offset(142, 128));
  if (v.contains(BaseModule.greenhouse)) pipe(const Offset(160, 162), const Offset(108, 196), const Offset(126, 168));
  if (v.contains(BaseModule.recycler)) pipe(const Offset(232, 160), const Offset(270, 184), const Offset(262, 164));
  if (v.contains(BaseModule.lab)) pipe(const Offset(250, 150), const Offset(286, 146));

  // ---- solar panels
  if (v.contains(BaseModule.power)) paintPowerModule(c, l);
  // ---- shield: a soft dome over the habitat when it is powered
  if (l.shield > 0.05) paintShieldDome(c, l);
  // ---- habitat
  if (v.contains(BaseModule.habitat)) paintHabitatModule(c, l);
  // ---- lab with a radio dish
  if (v.contains(BaseModule.lab)) paintLabModule(c, l);
  // ---- greenhouse
  if (v.contains(BaseModule.greenhouse)) paintGreenhouseModule(c, l);
  // ---- water recycler: two tanks
  if (v.contains(BaseModule.recycler)) paintRecyclerModule(c, l);
  // ---- selection / alert ring around a module
  final ring = l.alert ?? l.selected;
  if (ring != null && baseHotspots.containsKey(ring)) {
    final r = baseHotspots[ring]!.inflate(4);
    final color = l.alert != null ? const Color(0xFFFFD23F) : const Color(0xFF0ABCCA);
    _dashedOval(c, Rect.fromCenter(center: r.center + const Offset(0, 6), width: r.width + 2, height: r.height * 0.8), color, t);
  }

  // ---- markers (icon discs) on each module
  if (l.markers) {
    for (final e in baseMarkers.entries) {
      if (!v.contains(e.key)) continue;
      final col = moduleColor(e.key);
      final o = e.value;
      final pulse = l.alert == e.key ? 1 + 0.1 * math.sin(t * 6) : 1.0;
      c.drawCircle(o, 15 * pulse, _p(Color.alphaBlend(col.withValues(alpha: 0.2), const Color(0xFF16194A))));
      c.drawCircle(o, 15 * pulse, Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      paintLineIcon(c, moduleIcon(e.key), o - const Offset(8, 8), 16, col, stroke: 2.2);
    }
  }

  // ---- the label pill over the alert ("Recycler")
  if (l.alert != null && l.alertLabel != null) {
    final o = (baseHotspots[l.alert!]?.topCenter ?? Offset.zero) + const Offset(0, -16);
    final tp = TextPainter(
      text: TextSpan(text: l.alertLabel, style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF091230))),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 40, h = 30.0;
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w, height: h), const Radius.circular(15));
    c.drawRRect(rect, _p(const Color(0xFFFFD23F)));
    paintLineIcon(c, moduleIcon(l.alert!), Offset(rect.left + 9, o.dy - 8), 16, const Color(0xFF091230), stroke: 2.4);
    tp.paint(c, Offset(rect.left + 29, o.dy - tp.height / 2));
  }

  if (l.night) c.drawRect(const Rect.fromLTRB(-40, 0, 430, 300), _p(const Color(0x40050A1E)));
  c.restore();
  return (s, off);
}

void _dashedOval(Canvas c, Rect r, Color color, double t) {
  final p = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;
  const n = 18;
  final spin = t * 0.4;
  for (var i = 0; i < n; i++) {
    final a = spin + i / n * math.pi * 2;
    c.drawArc(r, a, math.pi * 2 / n * 0.55, false, p);
  }
}

/// Which module (if any) is at [local] in a canvas of [size].
BaseModule? baseModuleAt(Offset local, Size size, Set<BaseModule> visible) {
  final (s, off) = sceneFit(size);
  final p = (local - off) / s;
  for (final e in baseHotspots.entries) {
    if (visible.contains(e.key) && e.value.inflate(6).contains(p)) return e.key;
  }
  return null;
}

/// solar panels, drawn in the base picture's units.
void paintPowerModule(Canvas c, BaseLook l) {
  final t = l.t;
  final grey = _p(const Color(0xFFB9CBC6));
  c.drawRect(const Rect.fromLTRB(63.5, 74, 68.5, 130), grey);
  c.drawRRect(RRect.fromLTRBR(56, 126, 76, 138, const Radius.circular(3)), _p(const Color(0xFF6E66A0)));
  final lit = l.night ? 0.45 : 0.75 + 0.25 * l.power;
  final panel = _p(Color.lerp(const Color(0xFF26338F), const Color(0xFF405FFA), lit)!);
  final gridP = Paint()
    ..color = Color.lerp(const Color(0xFF26338F), const Color(0xFF2BA6F0), lit)!
    ..strokeWidth = 1.6;
  final left = Path()..moveTo(18, 46)..lineTo(62, 39)..lineTo(62, 86)..lineTo(18, 93)..close();
  final right = Path()..moveTo(71, 39)..lineTo(115, 46)..lineTo(115, 93)..lineTo(71, 86)..close();
  for (final pnl in [left, right]) {
    c.drawPath(pnl, panel);
  }
  c.drawLine(const Offset(40, 42.5), const Offset(40, 89.5), gridP);
  c.drawLine(const Offset(18, 69.5), const Offset(62, 62.5), gridP);
  c.drawLine(const Offset(93, 42.5), const Offset(93, 89.5), gridP);
  c.drawLine(const Offset(71, 62.5), const Offset(115, 69.5), gridP);
  if (l.dust > 0.05) {
    final d = _p(const Color(0xFFB8A78E).withValues(alpha: 0.75 * l.dust));
    c.drawPath(left, d);
    c.drawPath(right, d);
  }
  // a glint sweeps across the panels when they make power
  if (!l.night && l.dust < 0.5) {
    final k = (t * 0.25) % 1.0;
    final gx = 10 + k * 120;
    c.save();
    c.clipPath(Path()..addPath(left, Offset.zero)..addPath(right, Offset.zero));
    c.drawPath(Path()..moveTo(gx, 30)..lineTo(gx + 10, 30)..lineTo(gx - 6, 100)..lineTo(gx - 16, 100)..close(), _p(Colors.white.withValues(alpha: 0.25)));
    c.restore();
  }
  c.drawCircle(const Offset(66.5, 64), 2.5, _p(const Color(0xFF0ABCCA).withValues(alpha: 0.5 + 0.5 * math.sin(t * 4).abs())));
}

/// shield: a soft dome over the habitat when it is powered, drawn in the base picture's units.
void paintShieldDome(Canvas c, BaseLook l) {

  c.drawOval(
    const Rect.fromLTRB(118, 64, 272, 196),
    Paint()
      ..shader = RadialGradient(colors: [
        const Color(0x00FFD23F),
        const Color(0xFFFFD23F).withValues(alpha: 0.10 * l.shield),
        const Color(0xFFFFD23F).withValues(alpha: 0.35 * l.shield),
      ], stops: const [0, 0.8, 1]).createShader(const Rect.fromLTRB(118, 64, 272, 196)),
  );
}

/// habitat, drawn in the base picture's units.
void paintHabitatModule(Canvas c, BaseLook l) {
  final t = l.t;
  final grey = _p(const Color(0xFFB9CBC6));
  final white = _p(const Color(0xFFF2FFF8));
  final navy = _p(const Color(0xFF0A1331));
  c.drawArc(const Rect.fromLTRB(140, 100, 250, 210), math.pi, math.pi, true, white);
  c.drawRect(const Rect.fromLTRB(150, 126, 240, 131), _p(const Color(0xFFFF8A3D)));
  c.drawCircle(const Offset(195, 116), 16, _p(const Color(0xFF405FFA)));
  c.drawCircle(const Offset(195, 116), 11, l.night ? _p(Color.lerp(const Color(0xFF0A1331), const Color(0xFFFFD23F), 0.6 + 0.2 * math.sin(t * 2))!) : navy);
  c.drawRRect(RRect.fromLTRBR(182, 133, 208, 155, const Radius.circular(5)), _p(const Color(0xFF6E66A0)));
  c.drawRRect(RRect.fromLTRBR(134, 150, 256, 164, const Radius.circular(7)), grey);
  if (l.leak) {
    for (var k = 0; k < 4; k++) {
      final f = (t * 0.8 + k / 4) % 1.0;
      c.drawCircle(Offset(238 + f * 30, 118 - f * 26 + math.sin(f * 8 + k) * 3), 2 + f * 7, _p(const Color(0xFFDAFCEE).withValues(alpha: 0.6 * (1 - f))));
    }
  }
}

/// lab with a radio dish, drawn in the base picture's units.
void paintLabModule(Canvas c, BaseLook l) {
  final t = l.t;
  final grey = _p(const Color(0xFFB9CBC6));
  final white = _p(const Color(0xFFF2FFF8));
  final navy = _p(const Color(0xFF0A1331));
  c.drawLine(const Offset(342, 112), const Offset(342, 92), Paint()
    ..color = const Color(0xFFB9CBC6)
    ..strokeWidth = 4);
  c.save();
  c.translate(340, 80);
  c.rotate(-0.4 + 0.08 * math.sin(t * 0.5));
  c.drawArc(const Rect.fromLTRB(-18, -12, 18, 24), math.pi * 0.1, math.pi * 0.95, true, grey);
  c.restore();
  c.drawCircle(const Offset(343, 82), 3.5, _p(const Color(0xFFFF8A3D)));
  c.drawRRect(RRect.fromLTRBR(282, 110, 370, 156, const Radius.circular(23)), white);
  for (final x in [305.0, 326.0, 347.0]) {
    c.drawCircle(Offset(x, 133), 7, l.night ? _p(const Color(0xFFFFE9A8)) : navy);
  }
}

/// greenhouse, drawn in the base picture's units.
void paintGreenhouseModule(Canvas c, BaseLook l) {
  final t = l.t;
  final grey = _p(const Color(0xFFB9CBC6));
  c.drawRRect(RRect.fromLTRBR(38, 224, 136, 233, const Radius.circular(4.5)), grey);
  final dome = const Rect.fromLTRB(40, 186, 134, 262);
  final glow = l.night ? 0.55 : 0.35;
  c.drawArc(dome, math.pi, math.pi, true, _p(Color.alphaBlend(const Color(0xFF3DDC97).withValues(alpha: glow), const Color(0xFF2B4A62))));
  final rib = Paint()
    ..color = const Color(0xFF3DDC97).withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  c.drawLine(const Offset(87, 186), const Offset(87, 224), rib);
  c.drawArc(const Rect.fromLTRB(56, 186, 118, 262), math.pi, math.pi, false, rib);
  // plants grow with the greenhouse output
  final g = 0.6 + 0.6 * l.greenhouse;
  final plant = _p(Color.lerp(const Color(0xFF7FA07A), const Color(0xFF3DDC97), l.greenhouse)!);
  final dark = _p(const Color(0xFF2FBF83));
  for (final (x, r) in const [(64.0, 7.0), (87.0, 8.5), (110.0, 7.0)]) {
    final sway = math.sin(t * 1.4 + x) * 0.8;
    c.drawCircle(Offset(x + sway, 223 - r * g), r * g, x == 87 ? dark : plant);
  }
  c.drawArc(dome, math.pi, math.pi, false, Paint()
    ..color = const Color(0xFF3DDC97)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3);
}

/// water recycler: two tanks, drawn in the base picture's units.
void paintRecyclerModule(Canvas c, BaseLook l) {
  final grey = _p(const Color(0xFFB9CBC6));
  c.drawRRect(RRect.fromLTRBR(252, 224, 340, 233, const Radius.circular(4.5)), grey);
  c.drawRect(const Rect.fromLTRB(290, 198, 300, 206), grey);
  final tank = Paint()..shader = const LinearGradient(colors: [Color(0xFFF2FFF8), Color(0xFFB9CBC6)]).createShader(const Rect.fromLTRB(256, 176, 336, 226));
  c.drawRRect(RRect.fromLTRBR(258, 176, 292, 226, const Radius.circular(10)), tank);
  c.drawRRect(RRect.fromLTRBR(298, 188, 334, 226, const Radius.circular(10)), tank);
  // the window shows the water level
  final wl = l.water.clamp(0.05, 1.0);
  c.drawRRect(RRect.fromLTRBR(264, 190, 286, 204, const Radius.circular(4)), _p(const Color(0xFF26338F)));
  c.drawRRect(RRect.fromLTRBR(264, 204 - 14 * wl, 286, 204, const Radius.circular(4)), _p(const Color(0xFF405FFA)));
  c.drawRRect(RRect.fromLTRBR(303, 202, 329, 212, const Radius.circular(4)), _p(const Color(0xFF0ABCCA)));
}
