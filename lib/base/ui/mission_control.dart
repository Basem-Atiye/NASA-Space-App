/// Mission Control: the main base game (Figma 04 Base, 05 module panel,
/// 06/20 emergency cards, 14 Power, 15 Crew, 16 Log, 17 Pause).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../ui/game_helper.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../../services/audio.dart';
import '../../ui/astro_art.dart';
import '../../ui/figma_art.dart';
import '../../ui/kit.dart';
import '../../ui/line_icons.dart';
import '../../ui/theme.dart';
import '../base_engine.dart';
import '../base_strip.dart';
import 'base_screens.dart';
import 'base_style.dart';
import 'base_world.dart';

class MissionControlScreen extends StatefulWidget {
  final BaseState state;
  const MissionControlScreen({super.key, required this.state});

  @override
  State<MissionControlScreen> createState() => _MissionControlScreenState();
}

class _MissionControlScreenState extends State<MissionControlScreen> with SingleTickerProviderStateMixin {
  BaseState get s => widget.state;
  int _tab = 0;
  bool _paused = false;
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  Duration _last = Duration.zero;
  Timer? _auto;
  bool _ending = false;

  /// After an event choice: what happened (shown on the card before closing).
  EventOption? _result;
  EventDef? _resultEvent;
  int? _choice;

  /// A short line after each day ("The storm passed. The crew was safe.").
  String? _dayNote;

  /// Yesterday's numbers, to show what changed on each tile.
  Map<String, double> _yesterday = {};

  /// Nova and the side-scrolling base.
  final _strip = BaseStrip(start: spotX[Spot.habitat]!);
  double _viewMetres = 13;

  /// The building she is walking to for the player (its panel opens when she gets there).
  Spot? _openOnArrive;
  bool _moved = false;
  int _jumps = 0;

  static const _jumpLines = ['Moon jump! Gravity here is 1/6 of Earth’s.', 'I weigh 6 times less on the Moon!', 'Wheee! Slow and high!', 'No air, so no wind in my face.'];

  Map<String, double> _snap() => {'o': s.oxygen, 'w': s.water, 'f': s.food, 'b': s.battery, 'c': s.crewHealth};
  double? _d(String k, double now) => _yesterday[k] == null ? null : now - _yesterday[k]!;

  // ---------------------------------------------------------------- Nova and the base

  /// The buildings this mission has.
  Set<Spot> get _built => {
        Spot.power,
        Spot.habitat,
        Spot.lab,
        if (s.mission.systems.contains(Sys.greenhouse)) Spot.greenhouse,
        if (s.mission.systems.contains(Sys.recycler)) Spot.recycler,
      };

  /// The building that needs Nova most right now.
  Spot? get _alertSpot {
    if (s.leaking) return Spot.habitat;
    final w = s.warning;
    if (w?.system != null) return _spotFor(w!.system!);
    if (s.dust > 0.3) return Spot.power;
    return null;
  }

  static Spot _spotFor(Sys sys) => switch (sys) {
        Sys.lifeSupport => Spot.habitat,
        Sys.greenhouse => Spot.greenhouse,
        Sys.recycler => Spot.recycler,
        Sys.research => Spot.lab,
        Sys.shield => Spot.habitat,
      };

  String? get _alertLabel => switch (_alertSpot) {
        Spot.power => 'Dusty panels',
        Spot.habitat => s.leaking ? 'Air leak' : 'Life Support',
        Spot.greenhouse => 'Greenhouse',
        Spot.recycler => 'Recycler',
        Spot.lab => 'Lab',
        null => null,
      };

  bool get _sheetOpen => !mounted || ModalRoute.of(context)?.isCurrent != true;

  void _stepNova(double dt) {
    final arrived = _strip.update(dt, view: _viewMetres, shelter: s.sheltering);
    if (arrived == null) return;
    if (arrived == _openOnArrive) {
      _openOnArrive = null;
      if (!_sheetOpen) _useSpot(arrived);
    } else if (arrived == _alertSpot) {
      _strip.say('On it!');
      _strip.doEmote(StripEmote.work, 1.4);
    }
  }

  /// A building was tapped: Nova walks over and its panel opens. Far away,
  /// the panel opens at once and she bounds over while you decide.
  void _tapBuilding(Spot sp) {
    _moved = true;
    final reduce = sv.progress.reducedMotion || MediaQuery.of(context).disableAnimations;
    if (reduce || _strip.nearIn(_built) == sp || _openOnArrive == sp || _strip.inside) {
      _openOnArrive = null;
      _useSpot(sp);
      return;
    }
    sv.audio.tap();
    final secs = _strip.goTo(sp);
    if (secs > 3.2) {
      _openOnArrive = null;
      _useSpot(sp);
    } else {
      _openOnArrive = sp;
    }
  }

  /// Opens the panel for a building, with Nova working at it.
  void _useSpot(Spot sp) {
    if (_strip.nearIn(_built) == sp) _strip.doEmote(sp == Spot.greenhouse ? StripEmote.kneel : StripEmote.work, 2.4);
    switch (sp) {
      case Spot.power:
        _openPanels();
      case Spot.habitat:
        _openModule(Sys.lifeSupport);
      case Spot.greenhouse:
        _openModule(Sys.greenhouse);
      case Spot.recycler:
        _openModule(Sys.recycler);
      case Spot.lab:
        _openModule(s.mission.systems.contains(Sys.research) ? Sys.research : Sys.lifeSupport);
    }
  }

