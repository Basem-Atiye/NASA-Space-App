import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/catalogue.dart';
import '../data/levels.dart';
import '../data/messages.dart';
import '../main.dart';
import '../story/minigames.dart';
import '../story/story_controller.dart';
import '../story/story_model.dart';
import '../story/story_run.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/game_controls.dart';
import '../world/mission_theme.dart';
import '../ui/widgets/typing_text.dart';
import '../data/glossary.dart';
import '../world/characters.dart';
import '../world/surface_view.dart';
import 'cutscene.dart';

/// One story level, in portrait: the Moon's surface on top, the controls
/// (or the dialogue) at the bottom, and full-screen panels for mini-games,
/// decisions and the debrief.
class StoryScreen extends StatefulWidget {
  final StoryController controller;
  const StoryScreen({super.key, required this.controller});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  /// The colour of this mission (from its theme), used by the buttons and cards.
  Color _accent = C.cyan;
  StoryController get c => widget.controller;
  bool _wired = false;
  late bool _intro = c.showIntro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    final sv = Services.of(context);
    sv.nav.gameBack = _openMenu;
    sv.audio.ambient(null);
    if (!_intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
    }
  }

  void _introDone() {
    Services.of(context).progress.markIntroSeen();
    setState(() => _intro = false);
    c.start();
  }

  Future<void> _openMenu() async {
    if (c.finished || _intro) return;
    final sv = Services.of(context);
    c.setPaused(true);
    sv.audio.tap();
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Paused',
      barrierColor: const Color(0x99000000),
      transitionDuration: Motion.normal,
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.curve)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              color: C.panelSolid,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('PAUSED', style: T.label, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Level ${c.task.n} · ${c.task.title}', style: T.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  PrimaryButton(label: 'Resume', icon: Icons.play_arrow_rounded, onTap: () => Navigator.of(ctx).pop('resume')),
                  const SizedBox(height: 10),
                  HudButton(label: 'RESTART LEVEL', icon: Icons.replay_rounded, onTap: () => Navigator.of(ctx).pop('restart')),
                  const SizedBox(height: 10),
                  HudButton(label: 'QUIT TO MAP', icon: Icons.map_rounded, color: C.muted, onTap: () => Navigator.of(ctx).pop('quit')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restart':
        sv.nav.startStory(c.task.n, sv);
        break;
      case 'quit':
        sv.nav.endStory(to: Screen.map);
        break;
      default:
        c.setPaused(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final reduced = sv.progress.reducedMotion || MediaQuery.of(context).disableAnimations;
    if (_intro) return Cutscene(kind: CutsceneKind.arrival, onDone: _introDone, reducedMotion: reduced);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final phase = c.phase;
        final theme = c.look.theme;
        _accent = theme.accent;
        final launching = phase == StoryPhase.launching;
        final dialog = phase == StoryPhase.dialog && c.line != null;
        final bottom = MediaQuery.of(context).padding.bottom;
        return Stack(
          fit: StackFit.expand,
          children: [
            // the Moon fills the whole screen
            SurfaceView(driver: c, paused: c.paused || launching, reducedMotion: reduced),
            // a soft shade under the status bar so the text stays readable (no hard edge)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99020504), Color(0x55020504), Color(0x22020504), Color(0x00020504)],
                      stops: [0, 0.4, 0.7, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (!c.finished && !launching) _controls(bottom),
            // the mission's mood: a name that glides in when the light changes
            if (!c.finished && !launching)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).padding.top + 74,
                child: IgnorePointer(child: _MoodBanner(theme: theme, reduced: reduced)),
              ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hud(),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: Motion.normal,
                      switchInCurve: Motion.curve,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, -0.08), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: dialog
                          ? SizedBox(
                              key: ValueKey('line-${c.lineId}'),
                              height: 124,
                              child: _DialogueBox(
                                line: c.line!,
                                onNext: c.advance,
                                speed: sv.progress.textSpeed,
                                instant: reduced,
                                onClick: sv.audio.typeClick,
                                tips: c.tipsFor(c.line!.text),
                                onTip: c.showWord,
                              ),
                            )
                          : const SizedBox(key: ValueKey('noline'), width: double.infinity),
                    ),
                    if (dialog) const SizedBox(height: 8),
                    _toast(),
                  ],
                ),
              ),
            ),
            if (c.hintOpen && phase == StoryPhase.explore) Positioned(left: 16, right: 16, bottom: 150 + bottom, child: _hintCard()),
            // decisions slide up from the bottom
            _slideUp(visible: phase == StoryPhase.choice, child: _choicePanel()),
            // mini-games open full screen from the middle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              reverseDuration: const Duration(milliseconds: 380),
              switchInCurve: Motion.curve,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: reduced ? 1.0 : 0.86, end: 1.0).animate(a),
                  child: child,
                ),
              ),
              child: phase == StoryPhase.game && c.step.game != null ? _gamePanel(sv) : const SizedBox.shrink(key: ValueKey('nogame')),
            ),
            if (c.finished) _DebriefOverlay(c: c, key: ValueKey('debrief-${c.phase}')),
            if (launching) Cutscene(kind: CutsceneKind.launch, onDone: c.launched, reducedMotion: reduced),
            // live lesson: the teacher paused the whole class
            AnimatedBuilder(animation: sv.session, builder: (context, _) => sv.session.livePaused && !c.finished ? const _TeacherPause() : const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  Widget _slideUp({required bool visible, required Widget child}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: Motion.normal,
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(duration: Motion.normal, curve: Motion.curve, offset: visible ? Offset.zero : const Offset(0, 0.25), child: visible ? child : const SizedBox.shrink()),
      ),
    );
  }

  // ------------------------------------------------------------------ HUD

  Widget _hud() {
    final run = c.run;
    final s = c.step;
    final count = s.kind == StepKind.collect ? '${run.done.length}/${s.items.length}' : null;
    final cadet = c.mode == AgeMode.cadet;
    final o2 = run.suitO2, hp = run.carry.health;
    final f = run.carry.flags;
    final signalLevel = c.campaign.id == CampaignId.explorer && c.task.n == 1;
    final b = run.carry.battery;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.bg.withValues(alpha: 0.62), C.bg.withValues(alpha: 0.4)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color.lerp(C.frozen, _accent, 0.55)!.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  c.task.title,
                  style: T.h3.copyWith(fontSize: 14.5, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                AnimatedSwitcher(
                  duration: Motion.normal,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Level ${c.task.n} · ${s.objective}'),
                        if (count != null)
                          TextSpan(
                            text: '  $count',
                            style: const TextStyle(color: C.cyan, fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                    key: ValueKey('${s.id}$count'),
                    style: T.bodySmall.copyWith(fontSize: 11.5, color: C.muted, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          RingMeter(value: o2 / 100, label: 'O₂', text: '${o2.round()}', icon: cadet ? Icons.air_rounded : null, low: run.outside && o2 < 25 && !cadet),
          const SizedBox(width: 6),
          RingMeter(value: hp / 100, label: 'HP', text: '${hp.round()}', icon: cadet ? Icons.favorite_rounded : null, color: C.frozen, low: hp < 35),
          const SizedBox(width: 6),
          signalLevel
              ? RingMeter(
                  value: f.contains('radio') ? 1 : 0.08,
                  label: 'SIGNAL',
                  text: f.contains('radio') ? 'OK' : '–',
                  icon: Icons.cell_tower_rounded,
                  color: C.cyan,
                  low: !f.contains('radio'),
                )
              : RingMeter(value: b / 100, label: 'PWR', text: '${b.round()}', icon: cadet ? Icons.bolt_rounded : null, color: C.sapphire, low: b < 20),
          const SizedBox(width: 6),
          Pressable(
            onTap: _openMenu,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.frozen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.pause_rounded, color: C.frozen, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toast() {
    final t = c.toast;
    return AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.curve,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.2), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: t == null
          ? const SizedBox.shrink()
          : GestureDetector(
              key: ValueKey(t.id),
              onTap: c.dismissToast,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
                decoration: BoxDecoration(
                  color: C.indigo.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (t.good ? _accent : C.red).withValues(alpha: 0.6)),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PipFigure(size: 38, eye: t.good ? PipEye.happy : PipEye.alarm),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${t.who}: ',
                                  style: const TextStyle(color: C.cyan, fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: t.title),
                              ],
                            ),
                            style: T.h3.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          TypingText(
                            t.lines.take(4).join('\n'),
                            // a word card does not underline words inside its own meaning
                            tips: glossary.any((w) => t.lines.contains(w.meaning)) ? const [] : c.tipsFor(t.lines.take(4).join('\n')),
                            onTip: c.showWord,
                            style: T.body.copyWith(fontSize: 13.5, height: 1.35),
                            speed: Services.of(context).progress.textSpeed * 1.4,
                            instant: Services.of(context).progress.reducedMotion,
                            onClick: Services.of(context).audio.typeClick,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _hintCard() {
    return GestureDetector(
      onTap: c.toggleHint,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
        decoration: BoxDecoration(
          color: C.indigo.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            const PipFigure(size: 36, eye: PipEye.thinking),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'HINT: ',
                      style: TextStyle(color: C.cyan, fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: c.hint.isEmpty ? 'Follow the arrow to the glowing ring, then press the big button.' : c.hint),
                  ],
                ),
                style: T.body.copyWith(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ deck

  Widget _controls(double bottom) {
    final explore = c.phase == StoryPhase.explore;
    final label = c.actionLabel;
    final canGo = explore && c.goal != null && c.mode != AgeMode.engineer;
    String text;
    VoidCallback? tap;
    var color = C.sapphire;
    var textColor = Colors.white;
    if (label != null) {
      text = label;
      tap = c.action;
      // the action button wears this mission's colour
      color = _accent;
      textColor = _accent.computeLuminance() > 0.45 ? C.ink : Colors.white;
    } else if (explore && c.sprinting) {
      text = 'SPRINT';
      tap = c.jump;
      color = C.cyan;
      textColor = C.ink;
    } else if (canGo) {
      text = 'GO';
      tap = c.goToGoal;
      color = C.indigo;
    } else if (explore) {
      text = 'JUMP';
      tap = c.jump;
      color = C.indigo;
    } else {
      text = '···';
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 230 + bottom,
      child: Stack(
        children: [
          // left half: the joystick appears where the thumb lands
          Positioned(
            left: 0,
            bottom: bottom,
            width: MediaQuery.of(context).size.width * 0.52,
            height: 230,
            child: FloatingStick(enabled: explore, sprinting: c.sprinting, onChanged: c.steer, onSprint: c.setSprint, onSwipeUp: c.jump),
          ),
          Positioned(
            right: 20,
            bottom: 28 + bottom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // the two tools stand in a column exactly as tall as the action button
                SizedBox(
                  height: 92,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ToolDisc(icon: Icons.center_focus_strong_rounded, tooltip: 'Scan with Pip', onTap: c.paused ? null : c.scan),
                      ToolDisc(icon: Icons.lightbulb_outline_rounded, tooltip: 'Hint', active: c.hintOpen, onTap: explore ? c.toggleHint : null),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(a),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: ActionDisc(key: ValueKey(text), label: text, onTap: tap, color: color, textColor: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ decisions

  Widget _choicePanel() {
    final s = c.step;
    final run = c.run;
    final total = run.stepTimer;
    final last = c.lastChoice;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottom),
        decoration: const BoxDecoration(
          color: C.panelSolid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: C.line)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 30)],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('DECISION', style: T.label),
                  const Spacer(),
                  if (total > 0) Text('${run.timer.ceil()} s', style: T.h3.copyWith(color: run.timer < 6 ? C.red : C.cyan)),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: (run.timer / total).clamp(0.0, 1.0), minHeight: 5, backgroundColor: C.lineSoft, color: run.timer < 6 ? C.red : C.cyan),
                ),
              ],
              const SizedBox(height: 10),
              Text(s.question.isEmpty ? s.objective : s.question, style: T.h2.copyWith(fontSize: 19, height: 1.3)),
              if (last != null && last.mistake && s.options.contains(last)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.red.withValues(alpha: 0.4)),
                  ),
                  child: Text('"${last.label}" didn\'t work. Think again: what keeps Nova safest?', style: T.body.copyWith(fontSize: 13.5)),
                ),
              ],
              const SizedBox(height: 14),
              for (var i = 0; i < s.options.length; i++)
                EnterAnim(
                  delayMs: 60 * i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionButton(index: i, option: s.options[i], tried: last != null && last.id == s.options[i].id && last.mistake, onTap: () => c.choose(s.options[i].id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ mini-games

  Widget _gamePanel(Services sv) {
    final spec = c.step.game!;
    return Container(
      key: ValueKey('game-${c.step.id}'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2752), C.panelDeep, C.bg]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('LEVEL ${c.task.n} · ${c.task.title.toUpperCase()}', style: T.label.copyWith(fontSize: 10.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openMenu,
                    child: const Icon(Icons.pause_circle_outline_rounded, color: C.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GameContext(
                  mode: c.mode,
                  onHint: c.gameHint,
                  child: buildMiniGame(spec, c.finishGame, sv.audio, stepId: c.step.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================== pieces

class _OptionButton extends StatelessWidget {
  final int index;
  final StoryOption option;
  final bool tried;
  final VoidCallback onTap;
  const _OptionButton({required this.index, required this.option, required this.tried, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: tried ? null : onTap,
      child: Opacity(
        opacity: tried ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: C.indigo,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.cyan.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: C.sapphire.withValues(alpha: 0.9)),
                child: Text(String.fromCharCode(65 + index), style: T.h3.copyWith(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: T.h3.copyWith(fontSize: 15)),
                    if (option.detail.isNotEmpty) ...[const SizedBox(height: 2), Text(option.detail, style: T.bodySmall)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dialogue box: portrait, name, the line typing in. Tap to finish the
/// line at once, tap again for the next one.
class _DialogueBox extends StatefulWidget {
  final Line line;
  final VoidCallback onNext;
  final double speed;
  final bool instant;
  final VoidCallback? onClick;
  final List<TipHit> tips;
  final void Function(WordTip tip)? onTip;
  const _DialogueBox({required this.line, required this.onNext, this.speed = 1, this.instant = false, this.onClick, this.tips = const [], this.onTip});

  @override
  State<_DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<_DialogueBox> with SingleTickerProviderStateMixin {
  late final TypingClock _clock = TypingClock(widget.line.text, speed: widget.speed, onClick: widget.onClick);
  late final Ticker _ticker;
  final _rec = TipRecognizers();

  @override
  void initState() {
    super.initState();
    _rec.sync(widget.tips, widget.onTip);
    if (widget.instant) _clock.finish();
    _ticker = createTicker((e) {
      if (_clock.tick(e.inMicroseconds / 1e6)) setState(() {});
      if (_clock.done) _ticker.stop();
    });
    if (!widget.instant) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _tap() {
    if (!_clock.done) {
      // tap once: show the whole line (the clicks stop at once)
      _ticker.stop();
      setState(_clock.finish);
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final n = _clock.shown.clamp(0, l.text.length);
    final done = _clock.done;
    final color = l.who == Speaker.nova ? C.frozen : (l.who == Speaker.aria ? C.violet : C.cyan);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: C.indigo.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Portrait(who: l.who, mood: l.mood, talking: !done),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(speakerName(l.who).toUpperCase(), style: T.label.copyWith(color: color, fontSize: 10)),
                  const SizedBox(height: 3),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text.rich(
                        TextSpan(
                          children: typedSpans(l.text, n, tips: widget.tips, recognizers: _rec.map),
                        ),
                        style: T.body.copyWith(fontSize: 15, height: 1.38, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: done ? 1 : 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tap to continue', style: T.bodySmall.copyWith(fontSize: 11.5, color: C.dim)),
                          const Icon(Icons.chevron_right_rounded, color: C.cyan, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  final Speaker who;
  final Mood mood;
  final bool talking;
  const _Portrait({required this.who, required this.mood, required this.talking});

  @override
  Widget build(BuildContext context) {
    Widget inner;
    switch (who) {
      case Speaker.nova:
        inner = _NovaHead(mood: mood, talking: talking);
        break;
      case Speaker.aria:
        inner = _Wave(active: talking);
        break;
      case Speaker.capcom:
        inner = const Icon(Icons.headset_mic_rounded, color: C.cyan, size: 30);
        break;
      default:
        inner = const Icon(Icons.person_rounded, color: C.cyan, size: 30);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: Motion.normal,
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.panelDeep,
          border: Border.all(color: C.cyan.withValues(alpha: 0.5), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: inner,
      ),
    );
  }
}

class _NovaHead extends StatefulWidget {
  final Mood mood;
  final bool talking;
  const _NovaHead({required this.mood, required this.talking});

  @override
  State<_NovaHead> createState() => _NovaHeadState();
}

class _NovaHeadState extends State<_NovaHead> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = switch (widget.mood) {
      Mood.happy => NovaMood.happy,
      Mood.worried => NovaMood.worried,
      Mood.scared => NovaMood.scared,
      Mood.tired => NovaMood.tired,
      Mood.calm => NovaMood.calm,
    };
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(size: const Size(62, 62), painter: _HeadPainter(_c.value * 30, mood, widget.talking)),
    );
  }
}

class _HeadPainter extends CustomPainter {
  final double t;
  final NovaMood mood;
  final bool talking;
  _HeadPainter(this.t, this.mood, this.talking);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // centre the helmet (at about x 3, y -80 in Nova's units) in the circle
    const s = 1.55;
    canvas.translate(size.width / 2 - 6 * s, size.height / 2 + 81 * s);
    canvas.scale(s);
    paintNova(canvas, NovaPose(mood: mood, t: t, visorUp: true, talking: talking));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeadPainter old) => true;
}

class _Wave extends StatefulWidget {
  final bool active;
  const _Wave({required this.active});

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: const Size(40, 30), painter: _WavePainter(_c.value, widget.active)),
      );
}

class _WavePainter extends CustomPainter {
  final double t;
  final bool active;
  _WavePainter(this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.violet
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = i * size.width / 6;
      final h = active ? (0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 2 + i * 1.3)).abs()) : 0.2;
      canvas.drawLine(Offset(x, size.height / 2 - h * size.height / 2), Offset(x, size.height / 2 + h * size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}

// ==================================================================== debrief

class _DebriefOverlay extends StatefulWidget {
  final StoryController c;
  const _DebriefOverlay({super.key, required this.c});

  @override
  State<_DebriefOverlay> createState() => _DebriefOverlayState();
}

class _DebriefOverlayState extends State<_DebriefOverlay> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final sv = Services.of(context);
    final won = c.phase == StoryPhase.done;
    final info = c.campaign.info(c.task.n);
    final run = c.run;
    final mode = c.mode;
    final bottom = MediaQuery.of(context).padding.bottom;
    // Season 1 of the Explorer campaign ends with the flight home, then Season 2 opens
    final seasonEnd = c.campaign.id == CampaignId.explorer && c.task.n == 10;
    final next = c.task.n < c.campaign.length && !seasonEnd ? c.task.n + 1 : null;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Motion.curve,
      builder: (context, v, child) => Stack(
        fit: StackFit.expand,
        children: [
          // gameplay blurs and dims behind the card
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * v, sigmaY: 10 * v),
            child: ColoredBox(color: C.bg.withValues(alpha: 0.82 * v)),
          ),
          Transform.translate(
            offset: Offset(0, 60 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  Text(
                    won ? 'LEVEL ${c.task.n} COMPLETE' : 'LEVEL ${c.task.n} · MISSION FAILED',
                    style: T.label.copyWith(letterSpacing: 4, color: won ? C.cyan : C.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(won ? info.winTitle : 'Try again, Commander', style: T.hero.copyWith(fontSize: 36), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (won) Center(child: _PopStars(stars: run.stars)),
                  const SizedBox(height: 12),
                  Text(
                    won ? '${run.mistakes} mistake${run.mistakes == 1 ? '' : 's'} · Health ${run.carry.health.round()} · Spare parts ${run.carry.spares}' : run.failReason,
                    style: T.body.copyWith(color: C.muted),
                    textAlign: TextAlign.center,
                  ),
                  if (won && run.hintsUsed > 0 && !mode.hintsFree)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('A hint was used: one star less.', style: T.bodySmall, textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 20),
                  EnterAnim(delayMs: 200, child: _lesson(info, mode)),
                  const SizedBox(height: 12),
                  EnterAnim(
                    delayMs: 320,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _smallCard('YOU DID', _youDid(run), C.cyan)),
                          const SizedBox(width: 12),
                          Expanded(child: _smallCard('NASA DOES', info.nasaDoes, C.frozen)),
                        ],
                      ),
                    ),
                  ),
                  if (mode == AgeMode.engineer) ...[const SizedBox(height: 12), EnterAnim(delayMs: 380, child: _smallCard('HOW ENGINEERS CALCULATE IT', info.howCalc, C.sapphire))],
                  if (c.evidence.isNotEmpty) ...[const SizedBox(height: 12), EnterAnim(delayMs: 420, child: _SkillsEarned(evidence: c.evidence))],
                  if (won) ...[
                    const SizedBox(height: 16),
                    EnterAnim(
                      delayMs: 480,
                      child: _Journal(day: c.campaign.dayLabel(c.task.n), text: info.journal),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: HudButton(
                      label: won ? 'REPLAY' : 'MAP',
                      onTap: () => won ? sv.nav.startStory(c.task.n, sv) : sv.nav.endStory(to: Screen.map),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: PrimaryButton(
                      label: !won ? 'Try again' : (next == null ? 'Final message' : 'Next: level $next'),
                      onTap: () {
                        if (!won) {
                          sv.nav.startStory(c.task.n, sv);
                        } else if (next == null) {
                          sv.nav.endingCampaign = c.campaign.id;
                          sv.nav.endingLevel = c.task.n;
                          sv.nav.endStory(to: Screen.ending);
                        } else {
                          sv.nav.startStory(next, sv);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _youDid(StoryRun run) {
    if (run.outcome != TaskOutcome.complete) {
      return run.slips.isEmpty ? 'Kept going as long as the suit allowed.' : 'Tried hard, but ${run.slips.take(2).join(' and ')}.';
    }
    if (run.slips.isEmpty) return 'Got every decision right the first time and kept Nova at ${run.carry.health.round()} health.';
    final first = run.slips.first;
    return 'Made ${run.mistakes} mistake${run.mistakes == 1 ? '' : 's'} (first, $first), learned from it and finished the job.';
  }

  Widget _lesson(LevelInfo info, AgeMode mode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.cyan.withValues(alpha: 0.12), C.ink.withValues(alpha: 0.6)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.cyan.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_border_rounded, color: C.cyan, size: 22),
              const SizedBox(width: 10),
              Text('LESSON', style: T.label.copyWith(fontSize: 12, letterSpacing: 3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(info.moral, style: T.h3.copyWith(fontSize: 19, height: 1.3)),
          if (mode != AgeMode.cadet) ...[const SizedBox(height: 8), Text(info.moralBody, style: T.body.copyWith(color: C.muted))],
        ],
      ),
    );
  }

  Widget _smallCard(String label, String text, Color c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: C.indigo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.label.copyWith(color: c, letterSpacing: 2.2)),
          const SizedBox(height: 8),
          Text(text, style: T.body.copyWith(fontSize: 14, height: 1.45)),
        ],
      ),
    );
  }
}

/// Stars pop in one by one; the last one with a bigger burst.
class _PopStars extends StatelessWidget {
  final int stars;
  const _PopStars({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + 260 * i),
              curve: Interval((260 * i) / (500 + 260 * i), 1, curve: Curves.elasticOut),
              builder: (context, v, _) => Transform.scale(
                scale: i < stars ? v * (i == 1 ? 1.2 : 1) : 1,
                child: i < stars ? const SparkleStar(size: 50, color: C.cyan) : const _EmptyStar(size: 50),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyStar extends StatelessWidget {
  final double size;
  const _EmptyStar({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _OutlineStar()),
      );
}

class _OutlineStar extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      sparklePath(s.center(Offset.zero), s.width / 2),
      Paint()
        ..color = C.dim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nova's journal: a slightly tilted paper card in handwriting style.
/// Shown over the game while the teacher has paused a live lesson.
class _TeacherPause extends StatelessWidget {
  const _TeacherPause();

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: C.bg.withValues(alpha: 0.88),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PipFigure(size: 80, eye: PipEye.normal),
                const SizedBox(height: 16),
                Text('Eyes on your teacher', style: T.hero.copyWith(fontSize: 30), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Mission Control paused the class. The game continues when your teacher says go.',
                  style: T.body.copyWith(color: C.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

/// The skills this level gave evidence for, with how many decisions were good.
class _SkillsEarned extends StatelessWidget {
  final List<(Skill, bool)> evidence;
  const _SkillsEarned({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final good = <Skill, int>{}, all = <Skill, int>{};
    for (final (k, ok) in evidence) {
      all[k] = (all[k] ?? 0) + 1;
      if (ok) good[k] = (good[k] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: C.indigo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.violet.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SKILLS PRACTISED', style: T.label.copyWith(color: C.violet, letterSpacing: 2.2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in all.keys)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: C.panelDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon((good[k] ?? 0) == all[k] ? Icons.check_circle_rounded : Icons.trending_up_rounded, size: 16, color: (good[k] ?? 0) == all[k] ? C.cyan : C.violet),
                      const SizedBox(width: 6),
                      Text('${k.title}  ${good[k] ?? 0}/${all[k]}', style: T.body.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Journal extends StatelessWidget {
  final String day;
  final String text;
  const _Journal({required this.day, required this.text});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2B2118);
    return Transform.rotate(
      angle: -0.012,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E9D8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Nova\'s journal · $day', style: T.h2.copyWith(color: ink, fontSize: 19)),
                ),
                const SizedBox(width: 36, height: 24, child: CustomPaint(painter: _Doodle())),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: T.h2.copyWith(color: ink, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Doodle extends CustomPainter {
  const _Doodle();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFF2B2118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(2, s.height - 2)
        ..lineTo(s.width * 0.35, 2)
        ..lineTo(s.width * 0.68, s.height - 2)
        ..close(),
      p,
    );
    canvas.drawCircle(Offset(s.width * 0.35, s.height * 0.55), 2.5, Paint()..color = const Color(0xFFC0392B));
    final r = Paint()
      ..color = const Color(0xFFC0392B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.68, s.height - 3), Offset(s.width - 2, s.height - 3), r);
    canvas.drawLine(Offset(s.width - 8, s.height - 9), Offset(s.width - 2, s.height - 3), r);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Shows the mission's mood ("ICE CRATER", "SOLAR STORM"...) for a moment
/// each time it changes, in the mission colour.
class _MoodBanner extends StatefulWidget {
  final MissionTheme theme;
  final bool reduced;
  const _MoodBanner({required this.theme, this.reduced = false});

  @override
  State<_MoodBanner> createState() => _MoodBannerState();
}

class _MoodBannerState extends State<_MoodBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  String _name = '';

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void didUpdateWidget(covariant _MoodBanner old) {
    super.didUpdateWidget(old);
    if (old.theme.name != widget.theme.name) _show();
  }

  void _show() {
    _name = widget.theme.name;
    _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.theme.accent;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final o = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        final dx = widget.reduced ? 0.0 : (1 - Curves.easeOutCubic.transform((t / 0.25).clamp(0.0, 1.0))) * 40;
        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 26, height: 1.5, color: c.withValues(alpha: 0.8)),
                const SizedBox(width: 10),
                Text(_name, style: T.label.copyWith(color: c, fontSize: 12, letterSpacing: 4, shadows: const [Shadow(color: Colors.black, blurRadius: 8)])),
                const SizedBox(width: 10),
                Container(width: 26, height: 1.5, color: c.withValues(alpha: 0.8)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
