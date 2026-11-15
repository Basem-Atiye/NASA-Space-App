import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../cloud/models.dart' show Decision;
import '../data/catalogue.dart';
import '../data/encyclopedia.dart';
import '../data/glossary.dart';
import '../data/messages.dart';
import '../data/story.dart';
import '../services/audio.dart';
import '../services/progress.dart';
import '../services/voice.dart';
import '../world/characters.dart';
import '../world/surface_view.dart';
import '../world/world_model.dart';
import 'campaign.dart';
import 'level_record.dart';
import 'story_model.dart';
import 'story_run.dart';

export 'level_record.dart';

enum StoryPhase { dialog, explore, choice, game, launching, done, failed }

/// A small popup card: a pickup Nova grabbed, a fact Pip scanned, a site.
class StoryToast {
  final String title;
  final List<String> lines;
  final bool good;
  final int id;
  final String who;
  const StoryToast(this.title, this.lines, this.id, {this.good = true, this.who = 'PIP'});
}

/// Runs one story level: walks Nova around the 2D world, feeds what happens
/// into [StoryRun], plays the dialogue, and tells the view what to draw.
class StoryController extends ChangeNotifier implements SurfaceDriver {
  final Campaign campaign;
  final StoryTask task;
  final Audio audio;
  final Progress progress;
  final Voice? voice;
  late final StoryRun run;
  @override
  final WorldModel world;

  StoryPhase phase = StoryPhase.dialog;
  final List<Line> _queue = [];
  Line? line;

  /// Result lines of the last choice, shown under the options when retrying.
  StoryOption? lastChoice;

  StoryToast? toast;
  int _toastId = 0;
  Timer? _toastTimer;
  bool _disposed = false;

  /// What Nova says out loud for a moment (speech bubble over her head).
  @override
  String? bubble;
  double _bubbleLeft = 0;

  String? get near => world.near;

  bool paused = false;
  bool hintOpen = false;
  @override
  int meteorCount = 0;
  bool _saved = false;
  int _lastStep = -1;
  final Set<String> _factsShown = {};
  int _lastSuitWarn = 100;
  int _groundFact = 0;

  // animation state
  NovaAction? _emote;
  double _emoteLeft = 0;
  NovaMood _mood = NovaMood.calm;
  double _moodLeft = 0;
  String? _scan;
  double _scanLeft = 0;
  PipEye _pipEye = PipEye.normal;
  double _pipEyeLeft = 0;
  double _habitatShown = 0;
  double _notifyAcc = 0;

  /// Set when the arrival cutscene should play before the level.
  bool showIntro;

  /// Called once when the level ends (won or failed), with what to save.
  void Function(LevelRecord r)? onFinished;

  /// Live lesson hooks: a new step started, or the player asked for a hint.
  void Function(int step, int of)? onStep;
  void Function(int step)? onHelp;

  final String clientId = newClientId();
  DateTime _startedAt = DateTime.now();
  final List<(Skill, bool)> evidence = [];
  final List<Decision> decisionLog = [];

  StoryController({required this.campaign, required this.task, required Carry carry, required this.audio, required this.progress, this.voice, this.showIntro = false})
    : world = WorldModel(novaX: task.scene?.startX ?? _startX(task.n)) {
    run = StoryRun(task, carry, mode: campaign.mode == AgeMode.explorer ? progress.ageMode : campaign.mode);
    _habitatShown = carry.flags.contains('habitat') ? 1 : 0;
  }

  String get levelId => campaign.levelIdFor(task.n);

  /// The skill a step gives evidence for: its own, or the level's.
  Skill? skillFor(StoryStep s) {
    if (s.skill != null) return s.skill;
    final skills = catalogueEntry(levelId)?.skills ?? const [];
    if (skills.isEmpty) return null;
    return s.kind == StepKind.game ? skills.last : skills.first;
  }

  void _evidence(StoryStep s, bool good, String choice) {
    final k = skillFor(s);
    if (k != null) {
      evidence.add((k, good));
      progress.addSkillEvidence(k, good);
    }
    decisionLog.add(Decision(s.id, choice, good));
  }

  static double _startX(int n) {
    switch (n) {
      case 1:
        return 27;
      case 2:
        return 31;
      case 7:
      case 8:
      case 10:
        return 32;
      default:
        return 61;
    }
  }