  void _travel(Spot sp) {
    _moved = true;
    _openOnArrive = null;
    _strip.goTo(sp);
    sv.audio.tap();
  }

  void _walkTo(double m) {
    _moved = true;
    _openOnArrive = null;
    _strip.goToX(m);
  }

  void _steer(double v) {
    if (v.abs() > 0.08) {
      _moved = true;
      _openOnArrive = null;
    }
    _strip.steer(v);
  }

  /// A Moon jump (Nova tapped, the JUMP button or a flick up).
  void _jump({bool fact = false}) {
    if (_strip.jump()) {
      sv.audio.footstep(hard: true);
      HapticFeedback.selectionClick();
      if (fact) _strip.say(_jumpLines[_jumps++ % _jumpLines.length], secs: 2.8);
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final dt = (d - _last).inMicroseconds / 1e6;
      _last = d;
      if (!_paused) {
        final step = dt.clamp(0.0, 0.05);
        _t.value += step;
        _stepNova(step);
      }
    })
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sv = Services.of(context);
      sv.nav.gameBack = _togglePause;
      if (s.pendingEvent != null) sv.audio.play(Sfx.alert, volume: 0.6);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  Services get sv => Services.of(context);

  void _togglePause() {
    _stopAuto();
    setState(() => _paused = !_paused);
    if (_paused) sv.base.save(s);
  }

  // ---------------------------------------------------------------- days

  void _nextDay() {
    if (!mounted) return;
    if (s.pendingEvent != null || s.outcome != BaseOutcome.running || _ending) return;
    HapticFeedback.lightImpact();
    _yesterday = _snap();
    final r = s.nextDay();
    sv.audio.play(Sfx.tap, volume: 0.5);
    setState(() => _dayNote = r.notes.isEmpty ? null : r.notes.first);
    if (s.pendingEvent == null && s.warning == null && _auto == null && !_strip.walking) _strip.doEmote(StripEmote.cheer, 1.4);
    if (s.pendingEvent != null) {
      _stopAuto();
      sv.audio.play(Sfx.alert, volume: 0.6);
      HapticFeedback.mediumImpact();
    }
    if (s.outcome != BaseOutcome.running) {
      _stopAuto();
      _finish();
      return;
    }
    // stop fast-forward when something needs attention
    if (_auto != null && s.warning != null && s.warning!.color != 'blue') _stopAuto();
    sv.base.save(s);
  }

  void _startAuto() {
    if (_auto != null) return;
    setState(() => _auto = Timer.periodic(const Duration(milliseconds: 650), (_) => _nextDay()));
    _nextDay();
  }

  void _stopAuto() {
    if (_auto == null) return;
    _auto?.cancel();
    if (mounted) setState(() => _auto = null);
  }

