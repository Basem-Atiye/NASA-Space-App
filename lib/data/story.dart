/// The Story Campaign "Stranded at Shackleton": 10 tasks from the crash to
/// the launch home. Each task follows the NASA Space Apps master task order.
library;

import '../story/story_model.dart';
import 'messages.dart';

const _n = Speaker.nova;
const _c = Speaker.capcom;
const _a = Speaker.aria;

/// Days until the rescue window: the ascent stage can only reach the
/// orbiting Gateway when the orbit lines up again.
const rescueDays = 12;

/// Gear lying around the crash site and what each piece does.
class PickupInfo {
  final String id;
  final String name;
  final String what;
  final Effect effect;
  const PickupInfo(this.id, this.name, this.what, this.effect);
}

const pickupInfo = <String, PickupInfo>{
  'kit': PickupInfo('kit', 'Repair kit', 'Sealant, patches and tape. You can now fix small leaks.', Effect(flags: {'kit'})),
  'o2': PickupInfo('o2', 'Portable O2 bottle', 'Suit oxygen +40%.', Effect(suitO2: 40)),
  'aid': PickupInfo('aid', 'First-aid kit', 'Health +15. Nova patches up the bruises from the landing.', Effect(health: 15)),
  'radio': PickupInfo('radio', 'Emergency radio', 'Contact with Mission Control is back.', Effect(flags: {'radio'})),
  'tools': PickupInfo('tools', 'Tool bag', 'Multimeter, crimper and torque wrench.', Effect(flags: {'tools'})),
  'helmet': PickupInfo('helmet', 'Helmet', 'A gold visor blocks the strong sunlight, like sunglasses for your whole face.', Effect(flags: {'helmet'})),
  'gloves': PickupInfo('gloves', 'Gloves', 'Spacesuit gloves have many layers. Fingers get tired because the suit is full of air pushing back.', Effect(flags: {'gloves'})),
  'boots': PickupInfo('boots', 'Moon boots', 'Thick soles keep feet warm on ground that can be −170 °C in the shade.', Effect(flags: {'boots'})),
  'pack': PickupInfo('pack', 'Life-support backpack', 'The backpack gives oxygen, removes carbon dioxide and pumps cool water around the body.', Effect(flags: {'pack'})),
  'food': PickupInfo('food', 'Food box', 'Space food is mostly dried to save weight. Add water and it is ready.', Effect(flags: {'food'})),
  'water': PickupInfo('water', 'Water bottle', 'Each astronaut needs about 2.4 kg of water a day for drinking and food.', Effect(flags: {'water'})),
  'seed': PickupInfo('seed', 'Seeds', 'Lettuce, radish and tomato have all been grown in space.', Effect(flags: {'seeds'})),
  'part': PickupInfo('part', 'Spare part', 'Spares are gold on the Moon: the nearest shop is 384 000 km away.', Effect(spares: 1)),
  'filter': PickupInfo('filter', 'Water filter', 'Filters take out bits; UV light and chemistry make the water safe to drink.', Effect(flags: {'filter'})),
  'camera': PickupInfo('camera', 'Camera', 'Photos help scientists on Earth see what astronauts see.', Effect(flags: {'camera'})),
  'sensor': PickupInfo('sensor', 'Seismic sensor', 'Apollo seismometers found that the Moon has moonquakes, some lasting over ten minutes.', Effect(flags: {'sensor'})),
  'battpack': PickupInfo('battpack', 'Battery pack', 'A spare battery pack: about 4 kWh more for the rover.', Effect(battery: 15)),
  'flag': PickupInfo('flag', 'Marker flag', 'Flags mark safe paths and sample sites for the next crew.', Effect(flags: {'flag'})),
  'rock1': PickupInfo('rock1', 'Dark rock sample', 'Basalt: dark rock from lava that flooded the Moon billions of years ago.', Effect(flags: {'rock1'})),
  'rock2': PickupInfo('rock2', 'Light rock sample', 'Anorthosite: bright rock from the Moon\'s oldest crust, the light highlands.', Effect(flags: {'rock2'})),
  'rock3': PickupInfo('rock3', 'Cold rock sample', 'A rock from a shadowed crater, frozen at −170 °C. It may hold ice.', Effect(flags: {'rock3'})),
  'ice': PickupInfo('ice', 'Ice core', 'Dirty ice from a crater that never sees the Sun: water for drinking, air and rocket fuel.', Effect(flags: {'ice'})),
};

/// What Nova finds at each candidate habitat site (Task 2).
class SiteInfo {
  final String id;
  final String name;
  final List<String> facts;
  const SiteInfo(this.id, this.name, this.facts);
}

const siteInfo = <String, SiteInfo>{
  'site:A': SiteInfo('site:A', 'Site A · Crater rim', ['Sunlight 85% of the time', 'Slope 14° (too steep)', 'Far from the lander: 60 m', 'Loose boulders']),
  'site:B': SiteInfo('site:B', 'Site B · Flat plain', ['Sunlight 70% of the time', 'Slope 3° (flat)', 'Close to the lander: 30 m', 'Ice-rich crater nearby']),
  'site:C': SiteInfo('site:C', 'Site C · Crater floor', ['Sunlight 0%: permanent shadow', 'Temperature −170 °C', 'Slope 5°', 'Ice everywhere, but no solar power']),
};