  /// Builds a controller for [n], continuing the saved campaign when it is
  /// ready for this task, or starting from sensible defaults.
  factory StoryController.forLevel(Campaign c, int n, {required Audio audio, required Progress progress, Voice? voice}) {
    Carry carry;
    final saved = progress.carryFor(c.id);
    if (n == 1 && c.id == CampaignId.explorer) {
      carry = Carry();
    } else if (progress.carryTaskFor(c.id) == n && saved.isNotEmpty) {
      try {
        carry = Carry.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        carry = c.carryDefaults(n);
      }
    } else {
      carry = c.carryDefaults(n);
    }
    final intro = c.id == CampaignId.explorer && n == 1 && !progress.introSeen;
    return StoryController(campaign: c, task: c.task(n), carry: carry, audio: audio, progress: progress, voice: voice, showIntro: intro);
  }

  AgeMode get mode => run.mode;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _startedAt = DateTime.now();
    showIntro = false;
    _sync();
    _enterStep();
    if (line == null) _afterDialog();
  }

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    _toastTimer = null;
    audio.alarm(false);
    voice?.stop();
    super.dispose();
  }

  StoryStep get step => run.step;
  bool get finished => phase == StoryPhase.done || phase == StoryPhase.failed;
  String get hint => step.game?.hint.isNotEmpty == true ? step.game!.hint : step.hint;

  // ------------------------------------------------------------ the action button

  /// What the big action button says right now, or null when there's nothing
  /// to do where Nova stands.
  String? get actionLabel {
    if (phase != StoryPhase.explore) return null;
    final n = world.near;
    if (n == null) return null;
    if (step.kind == StepKind.goTo && run.atTarget) return step.useLabel;
    if (step.kind == StepKind.collect) {
      if (n.startsWith('site:')) return 'SURVEY';
      return 'PICK UP';
    }
    return null;
  }

  /// The big action button.
  void action() {
    if (phase != StoryPhase.explore) return;
    final n = world.near;
    if (n == null) return;
    audio.tap();
    audio.haptic(light: true);
    world.face(n);
    if (step.kind == StepKind.goTo && run.atTarget) {
      final repair = step.target == 'cable' || step.target == 'lander';
      emote(repair ? NovaAction.kneel : NovaAction.work, 1.8);
      _completeAndContinue(() => run.use());
    } else if (step.kind == StepKind.collect) {
      _collect(n);
    }
  }

  void _collect(String id) {
    final before = run.stepIndex;
    final s = step;
    if (!run.arrive(id)) return;
    final key = id.startsWith('pickup:') ? id.substring(7) : id;
    final p = pickupInfo[key];
    final site = siteInfo[id];
    if (p != null) {
      emote(NovaAction.carry, 1.0);
      say('Got the ${p.name.toLowerCase()}!', 2.2);
      _toast(StoryToast(p.name, [p.what], ++_toastId));
      progress.addFact('pickup:$key');
    } else if (site != null) {
      emote(NovaAction.kneel, 1.8);
      _scanFor(id, 1.6);
      _toast(StoryToast(site.name, site.facts, ++_toastId, good: id == 'site:B'));
      progress.addFact(id);
    }
    audio.play(Sfx.star, volume: 0.5);
    audio.play(Sfx.sparkle, volume: 0.4);
    if (run.stepIndex != before || run.finished) {
      _say(s.outro);
      if (line == null) _afterDialog();
    }
    _sync();
    notifyListeners();
  }

  // ------------------------------------------------------------ flow

  void _enterStep() {
    _lastStep = run.stepIndex;
    onStep?.call(run.stepIndex, task.steps.length);
    lastChoice = null;
    hintOpen = false;
    if (step.id == 't6_meteor') meteorCount++;
    if (step.id == 't9_alarm') audio.alarm(true);
    if (step.id == 't9_fix') audio.alarm(false);
    if (step.kind == StepKind.goTo) {
      say(step.objective, 3.2);
      world.face(step.target);
    }
    if (step.id == 't6_meteor') {
      emote(NovaAction.scared, 1.6);
      _eye(PipEye.alarm, 2.5);
    }
    // Cadet explore steps: keep walking — tip as bubble/toast, not a frozen dialog wall.
    final explore = step.kind == StepKind.goTo || step.kind == StepKind.collect;
    if (mode == AgeMode.cadet && explore && step.intro.isNotEmpty) {
      final tip = step.intro.first.text;
      say(tip, 3.6);
      voice?.say(tip);
      _toast(StoryToast('Pip', [tip], ++_toastId));
      _sync();
      return;
    }
    _say(step.intro);
    _sync();
  }

  /// Queues lines. Starts speaking when nothing is being said; when there
  /// is nothing to say the caller decides what happens next.
  void _say(List<Line> lines) {
    if (lines.isEmpty) return;
    _queue.addAll(lines);
    if (line == null) _nextLine();
  }

  /// Bumped for every new line (the dialogue box restarts its typing).
  int lineId = 0;

  void _nextLine() {
    if (_queue.isNotEmpty) {
      line = _queue.removeAt(0);
      lineId++;
      phase = StoryPhase.dialog;
      world.stop();
      final l = line!;
      if (l.who == Speaker.nova) {
        _mood = _novaMood(l.mood);
        _moodLeft = 7;
        if (l.mood == Mood.happy) emote(NovaAction.cheer, 1.4);
        if (l.mood == Mood.scared) emote(NovaAction.scared, 1.8);
      }
      if (l.who == Speaker.aria && l.text.toLowerCase().contains('warning')) _eye(PipEye.alarm, 2);
      // people on the radio come in with a little static; Nova and Pip are right here
      audio.play(l.who == Speaker.nova ? Sfx.message : Sfx.radio, volume: 0.5);
      voice?.say(l.text);
      notifyListeners();
      return;
    }
    line = null;
    _afterDialog();
  }

  static NovaMood _novaMood(Mood m) => switch (m) {
    Mood.happy => NovaMood.happy,
    Mood.worried => NovaMood.worried,
    Mood.scared => NovaMood.scared,
    Mood.tired => NovaMood.tired,
    Mood.calm => NovaMood.calm,
  };

  /// The player tapped the dialogue box.
  void advance() {
    if (phase != StoryPhase.dialog) return;
    audio.tap();
    _nextLine();
  }

  void _afterDialog() {
    if (run.finished) {
      _finish();
      return;
    }
    if (run.stepIndex != _lastStep) {
      _enterStep();
      if (line != null) return;
    }
    switch (step.kind) {
      case StepKind.talk:
        if (step.id == 't10_launch' || step.launch) {
          _launch();
          return;
        }
        _completeAndContinue(() => run.continueTalk());
        return;
      case StepKind.goTo:
      case StepKind.collect:
        phase = StoryPhase.explore;
        if (mode == AgeMode.cadet) _pipPoint();
        break;
      case StepKind.choice:
        phase = StoryPhase.choice;
        break;
      case StepKind.game:
        phase = StoryPhase.game;
        break;
    }
    _sync();
    // Nova may already be standing at the new target
    final n = world.near;
    if (phase == StoryPhase.explore && n != null && step.kind == StepKind.goTo) run.arrive(n);
    notifyListeners();
  }

  /// Cadets: Pip says where to go next (toast only — never freezes walking).
  void _pipPoint() {
    final g = goal;
    if (g == null) return;
    final dir = WorldModel.xOf(g) > world.novaX ? 'right' : 'left';
    final name = _nameOf(g);
    final tip = 'This way! The $name is to the $dir.';
    _toast(StoryToast('Pip', [tip, 'Follow my arrow!'], ++_toastId));
    say(tip, 2.8);
  }

  String _nameOf(String id) {
    if (id.startsWith('pickup:')) return pickupInfo[id.substring(7)]?.name.toLowerCase() ?? 'gear';
    if (id.startsWith('site:')) return 'site ${id.substring(5)}';
    return switch (id) {
      'lander' => 'lander',
      'habitat' => 'habitat',
      'battery' => 'battery',
      'crate' => 'crate',
      'panels' => 'solar panels',
      'cable' => 'cable',
      'rover' => 'rover',
      'greenhouse' => 'greenhouse',
      'pad' || 'rocket' => 'landing pad',
      'drill' => 'ice drill',
      'antenna' => 'antenna',
      _ => id,
    };
  }

  /// Runs [action] (which may complete the step), plays the finished step's
  /// outro, then moves on.
  void _completeAndContinue(void Function() action) {
    final before = run.stepIndex;
    final s = step;
    action();
    final advanced = run.stepIndex != before || run.finished;
    if (advanced) {
      if (run.outcome != TaskOutcome.failed) {
        audio.play(Sfx.success, volume: 0.45);
        _eye(PipEye.happy, 1.6);
        _say(s.outro);
      }
      if (line == null) _afterDialog();
    }
    _sync();
    notifyListeners();
  }

  // ------------------------------------------------------------ player input

  void choose(String optionId) {
    if (phase != StoryPhase.choice) return;
    final before = run.stepIndex;
    final s = step;
    final o = run.choose(optionId);
    if (o == null) return;
    _evidence(s, !o.mistake, o.id);
    lastChoice = o;
    audio.play(o.mistake ? Sfx.fail : Sfx.success, volume: 0.6);
    if (o.mistake) {
      audio.haptic(heavy: true);
      _mood = NovaMood.worried;
      _moodLeft = 5;
    } else {
      _eye(PipEye.happy, 1.6);
    }
    final advanced = run.stepIndex != before || run.finished;
    _say(o.result);
    if (advanced && run.outcome != TaskOutcome.failed) _say(s.outro);
    if (line == null) _afterDialog();
    notifyListeners();
  }

  void finishGame(GameResult r) {
    if (phase != StoryPhase.game) return;
    _evidence(step, r.mistakes == 0, r.mistakes == 0 ? 'clean' : '${r.mistakes} mistakes');
    if (r.mistakes == 0) emote(NovaAction.cheer, 1.5);
    _completeAndContinue(() => run.finishGame(r));
  }

  bool _sprintTipShown = false;

  /// The joystick: -1 (left) .. 1 (right). At the edge, Nova bounds.
  void steer(double x) {
    world.input = phase == StoryPhase.explore ? x : 0;
  }

  /// Hold to sprint (the stick at its edge does the same).
  void setSprint(bool on) {
    world.sprintHeld = on && phase == StoryPhase.explore;
  }

  /// A Moon jump (swipe up, or the action button when there is nothing to use).
  void jump() {
    if (phase != StoryPhase.explore || paused) return;
    if (world.jump()) audio.footstep(hard: true);
  }

  bool get sprinting => world.sprinting;

  @override
  void tapWorld(double x) {
    if (paused || finished) return;
    if (phase == StoryPhase.dialog) {
      advance();
      return;
    }
    if (phase != StoryPhase.explore) return;
    final look = this.look;
    final interact = world.active;
    final hit = world.objectAt(x, interact) ?? world.objectAt(x, look.present);
    if (hit != null) {
      world.walkTo(hit);
      if (!interact.contains(hit)) _scanObject(hit);
    } else if ((x - world.novaX).abs() < 0.5 && !world.walking) {
      // tapping Nova herself: she waves back
      _novaTaps++;
      emote(NovaAction.wave, 1.4);
      say(_hellos[_novaTaps % _hellos.length], 1.8);
      audio.play(Sfx.boop, volume: 0.35);
      audio.haptic();
    } else {
      audio.play(Sfx.boop, volume: 0.18);
      world.walkToX(x);
    }
  }

  int _novaTaps = 0;
  static const _hellos = ['Hi there!', 'That tickles!', 'Look, I can bounce!', 'Hello, Earth!', 'Let\'s keep going!'];

  /// The player tapped an underlined hard word: Pip explains it simply.
  void showWord(WordTip tip) {
    audio.play(Sfx.boop, volume: 0.3);
    final isNew = progress.addFact(tip.id);
    _eye(PipEye.happy, 1.2);
    _toast(StoryToast(isNew ? 'New word · ${tip.word}' : tip.word, [tip.meaning], ++_toastId));
    notifyListeners();
  }

  /// Hard words in [text] the player has not learned yet (at most two, so
  /// the line stays easy to read).
  List<TipHit> tipsFor(String text) => [
    for (final h in findTips(text))
      if (!progress.facts.contains(h.tip.id)) h,
  ].take(2).toList();

  /// The player tapped the sky: Pip tells a fact about what is up there.
  @override
  void tapSky(String what) {
    if (paused || finished) return;
    if (phase == StoryPhase.dialog) {
      advance();
      return;
    }
    if (phase != StoryPhase.explore) return;
    audio.play(Sfx.boop, volume: 0.25);
    final f = factById(what);
    if (f == null) return;
    _eye(PipEye.scanning, 1.4);
    final isNew = progress.addFact(what);
    _toast(StoryToast(isNew ? 'New fact · ${f.title}' : f.title, [f.text], ++_toastId));
    notifyListeners();
  }

  /// The GO arrow: walk Nova to the current goal.
  void goToGoal() {
    if (phase != StoryPhase.explore) return;
    final g = goal;
    if (g == null) return;
    audio.tap();
    world.walkTo(g);
  }

  /// Pip's scanner: scans the nearest thing and gives a real fact.
  void scan() {
    if (paused || finished) return;
    audio.tap();
    final target = world.nearestOf(look.present, range: 6);
    if (target != null) {
      _scanObject(target, always: true);
      return;
    }
    // nothing nearby: Pip scans the ground or the sky
    final ids = groundFactIds;
    final id = ids[_groundFact % ids.length];
    _groundFact++;
    final f = factById(id);
    if (f == null) return;
    _eye(PipEye.scanning, 1.4);
    final isNew = progress.addFact(id);
    _toast(StoryToast(isNew ? 'New fact · ${f.title}' : f.title, [f.text], ++_toastId));
    notifyListeners();
  }

  void _scanObject(String id, {bool always = false}) {
    final key = id == 'solar' ? 'panels' : id;
    final f = factById(key);
    if (f == null) return;
    if (!always && _factsShown.contains(key)) return;
    _factsShown.add(key);
    _scanFor(id, 1.6);
    final isNew = progress.addFact(key);
    audio.play(Sfx.message, volume: 0.35);
    _toast(StoryToast(isNew ? 'New fact · ${f.title}' : f.title, [f.text], ++_toastId));
    notifyListeners();
  }

  void toggleHint() {
    hintOpen = !hintOpen;
    if (hintOpen) {
      _eye(PipEye.thinking, 2);
      onHelp?.call(run.stepIndex);
      if (run.useHint()) {
        _toast(StoryToast('Hint used', ['Hints cost one star in this level. Cadets get them free.'], ++_toastId, good: false));
      }
    }
    notifyListeners();
  }

  /// A hint opened inside a mini-game.
  void gameHint() {
    onHelp?.call(run.stepIndex);
    if (run.useHint()) {
      _toast(StoryToast('Hint used', ['Hints cost one star in this level. Cadets get them free.'], ++_toastId, good: false));
      notifyListeners();
    }
  }

  void setPaused(bool p) {
    paused = p;
    if (p) world.stop();
    notifyListeners();
  }

  void dismissToast() {
    toast = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ animation hooks

  void emote(NovaAction a, double secs) {
    _emote = a;
    _emoteLeft = secs;
  }

  void say(String text, double secs) {
    bubble = text;
    _bubbleLeft = secs;
  }

  void _scanFor(String id, double secs) {
    _scan = id;
    _scanLeft = secs;
    _eye(PipEye.scanning, secs);
  }

  void _eye(PipEye e, double secs) {
    _pipEye = e;
    _pipEyeLeft = secs;
  }

  @override
  NovaPose novaPose(double t) {
    NovaAction a;
    if (_emote != null && _emoteLeft > 0) {
      a = _emote!;
    } else if (world.walking) {
      a = NovaAction.walk;
    } else if (phase == StoryPhase.game) {
      a = NovaAction.work;
    } else if (world.idle > 6 && phase == StoryPhase.explore) {
      a = NovaAction.wave;
    } else {
      a = NovaAction.idle;
    }
    if (a != NovaAction.walk && world.walking) a = NovaAction.walk;
    final suitLow = run.outside && run.suitO2 < 25 && mode != AgeMode.cadet;
    final air = world.airborne;
    if (air && a == NovaAction.idle) a = NovaAction.walk;
    return NovaPose(
      action: a,
      mood: suitLow ? NovaMood.worried : (_moodLeft > 0 ? _mood : NovaMood.calm),
      phase: world.walkPhase,
      t: t,
      talking: line?.who == Speaker.nova,
      air: air,
      sprint: world.sprinting,
      land: (_landLeft / 0.22).clamp(0.0, 1.0),
      rise: world.vy,
    );
  }

  @override
  PipEye get pipEye {
    if (_pipEyeLeft > 0) return _pipEye;
    if (run.outside && run.suitO2 < 20 && mode != AgeMode.cadet) return PipEye.alarm;
    if (look.alarm) return PipEye.alarm;
    return PipEye.normal;
  }

  @override
  String? get pipScan => _scanLeft > 0 ? _scan : null;

  // ------------------------------------------------------------ the frame

  @override
  void frame(double dt) {
    if (paused) return;
    _emoteLeft -= dt;
    _moodLeft -= dt;
    _scanLeft -= dt;
    _pipEyeLeft -= dt;
    if (_bubbleLeft > 0) {
      _bubbleLeft -= dt;
      if (_bubbleLeft <= 0) {
        bubble = null;
        notifyListeners();
      }
    }
    final targetHab = _habitatTarget;
    if ((_habitatShown - targetHab).abs() > 0.001) {
      _habitatShown += (targetHab - _habitatShown) * (1 - math.exp(-dt * 1.6));
      if ((_habitatShown - targetHab).abs() < 0.002) _habitatShown = targetHab;
      _lookCache = null;
    }
    if (finished) return;
    _landLeft = math.max(0, _landLeft - dt);
    for (final e in world.update(dt)) {
      _onWorld(e);
    }
    // bounding costs more oxygen; you hear your breathing speed up
    run.effort = world.sprinting ? 1.3 : (world.airborne ? 1.15 : 1.0);
    if (world.sprinting) {
      _breathLeft -= dt;
      if (_breathLeft <= 0) {
        _breathLeft = 1.1;
        audio.play(Sfx.breath, volume: 0.35);
      }
      if (!_sprintTipShown && mode != AgeMode.cadet && run.outside) {
        _sprintTipShown = true;
        _toast(StoryToast('Bounding', ['Bounding is fast, but it uses about 30% more suit oxygen. Walk when you can.'], ++_toastId));
      }
    }
    _tick(dt);
  }

  double _landLeft = 0;
  double _breathLeft = 0;

  void _onWorld(WorldEvent e) {
    switch (e.type) {
      case 'step':
        audio.footstep(hard: world.sprinting);
      case 'land':
        _landLeft = 0.25 * (world.lastLandSpeed / WorldModel.boundSpeed).clamp(0.6, 1.8);
        audio.footstep(hard: true);
        if (world.lastLandSpeed > 1.5) audio.haptic(light: true);
      case 'near':
        final prev = _prevNear;
        if (prev != null && prev != e.id) run.leave(prev);
        _prevNear = e.id;
        if (e.id != null && phase == StoryPhase.explore) {
          // goTo: standing at the target makes the action button appear;
          // gear is picked up with the button (or on arrival for Cadets)
          if (step.kind == StepKind.goTo && run.arrive(e.id!)) audio.play(Sfx.message, volume: 0.3);
          world.face(e.id!);
        }
        notifyListeners();
        break;
      case 'arrived':
        if (e.id != null) world.face(e.id!);
        // Cadets: arriving at gear picks it up straight away
        if (mode == AgeMode.cadet && step.kind == StepKind.collect && e.id != null && world.active.contains(e.id)) _collect(e.id!);
        break;
    }
  }

  String? _prevNear;

  void _tick(double dt) {
    if (phase == StoryPhase.explore || phase == StoryPhase.game || phase == StoryPhase.choice) {
      final before = run.stepIndex;
      final s = step;
      final wasTimer = run.timer;
      run.tick(dt);
      // suit warnings at 30%, 20%, 10%
      if (run.outside && mode != AgeMode.cadet) {
        final w = (run.suitO2 / 10).floor() * 10;
        if (w < _lastSuitWarn && w <= 30) {
          _lastSuitWarn = w;
          audio.play(Sfx.alert, volume: 0.6);
          say(w > 0 ? 'Suit oxygen $w%!' : 'I\'m out of oxygen!', 2.5);
          emote(NovaAction.scared, 1.2);
        }
        if (w > _lastSuitWarn) _lastSuitWarn = w;
      }
      if (run.finished) {
        _finish();
        return;
      }
      // a timed choice ran out
      if (s.kind == StepKind.choice && wasTimer > 0 && run.timer == 0 && (run.stepIndex != before || run.mistakes > 0)) {
        final o = s.options.firstWhere((o) => o.mistake, orElse: () => s.options.last);
        lastChoice = o;
        audio.play(Sfx.fail, volume: 0.6);
        _say([const Line(Speaker.capcom, 'Time ran out, Nova! Hesitating is a decision too.'), ...o.result]);
        if (run.stepIndex != before) _say(s.outro);
      }
      _notifyAcc += dt;
      if (_notifyAcc > 0.1 && (phase == StoryPhase.choice || run.outside)) {
        _notifyAcc = 0;
        notifyListeners();
      }
      final key = '${run.carry.battery.round()}';
      if (key != _batteryKey) {
        _batteryKey = key;
        _lookCache = null;
      }
    }
  }

  String _batteryKey = '';

  // ------------------------------------------------------------ launch & finish

  void _launch() {
    phase = StoryPhase.launching;
    world.stop();
    _sync();
    notifyListeners();
  }

  /// The launch cutscene finished (or was skipped).
  void launched() {
    if (phase != StoryPhase.launching) return;
    run.continueTalk();
    _finish();
  }

  void _finish() {
    audio.alarm(false);
    world.stop();
    final won = run.outcome == TaskOutcome.complete;
    if (won) {
      phase = StoryPhase.done;
      audio.play(Sfx.star);
    } else {
      phase = StoryPhase.failed;
      audio.play(Sfx.fail);
    }
    if (!_saved) {
      _saved = true;
      final carry = run.carry.toJson();
      if (won) progress.recordLevel(campaign.id, task.n, run.stars, jsonEncode(carry));
      progress.saveSkills();
      onFinished?.call(
        LevelRecord(
          clientId: clientId,
          levelId: levelId,
          mode: mode,
          startedAt: _startedAt,
          endedAt: DateTime.now(),
          complete: won,
          stars: won ? run.stars : 0,
          mistakes: run.mistakes,
          hints: run.hintsUsed,
          decisions: List.of(decisionLog),
          evidence: List.of(evidence),
          campaign: campaign.id,
          n: task.n,
          carry: carry,
        ),
      );
    }
    _sync();
    notifyListeners();
  }

  // ------------------------------------------------------------ what to draw

  WorldLook? _lookCache;

  @override
  WorldLook get look => _lookCache ??= _buildLook();

  /// The current goal (what the arrow points at), if any.
  String? get goal {
    if (phase != StoryPhase.explore && phase != StoryPhase.dialog) return null;
    final s = step;
    if (s.kind == StepKind.goTo) return s.target;
    if (s.kind == StepKind.collect) {
      final left = [
        for (final i in s.items)
          if (!run.done.contains(i)) i.startsWith('site:') ? i : 'pickup:$i',
      ];
      if (left.isEmpty) return null;
      // the nearest one left
      left.sort((a, b) => (WorldModel.xOf(a) - world.novaX).abs().compareTo((WorldModel.xOf(b) - world.novaX).abs()));
      return left.first;
    }
    return null;
  }

  double get _habitatTarget {
    final f = run.carry.flags;
    if (task.scene != null) return task.scene!.props.contains('habitat') ? 1 : 0;
    if (f.contains('habitat')) return 1;
    if (task.n == 2 && step.id == 't2_inflate' && !finished) return 0.14;
    return 0;
  }

  void _sync() {
    final s = step;
    final interact = <String>{};
    if (phase == StoryPhase.explore || phase == StoryPhase.dialog) {
      if (s.kind == StepKind.goTo) {
        interact.add(s.target);
      } else if (s.kind == StepKind.collect) {
        for (final i in s.items) {
          if (!run.done.contains(i)) interact.add(i.startsWith('site:') ? i : 'pickup:$i');
        }
      }
    }
    world.active = interact;
    _lookCache = null;
  }

  /// The look for levels that describe their own scene (2.0 levels).
  WorldLook _sceneLook(SceneSpec sc) {
    final f = run.carry.flags;
    bool shows(String prop) {
      if (!sc.props.contains(prop)) return false;
      final need = sc.showWhen[prop];
      if (need != null && !f.contains(need)) return false;
      final gone = sc.hideWhen[prop];
      if (gone != null && f.contains(gone)) return false;
      return true;
    }

    final s = step;
    return WorldLook(
      task: task.n,
      showLander: shows('lander'),
      landerTilt: sc.landerTilt ? -0.07 : 0,
      landerRepaired: true,
      habitat: shows('habitat') ? 1 : 0,
      bags: shows('habitat') ? math.min(run.carry.shielding, 10) : 0,
      sensors: f.contains('sensors') || f.contains('controller'),
      battery: shows('battery'),
      batteryLevel: (run.carry.battery / 100).clamp(0.05, 1.0).toDouble(),
      cable: shows('cable') && shows('battery') && shows('habitat'),
      crate: shows('crate'),
      panels: shows('panels'),
      panelDust: sc.dust > 0.3 ? sc.dust : 0,
      antenna: shows('antenna'),
      rover: shows('rover'),
      greenhouse: shows('greenhouse') ? (f.contains('grown') ? 1.0 : 0.65) : 0,
      greenhouseWilting: shows('greenhouse') && task.n == 13 && task.campaign == CampaignId.explorer && !f.contains('fanFixed'),
      pad: shows('pad'),
      rocket: shows('rocket') && phase != StoryPhase.launching,
      drill: shows('drill'),
      drillRunning: shows('drill') && run.stepIndex > 2,
      rim: shows('rim'),
      crater: shows('crater'),
      night: sc.night,
      pickups: {
        for (final p in sc.pickups)
          if (!f.contains('got_$p')) p,
      },
      goal: goal,
      arrows: mode.showArrows,
      dust: sc.dust,
      alarm: s.id == 's14_quake' && !finished,
      quake: s.id == 's14_quake' && phase == StoryPhase.dialog,
      novaHidden: phase == StoryPhase.launching && !sc.props.contains('rocket'),
    );
  }

  WorldLook _buildLook() {
    final sc = task.scene;
    if (sc != null) return _sceneLook(sc);
    final f = run.carry.flags;
    final n = task.n;
    final s = step;
    final idx = run.stepIndex;
    bool stepIs(String id) => s.id == id && !finished;
    bool before(String id) {
      final i = task.steps.indexWhere((x) => x.id == id);
      return i >= 0 && idx < i && !finished;
    }

    final pickups = <String>{};
    if (n == 1) {
      for (final p in const ['kit', 'o2', 'aid', 'radio', 'tools']) {
        if (!f.contains('got_$p')) pickups.add(p);
      }
    }
    final visited = <String>{};
    if (n == 2) {
      for (final x in ['site:A', 'site:B', 'site:C']) {
        if (f.contains('got_$x') || !before('t2_site')) visited.add(x);
      }
    }
    return WorldLook(
      task: n,
      showLander: true,
      landerTilt: n <= 8 && !(n == 8 && finished) ? -0.07 : 0,
      landerBay: f.contains('bayOpen') && (n == 7 || n == 8),
      landerRepaired: n >= 9 || (n == 8 && finished),
      landerSparking: (n == 1 && before('t1_gear')) || (n == 7 && !finished),
      landerVenting: n == 1 && !f.contains('sealed') && before('t1_fix'),
      habitat: _habitatShown,
      bags: run.carry.shielding > 0 && (n > 2 || !before('t2_seal')) ? run.carry.shielding : 0,
      sensors: f.contains('sensors') || f.contains('controller'),
      sensorAlarm: n == 9 && !f.contains('busFixed') && !finished,
      habitatVent: stepIs('t6_meteor') || stepIs('t6_patch'),
      patch: (n == 6 && !before('t6_patch')) || n > 6,
      thermalFault: stepIs('t6_thermal'),
      battery: n >= 3,
      batteryLevel: (run.carry.battery / 100).clamp(0.05, 1.0).toDouble(),
      batteryFault: n == 3 && before('t3_cable'),
      cable: f.contains('cable') || n > 3,
      cableBroken: n == 9 && !f.contains('busFixed'),
      crate: n == 3 && !f.contains('panelsUp'),
      panels: f.contains('panelsUp'),
      panelDust: stepIs('t6_dust') || stepIs('t6_clean') ? 0.7 : 0,
      antenna: f.contains('radio') && n >= 2,
      sites: n == 2 && before('t2_inflate'),
      visitedSites: visited,
      pickups: pickups,
      goal: goal,
      arrows: mode.showArrows,
      dust: stepIs('t6_dust') || stepIs('t6_clean') ? 0.6 : 0.04,
      stormWarning: stepIs('t6_spe'),
      alarm: n == 9 && !f.contains('busFixed') && !finished,
      novaHidden: phase == StoryPhase.launching,
    );
  }

  void _toast(StoryToast t) {
    toast = t;
    // Cadets hear Pip's cards too
    if (mode == AgeMode.cadet) voice?.say(t.lines.join(' '));
    final id = t.id;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: 3800 + 35 * t.lines.join(' ').length), () {
      if (_disposed || toast?.id != id) return;
      toast = null;
      notifyListeners();
    });
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    _lookCache = null;
    super.notifyListeners();
  }

  int get stars => run.stars;
}
