/// Explorer Season 2 (ages 11–14): "The Second Crew". Nova comes back to
/// Shackleton with Dr. Lina Rahme, Jun Park and Tomas Rivera to turn the
/// emergency camp into a real station. Levels 11–15 of the Explorer campaign.
library;

import '../story/story_model.dart';
import 'catalogue.dart';
import 'levels.dart';
import 'messages.dart';

const _n = Speaker.nova;
const _c = Speaker.capcom;
const _a = Speaker.aria;
const _l = Speaker.lina;
const _j = Speaker.jun;
const _t = Speaker.tomas;

const _station = {'lander', 'habitat', 'battery', 'cable', 'panels', 'antenna'};

final explorerS2Tasks = <StoryTask>[
  // ------------------------------------------------------------------ 11
  const StoryTask(
    n: 11,
    title: 'Ice Hunt',
    subtitle: 'Water in the dark',
    lesson: 'Measure before you dig: data tells you where the treasure really is.',
    nasaFact: 'In 2009 NASA\'s LCROSS crashed a rocket part into a south-pole crater. The dust it threw up was about 5.5% water.',
    days: 3,
    scene: SceneSpec(props: {..._station, 'crater', 'drill'}, pickups: ['ice'], startX: 96),
    steps: [
      const StoryStep(
        id: 's11_brief',
        kind: StepKind.talk,
        objective: 'Back at Shackleton',
        intro: [
          const Line(_n, 'Six months later, we are back. This time with a full crew.', Mood.happy),
          const Line(_l, 'Our first job: find water. A station needs a lot more than the camp did.'),
          const Line(_c, 'Orbiter data shows hydrogen in three shadowed spots. Check them with the neutron scanner.'),
        ],
      ),
      const StoryStep(
        id: 's11_scan',
        kind: StepKind.game,
        objective: 'Scan three spots for hydrogen',
        skill: Skill.rootCause,
        game: const GameSpec(
          kind: GameKind.probe,
          title: 'NEUTRON SCANNER',
          instructions: 'Hydrogen slows neutrons down, so fewer fast neutrons come back. Find the spot with the fewest.',
          items: ['Spot 1 · rim', 'Spot 2 · slope', 'Spot 3 · crater floor', 'Spot 4 · plain'],
          readings: ['412 counts/min', '398 counts/min', '231 counts/min', '405 counts/min'],
          faulty: {2},
          probes: 3,
          hint: 'A big dip in fast neutrons means hydrogen, and hydrogen in a cold trap means water ice.',
        ),
      ),
      const StoryStep(
        id: 's11_drill',
        kind: StepKind.goTo,
        objective: 'Set up the drill in the crater',
        target: 'drill',
        useLabel: 'START DRILL',
        intro: [const Line(_j, 'It\'s −190 °C down there. Suit heaters on full, and don\'t stay long.')],
      ),
      const StoryStep(
        id: 's11_core',
        kind: StepKind.collect,
        objective: 'Collect the ice core',
        items: ['ice'],
      ),
      const StoryStep(
        id: 's11_yield',
        kind: StepKind.game,
        objective: 'How much water can we mine?',
        eva: false,
        skill: Skill.resourceMath,
        game: const GameSpec(
          kind: GameKind.sim,
          title: 'WATER ESTIMATE',
          instructions: 'Choose how much ground to dig. We need 2 tonnes of water for six months, without digging for more than 20 days.',
          sim: 'ice_yield',
          hint: 'Water = area × depth × 1 600 kg/m³ × 5.5%. Try about 60 m² and half a metre deep.',
        ),
      ),
      const StoryStep(
        id: 's11_choice',
        kind: StepKind.choice,
        objective: 'Who controls the drill?',
        eva: false,
        skill: Skill.prioritise,
        timer: 30,
        question: 'The drill motor is overheating in the cold. What do you do?',
        options: [
          const StoryOption(id: 'pause', label: 'Pause and let it warm up', detail: 'Lose an hour', result: [const Line(_t, 'Good call. A cracked drill would end the whole ice survey.')]),
          const StoryOption(id: 'push', label: 'Keep drilling to finish today', mistake: true, effect: const Effect(spares: -1), result: [const Line(_t, 'The bit cracked. We used our only spare.', Mood.worried)]),
        ],
        outro: [const Line(_l, 'The core is 6% water. Shackleton Station will have its own water supply!', Mood.happy)],
      ),
    ],
  ),
  // ------------------------------------------------------------------ 12
  const StoryTask(
    n: 12,
    title: 'Rover Expedition',
    subtitle: 'Further than ever',
    lesson: 'Plan the trip home before you leave. A reserve is not wasted, it is insurance.',
    nasaFact: 'Apollo 17\'s rover drove 35.7 km in three days. It never went farther than the crew could walk back.',
    days: 2,
    scene: SceneSpec(props: {..._station, 'rover', 'rim'}, pickups: ['battpack', 'camera'], startX: 92),
    steps: [
      const StoryStep(
        id: 's12_brief',
        kind: StepKind.talk,
        objective: 'A trip to Malapert ridge',
        intro: [
          const Line(_c, 'Science wants samples from the ridge. Rover battery: 18 kWh. Use about 1.1 kWh per km.'),
          const Line(_n, 'Jun and I will drive. Tomas, you are our CAPCOM from the base.'),
        ],
      ),
      const StoryStep(
        id: 's12_gear',
        kind: StepKind.collect,
        objective: 'Pack a spare battery and the camera',
        items: ['battpack', 'camera'],
      ),
      const StoryStep(
        id: 's12_plan',
        kind: StepKind.game,
        objective: 'Plan the energy for the trip',
        eva: false,
        skill: Skill.resourceMath,
        game: const GameSpec(
          kind: GameKind.sim,
          title: 'TRIP PLANNER',
          instructions: 'Choose how far to go and how many spare packs to take. Come back with at least 20% left.',
          sim: 'rover_energy',
          hint: 'Out and back doubles the distance. 7 km out with one spare pack works.',
        ),
      ),
      const StoryStep(
        id: 's12_board',
        kind: StepKind.goTo,
        objective: 'Board the rover',
        target: 'rover',
        useLabel: 'DRIVE',
      ),
      const StoryStep(
        id: 's12_drive',
        kind: StepKind.game,
        objective: 'Drive through the boulder field',
        skill: Skill.prioritise,
        game: const GameSpec(
          kind: GameKind.drive,
          title: 'BOULDER FIELD',
          instructions: 'Steer around the boulders. Every bump costs battery.',
          count: 8,
          hint: 'Change lanes early: the rover is heavy and turns slowly.',
        ),
      ),
      const StoryStep(
        id: 's12_turn',
        kind: StepKind.choice,
        objective: 'Go further or turn back?',
        eva: false,
        skill: Skill.resourceMath,
        timer: 30,
        question: 'You reached the ridge with 55% battery. A beautiful crater is 3 km further. What do you do?',
        options: [
          const StoryOption(id: 'back', label: 'Take samples here, then head home', detail: 'Arrive with 25%', result: [const Line(_j, 'Plenty of reserve. Great samples too.', Mood.happy)]),
          const StoryOption(id: 'more', label: 'Go to the crater', detail: '+6.6 kWh round trip', mistake: true, effect: const Effect(battery: -20), result: [const Line(_t, 'Base to rover: you will arrive with 4%. That breaks the 20% rule!', Mood.worried)]),
        ],
        outro: [const Line(_n, 'Twenty kilos of rock from the ridge, and home safe.', Mood.happy)],
      ),
    ],
  ),
  // ------------------------------------------------------------------ 13
  const StoryTask(
    n: 13,
    title: 'Greenhouse Crisis',
    subtitle: 'The plants are dying',
    lesson: 'Look at all the data before blaming one cause. Systems connect in surprising ways.',
    nasaFact: 'In 2016 a zinnia on the ISS caught mould because the air was too wet. Astronaut Scott Kelly nursed it back and it flowered.',
    days: 2,
    scene: SceneSpec(props: {..._station, 'greenhouse'}, pickups: ['sensor'], startX: 102),
    steps: [
      const StoryStep(
        id: 's13_alarm',
        kind: StepKind.talk,
        objective: 'Bad news from the greenhouse',
        intro: [
          const Line(_l, 'Nova! Half the lettuce is wilting and the leaves have brown spots.', Mood.worried),
          const Line(_a, 'Greenhouse alarm: plant health 54%.'),
        ],
      ),
      const StoryStep(
        id: 's13_walk',
        kind: StepKind.goTo,
        objective: 'Walk to the greenhouse',
        target: 'greenhouse',
        useLabel: 'INSPECT',
      ),
      const StoryStep(
        id: 's13_sensors',
        kind: StepKind.game,
        objective: 'Read every sensor',
        eva: false,
        skill: Skill.rootCause,
        game: const GameSpec(
          kind: GameKind.probe,
          title: 'GREENHOUSE SENSORS',
          instructions: 'Read each sensor and mark the one that is out of the healthy range.',
          items: ['Light (LED)', 'Water in roots', 'Temperature', 'Humidity', 'CO₂'],
          readings: ['220 µmol · normal', '0.32 m³/m³ · normal', '23 °C · normal', '96% · very wet', '1 100 ppm · normal'],
          faulty: {3},
          probes: 4,
          hint: 'Brown spots and wilting with wet air: the problem is water in the air, not in the roots.',
        ),
      ),
      const StoryStep(
        id: 's13_cause',
        kind: StepKind.choice,
        objective: 'What is the real cause?',
        eva: false,
        skill: Skill.systems,
        question: 'Humidity is 96%. Why would the air in the greenhouse get so wet?',
        options: [
          const StoryOption(id: 'fan', label: 'The air fan stopped, so wet air is not moving', result: [const Line(_j, 'The fan breaker tripped two days ago. Still air plus wet leaves: mould.')]),
          const StoryOption(id: 'water', label: 'We watered too much', mistake: true, retry: true, result: [const Line(_l, 'The roots are fine, the sensor said so. Look at what moves air.')]),
          const StoryOption(id: 'light', label: 'The lights are too bright', mistake: true, retry: true, result: [const Line(_l, 'Light is normal. What would make air stop drying?')]),
        ],
      ),
      const StoryStep(
        id: 's13_fix',
        kind: StepKind.game,
        objective: 'Reconnect the fan',
        eva: false,
        skill: Skill.procedure,
        game: const GameSpec(
          kind: GameKind.wire,
          title: 'FAN CIRCUIT',
          instructions: 'Reconnect the fan to the right breaker and controller.',
          items: ['Fan power', 'Fan speed signal', 'Humidity sensor'],
          right: ['Controller input 3', 'Breaker 7 · 28 V', 'Controller output 2'],
          answer: [1, 2, 0],
          hint: 'Power goes to a breaker, a command comes from a controller output, and a sensor goes to an input.',
        ),
        effect: const Effect(flags: {'fanFixed'}),
        outro: [const Line(_l, 'Humidity falling: 70%... 65%. The plants are already perking up.', Mood.happy)],
      ),
      const StoryStep(
        id: 's13_sensor',
        kind: StepKind.collect,
        objective: 'Fit a backup humidity sensor',
        items: ['sensor'],
        outro: [const Line(_n, 'Next time, an alarm on the fan itself. Lesson learned.')],
      ),
    ],
  ),
  // ------------------------------------------------------------------ 14
  const StoryTask(
    n: 14,
    title: 'Moonquake',
    subtitle: 'The ground shakes for ten minutes',
    lesson: 'In a crisis, follow the plan in order: people first, then air, then everything else.',
    nasaFact: 'Apollo seismometers recorded thousands of moonquakes. Shallow ones can last over ten minutes because the dry Moon rings like a bell.',
    days: 1,
    scene: SceneSpec(props: {..._station, 'greenhouse'}, startX: 70),
    steps: [
      const StoryStep(
        id: 's14_quake',
        kind: StepKind.talk,
        objective: 'Moonquake!',
        eva: false,
        intro: [
          const Line(_a, 'Warning: seismic event, magnitude 4.6. Duration: still going.'),
          const Line(_n, 'Everyone hold on to something! Stay away from the shelves!', Mood.scared),
        ],
      ),
      const StoryStep(
        id: 's14_triage',
        kind: StepKind.game,
        objective: 'What first, after the shaking?',
        eva: false,
        skill: Skill.prioritise,
        game: const GameSpec(
          kind: GameKind.order,
          title: 'AFTER THE QUAKE',
          instructions: 'The shaking stopped. Put the jobs in order.',
          label: 'TAP IN ORDER: MOST URGENT FIRST',
          items: ['Is everyone okay?', 'Check cabin pressure', 'Check power', 'Check the greenhouse', 'Report to Houston'],
          answer: [0, 1, 2, 3, 4],
          hint: 'People first, then air, then power. Plants and reports can wait a few minutes.',
        ),
      ),
      const StoryStep(
        id: 's14_seams',
        kind: StepKind.game,
        objective: 'Find damage in the habitat',
        eva: false,
        skill: Skill.rootCause,
        game: const GameSpec(
          kind: GameKind.probe,
          title: 'STRUCTURE CHECK',
          instructions: 'Check each joint for cracks. Mark the one that moved.',
          items: ['Airlock ring', 'Floor anchors', 'Module joint A–B', 'Roof truss'],
          readings: ['0.0 mm', '0.1 mm', '4.2 mm gap', '0.2 mm'],
          faulty: {2},
          probes: 3,
          hint: 'A gap of a few millimetres is a lot for an airtight joint.',
        ),
      ),
      const StoryStep(
        id: 's14_check',
        kind: StepKind.game,
        objective: 'Make the station safe',
        eva: false,
        skill: Skill.procedure,
        game: const GameSpec(
          kind: GameKind.checklist,
          title: 'SAFE TO STAY?',
          instructions: 'Check every item. Fix any NO-GO before saying the station is safe.',
          label: 'Station safe',
          items: ['Crew', 'Cabin pressure', 'Module joint A–B', 'Power bus', 'Water tanks'],
          readings: ['All 4 okay · GO', '101 kPa · GO', 'Gap 4.2 mm · NO-GO', '28 V · GO', 'No leaks · GO'],
          faulty: {2},
          right: ['', '', 'Clamped and sealed · GO', '', ''],
          hint: 'Clamp and seal the joint before the next aftershock.',
        ),
        outro: [const Line(_c, 'Shackleton, we copy all GO. Nice work, crew.'), const Line(_t, 'Next station: flexible joints and deeper anchors.')],
      ),
    ],
  ),
  // ------------------------------------------------------------------ 15
  const StoryTask(
    n: 15,
    title: 'The Second Crew',
    subtitle: 'A station, not a camp',
    lesson: 'A team works when every person knows their role and everyone shares what they see.',
    nasaFact: 'Artemis Moon missions have four astronauts, each with a job. Mission Control on Earth is the fifth teammate.',
    days: 5,
    scene: SceneSpec(props: {..._station, 'greenhouse', 'pad', 'rocket', 'rover'}, startX: 120),
    steps: [
      const StoryStep(
        id: 's15_landed',
        kind: StepKind.talk,
        objective: 'The supply rocket has landed',
        intro: [
          const Line(_c, 'Cargo lander is down on the pad. Two more crew arrive next month.'),
          const Line(_n, 'Then Shackleton becomes a real station. Let\'s plan it properly.', Mood.happy),
        ],
      ),
      const StoryStep(
        id: 's15_roles',
        kind: StepKind.game,
        objective: 'Who does what?',
        eva: false,
        skill: Skill.teamwork,
        game: const GameSpec(
          kind: GameKind.sort,
          title: 'CREW ROLES',
          instructions: 'Give each job to the right crew member.',
          label: 'WHO DOES THIS JOB?',
          items: ['Plan the moonwalks', 'Fix the power bus', 'Check everyone\'s health', 'Study the ice cores', 'Repair the drill', 'Grow the food'],
          bins: ['Nova · Commander', 'Jun · Engineer', 'Lina · Doctor & biologist', 'Tomas · Geologist'],
          answer: [0, 1, 2, 3, 1, 2],
          hint: 'Engineers fix machines; the biologist looks after living things, including people.',
        ),
      ),
      const StoryStep(
        id: 's15_unload',
        kind: StepKind.goTo,
        objective: 'Unload the cargo lander',
        target: 'pad',
        useLabel: 'UNLOAD',
      ),
      const StoryStep(
        id: 's15_supplies',
        kind: StepKind.game,
        objective: 'Supplies for the bigger crew',
        eva: false,
        skill: Skill.resourceMath,
        game: const GameSpec(
          kind: GameKind.sim,
          title: 'SUPPLY PLAN',
          instructions: 'Make the food last until the next rocket, with a 10% reserve.',
          sim: 'crew_supplies',
          hint: '4 people × 30 days × 0.62 kg = 74.4 kg. Add 10%: about 82 kg.',
        ),
      ),
      const StoryStep(
        id: 's15_vote',
        kind: StepKind.choice,
        objective: 'A team decision',
        eva: false,
        skill: Skill.teamwork,
        question: 'Jun thinks the drill should be fixed first. Lina wants the greenhouse expanded. Only one can be done this week. How do you decide?',
        options: [
          const StoryOption(id: 'listen', label: 'Hear both, check the data, then decide and explain why', result: [const Line(_l, 'The water numbers say drill first. Fair enough, and thanks for listening.', Mood.happy)]),
          const StoryOption(id: 'boss', label: 'I\'m the commander: drill, no discussion', mistake: true, retry: true, result: [const Line(_l, 'Maybe you are right, but now I don\'t know why. That hurts the team.', Mood.worried)]),
          const StoryOption(id: 'coin', label: 'Flip a coin', mistake: true, retry: true, result: [const Line(_j, 'We have data for this! Let\'s use it.')]),
        ],
      ),
      const StoryStep(
        id: 's15_end',
        kind: StepKind.talk,
        objective: 'Shackleton Station',
        eva: false,
        intro: [
          const Line(_c, 'Shackleton Station, Houston. The whole world is watching tonight. Congratulations.'),
          const Line(_n, 'A year ago I crashed here alone. Now there is a station, a garden and a crew. Thank you, team.', Mood.happy),
        ],
      ),
    ],
  ),
];

