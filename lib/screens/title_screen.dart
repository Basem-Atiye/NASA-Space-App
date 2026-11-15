import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../data/encyclopedia.dart';
import '../base/base_badges.dart';
import '../data/missions.dart';
import '../main.dart';
import '../story/story_model.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/space_art.dart';
import '../world/mission_theme.dart';
import 'home_scene.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  Color _accent = C.cyan;
  String _themeName = '';
  static bool _firstOpen = true;
  late final bool _playIntro = _firstOpen;
  late final AnimationController _playGlow;

  @override
  void initState() {
    super.initState();
    _firstOpen = false;
    _playGlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sv = Services.of(context);
    sv.audio.ambient('music');
    final reduce = sv.progress.reducedMotion || MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _playGlow.value = 1;
    } else if (!_playGlow.isAnimating) {
      _playGlow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _playGlow.dispose();
    super.dispose();
  }

  void _play() {
    final sv = Services.of(context);
    sv.audio.tap();
    if (!sv.progress.rankChosen) {
      sv.nav.afterRank = Screen.map;
      sv.nav.go(Screen.rank);
    } else {
      sv.nav.go(Screen.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final camp = p.campaign;
    final next = p.nextStoryTask();
    final task = camp.task(next);
    final started = p.storyStarted();
    final introMs = _playIntro ? 1200 : 0;
    // the home screen takes the mood of the next mission
    final theme = themeForText('${task.title} ${task.subtitle} ${task.lesson}', next);
    _accent = theme.accent;
    _themeName = theme.name;
    return AuroraBackground(
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          // One composition: the Moon scene runs under the title so there is no hard cut.
          final artH = (box.maxHeight * 0.56).clamp(280.0, 440.0);
          const titleInset = 64.0;
          const topBarH = 64.0;
          return Stack(children: [
            // Art + page content: clipped under the top bar so the hero never covers the chips.
            Positioned.fill(
              child: ClipRect(
                child: Stack(clipBehavior: Clip.hardEdge, children: [
                  Positioned(
                    left: -20,
                    right: -20,
                    top: -40,
                    height: artH + 40,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: _playIntro ? 0 : 1, end: 1),
                      duration: Duration(milliseconds: introMs + 1),
                      builder: (context, intro, child) => Opacity(opacity: intro, child: child),
                      child: HomeScene(
                        theme: theme,
                        audio: sv.audio,
                        reducedMotion: sv.progress.reducedMotion,
                        blendTo: C.bg,
                      ),
                    ),
                  ),
                  // Long atmospheric veil (sky → page), not a hard band.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: artH - titleInset - 110,
                    height: titleInset + 150,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              theme.skyLow.withValues(alpha: 0.15),
                              Color.lerp(theme.skyLow, C.bg, 0.45)!.withValues(alpha: 0.55),
                              Color.lerp(theme.skyLow, C.bg, 0.85)!.withValues(alpha: 0.88),
                              C.bg,
                            ],
                            stops: const [0.0, 0.22, 0.48, 0.74, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, artH - titleInset, 24, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      EnterAnim(
                        delayMs: _playIntro ? 500 : 0,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const GameText('Open', style: T.hero),
                          GameText('Bounds', style: T.hero.copyWith(color: _accent)),
                          const SizedBox(height: 10),
                          GameText(camp.tagline, style: T.body.copyWith(color: C.muted, fontSize: 15)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _quietAccountChip(),
                      const SizedBox(height: 16),
                      _liveBanner(),
                      EnterAnim(delayMs: _playIntro ? 700 : 60, child: _continueCard(started, next, task.title)),
                      const SizedBox(height: 16),
                      EnterAnim(
                        delayMs: _playIntro ? 820 : 120,
                        child: _tileRow(
                          _tile(icon: Ln.star, color: C.yellow, title: 'My skills', sub: 'Readiness and skills map', onTap: () => sv.nav.go(Screen.skills)),
                          _tile(icon: Ln.map, color: C.water, title: 'Survival', sub: '${missions.length} Flight Director missions', onTap: () => sv.nav.go(Screen.missions)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      EnterAnim(
                        delayMs: _playIntro ? 900 : 160,
                        child: _tileRow(
                          _tile(icon: Ln.book, color: C.green, title: 'Moon Encyclopedia', sub: '${p.facts.length} of ${encyclopedia.length} facts', onTap: () => sv.nav.go(Screen.encyclopedia)),
                          _tile(icon: Ln.rocket, color: C.orange, title: 'Base Commander', sub: 'Bonus · run a base on the Moon and Mars', onTap: () => sv.nav.go(Screen.missionSelect)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      EnterAnim(
                        delayMs: _playIntro ? 980 : 200,
                        child: _tile(icon: Ln.award, color: C.violet, title: 'Badges', sub: '${sv.base.earned.length} of ${badges.length} earned', onTap: () => sv.nav.go(Screen.badges)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _link('Mission data', () => sv.nav.go(Screen.data))),
                        Expanded(child: _link('How to play', () => sv.nav.go(Screen.howToPlay))),
                        Expanded(child: _link('Settings', () => sv.nav.go(Screen.settings))),
                      ]),
                      const SizedBox(height: 4),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            // Sticky top bar: soft sky veil so scrolled hero text fades under the chips.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topBarH,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        C.bg.withValues(alpha: 0.92),
                        C.bg.withValues(alpha: 0.72),
                        C.bg.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 24,
              right: 24,
              child: Row(children: [
                _pill(Row(mainAxisSize: MainAxisSize.min, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: _playIntro ? 0 : 1, end: 1),
                    duration: Duration(milliseconds: introMs + 1),
                    builder: (context, v, _) => SizedBox(width: 18, height: 18, child: CustomPaint(painter: StarLogoPainter(v))),
                  ),
                  const SizedBox(width: 8),
                  GameText('SOUTH POLE', style: T.label.copyWith(color: C.frozen, fontSize: 11.5, letterSpacing: 2.4)),
                ])),
                const Spacer(),
                Flexible(
                  child: TapScale(
                    onTap: () {
                      sv.nav.afterRank = Screen.title;
                      sv.nav.go(Screen.rank);
                    },
                    child: _pill(Row(mainAxisSize: MainAxisSize.min, children: [
                      const LineIcon(Ln.star, size: 18, color: C.yellow),
                      const SizedBox(width: 6),
                      GameText('${p.storyTotalStars()}', style: T.h3.copyWith(fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 16, color: C.line),
                      const SizedBox(width: 8),
                      Flexible(child: GameText(p.rankChosen ? p.ageMode.title : 'Age group', style: T.body.copyWith(fontSize: 13.5, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ])),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _pill(Widget child) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.raised.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)),
        child: child,
      );

  Widget _continueCard(bool started, int next, String title) {
    final sv = Services.of(context);
    final p = sv.progress;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.55), width: 2),
        boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.18), blurRadius: 36, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(12)),
            child: GameText(started ? 'CONTINUE' : 'START', style: T.label.copyWith(fontSize: 11, letterSpacing: 2)),
          ),
          const SizedBox(width: 10),
          Expanded(child: GameText(p.campaign.title.toUpperCase(), style: T.label.copyWith(fontSize: 10.5, color: C.muted, letterSpacing: 1.4), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        GameText('Level $next · $title', style: T.h1.copyWith(fontSize: 24, height: 1.15)),
        const SizedBox(height: 6),
        Row(children: [
          const LineIcon(Ln.calendar, size: 15, color: C.muted),
          const SizedBox(width: 6),
          Expanded(child: GameText(p.campaign.dayLabel(next), style: T.body.copyWith(color: C.muted, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _accent, blurRadius: 8)])),
          const SizedBox(width: 8),
          Expanded(child: GameText('NEXT MISSION: $_themeName', style: T.label.copyWith(color: _accent, fontSize: 10.5, letterSpacing: 1.8), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 1; i <= p.campaign.length; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: Motion.slow,
                height: 6,
                decoration: BoxDecoration(
                  color: p.storyStars(i) > 0 ? _accent : (i == next ? C.progress : C.ink),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < p.campaign.length) const SizedBox(width: 3),
          ],
        ]),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _playGlow,
          builder: (context, child) {
            final v = Curves.easeInOut.transform(_playGlow.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: 0.12 + 0.22 * v), blurRadius: 14 + 12 * v, offset: const Offset(0, 6))],
              ),
              child: child,
            );
          },
          child: KitButton('Play', icon: Ln.play, onTap: _play),
        ),
      ]),
    );
  }

  /// A live lesson started by the teacher, or an unread teacher message.
  Widget _liveBanner() {
    final sv = Services.of(context);
    return AnimatedBuilder(
      animation: sv.session,
      builder: (context, _) {
        final s = sv.session;
        final level = s.liveLevel;
        if (level == null && s.nudges.isEmpty) return const SizedBox.shrink();
        final live = level != null && level <= sv.progress.campaign.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Pressable(
            onTap: () => live ? sv.nav.startStory(level, sv) : sv.nav.go(Screen.skills),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(color: C.sapphire, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: C.sapphire.withValues(alpha: 0.4), blurRadius: 24)]),
              child: Row(children: [
                Icon(live ? Icons.sensors_rounded : Icons.mark_email_unread_rounded, color: C.frozen),
                const SizedBox(width: 10),
                Expanded(
                  child: GameText(
                    live
                        ? 'Live lesson: your teacher started level $level · ${sv.progress.campaign.task(level).title}. Tap to join.'
                        : 'A message from your teacher. Tap to read it.',
                    style: T.h3.copyWith(fontSize: 14),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// Quiet account chip — never competes with Play.
  Widget _quietAccountChip() {
    final sv = Services.of(context);
    final p = sv.progress;
    return AnimatedBuilder(
      animation: sv.session,
      builder: (context, _) {
        final s = sv.session;
        final signedIn = s.signedIn;
        final label = signedIn
            ? (s.isTeacher ? 'Teacher · ${s.name}' : '${s.name}${p.className == null ? '' : ' · ${p.className}'}')
            : 'Guest · Sign in';
        return Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () => sv.nav.go(Screen.account),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: C.panelDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: C.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(signedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded, color: C.cyan, size: 18),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: GameText(label, style: T.bodySmall.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// Two tiles side by side with the same height.
  Widget _tileRow(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);

  Widget _tile({required LineIconData icon, required Color color, required String title, required String sub, required VoidCallback onTap}) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
        decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBox(icon, color: color, size: 38),
          const Spacer(),
          GameText(title, style: T.h3.copyWith(fontSize: 15.5, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          GameText(sub, style: T.bodySmall.copyWith(fontSize: 12, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: C.muted, minimumSize: const Size(44, 48)),
        child: GameText(label, style: T.h3.copyWith(fontSize: 13.5, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

/// The age mode a teacher or parent can see at a glance.
String rankLine(AgeMode m) => '${m.title} · ${m.ages}';
