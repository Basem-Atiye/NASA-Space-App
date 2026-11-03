/// The Story Campaign state machine. Pure Dart: the Flutter side feeds it
/// events (Nova arrived somewhere, USE pressed, option chosen, mini-game
/// finished, time passed) and draws whatever it says.
library;

import 'dart:math' as math;

import '../data/story.dart';
import '../world/world_model.dart' show worldAliases;
import 'story_logic.dart';
import 'story_model.dart';

enum TaskOutcome { running, complete, failed }

/// Numbers that carry over from task to task.
class Carry {
  double health;
  double dose;
  double battery;
  int spares;
  int shielding;
  double o2Kg;
  double waterKg;
  double foodKg;
  double foodPerDay;
  double waterPerDay;

  /// Mistakes over the whole campaign (shown on the final card).
  int mistakes;
  final Set<String> flags;

  Carry({
    this.health = 85,
    this.dose = 0,
    this.battery = 30,
    this.spares = 0,
    this.shielding = 0,
    this.o2Kg = 6.0,
    this.waterKg = 30,
    this.foodKg = 8.0,
    this.foodPerDay = 0.62,
    this.waterPerDay = 2.37,
    this.mistakes = 0,
    Set<String>? flags,
  }) : flags = flags ?? <String>{};

  Map<String, Object> toJson() => {
        'health': health,
        'dose': dose,
        'battery': battery,
        'spares': spares,
        'shielding': shielding,
        'o2Kg': o2Kg,
        'waterKg': waterKg,
        'foodKg': foodKg,
        'foodPerDay': foodPerDay,
        'waterPerDay': waterPerDay,
        'mistakes': mistakes,
        'flags': flags.toList(),
      };

  static Carry fromJson(Map<String, dynamic> j) => Carry(
        health: (j['health'] as num?)?.toDouble() ?? 85,
        dose: (j['dose'] as num?)?.toDouble() ?? 0,
        battery: (j['battery'] as num?)?.toDouble() ?? 30,
        spares: (j['spares'] as num?)?.toInt() ?? 0,
        shielding: (j['shielding'] as num?)?.toInt() ?? 0,
        o2Kg: (j['o2Kg'] as num?)?.toDouble() ?? 6,
        waterKg: (j['waterKg'] as num?)?.toDouble() ?? 30,
        foodKg: (j['foodKg'] as num?)?.toDouble() ?? 8,
        foodPerDay: (j['foodPerDay'] as num?)?.toDouble() ?? 0.62,
        waterPerDay: (j['waterPerDay'] as num?)?.toDouble() ?? 2.37,
        mistakes: (j['mistakes'] as num?)?.toInt() ?? 0,
        flags: {...((j['flags'] as List?) ?? const []).map((e) => '$e')},
      );

  /// A sensible state for starting a task directly (task select, teacher
  /// mode) when no saved run exists: as if every earlier task went well.
  static Carry defaultsFor(int task) {
    final c = Carry();
    if (task > 1) {
      c.health = 95;
      c.flags.addAll({'kit', 'radio', 'tools', 'sealed', 'rested'});
    }
    if (task > 2) {
      c.flags.addAll({'siteB', 'habitat', 'habSealed'});
      c.shielding = 6;
      c.spares = 4;
    }
    if (task > 3) {
      c.flags.addAll({'cable', 'panelsUp', 'wired'});
      c.battery = 70;
    }
    if (task > 4) {
      c.flags.addAll({'pipeFixed', 'generator'});
      c.foodPerDay = 0.55;
      c.waterPerDay = 2.1;
    }
    if (task > 5) c.flags.addAll({'sensors', 'controller'});
    if (task > 6) c.spares = 3;
    if (task > 7) c.flags.addAll({'bayOpen', 'diagnosed'});
    if (task > 8) {
      c.flags.addAll({'w2Fixed', 'valveFixed', 'j3'});
      c.spares = 1;
    }
    return c;
  }
}

class StoryRun {
  final StoryTask task;
  final Carry carry;

  /// The player's age mode: timers, suit drain, forgiveness, hint cost.
  final AgeMode mode;

  /// Hints opened in this level (they cost a star outside Cadet mode).
  int hintsUsed = 0;
  int stepIndex = 0;

  /// Suit oxygen, percent. Drains while Nova is outside.
  double suitO2;

  /// Habitat pressure in kPa (0 = no habitat yet).
  double pressure;

  int mistakes = 0;
  TaskOutcome outcome = TaskOutcome.running;
  String failReason = '';

  /// goTo: Nova is standing at the target, USE is available.
  bool atTarget = false;