final explorerS2Infos = <LevelInfo>[
  const LevelInfo(n: 11, brief: 'Use the neutron scanner to find ice, drill a core and work out how much water the crater holds.', games: ['Neutron scanner', 'Water estimate'], winTitle: 'Water found', chip: 'Lesson: measure first', moral: 'Measure before you dig.', moralBody: 'The neutron dip pointed to the crater floor. Data saved days of digging in the wrong place.', nasaDoes: 'LCROSS measured about 5.5% water at Cabeus crater; VIPER was built to map ice at the south pole.', journal: 'Season 2, day 3. 6% water in the core! Lina did a little dance in her suit.', howCalc: 'Water = area × depth × 1 600 kg/m³ × 5.5%.'),
  const LevelInfo(n: 12, brief: 'Plan the energy for a rover trip, drive through a boulder field and decide when to turn back.', games: ['Trip planner', 'Boulder field'], winTitle: 'Home with reserve', chip: 'Lesson: plan the way back', moral: 'Plan the trip home before you leave.', moralBody: 'The crater would have been beautiful, but arriving with 4% battery is how expeditions end badly.', nasaDoes: 'Apollo crews stayed within walking distance of the lander: the "walk-back limit".', journal: 'Season 2, day 5. Twenty kilos of ridge rock. Jun drove like a pro.', howCalc: 'Energy = 2 × distance × 1.1 kWh/km; keep 20% of the battery.'),
  const LevelInfo(n: 13, brief: 'Read the greenhouse sensors, find the real cause of the wilting and fix the fan circuit.', games: ['Greenhouse sensors', 'Fan circuit'], winTitle: 'The garden lives', chip: 'Lesson: find the real cause', moral: 'Look at all the data before blaming one cause.', moralBody: 'It looked like a watering problem. The data showed a stopped fan and wet, still air.', nasaDoes: 'Scott Kelly saved the ISS zinnias from mould in 2016 by drying the air around them.', journal: 'Season 2, day 7. The lettuce survived. A tripped breaker almost cost us the garden.', howCalc: 'Healthy humidity is about 50–70%. 96% invites mould.'),
  const LevelInfo(n: 14, brief: 'Ride out a moonquake, then sort the jobs, find the damaged joint and make the station safe.', games: ['After the quake', 'Structure check', 'Safe to stay?'], winTitle: 'Still standing', chip: 'Lesson: follow the plan', moral: 'In a crisis, follow the plan in order.', moralBody: 'People first, then air, then power. Fixing the plants first would have felt nice and been wrong.', nasaDoes: 'Apollo seismometers showed shallow moonquakes can last over ten minutes.', journal: 'Season 2, day 9. Ten minutes of shaking. Nobody hurt, one joint clamped.', howCalc: 'A 4 mm gap in a joint at 101 kPa leaks air fast: fix it before anything else structural.'),
  const LevelInfo(n: 15, brief: 'Share the jobs and unload the cargo lander. Plan supplies for a bigger crew and make a fair team choice.', games: ['Crew roles', 'Supply plan'], winTitle: 'Shackleton Station', chip: 'Lesson: everyone has a role', moral: 'A team works when everyone knows their role and is heard.', moralBody: 'The best commander listens, checks the data and explains the decision.', nasaDoes: 'Artemis crews of four each have roles, with Mission Control as the fifth teammate.', journal: 'Season 2, day 14. The station is real. Next month, six of us.', howCalc: 'Food = crew × days × 0.62 kg, plus 10%.'),
];
