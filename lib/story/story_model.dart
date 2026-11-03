/// Data model for the Story Campaign "Stranded at Shackleton".
///
/// A campaign is 10 [StoryTask]s. Each task is a list of [StoryStep]s that
/// the player clears in order. A step is one of a few kinds: walk Nova to
/// something and use it, pick up gear, make a decision, or play an
/// engineering mini-game. Everything here is plain data, so the rules can be
/// unit-tested without Flutter.
library;

import '../data/catalogue.dart' show CampaignId, Skill;
import '../data/messages.dart' show Speaker, Mood;

/// The three age modes. The story and art are the same for everyone; these
/// set the dials: reading, numbers, time pressure and how forgiving it is.
enum AgeMode {
  /// Ages 6–10: no timers, the suit never runs out, mistakes are explained
  /// and retried, Pip shows the way, hints are free.
  cadet,

  /// Ages 11–14: real numbers, gentle 30-second timers, hints cost a star.
  explorer,

  /// Ages 15–18: 15-second timers, the suit drains in real time, mistakes
  /// can fail the level and carry into the next one.
  engineer,
}

extension AgeModeInfo on AgeMode {
  String get title => const ['Cadet', 'Explorer', 'Engineer'][index];
  String get ages => const ['ages 6–10', 'ages 11–14', 'ages 15–18'][index];
  String get blurb => const [
        'Every line read aloud. Pictures instead of numbers. Pip shows the way and nothing runs out of time.',
        'Real numbers and simple maths. Gentle timers. Hints cost a star.',
        'Real NASA rates and formulas. Tight timers. Mistakes follow you to the next level.',
      ][index];

  /// Seconds on a timed decision (0 = no clock).
  int timerFor(int base) => base <= 0 ? 0 : const [0, 30, 15][index];

  /// How fast the suit drains, relative to the real rate.
  double get suitDrainScale => const [0.0, 0.55, 1.0][index];

  bool get hintsFree => this == AgeMode.cadet;
  bool get showArrows => this != AgeMode.engineer;

  static AgeMode parse(String? s) => AgeMode.values.firstWhere((m) => m.name == s, orElse: () => AgeMode.explorer);
}

enum StepKind {
  /// Nova walks to [StoryStep.target] and the player presses USE.
  goTo,

  /// Pick up every item in [StoryStep.items] (walk to each one).
  collect,

  /// A decision with [StoryStep.options]. May be timed.
  choice,

  /// An engineering mini-game, see [GameKind].
  game,

  /// Lines of dialogue only, tap to continue.
  talk,
}

enum GameKind {
  /// Put items in priority order (warning panel triage, load shedding,
  /// restore order after a cascade).
  order,

  /// Probe test points and find the faulty ones (leak finder, pipe gauges,
  /// multimeter).
  probe,

  /// Hold a button and release inside a band (inflate, torque, crimp).
  hold,

  /// Split a budget with sliders (materials, rations).
  allocate,

  /// Connect terminals with wires (polarity, sensor wiring).
  wire,

  /// Turn a dial to peak a meter (aim the solar panels).
  tune,

  /// Write controller rules and run simulated tests. WOW feature.
  rules,

  /// Live dependency diagram of a cascading failure. WOW feature.
  cascade,

  /// Pre-launch checklist. Skipping a check aborts.
  checklist,

  /// Drop each item into the right bin (sorting, classifying).
  sort,

  /// Time jumps over craters in low gravity.
  jump,

  /// Drive the rover along a route (tilt the phone or use the buttons).
  drive,

  /// Real movement: count exercise reps with the phone's motion sensor (or taps).
  fitness,

  /// Connect the dots in order to draw a shape or a message.
  draw,

  /// Engineering model with sliders and live numbers (registry in sims.dart).
  sim,
}

/// A change to the run's numbers or flags.
class Effect {
  final double suitO2; // percentage points
  final double health;
  final double dose; // mSv
  final double battery; // percentage points
  final int spares;
  final int materials;
  final double o2Kg;
  final double waterKg;
  final double foodKg;
  final double pressure; // kPa (habitat)
  final Set<String> flags;
  final Set<String> clear;

  const Effect({
    this.suitO2 = 0,
    this.health = 0,
    this.dose = 0,
    this.battery = 0,
    this.spares = 0,
    this.materials = 0,
    this.o2Kg = 0,
    this.waterKg = 0,
    this.foodKg = 0,
    this.pressure = 0,
    this.flags = const {},
    this.clear = const {},
  });

  static const none = Effect();
}

/// A spoken line. Nova's lines also pop up as a speech bubble over her head
/// in the 3D scene.
class Line {
  final Speaker who;
  final String text;
  final Mood mood;
  const Line(this.who, this.text, [this.mood = Mood.calm]);
}

class StoryOption {
  final String id;
  final String label;
  final String detail;
  final bool mistake;
  final Effect effect;

  /// What happens next, shown after the choice.
  final List<Line> result;

  /// When set, a wrong choice sends the player back to choose again
  /// (still counts the mistake). Used when the wrong answer would end the
  /// game, so kids learn instead of restarting.
  final bool retry;

  const StoryOption({
    required this.id,
    required this.label,
    this.detail = '',
    this.mistake = false,
    this.effect = Effect.none,
    this.result = const [],
    this.retry = false,
  });
}

/// Parameters for one mini-game. Only the fields its [GameKind] needs are set.
class GameSpec {
  final GameKind kind;
  final String title;
  final String instructions;

  /// order / checklist / probe / wire / allocate / tune item labels.
  final List<String> items;

  /// order: the correct order (indexes into items).
  final List<int> answer;

  /// probe: the reading shown for each item, and which items are faulty.
  final List<String> readings;
  final Set<int> faulty;

