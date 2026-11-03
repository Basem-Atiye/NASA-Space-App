import 'package:flutter/material.dart';

import '../data/encyclopedia.dart';
import '../data/missions.dart';
import '../main.dart';
import '../story/story_model.dart';
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

class _TitleScreenState extends State<TitleScreen> {
  Color _accent = C.cyan;
  String _themeName = '';
  static bool _firstOpen = true;
  late final bool _playIntro = _firstOpen;

  @override
  void initState() {
    super.initState();
    _firstOpen = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Services.of(context).audio.ambient('music');
  }

  @override
  void dispose() {
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
          final artH = (box.maxHeight * 0.44).clamp(230.0, 380.0);
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: artH,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned(
                        left: -20,
                        right: -20,
                        top: -40,
                        bottom: 0,
                        // a living Moon base: walk, jump, spin the Earth
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: _playIntro ? 0 : 1, end: 1),
                          duration: Duration(milliseconds: introMs + 1),
                          builder: (context, intro, child) => Opacity(opacity: intro, child: child),
                          child: HomeScene(theme: theme, audio: sv.audio, reducedMotion: sv.progress.reducedMotion),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 0,
                        child: _pill(
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: _playIntro ? 0 : 1, end: 1),
                              duration: Duration(milliseconds: introMs + 1),
                              builder: (context, v, _) => SizedBox(width: 18, height: 18, child: CustomPaint(painter: StarLogoPainter(v))),
                            ),
                            const SizedBox(width: 10),
                            Text('SOUTH POLE', style: T.label.copyWith(color: C.frozen, fontSize: 12, letterSpacing: 3)),
                          ]),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            sv.nav.afterRank = Screen.title;
                            sv.nav.go(Screen.rank);
                          },
                          child: _pill(Row(mainAxisSize: MainAxisSize.min, children: [
                            const SparkleStar(size: 16),
                            const SizedBox(width: 8),
                            Text('${p.storyTotalStars()}', style: T.h3.copyWith(fontSize: 14)),
                            Text(' · ${p.rankChosen ? p.ageMode.title : 'Choose rank'}', style: T.body.copyWith(fontSize: 13.5, color: C.muted)),
                          ])),
                        ),
                      ),
                    ]),
                  ),
                  EnterAnim(
                    delayMs: _playIntro ? 500 : 0,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Shackleton', style: T.hero),
                      Text('Station', style: T.hero.copyWith(color: _accent)),
                      const SizedBox(height: 12),
                      Text(camp.tagline, style: T.body.copyWith(color: C.muted, fontSize: 15)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _liveBanner(),
                  EnterAnim(delayMs: _playIntro ? 700 : 60, child: _continueCard(started, next, task.title)),
                  const SizedBox(height: 12),
                  EnterAnim(
                    delayMs: _playIntro ? 820 : 120,
                    child: Row(children: [
                      Expanded(
                        child: _tile(
                          icon: Icons.groups_rounded,
                          title: 'Co-op missions',
                          sub: '2–4 players · 18 missions',
                          green: true,
                          onTap: () => sv.nav.go(Screen.coop),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _tile(
                          icon: Icons.radar_rounded,
                          title: 'My skills',
                          sub: 'Readiness and skills map',
                          onTap: () => sv.nav.go(Screen.skills),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  EnterAnim(
                    delayMs: _playIntro ? 900 : 160,
                    child: Row(children: [
                      Expanded(
                        child: _tile(
                          icon: Icons.public_rounded,
                          title: 'Survival',
                          sub: '${missions.length} Flight Director missions',
                          onTap: () => sv.nav.go(Screen.missions),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _tile(
                          icon: Icons.menu_book_rounded,
                          title: 'Moon Encyclopedia',
                          sub: '${p.facts.length} of ${encyclopedia.length} facts',
                          onTap: () => sv.nav.go(Screen.encyclopedia),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _accountRow(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _link('Mission data', () => sv.nav.go(Screen.data)),
                    _link('For teachers', () => sv.nav.openTeacher(sv)),
                    _link('Settings', () => sv.nav.go(Screen.settings)),
                  ]),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _pill(Widget child) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: C.bg.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
        child: child,
      );

  Widget _continueCard(bool started, int next, String title) {
    final sv = Services.of(context);
    final p = sv.progress;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(started ? 'CONTINUE' : 'START', style: T.label.copyWith(fontSize: 12, letterSpacing: 3)),
          const SizedBox(width: 8),
          Expanded(child: Text(p.campaign.title.toUpperCase(), style: T.label.copyWith(fontSize: 10, color: C.muted, letterSpacing: 1.5), overflow: TextOverflow.ellipsis)),
          Flexible(child: Text(p.campaign.dayLabel(next), style: T.body.copyWith(color: C.muted, fontSize: 13.5), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Text('Level $next · $title', style: T.h1.copyWith(fontSize: 24)),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _accent, blurRadius: 8)])),
          const SizedBox(width: 8),
          Text('NEXT MISSION: $_themeName', style: T.label.copyWith(color: _accent, fontSize: 10.5, letterSpacing: 2)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 1; i <= p.campaign.length; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: Motion.slow,
                height: 5,
                decoration: BoxDecoration(
                  color: p.storyStars(i) > 0 ? _accent : (i == next ? C.sapphire : C.lineSoft),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < p.campaign.length) const SizedBox(width: 3),
          ],
        ]),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Play', icon: Icons.play_arrow_rounded, onTap: _play, height: 58),
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
                  child: Text(
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

  /// Who is signed in (or how to sign in), and the class the student is in.
  Widget _accountRow() {
    final sv = Services.of(context);
    final p = sv.progress;
    final session = sv.session;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final signedIn = session.signedIn;
        final label = signedIn
            ? (session.isTeacher ? 'Teacher · ${session.name}' : '${session.name}${p.className == null ? '' : ' · ${p.className}'}')
            : (session.cloudAvailable ? 'Playing as a guest · progress stays on this phone' : 'Offline · progress stays on this phone');
        return Pressable(
          onTap: () => sv.nav.go(Screen.account),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: C.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Row(children: [
              Icon(signedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded, color: signedIn ? C.cyan : C.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: T.body.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (session.pending > 0) Text('${session.pending} to sync  ', style: T.monoSmall),
              Text(signedIn ? 'ACCOUNT' : (session.cloudAvailable ? 'SIGN IN' : ''), style: T.label.copyWith(fontSize: 10)),
            ]),
          ),
        );
      },
    );
  }

  Widget _tile({required IconData icon, required String title, required String sub, required VoidCallback onTap, bool green = false}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: green ? C.evergreen.withValues(alpha: 0.85) : C.panelDeep.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: green ? C.cyan.withValues(alpha: 0.45) : C.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: _accent, size: 20),
          Text(title, style: T.h3.copyWith(fontSize: 15, height: 1.05), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sub, style: T.bodySmall.copyWith(fontSize: 12, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: C.muted, minimumSize: const Size(44, 44)),
        child: Text(label, style: T.h3.copyWith(fontSize: 13.5, color: C.muted)),
      );
}

/// The age mode a teacher or parent can see at a glance.
String rankLine(AgeMode m) => '${m.title} · ${m.ages}';