const storyTasks = <StoryTask>[
  // =========================================================== 1
  StoryTask(
    n: 1,
    title: 'Crash Landing',
    subtitle: 'Assess the damage and survive',
    lesson: 'In an emergency, fix the most dangerous thing first. Air first, then pressure, then power, then radio.',
    nasaFact: 'Apollo crews trained to "work the problem". Stay calm, check the facts and fix the most dangerous thing first. Apollo 13 survived exactly this way.',
    startX: -21,
    startZ: -14,
    suitStart: 55,
    suitDrain: 0.22,
    steps: [
      StoryStep(
        id: 't1_wake',
        kind: StepKind.talk,
        objective: 'Wake up',
        eva: false,
        intro: [
          Line(_a, 'Hard landing detected. Lander tilted 9°. Multiple warnings active.'),
          Line(_n, 'Ugh... I\'m okay. I\'m out of the lander. My suit says oxygen 55%. Flight, can you hear me?', Mood.scared),
          Line(_a, 'No signal. The main antenna is damaged. Commander, you are on your own until you find the emergency radio.'),
          Line(_n, 'Then I\'ll work the problem. Tap the ground to walk me around. Let\'s check the lander first.', Mood.worried),
        ],
      ),
      StoryStep(
        id: 't1_panel',
        kind: StepKind.goTo,
        objective: 'Walk to the lander and open the warning panel',
        target: 'lander',
        useLabel: 'OPEN PANEL',
        hint: 'Tap the glowing lander. Nova walks there by herself. Then press OPEN PANEL.',
      ),
      StoryStep(
        id: 't1_triage',
        kind: StepKind.game,
        objective: 'Sort the warnings by danger',
        game: GameSpec(
          kind: GameKind.order,
          title: 'WARNING PANEL TRIAGE',
          instructions: 'Five warnings are flashing. Tap them in the order you will deal with them: the one that can kill you fastest first.',
          items: ['SUIT O2 55%', 'CABIN PRESSURE FALLING', 'MAIN BUS VOLTAGE LOW', 'COMMS LINK LOST', 'STAR TRACKER FAULT'],
          answer: [0, 1, 2, 3, 4],
          hint: 'Without oxygen you have minutes. Without pressure, hours. Without power, a day. Comms and navigation can wait.',
        ),
        mistakeEffect: Effect(suitO2: -3),
        outro: [Line(_n, 'Air first. My suit is fine for now, but the cabin is leaking. I need to find that leak.')],
      ),
      StoryStep(
        id: 't1_leak',
        kind: StepKind.game,
        objective: 'Find the cabin leak',
        game: GameSpec(
          kind: GameKind.probe,
          title: 'LEAK FINDER',
          instructions: 'Hold the leak detector to each part of the cabin. It shows how fast pressure drops near it. Mark the leak.',
          items: ['Hatch seal', 'Window frame', 'Vent valve', 'Fuel line joint', 'Hull seam'],
          readings: ['−2.4 kPa/min  ·  hissing', '−0.1 kPa/min', '−0.1 kPa/min', '0.0 kPa/min', '−0.2 kPa/min'],
          faulty: {0},
          probes: 4,
          hint: 'Every seal leaks a tiny bit. Look for the reading that is much bigger than all the others.',
        ),
        mistakeEffect: Effect(suitO2: -3),
      ),
      StoryStep(
        id: 't1_fix',
        kind: StepKind.choice,
        objective: 'Choose how to fix the leak',
        question: 'There is a 4 cm crack in the rubber hatch seal. How do you fix it?',
        options: [
          StoryOption(
            id: 'sealant',
            label: 'Sealant patch',
            detail: 'Flexible, cures in 5 minutes, needs no power',
            effect: Effect(pressure: 0, flags: {'sealed'}),
            result: [Line(_n, 'Sealant on, pressing it down... the hissing stopped. Pressure is holding!', Mood.happy)],
          ),
          StoryOption(
            id: 'welder',
            label: 'Welding torch',
            detail: 'Strong metal joint',
            mistake: true,
            retry: true,
            effect: Effect(battery: -10, health: -5),
            result: [Line(_a, 'Warning: welding melts rubber seals and drains 10% battery. The leak got worse.'), Line(_n, 'Bad idea. Rubber needs something flexible.', Mood.worried)],
          ),
          StoryOption(
            id: 'tape',
            label: 'Duct tape',
            detail: 'Quick and easy',
            mistake: true,
            retry: true,
            effect: Effect(suitO2: -5),
            result: [Line(_n, 'The tape just pops off. Cabin pressure pushes on it with hundreds of kilograms of force.', Mood.worried)],
          ),
        ],
        hint: 'Rubber seals bend. The fix must bend too, and you have very little power.',
      ),
      StoryStep(
        id: 't1_gear',
        kind: StepKind.collect,
        objective: 'Collect the 5 survival items scattered by the crash',
        items: ['kit', 'o2', 'aid', 'radio', 'tools'],
        intro: [Line(_n, 'The crash threw our emergency gear everywhere. I see five glowing cases. Walk me to each one.')],
        hint: 'Tap a glowing case on the ground. Get the oxygen bottle early if your suit is low.',
        outro: [
          Line(_c, 'Shackleton, Houston! We have you on the emergency band. Nova, are you okay?'),
          Line(_n, 'Sami! I\'m okay. The lander is patched. I have all our survival gear.', Mood.happy),
          Line(_c, 'Great work. The ascent stage can reach the Gateway in $rescueDays days when the orbit lines up. You need to survive until then, and fix that lander.'),
        ],
      ),
      StoryStep(
        id: 't1_cabin',
        kind: StepKind.choice,
        objective: 'Decide where to spend the first night',
        question: 'The patched cabin holds 70 kPa. Your suit oxygen is low. What now?',
        options: [
          StoryOption(
            id: 'rest',
            label: 'Rest in the patched cabin',
            detail: 'Recharge the suit, sleep, start fresh',
            effect: Effect(suitO2: 100, health: 5, flags: {'rested'}),
            result: [Line(_c, 'Smart call. Rest is a safety tool. Tired astronauts make mistakes.'), Line(_n, 'Suit recharging. Goodnight, Houston.', Mood.tired)],
          ),
          StoryOption(
            id: 'work',
            label: 'Keep working outside',
            detail: 'Start building the base right away',
            mistake: true,
            effect: Effect(health: -15, suitO2: 100),
            result: [Line(_n, 'I worked until my suit alarm went off. I\'m exhausted and my hands are shaking.', Mood.tired), Line(_c, 'Nova, please rest next time. Fatigue causes accidents.')],
          ),
        ],
      ),
    ],
  ),

  // =========================================================== 2
  StoryTask(
    n: 2,
    title: 'Shelter',
    subtitle: 'Build a temporary base',
    lesson: 'A habitat site needs flat ground, sunlight for power, and to be close to your supplies. Every choice is a trade-off.',
    nasaFact: 'NASA studies inflatable habitats. They pack small for launch, then grow into a big home. One, BEAM, has been attached to the ISS since 2016.',
    startX: -18,
    startZ: -10,
    steps: [
      StoryStep(
        id: 't2_brief',
        kind: StepKind.talk,
        objective: 'Listen to Mission Control',
        eva: false,
        intro: [
          Line(_c, 'Nova, the lander cabin is too small and too damaged for $rescueDays days. Let\'s set up the inflatable habitat.'),
          Line(_c, 'I\'ve marked three possible sites: A, B and C. Walk to each one and look before you choose.'),
        ],
      ),
      StoryStep(
        id: 't2_survey',
        kind: StepKind.collect,
        objective: 'Survey sites A, B and C',
        items: ['site:A', 'site:B', 'site:C'],
        hint: 'Tap each flag. Nova reports the slope, sunlight and distance.',
      ),
      StoryStep(
        id: 't2_site',
        kind: StepKind.choice,
        objective: 'Choose the habitat site',
        eva: false,
        question: 'Where will you put the habitat?',
        options: [
          StoryOption(
            id: 'A',
            label: 'Site A · Crater rim',
            detail: 'Most sunlight, 14° slope',
            mistake: true,
            retry: true,
            result: [Line(_c, 'Veto from Houston. A 14° slope can tip the habitat and make it roll. Pick flatter ground.')],
          ),
          StoryOption(
            id: 'B',
            label: 'Site B · Flat plain',
            detail: 'Good sunlight, flat, close to the lander',
            effect: Effect(flags: {'siteB'}),
            result: [Line(_c, 'Agreed. Flat, sunny enough, and close to your supplies. Good engineering trade-off.')],
          ),
          StoryOption(
            id: 'C',
            label: 'Site C · Crater floor',
            detail: 'Lots of ice, permanent shadow',
            mistake: true,
            retry: true,
            result: [Line(_c, 'Veto. No sunlight means no solar power, and −170 °C would freeze the habitat. Ice is great, but you can fetch it.')],
          ),
        ],
      ),
      StoryStep(
        id: 't2_deploy',
        kind: StepKind.goTo,
        objective: 'Walk to Site B and deploy the habitat',
        target: 'site:B',
        useLabel: 'DEPLOY',
      ),
      StoryStep(
        id: 't2_inflate',
        kind: StepKind.game,
        objective: 'Inflate the habitat',
        eva: false,
        game: GameSpec(
          kind: GameKind.hold,
          title: 'INFLATE THE HABITAT',
          instructions: 'Hold to pump air in. Release between 92 and 98 kPa. Too much stretches the seams.',
          rate: 15,
          low: 92,
          high: 98,
          max: 120,
          unit: 'kPa',
          hint: 'The needle speeds up. Let go a little before it reaches the green band.',
        ),
        mistakeEffect: Effect(health: -3),
        effect: Effect(flags: {'habitat'}, pressure: 95),
        outro: [Line(_n, 'It\'s standing! Our new home is about the size of a small bedroom.', Mood.happy)],
      ),
      StoryStep(
        id: 't2_materials',
        kind: StepKind.game,
        objective: 'Split the building materials',
        eva: false,
        game: GameSpec(
          kind: GameKind.allocate,
          title: 'MATERIALS: 10 UNITS',
          instructions: 'Shielding (regolith bags around the habitat) protects you from radiation. Spare parts are needed to repair the lander. Split 10 units.',
          items: ['Shielding', 'Spare parts'],
          total: 10,
          hint: 'You need at least 5 units of shielding for a solar storm. You also need at least 3 spare parts for the lander.',
        ),
        outro: [Line(_n, 'Filling regolith bags around the habitat. Moon dirt makes a decent radiation shield.')],
      ),
      StoryStep(
        id: 't2_seal',
        kind: StepKind.game,
        objective: 'Seal test: find the leaking seam',
        eva: false,
        game: GameSpec(
          kind: GameKind.probe,
          title: 'SEAL TEST',
          instructions: 'Pressure is held for 10 minutes. Check how much each seam lost. Mark the one that leaks.',
          items: ['Door seal', 'Floor seam', 'Window seam', 'Roof seam'],
          readings: ['−0.1 kPa', '−0.2 kPa', '−3.8 kPa', '−0.1 kPa'],
          faulty: {2},
          probes: 3,
          hint: 'A healthy seam loses almost nothing in 10 minutes.',
        ),
        effect: Effect(flags: {'habSealed'}),
      ),
      StoryStep(
        id: 't2_connect',
        kind: StepKind.game,
        objective: 'Connect life support',
        eva: false,
        game: GameSpec(
          kind: GameKind.wire,
          title: 'LIFE SUPPORT CONNECTORS',
          instructions: 'Connect each line from the lander supply to the right habitat port. Wrong connections waste supplies.',
          items: ['O2 line', 'Water line', 'Power 28 V', 'Data'],
          right: ['Data port', 'O2 inlet', '28 V DC input', 'Water inlet'],
          answer: [1, 3, 2, 0],
          hint: 'Read the port labels carefully. Colors on real spacecraft follow the same idea: every line has one matching port.',
        ),
        mistakeEffect: Effect(o2Kg: -0.3),
        outro: [Line(_c, 'Habitat is pressurised and connected. Nova, you have a home.'), Line(_n, 'And it\'s warm in here! First good news today.', Mood.happy)],
      ),
    ],
  ),

  // =========================================================== 3
  StoryTask(
    n: 3,
    title: 'Electricity',
    subtitle: 'Get the power system running',
    lesson: 'Electricity needs a source (solar) and a store (battery). It needs the right cable and the right + and − sides. When power is short, choose what comes first.',
    nasaFact: 'The ISS solar arrays produce up to 120 kW. They turn to follow the Sun. A panel facing the Sun makes the most power. Power follows the cosine of the angle.',
    startX: 6,
    startZ: 8,
    steps: [
      StoryStep(
        id: 't3_brief',
        kind: StepKind.talk,
        objective: 'Listen to Mission Control',
        eva: false,
        intro: [
          Line(_c, 'Power is next. The lander battery is low and the habitat runs on it. Let\'s check the battery first.'),
        ],
      ),
      StoryStep(id: 't3_goBattery', kind: StepKind.goTo, objective: 'Walk to the battery', target: 'battery', useLabel: 'CHECK'),
      StoryStep(
        id: 't3_cells',
        kind: StepKind.game,
        objective: 'Find the dead battery cell',
        game: GameSpec(
          kind: GameKind.probe,
          title: 'BATTERY CHECK',
          instructions: 'Measure each cell with the multimeter. A healthy lithium cell reads about 3.6 to 3.8 volts. Mark the dead one so it can be bypassed.',
          items: ['Cell 1', 'Cell 2', 'Cell 3', 'Cell 4', 'Cell 5'],
          readings: ['3.71 V', '3.68 V', '0.42 V', '3.70 V', '3.66 V'],
          faulty: {2},
          probes: 4,
        ),
        effect: Effect(battery: 10),
      ),
      StoryStep(
        id: 't3_cable',
        kind: StepKind.choice,
        objective: 'Replace the damaged battery cable',
        question: 'The cable from the battery to the habitat was crushed. It carries 30 amps. Which cable do you use?',
        options: [
          StoryOption(id: 'awg10', label: 'Thick cable, rated 40 A', detail: 'Heavy', effect: Effect(flags: {'cable'}), result: [Line(_n, 'Rated above 30 A with margin. Installed.')]),
          StoryOption(
            id: 'awg18',
            label: 'Thin cable, rated 10 A',
            detail: 'Light and flexible',
            mistake: true,
            retry: true,
            effect: Effect(battery: -5),
            result: [Line(_a, 'Cable temperature 140 °C. Insulation melting. Disconnecting.'), Line(_n, 'Too thin for 30 amps. It got hot. Cables must be rated above the current.', Mood.worried)],
          ),
          StoryOption(
            id: 'data',
            label: 'Spare data cable',
            detail: 'Already in the tool bag',
            mistake: true,
            retry: true,
            result: [Line(_n, 'A data cable carries tiny signals, not 30 amps. That won\'t work.')],
          ),
        ],
        hint: 'Thin wires get hot when too much current flows. Pick one rated above 30 A.',
      ),
      StoryStep(id: 't3_crate', kind: StepKind.goTo, objective: 'Unpack the solar panel crate', target: 'crate', useLabel: 'UNPACK', effect: Effect(flags: {'panelsUp'})),
      StoryStep(
        id: 't3_aim',
        kind: StepKind.game,
        objective: 'Aim the solar panels at the Sun',
        eva: false,
        game: GameSpec(
          kind: GameKind.tune,
          title: 'AIM THE PANELS',
          instructions: 'At the south pole the Sun circles the horizon. Turn the panels until the power meter peaks, then lock.',
          best: 132,
          hint: 'Watch the meter, not the dial. Output is highest when the panel faces the Sun straight on.',
        ),
        effect: Effect(battery: 15),
      ),
      StoryStep(
        id: 't3_polarity',
        kind: StepKind.game,
        objective: 'Wire the charge controller',
        eva: false,
        game: GameSpec(
          kind: GameKind.wire,
          title: 'POLARITY',
          instructions: 'Connect the panels and battery to the charge controller. Plus to plus, minus to minus. A reversed wire blows the fuse.',
          items: ['Panel +', 'Panel −', 'Battery +', 'Battery −'],
          right: ['BAT −', 'PV +', 'BAT +', 'PV −'],
          answer: [1, 3, 2, 0],
          hint: 'Red is plus, black is minus. PV means the solar panel side.',
        ),
        mistakeEffect: Effect(spares: -1),
        effect: Effect(flags: {'wired'}),
      ),
      StoryStep(
        id: 't3_loads',
        kind: StepKind.game,
        objective: 'Set the power priorities',
        eva: false,
        game: GameSpec(
          kind: GameKind.order,
          title: 'LOAD PRIORITY',
          instructions: 'Only 1.2 kW is available. Tap the systems in the order they get power. The last ones are switched off first when power runs low.',
          items: ['Life support', 'Heaters', 'Comms', 'Lights', 'Science'],
          answer: [0, 1, 2, 3, 4],
          hint: 'What keeps Nova alive this minute? Then what keeps her alive tonight? Then what gets her rescued?',
        ),
        outro: [Line(_c, 'Battery charging at 1.1 kW. Lights on at Shackleton!'), Line(_n, 'Power! I could hug these panels.', Mood.happy)],
      ),
    ],
  ),

  // =========================================================== 4
  StoryTask(
    n: 4,
    title: 'Air, Water, Food',
    subtitle: 'Make the supplies last',
    lesson: 'Life support is a budget. Know how much you use each day. Find the leaks and recycle what you can. Share supplies out so they last the whole mission.',
    nasaFact: 'NASA plans 0.84 kg of oxygen, 2.37 kg of water and 0.62 kg of food per astronaut per day. On the ISS about 98% of water is recycled.',
    startX: 6,
    startZ: 8,
    steps: [
      StoryStep(id: 't4_go', kind: StepKind.goTo, objective: 'Take inventory in the habitat', target: 'habitat', useLabel: 'INVENTORY'),
      StoryStep(
        id: 't4_o2days',
        kind: StepKind.choice,
        objective: 'Work out the oxygen supply',
        eva: false,
        question: 'You have 6.0 kg of oxygen. One astronaut breathes 0.84 kg a day. How many days does it last?',
        options: [
          StoryOption(id: 'd5', label: 'About 5 days', mistake: true, retry: true, result: [Line(_a, 'Check: 6.0 ÷ 0.84 is more than 5.')]),
          StoryOption(id: 'd7', label: 'About 7 days', result: [Line(_n, '6.0 ÷ 0.84 = 7.1 days. Rescue is in $rescueDays. Not enough. We need the oxygen generator.', Mood.worried)]),
          StoryOption(id: 'd14', label: 'About 14 days', mistake: true, retry: true, result: [Line(_a, 'Check: 0.84 × 14 = 11.8 kg. You only have 6.0 kg.')]),
        ],
      ),
      StoryStep(
        id: 't4_pipe',
        kind: StepKind.game,
        objective: 'Find the leak in the water loop',
        eva: false,
        game: GameSpec(
          kind: GameKind.probe,
          title: 'PIPE GAUGES',
          instructions: 'The water tank level keeps dropping. Read the pressure at both ends of each pipe segment. A big drop means a leak.',
          items: ['Segment 1', 'Segment 2', 'Segment 3', 'Segment 4'],
          readings: ['210 → 208 kPa', '208 → 206 kPa', '206 → 151 kPa', '151 → 149 kPa'],
          faulty: {2},
          probes: 3,
          hint: 'Every pipe loses about 2 kPa from friction. Look for the segment that loses much more.',
        ),
        mistakeEffect: Effect(waterKg: -1),
        effect: Effect(flags: {'pipeFixed'}),
      ),
      StoryStep(
        id: 't4_generator',
        kind: StepKind.game,
        objective: 'Start the oxygen generator',
        eva: false,
        game: GameSpec(
          kind: GameKind.order,
          title: 'START-UP SEQUENCE',
          instructions: 'The oxygen generator splits water into oxygen and hydrogen using electricity. Tap the steps in a safe order.',
          items: ['Check water feed', 'Switch on power', 'Vent hydrogen line', 'Start electrolysis', 'Check O2 output'],
          answer: [0, 1, 2, 3, 4],
          hint: 'No water, no oxygen. And hydrogen must have a way out before you make any.',
        ),
        effect: Effect(flags: {'generator'}),
        outro: [Line(_a, 'Oxygen generator running: 0.9 kg per day. Water recycler online.')],
      ),
      StoryStep(
        id: 't4_rations',
        kind: StepKind.game,
        objective: 'Plan the rations',
        eva: false,
        game: GameSpec(
          kind: GameKind.allocate,
          title: 'RATIONS FOR $rescueDays DAYS',
          instructions: 'You have 8.0 kg of food and 30 kg of water (after recycling). Set the daily amounts so they last $rescueDays days with a 10% reserve, without starving Nova.',
          items: ['Food kg/day', 'Water kg/day'],
          mins: [0.3, 1.5],
          maxs: [0.8, 3.0],
          hint: 'Minimums: 0.5 kg food and 2.0 kg water a day. Maximum: stock ÷ ($rescueDays × 1.1).',
        ),
        outro: [Line(_n, 'Rations set. Not a feast, but I\'ll make it.', Mood.calm)],
      ),
    ],
  ),

  // =========================================================== 5
  StoryTask(
    n: 5,
    title: 'Smart Life Support',
    subtitle: 'Build an automatic controller',
    lesson: 'A controller reads sensors and switches actuators by rules. Thresholds keep values safe, and a gap between ON and OFF (hysteresis) stops it switching too often.',
    nasaFact: 'The ISS life support runs by itself. Sensors check oxygen, carbon dioxide, pressure and heat all day, so the crew can sleep.',
    startX: 6,
    startZ: 8,
    steps: [
      StoryStep(
        id: 't5_brief',
        kind: StepKind.talk,
        objective: 'Listen to Mission Control',
        eva: false,
        intro: [
          Line(_c, 'Nova, you can\'t watch the gauges 24 hours a day. You need to sleep. Let\'s make life support automatic.'),
          Line(_n, 'Sensors, a controller and rules. Like a thermostat, but for my whole house.'),
        ],
      ),
      StoryStep(id: 't5_go', kind: StepKind.goTo, objective: 'Go to the habitat equipment rack', target: 'habitat', useLabel: 'INSTALL'),
      StoryStep(
        id: 't5_wire',
        kind: StepKind.game,
        objective: 'Wire the sensors to the controller',
        eva: false,
        game: GameSpec(
          kind: GameKind.wire,
          title: 'SENSOR WIRING',
          instructions: 'Connect each sensor to the controller input that expects it.',
          items: ['O2 sensor', 'Pressure sensor', 'Temperature sensor', 'CO2 sensor'],
          right: ['IN-3 · °C', 'IN-1 · O2 %', 'IN-4 · CO2 ppm', 'IN-2 · kPa'],
          answer: [1, 3, 0, 2],
        ),
        effect: Effect(flags: {'sensors'}),
      ),
      StoryStep(
        id: 't5_rules',
        kind: StepKind.game,
        objective: 'Program the controller and run the tests',
        eva: false,
        game: GameSpec(
          kind: GameKind.rules,
          title: 'CONTROLLER RULES',
          instructions: 'Set when each actuator switches ON and OFF, then run four simulated tests. All four must pass.',
          hint: 'Oxygen: valve ON below about 19%, OFF above about 20.5%. Pressure: ON below about 90 kPa, OFF at about 98. Heater ON below 15 to 20 °C. Fan ON above 25 to 30 °C.',
        ),
        effect: Effect(flags: {'controller'}),
        outro: [
          Line(_a, 'Controller active. Life support is now automatic.'),
          Line(_n, 'I can finally sleep a whole night. Goodnight, Sami.', Mood.happy),
        ],
      ),
    ],
  ),

  // =========================================================== 6
  StoryTask(
    n: 6,
    title: 'Hazards',
    subtitle: 'Survive the Moon\'s environment',
    lesson: 'The Moon throws dust, micrometeoroids, extreme cold and radiation at you. Fast, calm decisions and good preparation save lives.',
    nasaFact: 'Lunar dust is sharp like crushed glass and sticks to everything. Apollo 17 astronauts reported it damaged seals and made suit joints stiff.',
    startX: 6,
    startZ: 8,
    steps: [
      // Walk first, then decide — play before theory.
      StoryStep(id: 't6_to_panels', kind: StepKind.goTo, objective: 'Walk to the dusty solar panels', target: 'panels', useLabel: 'INSPECT', intro: [const Line(_a, 'Power dropped 40%. Dust on the panels.')]),
      StoryStep(
        id: 't6_dust',
        kind: StepKind.choice,
        objective: 'Clean the panels',
        timer: 20,
        question: 'Dust covers the panels. What do you do?',
        options: [
          StoryOption(id: 'brush', label: 'Brush gently with the soft brush', effect: Effect(battery: 10), result: [Line(_n, 'Brushing in long strokes. Power back to normal.', Mood.happy)]),
          StoryOption(id: 'blow', label: 'Blow it off with suit oxygen', mistake: true, effect: Effect(suitO2: -15), result: [Line(_c, 'That cost 15% of your suit oxygen, and the dust just settles again. No air on the Moon to carry it away.')]),
          StoryOption(id: 'ignore', label: 'Ignore it for now', mistake: true, effect: Effect(battery: -15), result: [Line(_a, 'Battery charging slowly. Battery −15%.')]),
        ],
      ),
      const StoryStep(id: 't6_clean', kind: StepKind.goTo, objective: 'Finish cleaning at the panels', target: 'panels', useLabel: 'CLEAN'),
      StoryStep(id: 't6_to_habitat', kind: StepKind.goTo, objective: 'Run to the habitat — impact alert!', target: 'habitat', useLabel: 'ENTER', intro: [const Line(_a, 'Impact detected! Pressure falling!')]),
      StoryStep(
        id: 't6_meteor',
        kind: StepKind.choice,
        objective: 'Seal the micrometeoroid hole',
        timer: 15,
        question: 'A pinhole in the habitat. Pressure is falling. Act fast!',
        options: [
          StoryOption(id: 'patch', label: 'Patch the hole from the repair kit', effect: Effect(pressure: -3), result: [Line(_n, 'Found it, a pinhole. Patch on. Pressure stable at 92 kPa.', Mood.calm)]),
          StoryOption(id: 'pump', label: 'Pump in more air', mistake: true, effect: Effect(o2Kg: -1.0), result: [Line(_c, 'That just pushes more air out of the hole. You lost 1 kg of oxygen. Fix the leak first.')]),
          StoryOption(id: 'run', label: 'Run to the lander', mistake: true, effect: Effect(pressure: -10, health: -5), result: [Line(_c, 'The habitat kept leaking while you were gone. Pressure dropped 10 kPa.')]),
        ],
      ),
      const StoryStep(id: 't6_patch', kind: StepKind.goTo, objective: 'Check the habitat patch', target: 'habitat', useLabel: 'CHECK PATCH'),
      StoryStep(id: 't6_to_heater', kind: StepKind.goTo, objective: 'Check the heater at the habitat', target: 'habitat', useLabel: 'CHECK HEATER', intro: [const Line(_a, 'Heater 1 fault. Cabin 14 °C and falling.')]),
      StoryStep(
        id: 't6_thermal',
        kind: StepKind.choice,
        objective: 'Fix the heater fault',
        timer: 20,
        question: 'Main heater burned out. Night is coming. What do you do?',
        options: [
          StoryOption(id: 'backup', label: 'Switch to the backup heater and close the window shades', result: [Line(_n, 'Backup heater on, shades closed. 19 °C and rising.', Mood.calm)]),
          StoryOption(id: 'suit', label: 'Wear the suit inside to stay warm', mistake: true, effect: Effect(suitO2: -20), result: [Line(_c, 'That works for an hour, but burns suit oxygen. Use the backup heater.')]),
          StoryOption(id: 'wait', label: 'Wait and see', mistake: true, effect: Effect(health: -10), result: [Line(_n, 'It\'s 6 °C. My fingers are numb...', Mood.scared)]),
        ],
      ),
      StoryStep(id: 't6_to_shelter', kind: StepKind.goTo, objective: 'Get to shielded shelter — flare warning!', target: 'habitat', useLabel: 'SHELTER', intro: [const Line(_c, 'Solar flare! Protons in 30 minutes!')]),
      StoryStep(
        id: 't6_spe',
        kind: StepKind.choice,
        objective: 'Solar particle event',
        timer: 15,
        question: 'You were outside. Protons arrive in 30 minutes. What do you do?',
        options: [
          StoryOption(id: 'shelter', label: 'Stay inside the shielded habitat now', effect: Effect(flags: {'sheltered'}), result: [Line(_n, 'Inside, behind the regolith bags. Waiting it out.', Mood.worried)]),
          StoryOption(id: 'finish', label: 'Go back out and finish the cable job', mistake: true, effect: Effect(dose: 40, health: -15), result: [Line(_c, 'You took a big radiation dose out there. Never finish a job during a storm warning.')]),
        ],
      ),
      StoryStep(id: 't6_to_airlock', kind: StepKind.goTo, objective: 'Inspect the airlock seal', target: 'habitat', useLabel: 'CHECK SEAL', intro: [const Line(_a, 'Airlock seal worn. Leak rate rising.')]),
      StoryStep(
        id: 't6_seal',
        kind: StepKind.choice,
        objective: 'Fix the airlock seal',
        timer: 20,
        question: 'Dust scratched the airlock seal. How do you fix it?',
        options: [
          StoryOption(id: 'oring', label: 'Clean the groove and fit a spare O-ring', effect: Effect(spares: -1), result: [Line(_n, 'Groove cleaned, new O-ring in. That one used a spare part.')]),
          StoryOption(id: 'sealant', label: 'Smear sealant on it', mistake: true, result: [Line(_c, 'Sealant on a door seal glues the door or gets scraped off the next time you open it. Use an O-ring.')]),
          StoryOption(id: 'ignore', label: 'Use the airlock less', mistake: true, effect: Effect(o2Kg: -0.8), result: [Line(_a, 'Every airlock cycle now loses air. Oxygen −0.8 kg.')]),
        ],
        outro: [Line(_c, 'Five hazards, and you\'re still standing. That\'s an astronaut.'), Line(_n, 'The Moon is trying very hard to get rid of me.', Mood.tired)],
      ),
    ],
  ),

  // =========================================================== 7
  StoryTask(
    n: 7,
    title: 'Diagnose the Lander',
    subtitle: 'Find the real fault',
    lesson: 'Measure before you fix. Many faults are symptoms: find the root cause, or the problem comes back.',
    nasaFact: 'NASA engineers use "fault trees" to trace a failure back to its root cause. After every major incident, finding the root cause is the first job.',
    startX: -24,
    startZ: -14,
    steps: [
      StoryStep(
        id: 't7_brief',
        kind: StepKind.talk,
        objective: 'Listen to Mission Control',
        eva: false,
        intro: [
          Line(_c, 'Nova, the ascent engine valves don\'t respond. Without them, no launch. Open the maintenance bay and let\'s diagnose.'),
        ],
      ),
      StoryStep(id: 't7_open', kind: StepKind.goTo, objective: 'Open the lander maintenance bay', target: 'lander', useLabel: 'OPEN BAY', effect: Effect(flags: {'bayOpen'}), focus: 'landerBay'),
      StoryStep(
        id: 't7_meter',
        kind: StepKind.game,
        objective: 'Test the circuit with the multimeter',
        focus: 'landerBay',
        game: GameSpec(
          kind: GameKind.probe,
          title: 'MULTIMETER',
          instructions: 'Probe each part of the valve circuit. Mark EVERY part that is faulty. Healthy fuses and wires read near 0 Ω between their ends, and wires must never connect to the frame.',
          items: ['F1 fuse', 'W2 wire (to frame)', 'J3 connector', 'M1 valve coil', 'K1 relay', 'W1 wire'],
          readings: ['∞ Ω  ·  open', '0.2 Ω  ·  touching the frame!', 'flickers 0 V ↔ 28 V', '∞ Ω  ·  open coil', '28.1 V  ·  OK', '0.1 Ω  ·  OK'],
          faulty: {0, 1, 2, 3},
          probes: 6,
          hint: 'An open fuse reads ∞. A wire reading near 0 Ω to the frame is a short. A connector whose voltage flickers is loose.',
        ),
        mistakeEffect: Effect(health: -2),
      ),
      StoryStep(
        id: 't7_root',
        kind: StepKind.choice,
        objective: 'Find the root cause',
        focus: 'landerBay',
        question: 'Four parts are bad. Which one caused the others to fail?',
        options: [
          StoryOption(id: 'W2', label: 'W2 shorted to the frame', detail: 'Insulation rubbed through in the crash', result: [Line(_c, 'Exactly. The short pulled a huge current: it blew F1 and burned the M1 coil. Fix W2 first, or the new fuse blows too.')]),
          StoryOption(id: 'F1', label: 'F1 fuse blew', mistake: true, retry: true, result: [Line(_c, 'A fuse blowing is a symptom. Fuses blow to protect the circuit. What made it blow?')]),
          StoryOption(id: 'M1', label: 'M1 valve coil failed', mistake: true, retry: true, result: [Line(_c, 'The coil burned because too much current went through it. Where did that current come from?')]),
          StoryOption(id: 'J3', label: 'J3 connector loose', mistake: true, retry: true, result: [Line(_c, 'J3 is loose, and we must fix it, but a loose connector can\'t blow a fuse. Look for a short.')]),
        ],
        effect: Effect(flags: {'diagnosed'}),
      ),
    ],
  ),

  // =========================================================== 8
  StoryTask(
    n: 8,
    title: 'Repair',
    subtitle: 'Fix the lander and test it',
    lesson: 'Repairs follow a procedure: right part, right rating, right orientation, right torque. Then you test, because a repair is not done until it is tested.',
    nasaFact: 'Astronauts practise spacewalk repairs for hours in a giant NASA pool. They use exact copies of the real parts.',
    startX: -24,
    startZ: -14,
    steps: [
      StoryStep(id: 't8_go', kind: StepKind.goTo, objective: 'Go back to the maintenance bay', target: 'lander', useLabel: 'START REPAIR', focus: 'landerBay'),
      StoryStep(
        id: 't8_wire',
        kind: StepKind.game,
        objective: 'A · Repair wire W2',
        focus: 'landerBay',
        game: GameSpec(
          kind: GameKind.order,
          title: 'WIRE REPAIR PROCEDURE',
          instructions: 'Tap the steps of a safe wire repair in order.',
          items: ['Switch off and isolate power', 'Cut out the damaged section', 'Strip 8 mm of insulation', 'Slide on heat-shrink tube', 'Crimp the splice', 'Shrink and test insulation'],
          answer: [0, 1, 2, 3, 4, 5],
          hint: 'Power off first, always. And the heat-shrink tube must go on before you join the wires.',
        ),
        mistakeEffect: Effect(health: -3),
      ),
      StoryStep(
        id: 't8_strip',
        kind: StepKind.game,
        objective: 'Strip the wire to the right length',
        focus: 'landerBay',
        game: GameSpec(
          kind: GameKind.hold,
          title: 'STRIP LENGTH',
          instructions: 'Hold to slide the stripper. Release between 7 and 9 mm. Too short and the crimp won\'t grip; too long and bare wire is exposed.',
          rate: 3.2,
          low: 7,
          high: 9,
          max: 15,
          unit: 'mm',
        ),
        effect: Effect(flags: {'w2Fixed'}),
      ),
      StoryStep(
        id: 't8_fuse',
        kind: StepKind.choice,
        objective: 'B · Replace fuse F1',
        focus: 'landerBay',
        question: 'F1 is rated 10 A. Which replacement do you fit?',
        options: [
          StoryOption(id: 'f10', label: '10 A fuse', detail: 'Same rating', effect: Effect(spares: -1), result: [Line(_n, 'Same rating. The fuse protects the wire, so it must match.')]),
          StoryOption(id: 'f20', label: '20 A fuse', detail: 'Won\'t blow so easily', mistake: true, retry: true, result: [Line(_c, 'A 20 A fuse lets the wire overheat before it blows. That\'s how fires start. Same rating only.')]),
          StoryOption(id: 'bypass', label: 'Bypass it with a wire', mistake: true, retry: true, result: [Line(_c, 'Never bypass a fuse. Without it, the next short could burn the whole lander.')]),
        ],
      ),
      StoryStep(
        id: 't8_valve',
        kind: StepKind.choice,
        objective: 'B · Fit the new valve coil',
        focus: 'landerBay',
        question: 'The new M1 valve has an arrow on its body. How do you fit it?',
        options: [
          StoryOption(id: 'flow', label: 'Arrow pointing toward the engine', detail: 'Same direction as the fuel flow', effect: Effect(spares: -1), result: [Line(_n, 'Arrow follows the flow. Valve in.')]),
          StoryOption(id: 'back', label: 'Arrow pointing toward the tank', mistake: true, retry: true, result: [Line(_c, 'Backwards! Valves seal in one direction only. Fuel would leak straight through. Follow the flow.')]),
        ],
      ),
      StoryStep(
        id: 't8_torque',
        kind: StepKind.game,
        objective: 'B · Tighten the valve bolts',
        focus: 'landerBay',
        game: GameSpec(
          kind: GameKind.hold,
          title: 'TORQUE WRENCH',
          instructions: 'Hold to tighten. Release between 22 and 26 N·m. Too loose leaks; too tight cracks the fitting.',
          rate: 9,
          low: 22,
          high: 26,
          max: 40,
          unit: 'N·m',
        ),
        mistakeEffect: Effect(spares: -1),
        effect: Effect(flags: {'valveFixed'}),
      ),
      StoryStep(
        id: 't8_test',
        kind: StepKind.choice,
        objective: 'C · Propulsion system test',
        focus: 'landerBay',
        intro: [
          Line(_a, 'Running propulsion test. Valve M1... opens. Closes. Opens... signal lost. Test FAILED.'),
          Line(_n, 'What? Everything is new!', Mood.worried),
        ],
        question: 'The valve worked, then the signal dropped. What do you do?',
        options: [
          StoryOption(id: 'j3', label: 'Reseat and lock connector J3', effect: Effect(flags: {'j3'}), result: [Line(_a, 'Re-running test. Valve M1 responds 20 out of 20 times. Test PASSED.'), Line(_n, 'J3! The loose connector we found. Always fix everything you find.', Mood.happy)]),
          StoryOption(id: 'again', label: 'Replace the valve again', mistake: true, retry: true, effect: Effect(spares: -1), result: [Line(_c, 'The valve is fine; it worked until the signal dropped. Signal problems are wiring problems. What else did the multimeter find?')]),
          StoryOption(id: 'ignore', label: 'It mostly works. Call it done.', mistake: true, retry: true, result: [Line(_c, 'Mostly is not good enough for an engine you only get one chance to fire. Find it.')]),
        ],
        outro: [Line(_c, 'Lander propulsion is GO. Nova, you just fixed a spacecraft on the Moon.')],
      ),
    ],
  ),

  // =========================================================== 9
  StoryTask(
    n: 9,
    title: 'Cascade',
    subtitle: 'Stop a chain of failures',
    lesson: 'Systems depend on each other. One broken link can switch off everything downstream. Find the root cause, then restore the most important systems first.',
    nasaFact: 'In 2003 one software bug in Ohio started a chain of failures. 50 million people lost power. Engineers now map dependencies to stop failures from spreading.',
    startX: 6,
    startZ: 8,
    steps: [
      StoryStep(
        id: 't9_alarm',
        kind: StepKind.talk,
        objective: 'Alarm!',
        eva: false,
        intro: [
          Line(_a, 'MASTER ALARM. Life support offline. Heaters offline. Comms degraded. Lander charging stopped.'),
          Line(_n, 'Everything at once?! Sami, help!', Mood.scared),
          Line(_c, 'Nova, breathe. When everything fails at once, it\'s usually ONE thing. Open the system diagram.'),
        ],
      ),
      StoryStep(
        id: 't9_cascade',
        kind: StepKind.game,
        objective: 'Find the root cause and restore power',
        eva: false,
        game: GameSpec(
          kind: GameKind.cascade,
          title: 'SYSTEM DEPENDENCIES',
          instructions: 'Watch the failure spread. Tap the component where it started, then restore the systems in the right order.',
          hint: 'Follow the arrows backwards from the failed systems. The first broken link upstream is the root cause.',
        ),
        mistakeEffect: Effect(o2Kg: -0.3),
      ),
      StoryStep(id: 't9_fix', kind: StepKind.goTo, objective: 'Repair the battery-to-bus cable', target: 'cable', useLabel: 'REPAIR', effect: Effect(flags: {'busFixed'}), outro: [Line(_n, 'A boulder slid and crushed the cable. Spliced and protected. Power is back!', Mood.happy)]),
    ],
  ),

  // =========================================================== 10
  StoryTask(
    n: 10,
    title: 'Launch',
    subtitle: 'Final checks and lift-off',
    lesson: 'Checklists exist because people forget. Every item, every time, especially at the end when you are tired and in a hurry.',
    nasaFact: 'Every NASA launch runs a "go/no-go" poll: each flight controller confirms their system. One "no-go" stops the countdown.',
    startX: -22,
    startZ: -12,
    steps: [
      StoryStep(
        id: 't10_brief',
        kind: StepKind.talk,
        objective: 'Listen to Mission Control',
        eva: false,
        intro: [
          Line(_c, 'Nova, the Gateway is lining up. Launch window opens in 2 hours. Let\'s bring you home.'),
          Line(_n, 'I\'m going to miss this place. A little.', Mood.happy),
        ],
      ),
      StoryStep(id: 't10_go', kind: StepKind.goTo, objective: 'Board the lander', target: 'lander', useLabel: 'BOARD'),
      StoryStep(
        id: 't10_check',
        kind: StepKind.game,
        objective: 'Run the pre-launch checklist',
        eva: false,
        game: GameSpec(
          kind: GameKind.checklist,
          title: 'PRE-LAUNCH CHECKLIST',
          instructions: 'Check every item in order. Fix anything that is not GO. Only then press LAUNCH.',
          items: ['Propellant transferred', 'Cabin pressure', 'Suit oxygen', 'Engine valves', 'Guidance aligned', 'Gateway comms', 'Hatch sealed', 'Seat and harness'],
          readings: ['Tanks 81% · NO-GO', '70 kPa · GO', 'Suit 62% · NO-GO', '20/20 tests · GO', 'Star fix · GO', 'Link 9.6 kbps · GO', 'Seal check · GO', 'Locked · GO'],
          faulty: {0, 2},
          hint: 'Two items are NO-GO. Fix them before launch: an engine with too little propellant cannot reach orbit.',
        ),
        mistakeEffect: Effect(health: -5),
      ),
      StoryStep(
        id: 't10_launch',
        kind: StepKind.talk,
        objective: 'Launch!',
        eva: false,
        intro: [
          Line(_c, 'All stations report GO. Nova, you are GO for launch.'),
          Line(_n, 'Three... two... one... ignition!', Mood.happy),
        ],
      ),
    ],
  ),
];