  /// probe: how many probes the player gets before it counts a mistake.
  final int probes;

  /// hold: rate per second, and the success band.
  final double rate;
  final double low;
  final double high;
  final double max;
  final String unit;

  /// wire: right-hand terminals; [answer] maps left index -> right index.
  final List<String> right;

  /// allocate: total budget, per-slider min/max.
  final double total;
  final List<double> mins;
  final List<double> maxs;

  /// tune: the best dial angle (degrees).
  final double best;

  /// A tip shown by the HINT button.
  final String hint;

  /// Optional label over the puzzle (order: the rule; checklist: the final button).
  final String label;

  /// order: the message for a wrong tap, {item} is replaced by the item.
  final String wrong;

  /// sort: the bins; [answer] holds the right bin for each item.
  final List<String> bins;

  /// jump / drive / fitness / draw: how many (craters, rocks, reps, dots).
  final int count;

  /// draw: the dots, as x,y pairs from 0 to 1.
  final List<double> points;

  /// sim: which engineering model (see sims.dart).
  final String sim;

  const GameSpec({
    required this.kind,
    required this.title,
    required this.instructions,
    this.items = const [],
    this.answer = const [],
    this.readings = const [],
    this.faulty = const {},
    this.probes = 99,
    this.rate = 10,
    this.low = 0,
    this.high = 0,
    this.max = 100,
    this.unit = '',
    this.right = const [],
    this.total = 0,
    this.mins = const [],
    this.maxs = const [],
    this.best = 0,
    this.hint = '',
    this.label = '',
    this.wrong = '',
    this.bins = const [],
    this.count = 0,
    this.points = const [],
    this.sim = '',
  });
}

/// What a mini-game reports back.
class GameResult {
  final int mistakes;
  final bool success;
  final Map<String, Object> data;
  const GameResult({required this.mistakes, this.success = true, this.data = const {}});
}

class StoryStep {
  final String id;
  final StepKind kind;

  /// Shown in the objective list.
  final String objective;

  /// Dialogue played when the step starts.
  final List<Line> intro;

  /// Dialogue played when the step is done.
  final List<Line> outro;

  /// goTo: id of the 3D object (lander, habitat, battery, site:B ...).
  final String target;

  /// What the USE button says when Nova is there.
  final String useLabel;

  /// collect: pickup ids (kit, o2, aid, radio, tools).
  final List<String> items;

  final String question;
  final List<StoryOption> options;

  /// choice: seconds on the clock; 0 = untimed. Running out = first mistake option.
  final int timer;

  final GameSpec? game;

  /// Applied when the step completes.
  final Effect effect;

  /// Mistakes in a game step also apply this per mistake.
  final Effect mistakeEffect;

  /// Whether Nova is outside (suit oxygen drains in real time).
  final bool eva;

  final String hint;

  /// What the camera should look at during this step (scene focus id).
  final String? focus;

  /// The skill this step gives evidence for (defaults to the level's skills).
  final Skill? skill;

  /// Play the lift-off cutscene when this step starts.
  final bool launch;

  const StoryStep({
    required this.id,
    required this.kind,
    required this.objective,
    this.intro = const [],
    this.outro = const [],
    this.target = '',
    this.useLabel = 'USE',
    this.items = const [],
    this.question = '',
    this.options = const [],
    this.timer = 0,
    this.game,
    this.effect = Effect.none,
    this.mistakeEffect = Effect.none,
    this.eva = true,
    this.hint = '',
    this.focus,
    this.skill,
    this.launch = false,
  });
}

/// What the 2D world shows in a level (levels without one use the
/// Stranded-at-Shackleton look that follows the story's flags).
class SceneSpec {
  /// Props on the ground: lander, habitat, battery, cable, panels, antenna, crate,
  /// rover, greenhouse, pad, drill, rocket, rim, crater, sites.
  final Set<String> props;

  /// Pickups lying around until collected (ids in worldLayout).
  final List<String> pickups;

  /// A prop only appears once a flag is set (e.g. panels after 'panelsUp').
  final Map<String, String> showWhen;

  /// A prop disappears once a flag is set.
  final Map<String, String> hideWhen;

  final double startX;

  /// Lunar night: dark sky, lights on, cold.
  final bool night;
  final double dust;

  /// The lander leans after the crash (Season 1 only).
  final bool landerTilt;

  const SceneSpec({
    this.props = const {'lander', 'habitat', 'battery', 'cable', 'panels', 'antenna'},
    this.pickups = const [],
    this.showWhen = const {},
    this.hideWhen = const {},
    this.startX = 61,
    this.night = false,
    this.dust = 0.04,
    this.landerTilt = false,
  });
}

class StoryTask {
  final int n;
  final String title;
  final String subtitle;

  /// The engineering idea the task teaches, shown in the debrief.
  final String lesson;
  final String nasaFact;
  final List<StoryStep> steps;

  /// Where Nova stands when the task starts.
  final double startX;
  final double startZ;

  final CampaignId campaign;

  /// The 2D world for this level (null: the Season 1 story look).
  final SceneSpec? scene;

  /// Suit oxygen at the start (%), and how fast it drains outside (%/s at the real rate).
  final double suitStart;
  final double suitDrain;

  /// Days that pass during the level (supplies are used up).
  final double days;

  const StoryTask({
    required this.n,
    required this.title,
    required this.subtitle,
    required this.lesson,
    required this.nasaFact,
    required this.steps,
    this.startX = -21,
    this.startZ = -14,
    this.campaign = CampaignId.explorer,
    this.scene,
    this.suitStart = 100,
    this.suitDrain = 0.06,
    this.days = 1.2,
  });
}