  Future<void> _finish() async {
    _ending = true;
    final r = s.result();
    final record = await sv.base.finish(s, r);
    sv.session.recordBaseRun(record, badges: sv.base.justEarned);
    sv.audio.play(r.won ? Sfx.success : Sfx.fail, volume: 0.7);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) sv.nav.showBaseResult(r);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final event = s.pendingEvent;
    return Stack(children: [
      SpaceBackground(
        glow: s.stormIn > 0 ? C.orange : (s.leaking ? C.red : null),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Expanded(
              child: PhoneColumn(
                child: AnimatedSwitcher(
                  duration: Motion.normal,
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      0 => _baseTab(),
                      1 => _PowerTab(state: s, onChanged: () => setState(() {})),
                      2 => _CrewTab(state: s),
                      _ => _LogTab(state: s),
                    },
                  ),
                ),
              ),
            ),
            BottomTabs(
              items: const [TabItem(Ln.home, 'Base'), TabItem(Ln.zap, 'Power'), TabItem(Ln.users, 'Crew'), TabItem(Ln.book, 'Log')],
              index: _tab,
              dots: [false, s.battery < 25 || s.isNight, s.crew.any((c) => c.status != 'OK'), false],
              onTap: (i) => setState(() => _tab = i),
            ),
          ]),
        ),
      ),
      if (event != null || _resultEvent != null) _eventOverlay(),
      if (_paused) _pauseOverlay(),
    ]);
  }

  Widget _header() {
    final total = s.mission.days;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${s.mission.mars ? 'Sol' : 'Day'} ${s.day} ', style: T.h1.copyWith(fontSize: 32)),
                TextSpan(text: '/ $total', style: T.h2.copyWith(color: C.muted, fontSize: 21)),
              ]),
            ),
          ),
          RoundButton(icon: Ln.pause, tooltip: 'Pause', onTap: _togglePause),
          const SizedBox(width: 12),
          _NextDayButton(running: _auto != null, enabled: s.pendingEvent == null && s.outcome == BaseOutcome.running, onTap: _auto != null ? _stopAuto : _nextDay, onLongPress: _startAuto),
        ]),
        const SizedBox(height: 14),
        KitBar(frac: s.day / total, color: C.progress, track: C.panel, height: 8),
      ]),
    );
  }

  Widget _banner() {
    final w = s.warning;
    return AnimatedSwitcher(
      duration: Motion.normal,
      child: _dayNote != null
          ? WarnBanner(key: ValueKey('note${s.day}'), title: 'Day ${s.day - 1} report', sub: _dayNote, color: C.cyan, icon: Ln.info, onTap: () => setState(() => _dayNote = null))
          : s.sheltering
              ? const WarnBanner(key: ValueKey('shelter'), title: 'Sheltering from the storm', sub: 'The crew waits inside the habitat', color: C.orange, icon: Ln.radiation)
              : w != null
                  ? WarnBanner(
                      key: ValueKey(w.title),
                      title: w.title,
                      sub: w.action,
                      color: w.color == 'red' ? C.red : (w.color == 'blue' ? C.violet : C.yellow),
                      icon: w.color == 'blue' ? Ln.sun : Ln.alert,
                      onTap: _alertSpot == null ? null : () => _tapBuilding(_alertSpot!),
                    )
                  : const WarnBanner(key: ValueKey('ok'), title: 'All systems OK', sub: 'Walk around the base, or press Next Day', color: C.green, icon: Ln.check),
    );
  }

  BaseLook _look() {
    final f = s.flows();
    return BaseLook(
      t: _t.value,
      power: (f.gen / 100).clamp(0.0, 1.0),
      greenhouse: s.setting[Sys.greenhouse]!,
      water: s.water / 100,
      air: s.oxygen / 100,
      shield: s.mission.systems.contains(Sys.shield) ? (s.sheltering ? 0.4 : f.protection) : 0,
      dust: s.dust,
      night: s.isNight,
      storm: s.stormIn > 0,
      leak: s.leaking,
      mars: s.mission.mars,
    );
  }

  Widget _baseTab() {
    final f = s.flows();
    final crew = s.crewHealth;
    return LayoutBuilder(builder: (context, box) {
      // the base gets the room that is left; on a short phone the tiles
      // become compact so Nova still has a big stage
      const header = 100.0 + 14 + 14 + 18;
      final parts = s.mission.partsToLaunch > 0 ? 74.0 : 0.0;
      final roomy = box.maxHeight - header - parts - 272 >= 330;
      final tiles = roomy ? 272.0 : 204.0;
      final sceneH = (box.maxHeight - header - parts - tiles).clamp(300.0, 470.0);
      Widget tile(Widget t) => Expanded(child: t);
      final compact = !roomy;
      return ListView(padding: EdgeInsets.zero, physics: const ClampingScrollPhysics(), children: [
        _header(),
        const SizedBox(height: 14),
        // the base: walk around it like the story levels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: sceneH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BaseWorldView(
                strip: _strip,
                t: _t,
                look: _look,
                built: _built,
                alert: () => s.pendingEvent != null ? null : _alertSpot,
                alertLabel: _alertLabel,
                banner: _banner(),
                enabled: s.pendingEvent == null && !_paused,
                showHint: !_moved && s.day <= 2,
                onSize: (sz) => _viewMetres = sz.width / (26 * sz.height / 340),
                onBuilding: _tapBuilding,
                onUse: _useSpot,
                onTravel: _travel,
                onGround: _walkTo,
                onNova: () => _jump(fact: true),
                onJump: _jump,
                onSteer: _steer,
                onSprint: _strip.setSprint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child: Column(children: [
            Row(children: [
              tile(StatTile(compact: compact, icon: Ln.wind, iconColor: C.air, label: 'Oxygen', value: pct(s.oxygen), frac: s.oxygen / 100, delta: _d('o', s.oxygen), deltaKey: s.day, note: _note(s.oxygen, f.oxygenNet), onTap: () => _tapBuilding(Spot.habitat))),
              const SizedBox(width: 12),
              tile(StatTile(compact: compact, icon: Ln.droplet, iconColor: C.water, label: 'Water', value: pct(s.water), frac: s.water / 100, delta: _d('w', s.water), deltaKey: s.day, note: _note(s.water, f.waterNet), onTap: s.mission.systems.contains(Sys.recycler) ? () => _tapBuilding(Spot.recycler) : null)),
              const SizedBox(width: 12),
              tile(StatTile(compact: compact, icon: Ln.sprout, iconColor: C.food, label: 'Food', value: pct(s.food), frac: s.food / 100, delta: _d('f', s.food), deltaKey: s.day, note: _note(s.food, f.foodNet), onTap: s.mission.systems.contains(Sys.greenhouse) ? () => _tapBuilding(Spot.greenhouse) : null)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              tile(StatTile(compact: compact, icon: Ln.zap, iconColor: C.power, label: 'Power', value: pct(s.battery), frac: s.battery / 100, delta: _d('b', s.battery), deltaKey: s.day, note: _note(s.battery, f.batteryNet), onTap: () => setState(() => _tab = 1))),
              const SizedBox(width: 12),
              tile(_shieldTile(f, compact)),
              const SizedBox(width: 12),
              tile(StatTile(compact: compact, icon: Ln.heart, iconColor: C.green, label: 'Crew', value: pct(crew), frac: crew / 100, delta: _d('c', crew), deltaKey: s.day, onTap: () => setState(() => _tab = 2))),
            ]),
            if (s.mission.partsToLaunch > 0) ...[
              const SizedBox(height: 12),
              KitCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                radius: 18,
                border: s.parts >= s.mission.partsToLaunch ? C.green : null,
                child: Row(children: [
                  const IconBox(Ln.wrench, color: C.orange, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: GameText('Repair parts for the launch', style: T.h3.copyWith(fontSize: 16))),
                  GameText('${s.parts.round()} / ${s.mission.partsToLaunch}', style: T.h2.copyWith(color: s.parts >= s.mission.partsToLaunch ? C.green : C.frozen)),
                ]),
              ),
            ],
          ]),
        ),
      ]);
    });
  }

  /// "LOW" under a tile, or a little trend while it is fine.
  String? _note(double v, double perDay) {
    if (v < 20) return 'DANGER';
    if (v < 40) return 'LOW';
    return null;
  }

  Widget _shieldTile(Flows f, bool compact) {
    if (!s.mission.systems.contains(Sys.shield)) {
      return StatTile(compact: compact, icon: Ln.flask, iconColor: C.frozen, label: 'Science', value: '${s.research.round()}', frac: (s.research / s.mission.researchGoal).clamp(0.0, 1.0), state: C.green, onTap: () => _tapBuilding(Spot.lab));
    }
    final storm = s.stormIn > 0;
    final safe = s.sheltering || f.protection >= 0.7;
    return StatTile(
      compact: compact,
      icon: Ln.radiation,
      iconColor: C.shield,
      label: 'Shield',
      value: storm ? (safe ? 'Ready' : 'Storm!') : (f.protection >= 0.15 ? 'Safe' : 'Off'),
      frac: storm && !safe ? 0.15 : math.max(f.protection, 0.05),
      state: storm && !safe ? C.red : (f.protection >= 0.15 || storm ? C.green : C.yellow),
      note: storm ? 'IN ${s.stormIn} DAY${s.stormIn == 1 ? '' : 'S'}' : null,
      onTap: () => _openModule(Sys.shield),
    );
  }

  // ---------------------------------------------------------------- module panel (05)

  Future<void> _openModule(Sys sys) async {
    if (!s.mission.systems.contains(sys)) return;
    sv.audio.tap();
    final apply = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xAA050A1E),
      builder: (_) => _ModuleSheet(state: s, sys: sys, engineer: s.level == Level.engineer),
    );
    if (apply != null) {
      setState(() => s.adjust(sys, apply));
      sv.base.save(s);
      if (_strip.nearIn(_built) == _spotFor(sys)) {
        _strip.doEmote(StripEmote.work, 1.6);
        _strip.say('Done!', secs: 1.8);
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _openPanels() async {
    sv.audio.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xAA050A1E),
      builder: (_) => _PanelsSheet(state: s),
    );
    if (_strip.nearIn(_built) == Spot.power && s.dust < 0.1) _strip.say('Panels shining!', secs: 2);
    setState(() {});
  }

  // ---------------------------------------------------------------- events (06, 20)

  Widget _eventOverlay() {
    final e = _resultEvent ?? s.pendingEvent!;
    final color = colorNamed(e.color);
    final result = _result;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3050A1E),
        child: Stack(children: [
          // the event's colour glows from the top of the screen
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -1.1), radius: 1.1, colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)]))))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${e.id}-${result != null}'),
                    tween: Tween(begin: 0.9, end: 1),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) => Transform.scale(scale: v, child: Opacity(opacity: ((v - 0.9) * 10).clamp(0.0, 1.0), child: child)),
                    child: ModalCard(
                      edge: color,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        GlowDisc(icon: iconNamed(e.icon), color: color, size: 104),
                        const SizedBox(height: 18),
                        GameText(result == null ? e.title : result.logTitle, textAlign: TextAlign.center, style: T.h1.copyWith(fontSize: result == null ? 32 : 24)),
                        const SizedBox(height: 10),
                        GameText(result == null ? e.text : result.result, textAlign: TextAlign.center, style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 16)),
                        const SizedBox(height: 20),
                        if (result == null) ...[
                          for (var i = 0; i < e.options.length; i++) ...[
                            ChoiceCard(
                              letter: String.fromCharCode(65 + i),
                              title: e.options[i].title,
                              selected: _choice == i,
                              chips: [for (final c in e.options[i].chips) changeChip(c, on: _choice == i ? C.raised : C.ink, size: 13.5)],
                              onTap: () {
                                sv.audio.tap();
                                setState(() => _choice = i);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 6),
                          KitButton('Confirm Choice', onTap: _choice == null ? null : _confirm),
                        ] else ...[
                          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final c in result.chips) changeChip(c, size: 13.5)]),
                          const SizedBox(height: 16),
                          TipCard(title: 'Real science', text: e.science, icon: Ln.sparkles, iconColor: C.yellow),
                          const SizedBox(height: 16),
                          KitButton('Continue', onTap: () => setState(() {
                                _result = null;
                                _resultEvent = null;
                                _choice = null;
                              })),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirm() {
    final i = _choice!;
    final e = s.pendingEvent!;
    final o = s.choose(i);
    sv.audio.play(o.score >= 2 ? Sfx.success : (o.score < 0 ? Sfx.fail : Sfx.tap), volume: 0.5);
    HapticFeedback.mediumImpact();
    sv.base.save(s);
    setState(() {
      _resultEvent = e;
      _result = o;
    });
  }

  // ---------------------------------------------------------------- pause (17)

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3050A1E),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ModalCard(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 84, height: 84, alignment: Alignment.center, decoration: BoxDecoration(color: tint(C.cyan, 0.25), shape: BoxShape.circle), child: const LineIcon(Ln.pause, size: 34, color: C.cyan)),
                    const SizedBox(height: 16),
                    const GameText('Paused', style: T.h1),
                    const SizedBox(height: 6),
                    GameText('${s.mission.mars ? 'Sol' : 'Day'} ${s.day} of ${s.mission.days} · Mission ${two(s.mission.n)}', style: T.body.copyWith(color: C.muted, fontSize: 16)),
                    const SizedBox(height: 22),
                    KitButton('Resume', onTap: _togglePause),
                    const SizedBox(height: 10),
                    KitButton('How to Play', style: KitButtonStyle.secondary, onTap: () => sv.nav.go(Screen.howToPlay)),
                    const SizedBox(height: 10),
                    KitButton('Settings', style: KitButtonStyle.secondary, onTap: () => sv.nav.go(Screen.settings)),
                    const SizedBox(height: 10),
                    KitButton('Quit Mission', style: KitButtonStyle.secondary, onTap: () async {
                      await sv.base.save(s);
                      sv.nav.gameBack = null;
                      sv.nav.base = null;
                      sv.nav.resetTo(Screen.missionSelect);
                    }),
                    const SizedBox(height: 14),
                    GameText('Your progress is saved', style: T.bodySmall.copyWith(fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================= NEXT DAY BUTTON

class _NextDayButton extends StatelessWidget {
  final bool running;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _NextDayButton({required this.running, required this.enabled, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: running ? 'Stop fast forward' : 'Next day. Hold to fast forward',
        child: GestureDetector(
          onLongPress: enabled ? onLongPress : null,
          child: TapScale(
            onTap: enabled || running ? onTap : null,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: enabled ? (running ? C.yellow : C.cyan) : const Color(0xFF34305C),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: enabled ? (running ? const Color(0xFFB08F1E) : C.cyanEdge) : const Color(0xFF26234A), offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GameText(running ? 'Stop' : 'Next Day', style: T.button.copyWith(fontSize: 18, color: enabled ? C.ink : C.dim)),
                const SizedBox(width: 8),
                LineIcon(running ? Ln.pause : Ln.forward, size: 18, color: enabled ? C.ink : C.dim),
              ]),
            ),
          ),
        ),
      );
}

