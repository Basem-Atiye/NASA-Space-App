import 'package:flutter/material.dart';

import '../engine/simulation.dart';
import '../game/game_controller.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/hud.dart';
import '../world/base_view.dart';
import 'game_sheets.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _alarmPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  bool _leaving = false;
  bool _wired = false;

  GameController get g => widget.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    final sv = Services.of(context);
    sv.nav.gameBack = _openMenu;
    g.addListener(_onGame);
  }

  @override
  void dispose() {
    g.removeListener(_onGame);
    _alarmPulse.dispose();
    super.dispose();
  }

  void _onGame() {
    if (g.finished && !_leaving) {
      _leaving = true;
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        final sv = Services.of(context);
        sv.nav.go(Screen.debrief);
      });
    }
  }

  /// Tapping a room in the base opens what you can do there.
  void _onBaseTap(String area) {
    if (!mounted || g.modal != null || g.cargo != null || g.finished || g.sheetOpen) return;
    switch (area) {
      case 'command':
        _open((c) => LogSheet(g: g));
        break;
      case 'life':
        _open((c) => TaskSheet(g: g));
        break;
      case 'greenhouse':
      case 'outside':
        _open((c) => PowerSheet(g: g));
        break;
      case 'airlock':
        _open((c) => EvaSheet(g: g));
        break;
    }
  }

  void _open(Widget Function(BuildContext) b) => openSheet(context, g, b);

  void _openData() {
    Navigator.of(context).maybePop();
    final sv = Services.of(context);
    g.userPaused = true;
    sv.nav.go(Screen.data);
  }

  Future<void> _openMenu() async {
    if (g.finished) return;
    final sv = Services.of(context);
    final wasPaused = g.userPaused;
    g.userPaused = true;
    g.audio.tap();
    // ignore: use_build_context_synchronously
    final choice = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('MISSION PAUSED', style: T.h2, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                HudButton(label: 'RESUME', icon: Icons.play_arrow_rounded, filled: true, onTap: () => Navigator.of(ctx).pop('resume')),
                const SizedBox(height: 8),
                HudButton(label: 'RESTART MISSION', icon: Icons.replay_rounded, onTap: () => Navigator.of(ctx).pop('restart')),
                const SizedBox(height: 8),
                HudButton(label: 'MISSION DATA', icon: Icons.menu_book_rounded, onTap: () => Navigator.of(ctx).pop('data')),
                const SizedBox(height: 8),
                HudButton(label: 'QUIT TO MISSIONS', icon: Icons.logout_rounded, color: C.amber, onTap: () => Navigator.of(ctx).pop('quit')),
              ]),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restart':
        g.restart();
        break;
      case 'data':
        sv.nav.go(Screen.data);
        break;
      case 'quit':
        g.stop();
        sv.audio.ambient('music');
        sv.nav.resetTo(Screen.missions);
        break;
      default:
        g.userPaused = choice == 'resume' ? false : wasPaused;
        g.audio.tap();
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return AnimatedBuilder(
      animation: g,
      builder: (context, _) {
        final s = g.sim;
        final modal = g.modal;
        final cargo = g.cargo;
        return Stack(
          fit: StackFit.expand,
          children: [
            Shaker(
              trigger: g.shake,
              strength: g.shakeStrength,
              child: Column(children: [
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    BaseView(view: () => g.view, onTap: _onBaseTap, paused: g.userPaused),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TopBar(g: g, onMenu: _openMenu),
                          const SizedBox(height: 8),
                          GaugeStrip(sim: s, onTap: (id) => _open((c) => GaugeInfoSheet(g: g, id: id))),
                          const SizedBox(height: 6),
                          Center(child: ObjectivesStrip(s: s)),
                          const SizedBox(height: 6),
                          Center(child: EventBanner(info: g.banner)),
                        ]),
                      ),
                    ),
                    if (g.userPaused && modal == null)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(child: Center(child: Text('PAUSED · tap 1x to resume', style: T.label.copyWith(color: C.frozen, fontSize: 12)))),
                      ),
                  ]),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
                  decoration: const BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.lineSoft))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CrewCard(g: g, textSpeed: sv.progress.textSpeed, onOpenLog: () => _open((c) => LogSheet(g: g))),
                    const SizedBox(height: 10),
                    _dock(s),
                  ]),
                ),
              ]),
            ),
            if (modal != null || cargo != null) Positioned.fill(child: GestureDetector(onTap: () {}, child: Container(color: const Color(0x8C000000)))),
            if (modal != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: MessageModal(
                      key: ValueKey(modal.hashCode ^ g.feed.length),
                      message: modal,
                      textSpeed: sv.progress.textSpeed,
                      onDone: (r) => g.dismissModal(reply: r),
                    ),
                  ),
                ),
              )
            else if (cargo != null)
              SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: CargoModal(options: cargo, onChoose: g.chooseCargo)))),
            if (g.finished) IgnorePointer(child: _FinishFlash(won: s.outcome == Outcome.won)),
          ],
        );
      },
    );
  }

  Widget _dock(MissionSim s) {
    final taskBadge = s.broken.isNotEmpty && s.activity != Activity.repair && !s.onEva
        ? '!'
        : (s.storm != null && s.location != CrewLocation.shelter && !s.onEva ? '!' : null);
    final evaBadge = s.onEva && s.storm != null ? '!' : null;
    Widget tile(String label, IconData icon, VoidCallback onTap, {String? badge, bool active = false, bool enabled = true}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Pressable(
              onTap: onTap,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: active ? C.evergreen : C.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: active ? C.cyan : C.line, width: active ? 1.5 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: enabled ? C.cyan : C.dim, size: 22),
                    const SizedBox(height: 4),
                    Text(label, style: T.h3.copyWith(fontSize: 12, letterSpacing: 1, color: enabled ? C.text : C.dim), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (badge != null)
                  Positioned(
                    right: 4,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(9)),
                      child: Text(badge, style: T.h3.copyWith(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ]),
            ),
          ),
        );
    return Row(children: [
      tile('POWER', Icons.bolt_rounded, () => _open((c) => PowerSheet(g: g)), badge: s.brownout || (s.netKw < 0 && (s.batteryHoursLeft ?? 99) < 8) ? '!' : null),
      tile('TASK', Icons.build_rounded, () => _open((c) => TaskSheet(g: g)), badge: taskBadge, active: s.broken.isNotEmpty),
      tile(s.onEva ? 'EVA ${s.evaLeft}h' : 'EVA', Icons.directions_walk_rounded, () => _open((c) => EvaSheet(g: g)), badge: evaBadge, enabled: s.mission.evaUnlocked),
      tile('MISSION', Icons.flag_rounded, () => _open((c) => MissionSheet(g: g, onData: _openData))),
    ]);
  }
}

class _FinishFlash extends StatelessWidget {
  final bool won;
  const _FinishFlash({required this.won});

  @override
  Widget build(BuildContext context) {
    final c = won ? C.green : C.red;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        color: C.bg.withValues(alpha: 0.55 * v),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 0.9 + 0.1 * v,
          child: Opacity(
            opacity: v,
            child: Text(
              won ? 'Mission complete' : 'Mission failed',
              textAlign: TextAlign.center,
              style: T.hero.copyWith(fontSize: 38, color: c, shadows: [Shadow(color: c, blurRadius: 24)]),
            ),
          ),
        ),
      ),
    );
  }
}
