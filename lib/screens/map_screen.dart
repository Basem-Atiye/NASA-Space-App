import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../main.dart';
import '../story/story_model.dart' show AgeModeInfo;
import '../ui/theme.dart';
import '../ui/figma_art.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
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

  /// The Sun goes once round the horizon (at the pole it never rises high),
  /// so the crater shadows slowly sweep around.
  late final AnimationController _sun = AnimationController(vsync: this, duration: const Duration(seconds: 50));
  bool _sunStarted = false;
  final ScrollController _scroll = ScrollController();

  /// The rover drives along the path to the level you pick (in node units).
  late final AnimationController _drive = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late double _roverFrom = (Services.of(context).progress.nextStoryTask() - 1).toDouble();
  late double _roverTo = _roverFrom;
  double get _rover => _roverFrom + (_roverTo - _roverFrom) * Curves.easeInOutCubic.transform(_drive.value);

  /// Little dust rings where the player taps the ground.
  final List<(Offset, int)> _taps = [];
  bool _scrolled = false;

  /// The level card's real height, so the map ends just above it.
  final GlobalKey _cardKey = GlobalKey();
  double? _cardH;
  double _viewH = 0;

  void _measureCard() {
    final h = _cardKey.currentContext?.size?.height;
    if (h == null || !mounted) return;
    if (_cardH == null || (h - _cardH!).abs() > 1) {
      setState(() => _cardH = h);
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_selected));
    }
  }

  /// Scrolls the map so [level] sits comfortably above the card.
  void _reveal(int level, {bool animate = true}) {
    if (!mounted || !_scroll.hasClients || _viewH <= 0) return;
    final pos = _scroll.position;
    final fromBottom = 84 + (level - 1) * _rowH;
    const margin = 70.0;
    final o = pos.pixels;
    if (fromBottom >= o + margin && fromBottom <= o + _viewH - margin) return;
    final target = (fromBottom - _viewH * 0.4).clamp(0.0, pos.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _draw.dispose();
    _zoom.dispose();
    _sun.dispose();
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
    final reduced = p.reducedMotion || MediaQuery.of(context).disableAnimations;
    if (!_sunStarted && !reduced) {
      _sunStarted = true;
      _sun.repeat();
    }
    return ColoredBox(
      color: _ground,
      child: LayoutBuilder(builder: (context, box) {
        final mapTop = top + (p.className != null ? 124 : 98);
        final cardH = _cardH ?? 346.0 + (showPre || showPost ? 132 : 0);
        // the map stops just above the card (a little overlap hides under its shadow)
        final viewH = math.max(200.0, box.maxHeight - mapTop - (cardH + 16 + bottom) + 10);
        _viewH = viewH;
        final contentH = math.max(viewH, n * _rowH + 170);
        Offset nodeAt(int i) => Offset(_nodeX(i) * box.maxWidth, contentH - 84 - i * _rowH);
        WidgetsBinding.instance.addPostFrameCallback((_) => _measureCard());
        if (!_scrolled) {
          _scrolled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_selected, animate: false));
        }
        return AnimatedBuilder(
          animation: _zoom,
          builder: (context, child) {
            final z = Curves.easeInCubic.transform(_zoom.value);
            return Transform.scale(scale: 1 + z * 1.4, child: Opacity(opacity: 1 - z * 0.9, child: child));
          },
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: _ground),
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
                      // the Moon's surface, moving with the path
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _SurfacePainter(sun: _sun, nodes: [for (var i = 0; i < n; i++) nodeAt(i)])),
                        ),
                      ),
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
                            left: 24,
                            top: nodeAt(s.first - 1).dy + 34,
                            child: Builder(builder: (_) {
                              final seasonOpen = p.storyUnlocked(s.first);
                              final seasonNew = seasonOpen && p.storyStars(s.first) == 0 && current == s.first;
                              return Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: seasonNew ? C.sapphire : C.ink.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: seasonNew ? [BoxShadow(color: C.sapphire.withValues(alpha: 0.45), blurRadius: 16)] : null,
                                ),
                                child: GameText(
                                  seasonNew ? '${s.name.toUpperCase()} · NEW' : s.name.toUpperCase(),
                                  style: T.label.copyWith(fontSize: 10, letterSpacing: 1.6, color: seasonNew ? C.frozen : C.muted),
                                ),
                              );
                            }),
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
                      Positioned(left: nodeAt(0).dx - 74, top: nodeAt(0).dy - 6, child: const IgnorePointer(child: _MiniLander())),
                      Positioned(left: nodeAt(n - 1).dx + 46, top: nodeAt(n - 1).dy - 44, child: IgnorePointer(child: _MiniRocket(sun: _sun))),
                    ]),
                  ),
                ),
              ),
            ),
            // the black sky and the horizon at the top, with the low Sun and Earth
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: mapTop + 10,
              child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _HorizonPainter(_sun)))),
            ),
            // header
            Positioned(
              left: 24,
              right: 24,
              top: top + 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  RoundButton(onTap: () => sv.nav.resetTo(Screen.title)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GameText(camp.title.toUpperCase(), style: T.label.copyWith(fontSize: 11, letterSpacing: 2.4), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: GameText(camp.dayLabel(current), style: T.h2.copyWith(fontSize: 22)),
                      ),
                    ]),
                  ),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(22)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const LineIcon(Ln.star, size: 17, color: C.yellow),
                      const SizedBox(width: 7),
                      GameText('${p.storyTotalStars()} / ${n * 3}', style: T.h3.copyWith(fontSize: 15)),
                    ]),
                  ),
                ]),
                if (p.className != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 56),
                    child: Row(children: [
                      const LineIcon(Ln.users, size: 16, color: C.cyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GameText('${p.className}${(p.teacherName ?? '').isEmpty ? '' : ' · ${p.teacherName}'} · ${camp.mode.title} level',
                            style: T.bodySmall.copyWith(color: C.frozen), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
              ]),
            ),
            // the level card
            Positioned(
              left: 24,
              right: 24,
              bottom: 16 + bottom,
              child: AnimatedSwitcher(
                key: _cardKey,
                duration: Motion.normal,
                switchInCurve: Motion.curve,
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: c)),
                child: Container(
                  key: ValueKey('${camp.id}-$_selected'),
                  decoration: BoxDecoration(
                    color: C.panel,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12)),
                      BoxShadow(color: selTheme.accent.withValues(alpha: 0.18), blurRadius: 40),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    // a strip in the colour of the mission
                    Container(height: 5, color: selTheme.accent),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Overline('LEVEL $_selected', color: C.cyan, size: 11.5),
                          const SizedBox(width: 8),
                          const LineIcon(Ln.clock, size: 14, color: C.muted),
                          const SizedBox(width: 4),
                          Flexible(child: GameText('about $mins min', style: T.bodySmall.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                          const Spacer(),
                          if (p.storyStars(_selected) > 0) StarRow(stars: p.storyStars(_selected), size: 15),
                        ]),
                        const SizedBox(height: 8),
                        GameText(task.title, style: T.h2.copyWith(fontSize: 23), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(color: selTheme.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(13)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(moodIcon(selTheme), size: 14, color: selTheme.accent),
                              const SizedBox(width: 6),
                              GameText(selTheme.name.toUpperCase(), style: T.label.copyWith(color: selTheme.accent, fontSize: 10.5, letterSpacing: 1.6)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        GameText(info.brief, style: T.body.copyWith(color: C.muted, fontSize: 14, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final g in info.games) _chip(g, C.panelDeep, C.text),
                          _chip(info.chip, C.info, C.frozen),
                        ]),
                        const SizedBox(height: 16),
                        if (showPre || showPost) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: C.yellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              const IconBox(Ln.bulb, color: C.yellow, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GameText(
                                  showPre ? 'Take the short readiness check before Level 1 (about 2 min).' : 'Campaign complete! Finish the final readiness check.',
                                  style: T.body.copyWith(fontSize: 13.5, color: C.frozen),
                                ),
                              ),
                            ]),
                          ),
                          KitButton(showPre ? 'Readiness check first' : 'Final readiness check', icon: Ln.check, onTap: () => sv.nav.go(Screen.readiness)),
                          const SizedBox(height: 12),
                        ],
                        KitButton(
                          p.storyUnlocked(_selected)
                              ? (_selected == current && p.storyStars(_selected) == 0 ? 'Play next · Level $_selected' : 'Play level $_selected')
                              : 'Locked',
                          icon: p.storyUnlocked(_selected) ? Ln.play : Ln.lock,
                          style: showPre || showPost ? KitButtonStyle.secondary : KitButtonStyle.primary,
                          onTap: p.storyUnlocked(_selected) ? _playLevel : null,
                        ),
                      ]),
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
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: GameText(text, style: T.body.copyWith(fontSize: 12.5, color: fg, fontWeight: FontWeight.w700, height: 1.1)),
      );

  Widget _node(int n, Offset at, int current) {
    final p = Services.of(context).progress;
    final done = p.storyStars(n) > 0;
    final isCurrent = n == current && !done;
    final unlocked = p.storyUnlocked(n);
    final selected = n == _selected;
    final size = isCurrent || selected ? 60.0 : 50.0;
    final info = p.campaign.info(n);
    final task = p.campaign.task(n);
    final theme = themeForText('${task.title} ${task.subtitle} ${task.lesson}', n);
    final mood = theme.accent;
    // a raised 3D button, like the Figma buttons
    final (face, edge, ink) = isCurrent
        ? (C.cyan, C.cyanEdge, C.ink)
        : done
            ? (C.raised, C.raisedEdge, C.text)
            : unlocked
                ? (C.panel, C.raisedEdge, C.text)
                : (C.locked, const Color(0xFF26224A), C.dim);
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      child: Semantics(
        button: true,
        label: 'Level $n${done ? ', ${p.storyStars(n)} stars' : ''}${unlocked ? '' : ', locked'}',
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
                  WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(n));
                }
              : null,
          child: Stack(clipBehavior: Clip.none, children: [
            if (isCurrent)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Transform.scale(
                  scale: 1 + _pulse.value * 0.6,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.cyan.withValues(alpha: 0.7 * (1 - _pulse.value)), width: 3)),
                  ),
                ),
              ),
            // the 3D edge underneath
            Positioned(
              left: 0,
              top: 5,
              child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: edge, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))])),
            ),
            AnimatedContainer(
              duration: Motion.normal,
              curve: Motion.curve,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: face,
                border: Border.all(color: selected && !isCurrent ? C.frozen : (unlocked && !isCurrent ? mood.withValues(alpha: 0.9) : Colors.transparent), width: selected ? 3 : 2.5),
                boxShadow: isCurrent || selected ? [BoxShadow(color: (isCurrent ? C.cyan : mood).withValues(alpha: 0.55), blurRadius: 24)] : null,
              ),
              child: unlocked || done
                  ? GameText('$n', style: T.h3.copyWith(fontSize: isCurrent || selected ? 23 : 19, color: ink, height: 1))
                  : LineIcon(Ln.lock, size: 18, color: ink),
            ),
            // the mission's mood, as a little badge
            if (unlocked || done)
              Positioned(
                left: -5,
                top: -5,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle, border: Border.all(color: mood, width: 1.5)),
                  child: Icon(moodIcon(theme), size: 13, color: mood),
                ),
              ),
            if (done)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                  child: const Center(child: LineIcon(Ln.check, size: 13, color: C.ink, stroke: 3)),
                ),
              ),
            if (info.wow)
              Positioned(
                left: size + 4,
                top: size / 2 - 11,
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(11)),
                  child: GameText('WOW', style: T.label.copyWith(color: C.ink, fontSize: 10, letterSpacing: 1.4)),
                ),
              ),
            if (done)
              Positioned(
                left: size / 2 - 33,
                top: size + 8,
                child: SizedBox(width: 66, child: Center(child: StarRow(stars: p.storyStars(n), size: 15))),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The colour of the ground on the map (Figma's hill colour, a bit darker).
const _ground = Color(0xFF3B3468);

class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int done; // segments fully done
  final double drawn;
  _PathPainter({required this.points, required this.done, required this.drawn});

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()..color = const Color(0xFFB9B4E0).withValues(alpha: 0.75);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final ctrl = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + 14);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      if (i < done) {
        // the path already travelled glows; it draws itself on arrival
        final m = path.computeMetrics().first;
        final k = (drawn * done - i).clamp(0.0, 1.0);
        final part = m.extractPath(0, m.length * k);
        canvas.drawPath(
            part,
            Paint()
              ..color = C.cyan.withValues(alpha: 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 16
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawPath(
            part,
            Paint()
              ..color = C.cyan
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round);
        // rover tyre tracks along the middle
        for (var d = 6.0; d < m.length * k - 6; d += 12) {
          final tan = m.getTangentForOffset(d);
          if (tan == null) continue;
          canvas.drawCircle(tan.position, 1.3, Paint()..color = C.cyanEdge);
        }
      } else {
        for (final m in path.computeMetrics()) {
          for (var d = 12.0; d < m.length - 12; d += 14) {
            final tan = m.getTangentForOffset(d);
            if (tan != null) canvas.drawCircle(tan.position, 2.6, dots);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.drawn != drawn || old.done != done;
}

double _hash(double v) {
  final s = math.sin(v * 12.9898 + 78.233) * 43758.5453;
  return s - s.floorToDouble();
}

/// The Moon's surface under the path: craters whose shadows sweep round as
/// the low Sun circles the horizon, a few craters in shadow for ever with
/// ice glinting inside, rocks, and the landing site and crater rim labels.
class _SurfacePainter extends CustomPainter {
  final Animation<double> sun;
  final List<Offset> nodes;
  _SurfacePainter({required this.sun, required this.nodes}) : super(repaint: sun);

  @override
  void paint(Canvas c, Size s) {
    final a = sun.value * math.pi * 2;
    final t = sun.value * 50;
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A4378), Color(0xFF433C72), _ground]).createShader(r));
    // the light comes from the Sun's side; shadows fall the other way, long
    final light = Offset(math.cos(a), math.sin(a) * 0.45);

    // big Shackleton crater rim across the top: dark for ever inside
    final rimC = Offset(s.width * 0.5, -s.width * 0.26);
    final rim = Rect.fromCenter(center: rimC, width: s.width * 1.5, height: s.width * 0.72);
    c.drawOval(rim.inflate(10), Paint()..color = const Color(0xFF5A5290));
    c.drawOval(rim, Paint()..color = const Color(0xFF1C1D43));
    final rnd0 = math.Random(5);
    for (var i = 0; i < 14; i++) {
      final p = Offset(rnd0.nextDouble() * s.width, rnd0.nextDouble() * rim.bottom * 0.85);
      if (p.dy < 4) continue;
      paintSparkle(c, p, 4 + 3 * (0.5 + 0.5 * math.sin(t * 2 + i)), const Color(0xFFBDF4FF).withValues(alpha: 0.75));
    }
    _label(c, 'SHACKLETON CRATER · ICE IN THE SHADOWS', Offset(s.width / 2, rim.bottom + 20), C.frozen);

    final rnd = math.Random(23);
    final count = (s.height / 70).round() + 6;
    for (var i = 0; i < count; i++) {
      final p = Offset(rnd.nextDouble() * s.width, rim.bottom + 40 + rnd.nextDouble() * (s.height - rim.bottom - 60));
      final rad = 12 + rnd.nextDouble() * 34;
      final dark = rnd.nextDouble() < 0.18; // a crater the Sun never reaches
      if (nodes.any((n) => (n - p).distance < rad + 34)) continue;
      final bowl = Rect.fromCenter(center: p, width: rad * 2, height: rad * 1.1);
      // the long shadow outside the rim, falling away from the Sun
      c.drawOval(bowl.shift(-light * rad * 0.55), Paint()..color = const Color(0xFF2A2456).withValues(alpha: 0.5));
      c.drawOval(bowl.inflate(2), Paint()..color = const Color(0xFF524A85));
      c.drawOval(bowl, Paint()..color = dark ? const Color(0xFF1C1D43) : const Color(0xFF3A3366));
      if (!dark) {
        // the lit inner wall faces the Sun (light enters from the far side)
        c.save();
        c.clipPath(Path()..addOval(bowl));
        c.drawOval(bowl.shift(-light * rad * 0.5), Paint()..color = const Color(0xFF5E5690).withValues(alpha: 0.75));
        c.restore();
      } else {
        for (var k = 0; k < 2; k++) {
          final g = p + Offset((_hash(i + k * 3.0) - 0.5) * rad, (_hash(i + k * 7.0) - 0.5) * rad * 0.4);
          paintSparkle(c, g, 3.5 + 2 * (0.5 + 0.5 * math.sin(t * 2.4 + i + k)), const Color(0xFFBDF4FF).withValues(alpha: 0.8));
        }
      }
      c.drawArc(bowl.inflate(1), math.atan2(light.dy, light.dx) - 1.1, 2.2, false, Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    // rocks with short moving shadows
    for (var i = 0; i < count * 2; i++) {
      final p = Offset(rnd.nextDouble() * s.width, rim.bottom + 30 + rnd.nextDouble() * (s.height - rim.bottom - 40));
      if (nodes.any((n) => (n - p).distance < 30)) continue;
      final w = 4 + rnd.nextDouble() * 9;
      c.drawOval(Rect.fromCenter(center: p - light * w * 0.9, width: w * 2.2, height: w * 0.7), Paint()..color = const Color(0xFF2A2456).withValues(alpha: 0.45));
      c.drawOval(Rect.fromCenter(center: p, width: w * 1.6, height: w), Paint()..color = const Color(0xFF6A62A0));
      c.drawOval(Rect.fromCenter(center: p + Offset(light.dx * w * 0.25, -w * 0.15), width: w * 0.8, height: w * 0.35), Paint()..color = Colors.white.withValues(alpha: 0.18));
    }
    if (nodes.isNotEmpty) _label(c, 'LANDING SITE', nodes.first + const Offset(0, 52), C.muted);
  }

  void _label(Canvas c, String text, Offset at, Color col) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: F.body, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 2, color: col.withValues(alpha: 0.8))),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: tp.width + 22, height: 24), const Radius.circular(12));
    c.drawRRect(box, Paint()..color = C.ink.withValues(alpha: 0.7));
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter old) => old.nodes.length != nodes.length || (old.nodes.isNotEmpty && nodes.isNotEmpty && old.nodes.first != nodes.first);
}