  /// collect: ids picked up / visited in this step.
  final Set<String> done = {};

  /// Every option the player chose, for the debrief.
  final List<String> decisions = [];

  /// The mistakes, in words, for the debrief's "You did" card.
  final List<String> slips = [];

  /// Seconds left on a timed choice.
  double timer = 0;

  double elapsed = 0;

  StoryRun(this.task, this.carry, {this.mode = AgeMode.explorer})
      : suitO2 = task.suitStart,
        pressure = carry.flags.contains('habitat') ? 95 : 0 {
    _enterStep();
  }

  StoryStep get step => task.steps[math.min(stepIndex, task.steps.length - 1)];
  bool get finished => outcome != TaskOutcome.running;
  int get stepCount => task.steps.length;

  /// Suit oxygen used per second outside. Task 1 starts with a damaged suit
  /// and little oxygen, so the clock really matters there.
  /// 1 walking, more when sprinting (bounding uses about 30% more oxygen).
  double effort = 1;

  double get suitDrainPerSecond => task.suitDrain * mode.suitDrainScale * effort;

  /// Seconds on the clock for the current timed choice.
  int get stepTimer => mode.timerFor(step.timer);

  /// The player opened a hint. Returns true the first time it costs a star.
  bool useHint() {
    hintsUsed++;
    return hintsUsed == 1 && !mode.hintsFree;
  }

  bool get outside => step.eva && !finished;

  // ------------------------------------------------------------ time

  void tick(double dt) {
    if (finished) return;
    elapsed += dt;
    if (outside) {
      suitO2 = math.max(0, suitO2 - suitDrainPerSecond * dt);
      if (suitO2 <= 0) {
        carry.health -= 4 * dt;
        if (carry.health <= 0) _fail('Nova ran out of suit oxygen. Collect the O2 bottle early and keep an eye on the suit gauge.');
      }
    } else {
      // inside: the suit tops up slowly from the cabin supply
      suitO2 = math.min(100, suitO2 + 0.5 * dt);
    }
    if (step.kind == StepKind.choice && stepTimer > 0 && timer > 0) {
      timer -= dt;
      if (timer <= 0) {
        timer = 0;
        final firstBad = step.options.firstWhere((o) => o.mistake, orElse: () => step.options.last);
        choose(firstBad.id, timedOut: true);
      }
    }
  }

  // ------------------------------------------------------------ events

  /// Nova reached (or is standing next to) a scene object.
  /// Returns true when it advanced the story.
  bool arrive(String id) {
    if (finished) return false;
    final s = step;
    if (s.kind == StepKind.goTo && _matches(id, s.target)) {
      atTarget = true;
      return true;
    }
    if (s.kind == StepKind.collect) {
      final key = id.startsWith('pickup:') ? id.substring(7) : id;
      if (s.items.contains(key) && !done.contains(key)) {
        done.add(key);
        carry.flags.add('got_$key');
        final p = pickupInfo[key];
        if (p != null) _apply(p.effect);
        if (done.length == s.items.length) _complete();
        return true;
      }
    }
    return false;
  }

  /// Nova walked away from the target.
  void leave(String id) {
    if (step.kind == StepKind.goTo && _matches(id, step.target)) atTarget = false;
  }

  bool _matches(String id, String target) {
    if (id == target) return true;
    // the habitat and its airlock are the same place for the story
    return worldAliases[id] == target || worldAliases[target] == id;
  }

  /// The USE button.
  bool use() {
    if (finished || step.kind != StepKind.goTo || !atTarget) return false;
    _complete();
    return true;
  }

  /// Talk steps: the player read the lines.
  void continueTalk() {
    if (!finished && step.kind == StepKind.talk) _complete();
  }

  /// A choice. Returns the option (its result lines are shown by the UI).
  StoryOption? choose(String optionId, {bool timedOut = false}) {
    if (finished || step.kind != StepKind.choice) return null;
    final o = step.options.firstWhere((o) => o.id == optionId, orElse: () => step.options.first);
    decisions.add('${step.objective}: ${o.label}${timedOut ? ' (time ran out)' : ''}');
    _apply(o.effect);
    if (o.mistake) {
      mistakes++;
      slips.add(timedOut ? 'ran out of time on "${step.objective}"' : 'chose "${o.label}"');
    }
    _checkAlive();
    if (finished) return o;
    // Cadets always get to try again: mistakes are explained, never fatal
    if (o.mistake && (o.retry || mode == AgeMode.cadet)) {
      timer = stepTimer.toDouble();
      return o;
    }
    _complete();
    return o;
  }