// ======================================================================= THE BASE PICTURE

// ======================================================================= MODULE SHEET (05)

class _ModuleSheet extends StatefulWidget {
  final BaseState state;
  final Sys sys;
  final bool engineer;
  const _ModuleSheet({required this.state, required this.sys, required this.engineer});

  @override
  State<_ModuleSheet> createState() => _ModuleSheetState();
}

class _ModuleSheetState extends State<_ModuleSheet> {
  late final double _from = widget.state.setting[widget.sys]!;
  late double _to = _from;

  BaseState get s => widget.state;
  Sys get sys => widget.sys;

  /// Over the next 10 days: (label, change in % points, good?, icon, colour).
  List<(String, double, bool, LineIconData, Color)> _changes() {
    final a = s.flows({sys: _from}), b = s.flows({sys: _to});
    const days = 10.0;
    final power = -(b.demand - a.demand) * 0.2 * days; // battery change
    final out = <(String, double, bool, LineIconData, Color)>[];
    switch (sys) {
      case Sys.greenhouse:
        out.add(('Food made', (b.foodMade - a.foodMade) * days, b.foodMade >= a.foodMade, Ln.sprout, C.food));
        out.add(('Water used', -((b.waterUse['greenhouse'] ?? 0) - (a.waterUse['greenhouse'] ?? 0)) * days, b.waterUse['greenhouse']! <= a.waterUse['greenhouse']!, Ln.droplet, C.water));
        out.add(('Air made', (b.oxygenMade - a.oxygenMade) * days, b.oxygenMade >= a.oxygenMade, Ln.wind, C.air));
      case Sys.recycler:
        out.add(('Water cleaned', (b.waterMade - a.waterMade) * days, b.waterMade >= a.waterMade, Ln.droplet, C.water));
      case Sys.lifeSupport:
        out.add(('Air made', (b.oxygenMade - a.oxygenMade) * days, b.oxygenMade >= a.oxygenMade, Ln.wind, C.air));
      case Sys.research:
        out.add(('Research', (b.researchMade - a.researchMade) * days, b.researchMade >= a.researchMade, Ln.flask, C.frozen));
      case Sys.shield:
        out.add(('Storm protection', (b.protection - a.protection) * 100, b.protection >= a.protection, Ln.shield, C.shield));
    }
    out.add(('Power used', power, power >= 0, Ln.zap, C.power));
    return out;
  }