/// The black sky over the horizon: stars, Earth, and the low Sun gliding
/// along the edge (at the south pole it circles, it never climbs high).
class _HorizonPainter extends CustomPainter {
  final Animation<double> sun;
  _HorizonPainter(this.sun) : super(repaint: sun);

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.bg, C.bg, Color(0x000A1331)], stops: [0, 0.72, 1]).createShader(r));
    final rnd = math.Random(9);
    for (var i = 0; i < 40; i++) {
      final p = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.7);
      c.drawCircle(p, 0.6 + rnd.nextDouble(), Paint()..color = Colors.white.withValues(alpha: 0.25 + 0.45 * rnd.nextDouble()));
    }
    // the Sun slides along the horizon (left to right and round again)
    final x = ((sun.value * 1.4) % 1.4 - 0.2) * s.width;
    final y = s.height * 0.78;
    c.drawCircle(Offset(x, y), 70, Paint()..shader = const RadialGradient(colors: [Color(0x66FFD23F), Color(0x00FFD23F)]).createShader(Rect.fromCircle(center: Offset(x, y), radius: 70)));
    c.drawCircle(Offset(x, y), 9, Paint()..color = const Color(0xFFFFF3C4));
    // Earth, low and far
    paintEarthBall(c, Offset(s.width * 0.82, s.height * 0.62), 9);
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter old) => false;
}