  /// A mini-game finished.
  void finishGame(GameResult r) {
    if (finished || step.kind != StepKind.game) return;
    mistakes += r.mistakes;
    if (r.mistakes > 0) slips.add('${r.mistakes} slip${r.mistakes == 1 ? '' : 's'} in ${step.game?.title.toLowerCase() ?? 'a test'}');
    for (var i = 0; i < r.mistakes; i++) {
      _apply(step.mistakeEffect);
    }
    switch (step.id) {
      case 't2_materials':
        final sh = (r.data['shielding'] as num?)?.toInt() ?? 5;
        carry.shielding = sh;
        carry.spares = 10 - sh;
        break;
      case 't4_rations':
        carry.foodPerDay = (r.data['food'] as num?)?.toDouble() ?? carry.foodPerDay;
        carry.waterPerDay = (r.data['water'] as num?)?.toDouble() ?? carry.waterPerDay;
        break;
    }
    decisions.add('${step.objective}: ${r.mistakes == 0 ? 'clean' : '${r.mistakes} mistake${r.mistakes == 1 ? '' : 's'}'}');
    _checkAlive();
    if (!finished) _complete();
  }

  // ------------------------------------------------------------ internals

  void _enterStep() {
    atTarget = false;
    done.clear();
    timer = step.kind == StepKind.choice ? stepTimer.toDouble() : 0;
  }

  void _complete() {
    _apply(step.effect);
    // the storm dose in Task 6 depends on the shielding built in Task 2
    if (step.id == 't6_spe' && carry.flags.contains('sheltered')) {
      carry.dose += carry.shielding >= 5 ? 2 : 12;
      if (carry.shielding < 5) {
        mistakes++;
        decisions.add('Thin shielding from Task 2: extra radiation dose');
      }
    }
    // a lander repair without spare parts means improvising: a mistake
    if (carry.spares < 0) {
      mistakes++;
      decisions.add('Ran out of spare parts and had to improvise');
      carry.spares = 0;
    }
    if (stepIndex >= task.steps.length - 1) {
      outcome = TaskOutcome.complete;
      _finishTask();
      return;
    }
    stepIndex++;
    _enterStep();
  }

  void _finishTask() {
    // the days passing in this task use supplies
    final days = task.days;
    final o2Made = carry.flags.contains('generator') ? 0.9 * days : 0;
    carry.o2Kg = math.max(0, carry.o2Kg - 0.84 * days + o2Made);
    carry.foodKg = math.max(0, carry.foodKg - carry.foodPerDay * days);
    carry.waterKg = math.max(0, carry.waterKg - carry.waterPerDay * days * (carry.flags.contains('generator') ? 0.1 : 1));
    carry.dose += 1.369 * days * (carry.flags.contains('habitat') ? 0.6 : 1);
    carry.flags.remove('sheltered');
    carry.mistakes += mistakes;
  }

  void _apply(Effect e) {
    suitO2 = (suitO2 + e.suitO2).clamp(0, 100).toDouble();
    carry.health = (carry.health + e.health).clamp(mode == AgeMode.cadet ? 20 : 0, 100).toDouble();
    carry.dose += e.dose;
    carry.battery = (carry.battery + e.battery).clamp(0, 100).toDouble();
    carry.spares += e.spares;
    carry.o2Kg = math.max(0, carry.o2Kg + e.o2Kg);
    carry.waterKg = math.max(0, carry.waterKg + e.waterKg);
    carry.foodKg = math.max(0, carry.foodKg + e.foodKg);
    if (e.pressure != 0) {
      pressure = e.pressure > 50 ? e.pressure : math.max(0, pressure + e.pressure);
    }
    carry.shielding = math.max(0, carry.shielding + e.materials);
    carry.flags.addAll(e.flags);
    carry.flags.removeAll(e.clear);
  }

  void _checkAlive() {
    if (carry.health <= 0) _fail('Nova\'s health reached zero. Too many risky choices in a row.');
  }

  void _fail(String why) {
    outcome = TaskOutcome.failed;
    failReason = why;
  }

  int get stars {
    final s = storyStars(mistakes, carry.health);
    return hintsUsed > 0 && !mode.hintsFree ? (s - 1).clamp(1, 3) : s;
  }

  /// The objective checklist: done, current, upcoming.
  List<(String, int)> objectives() => [
        for (var i = 0; i < task.steps.length; i++)
          if (task.steps[i].kind != StepKind.talk) (task.steps[i].objective, i < stepIndex || (finished && outcome == TaskOutcome.complete) ? 1 : (i == stepIndex ? 0 : -1)),
      ];
}