  String get _sub => switch (sys) {
        Sys.lifeSupport => 'Makes air for your crew',
        Sys.greenhouse => 'Grows food for your crew',
        Sys.recycler => 'Cleans water to drink again',
        Sys.research => 'Science to send home to Earth',
        Sys.shield => 'Blocks radiation from the Sun',
      };

  String get _tip => switch (sys) {
        Sys.greenhouse => s.water < 40 ? 'Water is low! Plants drink a lot. Fix the water first.' : 'More food uses more water and power. Fix the water first!',
        Sys.recycler => 'The recycler gets most of the water back. If water still runs low, melt ice from the crater.',
        Sys.lifeSupport => 'Life Support is the most important system. It gets power first when the battery is empty.',
        Sys.research => 'Research is great for Earth, but it is the first thing to turn off when power is short.',
        Sys.shield => s.stormIn > 0 ? 'A storm is coming! Turn the shield up before it hits.' : 'The shield only needs full power during a solar storm.',
      };

  String? get _real => switch (sys) {
        Sys.lifeSupport => 'NASA: each astronaut breathes about 0.84 kg of oxygen a day.',
        Sys.recycler => 'NASA: the space station recycles about 98% of its water, even sweat.',
        Sys.greenhouse => 'NASA: astronauts eat about 1.8 kg of food a day. Plants also clean the air.',
        Sys.shield => 'On the Moon there is no air or magnetic field to block the Sun\'s radiation.',
        Sys.research => 'The space station has run more than 3,000 experiments.',
      };

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final color = sysColor(sys);
    final changes = _changes();
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: C.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          Row(children: [
            IconBox(sysIcon(sys), color: color, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText(sys.title, style: T.h1.copyWith(fontSize: 28)),
                GameText(_sub, style: T.body.copyWith(color: C.muted)),
              ]),
            ),
            RoundButton(icon: Ln.close, tooltip: 'Close', onTap: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Expanded(child: Overline('Production', size: 12)),
                if ((_to - _from).abs() > 0.004) ...[
                  GameText(pct(_from * 100), style: T.h2.copyWith(color: C.muted, fontSize: 21)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: LineIcon(Ln.forward, size: 14, color: C.muted)),
                ],
                GameText(pct(_to * 100), style: T.h1.copyWith(color: C.cyan, fontSize: 40, height: 1)),
              ]),
              const SizedBox(height: 6),
              KitSlider(
                value: _to,
                color: C.cyan,
                endColor: C.green,
                divisions: 20,
                onChanged: (v) {
                  if ((v * 20).round() != (_to * 20).round()) sv.audio.typeClick();
                  setState(() => _to = v);
                },
              ),
              Row(children: [
                GameText('${(_to * sys.maxKw).round()} kW of ${sys.maxKw.round()} kW', style: T.bodySmall),
                const Spacer(),
                if (widget.engineer) GameText('${s.flows({sys: _to}).demand.round()} kW total', style: T.bodySmall),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          const Overline('What changes'),
          const SizedBox(height: 4),
          const GameText('Over the next 10 days', style: T.bodySmall),
          const SizedBox(height: 10),
          for (final (label, v, good, icon, c) in changes) ...[
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                IconBox(icon, color: c, size: 34, on: C.raised),
                const SizedBox(width: 12),
                Expanded(child: GameText(label, style: T.h3.copyWith(fontSize: 17))),
                if (v.abs() < 0.5)
                  const TagChip('no change', color: C.muted, on: C.raised, size: 13.5)
                else
                  TagChip('${v > 0 ? '+' : '−'}${v.abs().round()}%', color: good ? C.green : C.red, icon: v > 0 ? Ln.up : Ln.down, on: C.raised, size: 14),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          TipCard(title: 'Engineer tip', text: widget.engineer && _real != null ? '$_tip ${_real!}' : _tip),
          ..._extraActions(sv),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: KitButton('Cancel', style: KitButtonStyle.secondary, onTap: () => Navigator.pop(context))),
            const SizedBox(width: 12),
            Expanded(child: KitButton('Apply', onTap: () => Navigator.pop(context, _to))),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _extraActions(Services sv) {
    final out = <Widget>[];
    if (sys == Sys.recycler) {
      out.addAll([
        const SizedBox(height: 12),
        KitCard(
          color: C.raised,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              IconBox(Ln.droplet, color: C.water, size: 40, on: C.raised),
              SizedBox(width: 12),
              const Expanded(
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const GameText('Melt crater ice', style: T.h3),
                  const GameText('Drill ice from the dark crater: +14% water for 12% battery.', style: T.bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            KitButton(
              s.canMeltIce ? 'Melt ice' : (s.iceReadyIn > 0 ? 'Drill cooling: ${s.iceReadyIn} day${s.iceReadyIn == 1 ? '' : 's'}' : 'Not enough battery'),
              height: 46,
              fontSize: 17,
              onTap: s.canMeltIce
                  ? () {
                      s.meltIce();
                      sv.audio.play(Sfx.success, volume: 0.5);
                      setState(() {});
                    }
                  : null,
            ),
          ]),
        ),
      ]);
    }
    if (sys == Sys.lifeSupport && s.leaking) {
      out.addAll([
        const SizedBox(height: 12),
        KitButton('Fix the leaking seal (−10 Power)', style: KitButtonStyle.danger, height: 50, fontSize: 17, onTap: () {
          s.fixLeak();
          sv.audio.play(Sfx.success, volume: 0.5);
          setState(() {});
        }),
      ]);
    }
    return out;
  }
}

/// The solar panels: how much power they make, and cleaning them.
class _PanelsSheet extends StatefulWidget {
  final BaseState state;
  const _PanelsSheet({required this.state});
  @override
  State<_PanelsSheet> createState() => _PanelsSheetState();
}

class _PanelsSheetState extends State<_PanelsSheet> {
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final sv = Services.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    final sun = s.sunToday();
    return Container(
      decoration: const BoxDecoration(color: C.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHandle(),
        const SizedBox(height: 18),
        Row(children: [
          const IconBox(Ln.sun, color: C.power, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText('Solar Panels', style: T.h1.copyWith(fontSize: 28)),
              GameText('Turn sunlight into power', style: T.body.copyWith(color: C.muted)),
            ]),
          ),
          RoundButton(icon: Ln.close, tooltip: 'Close', onTap: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: StatTile(icon: Ln.zap, iconColor: C.power, label: 'Making', value: '${s.generation.round()} kW', frac: s.generation / 100, state: stateColor(s.generation / 100))),
          const SizedBox(width: 12),
          Expanded(child: StatTile(icon: Ln.sun, iconColor: C.yellow, label: 'Sunlight', value: pct(sun * 100), frac: sun, state: stateColor(sun))),
          const SizedBox(width: 12),
          Expanded(child: StatTile(icon: Ln.wind, iconColor: C.muted, label: 'Dust', value: pct(s.dust * 100), frac: s.dust, state: s.dust > 0.3 ? C.yellow : C.green)),
        ]),
        const SizedBox(height: 14),
        TipCard(title: 'Real science', text: s.isNight ? 'Night at the south pole: the Sun hides behind crater rims. The battery keeps the base alive until it comes back.' : 'Moon dust sticks to everything. Dusty panels can lose a lot of their power.', icon: Ln.sparkles, iconColor: C.yellow),
        const SizedBox(height: 16),
        KitButton(
          s.dust >= 0.1 ? 'Clean the panels (−2% air)' : 'The panels are clean',
          onTap: s.dust >= 0.1
              ? () {
                  s.cleanPanels();
                  sv.audio.play(Sfx.success, volume: 0.5);
                  Navigator.pop(context);
                }
              : null,
        ),
      ]),
    );
  }
}