class _MiniLander extends StatelessWidget {
  const _MiniLander();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(52, 46), painter: _LanderIcon());
}

/// The lander you arrived in, parked at the landing site.
class _LanderIcon extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final grey = Paint()..color = const Color(0xFFB9CBC6);
    c.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height - 2), width: s.width * 0.95, height: 6), Paint()..color = Colors.black.withValues(alpha: 0.3));
    // legs
    final leg = Paint()
      ..color = const Color(0xFFB9CBC6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(s.width * 0.3, s.height * 0.55), Offset(s.width * 0.1, s.height - 3), leg);
    c.drawLine(Offset(s.width * 0.7, s.height * 0.55), Offset(s.width * 0.9, s.height - 3), leg);
    // gold body and white top
    c.drawRRect(RRect.fromLTRBR(s.width * 0.2, s.height * 0.32, s.width * 0.8, s.height * 0.72, const Radius.circular(5)), Paint()..color = C.yellow);
    c.drawRRect(RRect.fromLTRBR(s.width * 0.28, s.height * 0.06, s.width * 0.72, s.height * 0.38, const Radius.circular(8)), Paint()..color = const Color(0xFFF2FFF8));
    c.drawCircle(Offset(s.width * 0.5, s.height * 0.22), 5, Paint()..color = C.sapphire);
    c.drawRect(Rect.fromLTRB(s.width * 0.2, s.height * 0.5, s.width * 0.8, s.height * 0.54), grey);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniRocket extends StatelessWidget {
  final Animation<double> sun;
  const _MiniRocket({required this.sun});
  @override
  Widget build(BuildContext context) => SizedBox(width: 44, height: 70, child: CustomPaint(painter: _RocketIcon(sun)));
}

/// The rocket home, waiting at the end of the path.
class _RocketIcon extends CustomPainter {
  final Animation<double> sun;
  _RocketIcon(this.sun) : super(repaint: sun);
  @override
  void paint(Canvas c, Size s) {
    c.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height - 2), width: s.width * 0.9, height: 6), Paint()..color = Colors.black.withValues(alpha: 0.3));
    paintRocket(c, Offset(s.width / 2, s.height * 0.46), s.height * 0.86, flame: 0.15 + 0.1 * math.sin(sun.value * math.pi * 60), t: sun.value * 50);
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
