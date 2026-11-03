import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../story/story_model.dart' show AgeModeInfo;
import '../ui/theme.dart';
import '../services/audio.dart';
import '../ui/widgets/common.dart';
import '../world/mission_theme.dart';
import '../world/world_art.dart';

/// The mission map: a winding path across the Moon with the campaign's
/// levels (12 or 15), level 1 at the bottom. Scrolls when it is long.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Horizontal position of node [i] (0-based), as a fraction of the width.
double _nodeX(int i) => 0.5 + 0.24 * math.sin(i * 1.3 + 0.6);

const _rowH = 92.0;

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late int _selected = Services.of(context).progress.nextStoryTask();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  final ScrollController _scroll = ScrollController();

  /// The rover drives along the path to the level you pick (in node units).
  late final AnimationController _drive = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late double _roverFrom = (Services.of(context).progress.nextStoryTask() - 1).toDouble();
  late double _roverTo = _roverFrom;
  double get _rover => _roverFrom + (_roverTo - _roverFrom) * Curves.easeInOutCubic.transform(_drive.value);

  /// Little dust rings where the player taps the ground.
  final List<(Offset, int)> _taps = [];
  bool _scrolled = false;

  @override
  void dispose() {
    _pulse.dispose();
    _draw.dispose();
    _zoom.dispose();
    _drive.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _playLevel() async {
    final sv = Services.of(context);
    sv.audio.tap();
    final reduced = sv.progress.reducedMotion || MediaQuery.of(context).disableAnimations;
    if (!reduced) await _zoom.forward(from: 0);
    if (!mounted) return;
    sv.nav.startStory(_selected, sv);
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final camp = p.campaign;
    final n = camp.length;
    final current = p.nextStoryTask();
    final info = camp.info(_selected);
    final task = camp.task(_selected);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final mins = info.minutes[camp.mode.index];
    final selTheme = themeForText('${task.title} ${task.subtitle} ${task.lesson}', _selected);
    final pre = p.assessment(camp.id, 'pre');
    final post = p.assessment(camp.id, 'post');
    final showPre = pre == null && _selected == 1 && !p.storyStarted();
    final showPost = post == null && p.campaignComplete();
    return ColoredBox(
      color: const Color(0xFF8B8781),
      child: LayoutBuilder(builder: (context, box) {
        final mapTop = top + (p.className != null ? 122 : 96);
        final cardH = 330.0 + (showPre || showPost ? 52 : 0);
        final viewH = math.max(200.0, box.maxHeight - mapTop - cardH - bottom + 26);
        final contentH = math.max(viewH, n * _rowH + 90);
        Offset nodeAt(int i) => Offset(_nodeX(i) * box.maxWidth, contentH - 60 - i * _rowH);
        if (!_scrolled) {
          _scrolled = true;
          // start with the current level in view
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            final y = (current - 1) * _rowH - viewH * 0.35;
            _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
          });
        }
        return AnimatedBuilder(
          animation: _zoom,
          builder: (context, child) {
            final z = Curves.easeInCubic.transform(_zoom.value);
            return Transform.scale(scale: 1 + z * 1.4, child: Opacity(opacity: 1 - z * 0.9, child: child));
          },
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: _TerrainPainter()),
            // the scrolling path
            Positioned(
              left: 0,
              right: 0,
              top: mapTop - 20,
              height: viewH + 20,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                    stops: [0, 0.07, 0.93, 1]).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  controller: _scroll,
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    height: contentH,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulse, _draw]),
                          builder: (context, _) => CustomPaint(
                            painter: _PathPainter(points: [for (var i = 0; i < n; i++) nodeAt(i)], done: current - 1, drawn: Curves.easeOutCubic.transform(_draw.value)),
                          ),
                        ),
                      ),
                      for (final s in camp.seasons)
                        if (camp.seasons.length > 1)
                          Positioned(
                            left: 14,
                            top: nodeAt(s.first - 1).dy + 30,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: C.bg.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)),
                              child: Text(s.name.toUpperCase(), style: T.label.copyWith(fontSize: 9.5, letterSpacing: 1.6)),
                            ),
                          ),
                      // tap the ground: a dust ring
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (d) {
                            setState(() => _taps.add((d.localPosition, DateTime.now().millisecondsSinceEpoch)));
                            sv.audio.play(Sfx.boop, volume: 0.15);
                          },
                        ),
                      ),
                      for (final (pos, ms) in _taps)
                        Positioned(
                          left: pos.dx - 40,
                          top: pos.dy - 20,
                          child: _DustRing(key: ValueKey(ms), onDone: () => setState(() => _taps.removeWhere((x) => x.$2 == ms))),
                        ),
                      for (var i = 0; i < n; i++) _node(i + 1, nodeAt(i), current),
                      // the rover, parked at the chosen level or driving there
                      AnimatedBuilder(
                        animation: _drive,
                        builder: (context, _) {
                          final f = _rover.clamp(0.0, n - 1.0);
                          final i0 = f.floor(), i1 = math.min(n - 1, i0 + 1);
                          final a = nodeAt(i0), b = nodeAt(i1);
                          final pos = Offset.lerp(a, b, f - i0)!;
                          final dir = (_roverTo - _roverFrom).sign * (b.dx - a.dx).sign;
                          final moving = _drive.isAnimating;
                          return Positioned(
                            left: pos.dx - 22,
                            top: pos.dy + 18,
                            child: IgnorePointer(
                              child: SizedBox(
                                width: 44,
                                height: 26,
                                child: CustomPaint(painter: _RoverIcon(t: _drive.value * 10, facing: dir == 0 ? 1 : dir, moving: moving)),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(left: nodeAt(0).dx - 50, top: nodeAt(0).dy + 18, child: const _MiniLander()),
                      Positioned(left: nodeAt(n - 1).dx + 52, top: nodeAt(n - 1).dy - 6, child: const _MiniRocket()),
                    ]),
                  ),
                ),
              ),
            ),
            // dark sky band at the top
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: mapTop,
              child: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.bg, Color(0xCC071A10), Color(0x00071A10)], stops: [0, 0.7, 1]))),
            ),
            // header
            Positioned(
              left: 20,
              right: 20,
              top: top + 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconButton(
                    onPressed: () => sv.nav.resetTo(Screen.title),
                    icon: const Icon(Icons.arrow_back_rounded, color: C.frozen),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(camp.title.toUpperCase(), style: T.label.copyWith(letterSpacing: 3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(camp.dayLabel(current), style: T.h1.copyWith(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 0.5)),
                      ),
                    ]),
                  ),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cyan.withValues(alpha: 0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SparkleStar(size: 16),
                      const SizedBox(width: 8),
                      Text('${p.storyTotalStars()} / ${n * 3}', style: T.h3.copyWith(fontSize: 15)),
                    ]),
                  ),
                ]),
                if (p.className != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 44),
                    child: Row(children: [
                      const Icon(Icons.groups_rounded, size: 16, color: C.cyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${p.className}${(p.teacherName ?? '').isEmpty ? '' : ' · ${p.teacherName}'} · ${camp.mode.title} level',
                            style: T.bodySmall.copyWith(color: C.frozen), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
              ]),
            ),
            // the level card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottom,
              child: AnimatedSwitcher(
                duration: Motion.normal,
                switchInCurve: Motion.curve,
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: c)),
                child: Container(
                  key: ValueKey('${camp.id}-$_selected'),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: C.indigo.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: selTheme.accent.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [BoxShadow(color: selTheme.accent.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text('LEVEL $_selected', style: T.label.copyWith(fontSize: 12, letterSpacing: 3)),
                      Flexible(child: Text('  · about $mins min', style: T.bodySmall, overflow: TextOverflow.ellipsis)),
                      const Spacer(),
                      if (p.storyStars(_selected) > 0) StarRow(stars: p.storyStars(_selected), size: 14),
                    ]),
                    const SizedBox(height: 4),
                    Text(task.title, style: T.h1.copyWith(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 24)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(moodIcon(selTheme), size: 14, color: selTheme.accent),
                      const SizedBox(width: 6),
                      Text(selTheme.name, style: T.label.copyWith(color: selTheme.accent, fontSize: 10.5, letterSpacing: 2)),
                    ]),
                    const SizedBox(height: 6),
                    Text(info.brief, style: T.body.copyWith(color: C.muted, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final g in info.games) _chip(g, C.panelDeep, C.text),
                      _chip(info.chip, const Color(0xFF2A1F12), const Color(0xFFF3E9D8)),
                    ]),
                    const SizedBox(height: 14),
                    if (showPre || showPost) ...[
                      HudButton(
                        label: showPre ? 'READINESS CHECK FIRST (2 MIN)' : 'FINAL READINESS CHECK',
                        icon: Icons.quiz_rounded,
                        onTap: () => sv.nav.go(Screen.readiness),
                      ),
                      const SizedBox(height: 10),
                    ],
                    PrimaryButton(
                      label: p.storyUnlocked(_selected) ? 'Play level $_selected' : 'Locked',
                      icon: p.storyUnlocked(_selected) ? Icons.play_arrow_rounded : Icons.lock_rounded,
                      onTap: p.storyUnlocked(_selected) ? _playLevel : null,
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: T.body.copyWith(fontSize: 12.5, color: fg)),
      );

  Widget _node(int n, Offset at, int current) {
    final p = Services.of(context).progress;
    final done = p.storyStars(n) > 0;
    final isCurrent = n == current && !done;
    final unlocked = p.storyUnlocked(n);
    final selected = n == _selected;
    final size = isCurrent || selected ? 58.0 : 46.0;
    final info = p.campaign.info(n);
    final task = p.campaign.task(n);
    final theme = themeForText('${task.title} ${task.subtitle} ${task.lesson}', n);
    final mood = theme.accent;
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      child: GestureDetector(
        onTap: unlocked
            ? () {
                final sv = Services.of(context);
                sv.audio.tap();
                if (n != _selected) {
                  _roverFrom = _rover;
                  _roverTo = (n - 1).toDouble();
                  _drive.duration = Duration(milliseconds: (380 + 260 * (_roverTo - _roverFrom).abs()).clamp(380, 2200).round());
                  _drive.forward(from: 0);
                  sv.audio.play(Sfx.step, volume: 0.25);
                }
                setState(() => _selected = n);
              }
            : null,
        child: Stack(clipBehavior: Clip.none, children: [
          if (isCurrent)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Transform.scale(
                scale: 1 + _pulse.value * 0.5,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.sapphire.withValues(alpha: 0.35 * (1 - _pulse.value))),
                ),
              ),
            ),
          AnimatedContainer(
            duration: Motion.normal,
            curve: Motion.curve,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // each level wears the colour of its mission (ice, storm, night...)
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: isCurrent
                    ? [Color.lerp(mood, Colors.white, 0.2)!, Color.lerp(mood, C.sapphire, 0.5)!]
                    : (done
                        ? [Color.lerp(mood, Colors.black, 0.45)!, const Color(0xFF0B1A12)]
                        : (unlocked ? [Color.lerp(mood, Colors.black, 0.55)!, const Color(0xFF1F2225)] : [const Color(0xFF2A2D31), const Color(0xFF1F2225)])),
              ),
              border: Border.all(color: isCurrent || selected ? C.frozen : (unlocked || done ? mood : const Color(0xFF9A9FA6)), width: isCurrent || selected ? 3.5 : 2.5),
              boxShadow: isCurrent || selected ? [BoxShadow(color: mood.withValues(alpha: 0.65), blurRadius: 26)] : null,
            ),
            child: unlocked || done
                ? Text('$n', style: T.h3.copyWith(fontSize: isCurrent ? 22 : 18, fontWeight: FontWeight.w800))
                : const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF9A9FA6)),
          ),
          // a small badge with the mission's mood
          if (unlocked || done)
            Positioned(
              left: -6,
              top: -6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle, border: Border.all(color: mood, width: 1.5)),
                child: Icon(moodIcon(theme), size: 13, color: mood),
              ),
            ),
          if (info.wow)
            Positioned(
              left: size - 6,
              top: size / 2 - 11,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(10)),
                child: Text('WOW', style: T.label.copyWith(color: C.frozen, fontSize: 10, letterSpacing: 1.4)),
              ),
            ),
          if (done)
            Positioned(
              left: size / 2 - 33,
              top: size + 2,
              child: SizedBox(width: 66, child: Center(child: StarRow(stars: p.storyStars(n), size: 15))),
            ),
        ]),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int done; // segments fully done
  final double drawn;
  _PathPainter({required this.points, required this.done, required this.drawn});

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final ctrl = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + 14);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      if (i < done) {
        // the path to the current level draws itself on arrival
        final m = path.computeMetrics().first;
        final k = (drawn * done - i).clamp(0.0, 1.0);
        canvas.drawPath(
            m.extractPath(0, m.length * k),
            Paint()
              ..color = C.cyan
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);
      } else {
        for (final m in path.computeMetrics()) {
          for (var d = 10.0; d < m.length - 10; d += 14) {
            final tan = m.getTangentForOffset(d);
            if (tan != null) canvas.drawCircle(tan.position, 2.4, dots);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.drawn != drawn || old.done != done;
}

class _TerrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
        r,
        Paint()
          ..shader =
              const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6E6B66), Color(0xFF8E8A84), Color(0xFF7A7671)]).createShader(r));
    final rnd = math.Random(17);
    for (var i = 0; i < 9; i++) {
      final c = Offset(rnd.nextDouble() * s.width, 140 + rnd.nextDouble() * (s.height - 300));
      final cr = 20 + rnd.nextDouble() * 80;
      canvas.drawCircle(
          c,
          cr,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(0.2, 0.25),
                colors: [const Color(0xFF3F3D3A).withValues(alpha: 0.85), const Color(0xFF6E6B66).withValues(alpha: 0.6), const Color(0xFF9B978F).withValues(alpha: 0.0)],
                stops: const [0, 0.7, 1]).createShader(Rect.fromCircle(center: c, radius: cr)));
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: cr * 0.92),
          math.pi * 0.15,
          math.pi * 0.8,
          false,
          Paint()
            ..color = const Color(0xFFB9B5AD).withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    for (var i = 0; i < 40; i++) {
      final c = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
      canvas.drawCircle(c, 2 + rnd.nextDouble() * 5, Paint()..color = const Color(0xFF5E5B57).withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniLander extends StatelessWidget {
  const _MiniLander();
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.2,
        child: CustomPaint(
          size: const Size(40, 30),
          painter: _LanderIcon(),
        ),
      );
}

class _LanderIcon extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawLine(
        Offset(s.width * 0.2, s.height * 0.1),
        Offset(s.width * 0.2, s.height * 0.6),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2);
    c.drawPath(
        Path()
          ..moveTo(s.width * 0.2, s.height * 0.35)
          ..lineTo(s.width * 0.85, s.height * 0.3)
          ..lineTo(s.width * 0.75, s.height)
          ..lineTo(s.width * 0.15, s.height * 0.95)
          ..close(),
        Paint()..color = const Color(0xFFE1A23A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniRocket extends StatelessWidget {
  const _MiniRocket();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(32, 40), painter: _RocketIcon());
}

class _RocketIcon extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.2, 0, s.width * 0.6, s.height * 0.75), const Radius.circular(8)), Paint()..color = Colors.white);
    c.drawPath(
        Path()
          ..moveTo(s.width * 0.2, s.height * 0.5)
          ..lineTo(0, s.height * 0.85)
          ..lineTo(s.width * 0.2, s.height * 0.75)
          ..close(),
        Paint()..color = C.sapphire);
    c.drawPath(
        Path()
          ..moveTo(s.width * 0.8, s.height * 0.5)
          ..lineTo(s.width, s.height * 0.85)
          ..lineTo(s.width * 0.8, s.height * 0.75)
          ..close(),
        Paint()..color = C.sapphire);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// An icon for each mission mood.
