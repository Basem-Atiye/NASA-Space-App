/// The first screen: Nova floats in front of the Moon and waves hello.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../ui/astro_art.dart';
import '../ui/figma_art.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  /// The sky's clock (stars, satellite, shooting stars).
  late final AnimationController _sky = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  /// Nova's idle body: float + wave (kept separate so welcome motion never depends on a nested ticker).
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));

  /// Nova flying in.
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  int _line = 0;
  bool _bubble = false;
  bool _reduced = false;

  static const _hello = ['Hi! I’m Nova.', 'Ready for the Moon?', 'Tap me!'];
  static const _spinLines = ['The Moon has very low gravity!', 'Ice hides in the dark craters.', 'Let’s build a Moon base!'];
  int _spins = 0;

  @override
  void initState() {
    super.initState();
    _life.repeat();
    _sky.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefer the in-app toggle. OS "reduce motion" only skips the fly-in —
    // Nova's idle float/wave still runs so the welcome screen never looks frozen.
    final appReduce = Services.of(context).progress.reducedMotion;
    final osReduce = MediaQuery.of(context).disableAnimations;
    final reduced = appReduce;
    if (reduced == _reduced && _intro.status != AnimationStatus.dismissed) return;
    _reduced = reduced;
    // Idle float/wave always runs on this screen — reduced motion only skips the fly-in.
    if (!_life.isAnimating) _life.repeat();
    if (_reduced || osReduce) {
      _sky.stop();
      _intro.value = 1;
      _bubble = true;
      if (_intro.status == AnimationStatus.dismissed) _cycleHello();
    } else {
      if (!_sky.isAnimating) _sky.repeat();
      if (_intro.status == AnimationStatus.dismissed) {
        _intro.forward().whenComplete(() {
          if (mounted) setState(() => _bubble = true);
          _cycleHello();
        });
      }
    }
  }

  Future<void> _cycleHello() async {
    for (var i = 1; i < _hello.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2800));
      if (!mounted || _spins > 0) return;
      setState(() => _line = i);
    }
  }

  void _tapNova() {
    Services.of(context).audio.tap();
    setState(() {
      _line = -1 - (_spins % _spinLines.length);
      _spins++;
      _bubble = true;
    });
  }

  String get _bubbleText => _line >= 0 ? _hello[_line] : _spinLines[-1 - _line];

  @override
  void dispose() {
    _sky.dispose();
    _life.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _start() {
    final sv = Services.of(context);
    sv.audio.tap();
    if (!sv.progress.rankChosen) {
      // the first time: choose the age group, then the station
      sv.nav.afterRank = Screen.title;
      sv.nav.go(Screen.rank);
    } else {
      sv.nav.go(Screen.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        // the moving sky behind everything
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(_sky, _intro)))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // account and badges, quietly at the top
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(children: [
                    Flexible(child: _Chip(icon: Ln.user, label: sv.session.signedIn ? sv.session.name : 'Guest', onTap: () => sv.nav.go(Screen.account))),
                    const SizedBox(width: 12),
                    const Spacer(),
                    _Chip(icon: Ln.award, label: '${sv.base.earned.length}', onTap: () => sv.nav.go(Screen.badges)),
                    const SizedBox(width: 8),
                    _Chip(icon: Ln.settings, onTap: () => sv.nav.go(Screen.settings)),
                  ]),
                ),
                // the stage: the Moon, its satellite and Nova
                Expanded(child: LayoutBuilder(builder: (context, box) => _stage(box))),
                // the title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: EnterAnim(
                    delayMs: 350,
                    child: Column(children: [
                      const Overline('OPEN BOUNDS', color: C.cyan, size: 12),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, box) => Text('Mission Trainer', textAlign: TextAlign.center, style: T.hero.copyWith(fontSize: math.min(44, box.maxWidth * 0.12), height: 1.05)),
                      ),
                      const SizedBox(height: 10),
                      Text('Run a real Moon base, make smart choices\nand bring your crew home safely.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted, fontSize: 15.5, height: 1.45)),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: EnterAnim(
                    delayMs: 550,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      KitButton(sv.progress.rankChosen ? 'Start' : 'Start your training', icon: Ln.rocket, onTap: _start),
                      const SizedBox(height: 12),
                      KitButton('How to Play', style: KitButtonStyle.secondary, onTap: () => sv.nav.go(Screen.howToPlay)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stage(BoxConstraints box) {
    final w = box.maxWidth, h = box.maxHeight;
    final moon = math.min(w * 0.5, h * 0.55);
    // 15% smaller than the previous welcome size, nudged slightly up.
    final nova = math.min(h * 0.88, 300.0) * 0.85;
    final novaLift = h * 0.05;
    return Stack(clipBehavior: Clip.none, children: [
      // the Moon with its glow and a satellite going round it
      Positioned(
        right: -moon * 0.12,
        top: h * 0.04,
        width: moon,
        height: moon,
        child: RepaintBoundary(child: CustomPaint(painter: _MoonPainter(_sky, _intro))),
      ),
      // Nova flies in, floats, waves, and hops when tapped
      Positioned(
        left: 0,
        right: 0,
        bottom: novaLift,
        height: nova,
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final v = Curves.easeOutCubic.transform(_intro.value);
            return Transform.translate(
              offset: Offset(-w * 0.55 * (1 - v), h * 0.35 * (1 - v)),
              child: Transform.rotate(
                angle: -0.9 * (1 - v),
                child: Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Align(
                    alignment: const Alignment(-0.28, 1),
                    child: Semantics(
                      button: true,
                      label: 'Nova the astronaut. Tap to hear her talk.',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _tapNova,
                        child: CustomPaint(
                          size: Size(nova * 0.95, nova),
                          painter: _NovaPainter(_life),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      // what Nova says
      Positioned(
        left: w * 0.5,
        right: 16,
        top: math.max(0, h - nova - novaLift - 52),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedScale(
            scale: _bubble ? 1 : 0.6,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            alignment: Alignment.bottomLeft,
            child: AnimatedOpacity(
              opacity: _bubble ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: _Bubble(text: _bubbleText),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _NovaPainter extends CustomPainter {
  final Animation<double> life;
  _NovaPainter(this.life) : super(repaint: life);

  @override
  void paint(Canvas canvas, Size size) {
    paintAstronautIdle(canvas, size, life.value, tilt: -0.2, waving: true, floating: true);
  }

  @override
  bool shouldRepaint(covariant _NovaPainter old) => old.life != life;
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _BubbleTail(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: C.text,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, axis: Axis.horizontal, child: c)),
            child: Text(text, key: ValueKey(text), style: T.h3.copyWith(color: C.ink, fontSize: 16, height: 1.2)),
          ),
        ),
      );
}

class _BubbleTail extends CustomPainter {
  const _BubbleTail();
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(16, s.height - 10)
      ..lineTo(10, s.height)
      ..lineTo(32, s.height - 10)
      ..close();
    c.drawPath(p, Paint()..color = C.text);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  final LineIconData icon;
  final String? label;
  final VoidCallback onTap;
  const _Chip({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
        onTap: onTap,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 40),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.raised.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
          child: label == null
              ? LineIcon(icon, size: 18, color: C.frozen)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  LineIcon(icon, size: 17, color: C.cyan),
                  const SizedBox(width: 7),
                  Flexible(child: Text(label!, style: T.h3.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
        ),
      );
}

// ======================================================================= THE SKY

class _SkyPainter extends CustomPainter {
  final Animation<double> sky, intro;
  _SkyPainter(this.sky, this.intro) : super(repaint: Listenable.merge([sky, intro]));

  @override
  void paint(Canvas c, Size size) {
    final t = sky.value * 24; // seconds
    final r = Offset.zero & size;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF070D26), Color(0xFF0A1331), Color(0xFF171B41)], stops: [0, 0.55, 1]).createShader(r));
    // soft coloured glows (far-away gas clouds)
    void glow(Offset o, double rad, Color col) => c.drawCircle(o, rad, Paint()..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: rad)));
    glow(Offset(size.width * 0.15, size.height * 0.22), size.width * 0.6, const Color(0x1A5B7BFF));
    glow(Offset(size.width * 0.95, size.height * 0.62), size.width * 0.55, const Color(0x140ABCCA));
    // three layers of stars: far ones drift slowest
    final fade = Curves.easeOut.transform(intro.value.clamp(0.0, 1.0));
    final rnd = math.Random(4);
    for (var layer = 0; layer < 3; layer++) {
      final speed = [1.2, 2.6, 4.4][layer];
      final n = [70, 36, 16][layer];
      for (var i = 0; i < n; i++) {
        final x0 = rnd.nextDouble() * size.width, y = rnd.nextDouble() * size.height * 0.92;
        final tw = rnd.nextDouble() * math.pi * 2, sp = 0.6 + rnd.nextDouble() * 1.6;
        final x = (x0 - t * speed) % size.width;
        final a = (0.25 + 0.2 * layer + 0.3 * (0.5 + 0.5 * math.sin(t * sp + tw))) * fade;
        final rad = [0.7, 1.1, 1.6][layer];
        c.drawCircle(Offset(x, y), rad, Paint()..color = Colors.white.withValues(alpha: a.clamp(0.0, 1.0)));
        if (layer == 2 && i % 4 == 0) {
          // a few bright stars sparkle
          paintSparkle(c, Offset(x, y), 5 * (0.6 + 0.4 * math.sin(t * sp + tw)), C.yellow.withValues(alpha: 0.7 * fade));
        }
      }
    }
    // a shooting star every 8 seconds
    final k = (t % 8) / 8;
    if (k < 0.11 && fade > 0.9) {
      final v = k / 0.11;
      final start = Offset(size.width * (0.2 + 0.5 * ((t / 8).floor() % 3) / 2), size.height * 0.08);
      final head = start + Offset(size.width * 0.45 * v, size.height * 0.16 * v);
      final tail = head - Offset(size.width * 0.12, size.height * 0.045);
      c.drawLine(tail, head, Paint()
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.9 * (1 - v))]).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }
    // Earth, small and far away
    paintEarthBall(c, Offset(size.width * 0.12, size.height * 0.2), math.min(size.width, 460) * 0.045, spin: t * 0.02);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}

class _MoonPainter extends CustomPainter {
  final Animation<double> sky, intro;
  _MoonPainter(this.sky, this.intro) : super(repaint: Listenable.merge([sky, intro]));

  @override
  void paint(Canvas c, Size size) {
    final t = sky.value * 24;
    final v = Curves.easeOutCubic.transform(intro.value.clamp(0.0, 1.0));
    final o = size.center(Offset(size.width * 0.15 * (1 - v), 0));
    final r = size.shortestSide / 2;
    // a soft halo
    c.drawCircle(o, r * 1.45, Paint()..shader = const RadialGradient(colors: [Color(0x33A3C4BA), Color(0x00A3C4BA)]).createShader(Rect.fromCircle(center: o, radius: r * 1.45)));
    // the satellite's orbit: behind the Moon for half the turn
    final a = t * 0.5;
    final orbit = Offset(math.cos(a) * r * 1.3, math.sin(a) * r * 0.36);
    final behind = math.sin(a) < 0;
    if (behind) _satellite(c, o + orbit, r * 0.1, a);
    paintMoonBall(c, o, r);
    if (!behind) _satellite(c, o + orbit, r * 0.12, a);
  }

  void _satellite(Canvas c, Offset o, double s, double a) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-0.4 + math.sin(a) * 0.1);
    final panel = Paint()..color = const Color(0xFF3D5BFF);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-s * 1.4, 0), width: s * 1.6, height: s * 0.7), Radius.circular(s * 0.1)), panel);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * 1.4, 0), width: s * 1.6, height: s * 0.7), Radius.circular(s * 0.1)), panel);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 0.9, height: s * 0.9), Radius.circular(s * 0.2)), Paint()..color = const Color(0xFFF2FFF8));
    c.drawCircle(Offset(0, -s * 0.62), s * 0.18, Paint()..color = C.orange);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPainter old) => false;
}
