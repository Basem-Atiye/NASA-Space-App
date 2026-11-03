/// What each story level adds around the gameplay: the map card, the moral
/// lesson, "What NASA really does" and Nova's journal page.
library;

class LevelInfo {
  final int n;

  /// One-line goal shown on the mission map card.
  final String brief;

  /// Mini-game names, shown as chips on the map card.
  final List<String> games;

  /// Marked WOW on the map (the two showcase engineering levels).
  final bool wow;

  /// The debrief headline when the level is won.
  final String winTitle;

  /// The moral lesson, short (for Cadets and the map chip) and full.
  final String chip;
  final String moral;
  final String moralBody;

  /// What NASA really does, in one or two sentences.
  final String nasaDoes;

  /// Nova's journal page.
  final String journal;

  /// For Engineers: how engineers calculate it.
  final String howCalc;

  /// Minutes per level for Cadet, Explorer, Engineer.
  final List<int> minutes;

  const LevelInfo({
    required this.n,
    required this.brief,
    required this.games,
    this.wow = false,
    required this.winTitle,
    required this.chip,
    required this.moral,
    required this.moralBody,
    required this.nasaDoes,
    required this.journal,
    required this.howCalc,
    this.minutes = const [6, 10, 15],
  });
}

const levelInfos = <LevelInfo>[
  LevelInfo(
    n: 1,
    brief: 'Climb out of the crashed lander and sort the warnings. Seal the leak and collect five survival items before your air runs low.',
    games: ['Warning triage', 'Leak finder'],
    winTitle: 'Still breathing',
    chip: 'Lesson: stay calm',
    moral: 'Stay calm and fix the most dangerous problem first.',
    moralBody: 'Everything looked broken at once. Air kills fastest, so air came first, then pressure, then power, then the radio.',
    nasaDoes: 'Apollo 13\'s crew and Mission Control "worked the problem" step by step, and got everyone home.',
    journal: 'Day 1. The landing was rough, but I\'m alive. Air first, then everything else. Pip hasn\'t stopped beeping.',
    howCalc: 'Suit O₂ 55% at 0.22% per second gives about 4 minutes outside. Grab the O₂ bottle first.',
  ),
  LevelInfo(
    n: 2,
    brief: 'Check three sites and choose where to build. Houston can say no! Then blow up the habitat and share your materials.',
    games: ['Inflate', 'Materials split'],
    winTitle: 'A roof over Nova',
    chip: 'Lesson: listen to advice',
    moral: 'Listen to advice, and make choices you can explain.',
    moralBody: 'The crater rim had more sunlight, but it was too steep. A good engineer can say why a choice is right, not just that it feels right.',
    nasaDoes: 'In 2016 NASA added an inflatable test room, BEAM, to the ISS. They tested it for years before trusting it.',
    journal: 'Day 2. Home is a bouncy white bubble on a flat plain. Houston said no to the cliff. They were right.',
    howCalc: 'Inflate to 92–98 kPa. Every shielding bag now means less radiation in the storm later.',
  ),
  LevelInfo(
    n: 3,
    brief: 'Find the dead battery cell and choose the right cable. Aim the panels at the low Sun and decide who gets power first.',
    games: ['Panel aiming', 'Polarity', 'Load priority'],
    winTitle: 'Lights on',
    chip: 'Lesson: share fairly',
    moral: 'When there isn\'t enough for everything, share fairly, by priority.',
    moralBody: 'Life support comes before lights, and lights before science. Fair doesn\'t mean equal: it means the most important need goes first.',
    nasaDoes: 'The ISS gets power from huge solar panels that follow the Sun. When power runs short, machines are switched off.',
    journal: 'Day 3. The panels are catching the Sun sideways, it never gets high here. The heater hums. I finally feel warm.',
    howCalc: 'Panel output = cos(angle to the Sun). 30° off still gives 87%; 60° off gives only half.',
  ),
  LevelInfo(
    n: 4,
    brief: 'The water tank keeps dropping. Find the leak, start the oxygen generator and make supplies last 12 days.',
    games: ['Pipe gauges', 'Ration planner'],
    winTitle: 'Enough for 12 days',
    chip: 'Lesson: waste nothing',
    moral: 'Waste nothing, and plan so there is enough for later.',
    moralBody: 'A slow leak is easy to ignore until the tank is empty. Planning rations today is how Nova eats on day 12.',
    nasaDoes: 'The ISS recycles about 98% of its water, including sweat and urine, and splits water to make oxygen.',
    journal: 'Day 5. Found the leak in segment 3. The oxygen machine bubbles like a fish tank. Dinner is small but there\'s enough.',
    howCalc: 'Oxygen days = 6.0 kg ÷ 0.84 kg per day ≈ 7 days. The generator makes up the rest.',
  ),
  LevelInfo(
    n: 5,
    brief: 'Wire the sensors and program the life-support controller, then watch four simulated tests run live.',
    games: ['Sensor wiring', 'Rule builder'],
    wow: true,
    winTitle: 'The base runs itself',
    chip: 'Lesson: test before you trust',
    moral: 'Build things that keep people safe even while you sleep, and test before you trust.',
    moralBody: 'Rules without a gap made the valve chatter on and off. Running the tests showed it before it mattered.',
    nasaDoes: 'The ISS life support runs by itself. Engineers on the ground watch it day and night.',
    journal: 'Day 6. I slept eight whole hours. The controller kept the air right all night. Pip watched the charts.',
    howCalc: 'Hysteresis: switch ON below one level and OFF above a higher one, so the valve doesn\'t chatter.',
    minutes: [8, 12, 18],
  ),
  LevelInfo(
    n: 6,
    brief: 'Five emergencies, one after another! Dust, a tiny space rock hit, a heater fault, a solar storm and a failing seal.',
    games: ['Timed decisions'],
    winTitle: 'Storm survived',
    chip: 'Lesson: courage',
    moral: 'Courage is acting calmly when things go wrong.',
    moralBody: 'Scared is normal. Brave is doing the right next step anyway, quickly but without panic.',
    nasaDoes: 'NASA watches the Sun day and night. When a storm hits, Orion crews build a shelter from their supplies.',
    journal: 'Day 7. Five alarms in one day. I hid behind the water bags during the storm. My hands shook, but I did it.',
    howCalc: 'Dose in the storm depends on the shielding from Level 2: 6+ bags cut it to 2 mSv instead of 12.',
  ),
  LevelInfo(
    n: 7,
    brief: 'Open the lander\'s engine bay. Test six parts with a meter and find the real cause.',
    games: ['Multimeter'],
    winTitle: 'Root cause found',
    chip: 'Lesson: be honest',
    moral: 'Be honest about the real cause. Don\'t blame the first suspect.',
    moralBody: 'The blown fuse looked guilty, but it was only protecting the circuit. The real culprit was a hidden wire touching the frame.',
    nasaDoes: 'After every big failure, a team finds the root cause. Only then do they fly again.',
    journal: 'Day 8. Pip helped me find the sneaky wire. The lander might fly after all!',
    howCalc: 'Open circuit: infinite resistance. Short: almost zero. A loose joint reads high and jumps around.',
  ),
  LevelInfo(
    n: 8,
    brief: 'Fix the wire and fit the right fuse and valve. Tighten each bolt the right amount, then test the engine.',
    games: ['Procedure', 'Strip length', 'Torque'],
    winTitle: 'Engine test: GO',
    chip: 'Lesson: patience',
    moral: 'Patience and checking your work matter more than speed.',
    moralBody: 'Each step was simple. Doing them in order, to the right number, and then testing, is what made the repair real.',
    nasaDoes: 'Astronauts repaired Hubble five times, after practising every move for months in a giant pool.',
    journal: 'Day 10. The engine roared for 3 seconds and stopped exactly on time. I cried a little. Don\'t tell Houston.',
    howCalc: 'Strip 7–9 mm of insulation. Torque 22–26 N·m: too loose leaks, too tight cracks the fitting.',
  ),
  LevelInfo(
    n: 9,
    brief: 'Everything fails at once. Watch the failure spread on a live diagram, find where it started and restore life support first.',
    games: ['Live dependency diagram'],
    wow: true,
    winTitle: 'Cascade stopped',
    chip: 'Lesson: help the vulnerable first',
    moral: 'Everything is connected. Help the most vulnerable first.',
    moralBody: 'One crushed cable switched off everything downstream. Fixing the root brought power back; life support had to come first.',
    nasaDoes: 'Engineers map how systems depend on each other, so a single failure can\'t take down everything.',
    journal: 'Day 11. A rock slid and cut the power cable. Everything went dark at once. Air first, then heat, then the radio.',
    howCalc: 'With limited power, restore in priority order: life support → heaters → comms → lander charging.',
    minutes: [8, 12, 18],
  ),
  LevelInfo(
    n: 10,
    brief: 'The last checklist. Every item must say GO, then the lander lifts off to meet the ship home.',
    games: ['Go / no-go checklist'],
    winTitle: 'Going home',
    chip: 'Lesson: never skip a step',
    moral: 'Teamwork, and never skip a step, even when you are tired.',
    moralBody: 'Two items said NO-GO on the last day. Fixing them took minutes. Skipping them could have cost everything.',
    nasaDoes: 'Before every launch, each controller says "go" or "no-go" for their system. One "no-go" stops the countdown.',
    journal: 'Day 12. Through the window: the base, my footprints, and the big blue Earth. Thank you, Pip. Thank you, team.',
    howCalc: 'Propellant 100%, suit 100%, cabin sealed, Gateway in position: every line must read GO.',
  ),
];

LevelInfo levelInfo(int n) => levelInfos.firstWhere((l) => l.n == n);

/// The in-game day each level starts on.
int levelDay(int n) => const [1, 2, 3, 4, 6, 7, 8, 9, 11, 12][(n - 1).clamp(0, 9)];