IconData moodIcon(MissionTheme t) => switch (t.id) {
      'ice' => Icons.ac_unit_rounded,
      'storm' => Icons.flash_on_rounded,
      'night' => Icons.nightlight_round,
      'garden' => Icons.eco_rounded,
      'launch' => Icons.rocket_launch_rounded,
      'alarm' => Icons.warning_amber_rounded,
      'quake' => Icons.waves_rounded,
      'silver' => Icons.construction_rounded,
      _ => Icons.wb_twilight_rounded,
    };

/// The little rover on the map, drawn with the same art as the game.
class _RoverIcon extends CustomPainter {
  final double t;
  final double facing;
  final bool moving;
  _RoverIcon({required this.t, required this.facing, required this.moving});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height - 2), width: size.width * 0.9, height: 5), Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.save();
    canvas.translate(size.width / 2, size.height - 2 + (moving ? math.sin(t * 9).abs() * -1.5 : 0));
    canvas.scale(facing * 0.21, 0.21);
    paintRover(canvas, t, lights: true, wheelTurn: t * 6);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoverIcon old) => old.t != t || old.facing != facing || old.moving != moving;
}

/// A quick ring of dust where the finger touched the map.
class _DustRing extends StatefulWidget {
  final VoidCallback onDone;
  const _DustRing({super.key, required this.onDone});

  @override
  State<_DustRing> createState() => _DustRingState();
}

class _DustRingState extends State<_DustRing> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) => CustomPaint(size: const Size(80, 40), painter: _RingPainter(_a.value)),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double k;
  _RingPainter(this.k);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: 12 + 60 * k, height: 5 + 20 * k),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - k))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - k) + 0.5);
    final rnd = math.Random(3);
    for (var i = 0; i < 6; i++) {
      final a = -math.pi * rnd.nextDouble();
      final d = 30 * k * (0.5 + rnd.nextDouble());
      canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d * 0.6 - 10 * k * (1 - k) * 4), 1.6, Paint()..color = const Color(0xFFE8E2D6).withValues(alpha: 1 - k));
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.k != k;
}