StoryTask storyTask(int n) => storyTasks.firstWhere((t) => t.n == n);

const finalMessage = 'Mission accomplished! Your engineering decisions helped you survive the Moon and return home safely.';

/// Real facts shown when the player taps things in the 3D world.
const objectFacts = <String, String>{
  'earth': 'Earth is 3.7 times wider than the Moon. From the Moon\'s south pole, Earth never rises or sets. It hangs low in the sky and has phases, like our Moon.',
  'lander': 'Landers carry their own way home. The top part lifts off. The bottom part stays behind as a launch pad, just like Apollo.',
  'habitat': 'Inflatable habitats pack small for launch and expand on site. Their walls are many layers of fabric, including Kevlar-like fibres that stop micrometeoroids.',
  'battery': 'Lithium-ion batteries power the ISS through the 45 minutes of darkness on every orbit. On the Moon, the night can last up to two weeks.',
  'solar': 'At the south pole the Sun stays low and circles the sky. So solar panels stand tall and straight to catch it.',
  'panels': 'At the south pole the Sun stays low and circles the sky. So solar panels stand tall and straight to catch it.',
  'antenna': 'Radio takes about 1.3 seconds to go from the Moon to Earth. So every talk with Mission Control has a short wait.',
  'shelter': 'Packed Moon soil (regolith) is a good radiation shield. Half a metre of it blocks a lot of a solar storm.',
  'crate': 'Every kilogram sent to the Moon costs a lot. So engineers pack tightly and reuse crates.',
  'astronaut': 'A spacesuit is a tiny spaceship. It gives oxygen, removes carbon dioxide, keeps the pressure and keeps the astronaut warm or cool.',
  'rover': 'NASA is building a closed rover with air inside. Astronauts can drive it for days without suits.',
  'greenhouse': 'Plants on the ISS grow in "pillows" of soil under red and blue LEDs. Plants also make oxygen and take in carbon dioxide.',
  'pad': 'Rocket exhaust blasts Moon dust at more than 1 km/s, with no air to slow it down. A hard landing pad stops the sandblasting.',
  'drill': 'NASA\'s VIPER and PRIME-1 missions were made to drill at the south pole. They measure how much ice is hidden there.',
};