// ======================================================================= POWER TAB (14)

class _PowerTab extends StatelessWidget {
  final BaseState state;
  final VoidCallback onChanged;
  const _PowerTab({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final sv = Services.of(context);
    final systems = [for (final x in Sys.values) if (s.mission.systems.contains(x)) x];
    final used = Sys.values.fold(0.0, (a, x) => a + s.askKw(x));
    final gen = s.generation;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), children: [
      Overline('${s.mission.mars ? 'Sol' : 'Day'} ${s.day} / ${s.mission.days}', color: C.cyan, size: 11.5),
      const GameText('Power', style: T.h1),
      const SizedBox(height: 16),
      KitCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Overline('Power to share', size: 11.5),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${BaseState.shareKw.round()} ', style: T.h1.copyWith(fontSize: 34)),
              TextSpan(text: 'kW', style: T.h3.copyWith(color: C.muted)),
            ])),
            const Spacer(),
            TagChip('Battery ${pct(s.battery)}', color: s.battery < 25 ? C.yellow : C.cyan, icon: Ln.battery, size: 15),
          ]),
          const SizedBox(height: 12),
          // the allocation bar: one coloured piece per system
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 16,
              child: Row(children: [
                for (final x in systems)
                  if (s.askKw(x) > 0.5) ...[
                    Expanded(flex: (s.askKw(x) * 10).round(), child: Container(decoration: BoxDecoration(color: sysColor(x), borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(width: 3),
                  ],
                if (used < BaseState.shareKw - 0.5) Expanded(flex: ((BaseState.shareKw - used) * 10).round(), child: const ColoredBox(color: C.ink)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            LineIcon(Ln.sun, size: 16, color: gen < used ? C.yellow : C.green),
            const SizedBox(width: 6),
            Expanded(
              child: GameText(
                gen < used ? 'The panels make ${gen.round()} kW today. The battery gives the other ${(used - gen).round()} kW.' : 'The panels make ${gen.round()} kW today. Extra power charges the battery.',
                style: T.bodySmall.copyWith(color: gen < used ? C.yellow : C.muted),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      for (final x in systems) ...[
        KitCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(children: [
            Row(children: [
              IconBox(sysIcon(x), color: sysColor(x), size: 36),
              const SizedBox(width: 12),
              Expanded(child: GameText(x.title, style: T.h3)),
              GameText('${s.askKw(x).round()} kW', style: T.h3.copyWith(color: x == Sys.research ? C.frozen : sysColor(x))),
            ]),
            KitSlider(
              value: s.setting[x]!,
              color: sysColor(x),
              divisions: 20,
              onChanged: s.outcome == BaseOutcome.running
                  ? (v) {
                      if ((v * 20).round() != (s.setting[x]! * 20).round()) sv.audio.typeClick();
                      s.setPower(x, v);
                      onChanged();
                    }
                  : null,
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      Row(children: [
        const LineIcon(Ln.bulb, size: 18, color: C.muted),
        const SizedBox(width: 8),
        Expanded(child: GameText('Give more to one, and another gets less.', style: T.body.copyWith(color: C.muted))),
      ]),
    ]);
  }
}

// ======================================================================= CREW TAB (15)

class _CrewTab extends StatelessWidget {
  final BaseState state;
  const _CrewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final h = s.crewHealth;
    final (word, color) = h >= 80 ? ('Doing well', C.green) : (h >= 50 ? ('Needs care', C.yellow) : ('In danger', C.red));
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), children: [
      Overline('${s.mission.mars ? 'Sol' : 'Day'} ${s.day} / ${s.mission.days}', color: C.cyan, size: 11.5),
      const GameText('Crew', style: T.h1),
      const SizedBox(height: 16),
      KitCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
        child: Row(children: [
          SizedBox(
            width: 118,
            height: 118,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: h / 100),
              duration: const Duration(milliseconds: 700),
              builder: (context, v, _) => CustomPaint(painter: _Ring(v, color), child: Center(child: GameText(pct(h), style: T.h2.copyWith(fontSize: 22)))),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Overline('Crew health', size: 11.5),
              GameText(word, style: T.h1.copyWith(color: color, fontSize: 25)),
              const SizedBox(height: 4),
              GameText('Health goes down when air, water, food or protection runs low.', style: T.body.copyWith(color: C.muted, fontSize: 14)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      const Overline('Your crew'),
      const SizedBox(height: 10),
      for (final c in s.crew) ...[
        KitCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(children: [
            SizedBox(width: 58, height: 58, child: CustomPaint(painter: AstroHeadPainter())),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: GameText(c.role, style: T.h3.copyWith(fontSize: 19))),
                  TagChip(c.status, color: _statusColor(c), size: 13.5),
                ]),
                const SizedBox(height: 10),
                KitBar(frac: c.health / 100, color: _statusColor(c), height: 8),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  static Color _statusColor(CrewMember c) => c.health < 40 || c.status == 'Sick' || c.status == 'Short of air' ? C.red : (c.status == 'OK' ? C.green : C.yellow);
}

class _Ring extends CustomPainter {
  final double v;
  final Color color;
  _Ring(this.v, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 7);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0.0, 1.0), false, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.v != v || old.color != color;
}

// ======================================================================= LOG TAB (16)

class _LogTab extends StatelessWidget {
  final BaseState state;
  const _LogTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.log.reversed.toList();
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), children: [
      const Overline('What happened so far', color: C.cyan, size: 11.5),
      const GameText('Mission Log', style: T.h1),
      const SizedBox(height: 16),
      for (var i = 0; i < entries.length; i++) LogRow(entry: entries[i], last: i == entries.length - 1),
    ]);
  }
}

/// One timeline row: a coloured ring with an icon, a line down to the next,
/// and the card ("DAY 12 · Water is running low · Tap the Water Recycler").
class LogRow extends StatelessWidget {
  final LogEntry entry;
  final bool last;
  const LogRow({super.key, required this.entry, this.last = false});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (icon, color) = _style(e);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 64,
          child: Column(children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint(color, 0.12, C.bg), border: Border.all(color: color, width: 2.5)),
              child: LineIcon(icon, size: 24, color: color),
            ),
            if (!last) Expanded(child: Container(width: 3, color: C.line)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: KitCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Overline('Day ${e.day}', color: C.muted, size: 11.5),
                const SizedBox(height: 4),
                GameText(e.title, style: T.h3.copyWith(fontSize: 17.5, height: 1.3)),
                if (e.action != null) ...[const SizedBox(height: 8), TagChip(e.action!, color: C.yellow, size: 13.5)],
                if (e.changes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final c in e.changes) changeChip(c, size: 13.5)]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  static (LineIconData, Color) _style(LogEntry e) {
    if (e.kind.startsWith('adjust-')) {
      final sys = Sys.values[int.parse(e.kind.substring(7))];
      return (sysIcon(sys), sysColor(sys));
    }
    return switch (e.kind) {
      'rocket' => (Ln.rocket, C.cyan),
      'sun' => (Ln.sun, C.orange),
      'danger' => (Ln.alert, C.red),
      'fix' => (Ln.wrench, C.green),
      'water' => (Ln.droplet, C.water),
      'shield' => (Ln.shield, C.yellow),
      _ => (Ln.alert, C.yellow),
    };
  }
}
