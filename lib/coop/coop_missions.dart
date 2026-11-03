/// The 18 co-op missions: 6 per age level. 2–4 players each, 3 rounds.
/// Each role sees different information, so the team has to talk.
library;

import 'coop_engine.dart';

const _A = CoopRole.astronaut, _C = CoopRole.capcom, _E = CoopRole.engineer, _S = CoopRole.surgeon;
const _two = [_A, _C];
const _three = [_A, _C, _E];
const _four = [_A, _C, _E, _S];

CoopAction _a(String id, String label, [CoopRole owner = _A]) => CoopAction(id, label, owner);

final coopMissions = <CoopMission>[
  // ================================================================ CADET
  CoopMission(
    id: 'coop-01', n: 1, title: 'Suit Up Together', age: 0, template: CoopTemplate.sequence, roles: _two,
    brief: 'CAPCOM has the suit card. The Astronaut puts the suit on. Read it out loud, one step at a time!',
    lesson: 'Good teams say each step out loud and check it together.',
    nasaDoes: 'Astronauts always suit up with a helper who reads the checklist.',
    rounds: [
      CoopRound(
        prompt: 'Put the suit on in the right order.',
        info: {_C: 'SUIT CARD: 1 Cooling underwear · 2 Suit body · 3 Boots · 4 Gloves · 5 Helmet', _A: 'Your suit parts are in front of you. Listen to CAPCOM!'},
        actions: [_a('helmet', 'Helmet'), _a('boots', 'Boots'), _a('under', 'Cooling underwear'), _a('gloves', 'Gloves'), _a('body', 'Suit body')],
        answer: ['under', 'body', 'boots', 'gloves', 'helmet'],
        success: 'Suit on!',
      ),
      CoopRound(
        prompt: 'Buddy check: CAPCOM checks, the Astronaut locks.',
        info: {_C: 'CHECK CARD: lock the helmet, then the gloves, then turn the air ON.', _A: 'Wait for CAPCOM before each lock.'},
        actions: [_a('air', 'Turn air ON'), _a('glock', 'Lock gloves'), _a('hlock', 'Lock helmet'), _a('check', 'All good!', _C)],
        answer: ['hlock', 'glock', 'air', 'check'],
        success: 'Buddy check done!',
      ),
      CoopRound(
        prompt: 'Go out through the airlock.',
        info: {_C: 'AIRLOCK CARD: close inner door, pump the air out, open outer door.', _A: 'The airlock buttons are on the wall.'},
        actions: [_a('outer', 'Open outer door'), _a('inner', 'Close inner door'), _a('pump', 'Pump the air out', _C)],
        answer: ['inner', 'pump', 'outer'],
        success: 'Outside on the Moon!',
      ),
    ],
  ),
  CoopMission(
    id: 'coop-02', n: 2, title: 'Find Pip', age: 0, template: CoopTemplate.identify, roles: _two,
    brief: 'Pip the drone is lost! CAPCOM can see Pip on the camera. The Astronaut must walk to the right place.',
    lesson: 'Describe clearly: left, right, near, far. Then check you understood.',
    nasaDoes: 'Mission Control guides astronauts with maps and camera views from far away.',
    rounds: [
      CoopRound(prompt: 'Where is Pip?', info: {_C: 'CAMERA: Pip is next to the big crater, on the LEFT of the rover.', _A: 'You can walk to four places.'}, actions: [_a('lander', 'By the lander'), _a('crater', 'Big crater, left of the rover'), _a('roof', 'On the base roof'), _a('panels', 'Behind the panels')], answer: ['crater'], success: 'Found Pip!'),
      CoopRound(prompt: 'Pip flew off again!', info: {_C: 'CAMERA: Pip is under the solar panels, in the shade.', _A: 'Four places again. Ask CAPCOM!'}, actions: [_a('panels', 'Under the solar panels'), _a('rover', 'Inside the rover'), _a('flag', 'At the flag'), _a('rocks', 'By the rocks')], answer: ['panels'], success: 'There you are, Pip!'),
      CoopRound(prompt: 'One last time!', info: {_C: 'CAMERA: Pip is on top of the antenna, beeping.', _A: 'Look up high!'}, actions: [_a('antenna', 'On the antenna'), _a('crater', 'In the crater'), _a('door', 'At the door'), _a('lander', 'On the lander')], answer: ['antenna'], success: 'Pip is home!'),
    ],
  ),
  CoopMission(
    id: 'coop-03', n: 3, title: 'Colour Circuit', age: 0, template: CoopTemplate.identify, roles: _two,
    brief: 'Fix the lights. CAPCOM has the wiring card. The Astronaut holds the cables.',
    lesson: 'Match carefully and say each match out loud before you plug it in.',
    nasaDoes: 'Spacecraft cables have colour codes and labels so nobody plugs in the wrong one.',
    rounds: [
      CoopRound(prompt: 'Connect the two right cables.', info: {_C: 'WIRING CARD: RED goes to PLUS (+). BLACK goes to MINUS (−).', _A: 'Your cables: red, black, green.'}, actions: [_a('rp', 'Red → +'), _a('rm', 'Red → −'), _a('bm', 'Black → −'), _a('gp', 'Green → +')], answer: ['rp', 'bm'], ordered: false, success: 'Lights on!'),
      CoopRound(prompt: 'Now the heater.', info: {_C: 'WIRING CARD: YELLOW to the heater. BLUE to the fan.', _A: 'Your cables: yellow, blue, white.'}, actions: [_a('yh', 'Yellow → heater'), _a('bf', 'Blue → fan'), _a('wh', 'White → heater'), _a('yf', 'Yellow → fan')], answer: ['yh', 'bf'], ordered: false, success: 'Warm and breezy!'),
      CoopRound(prompt: 'Last: the radio.', info: {_C: 'WIRING CARD: ORANGE to the radio, then press TEST.', _A: 'Plug in, then wait for CAPCOM to test.'}, actions: [_a('or', 'Orange → radio'), _a('pr', 'Purple → radio'), _a('test', 'Press TEST', _C)], answer: ['or', 'test'], success: 'Radio works!'),
    ],
  ),
  CoopMission(
    id: 'coop-04', n: 4, title: 'Garden Rescue', age: 0, template: CoopTemplate.identify, roles: _two,
    brief: 'The plants look sad. CAPCOM reads the plant sensors. The Astronaut cares for the plants.',
    lesson: 'Look at the facts first, then fix the real problem.',
    nasaDoes: 'Astronauts on the space station look after plants with help from scientists on Earth.',
    rounds: [
      CoopRound(prompt: 'What do the plants need?', info: {_C: 'SENSORS: soil DRY · light ON · air OK', _A: 'You can water, turn on lights, or open the vent.'}, actions: [_a('water', 'Water them'), _a('light', 'Turn on lights'), _a('vent', 'Open the vent')], answer: ['water'], success: 'Drink up, plants!'),
      CoopRound(prompt: 'Now the leaves are pale.', info: {_C: 'SENSORS: soil WET · light OFF · air OK', _A: 'Same three choices.'}, actions: [_a('water', 'Water them'), _a('light', 'Turn on lights'), _a('vent', 'Open the vent')], answer: ['light'], success: 'Green again!'),
      CoopRound(prompt: 'The air feels heavy and wet.', info: {_C: 'SENSORS: soil WET · light ON · air VERY WET', _A: 'Same three choices.'}, actions: [_a('water', 'Water them'), _a('light', 'Turn on lights'), _a('vent', 'Open the vent')], answer: ['vent'], success: 'Happy garden!'),
    ],
  ),
  CoopMission(
    id: 'coop-05', n: 5, title: 'Rocket Countdown', age: 0, template: CoopTemplate.sequence, roles: _two,
    brief: 'Launch the cargo rocket together. CAPCOM calls the countdown, the Astronaut does each step.',
    lesson: 'Wait for your turn and follow the steps in order.',
    nasaDoes: 'At every launch, the launch director calls each step and waits for "GO".',
    rounds: [
      CoopRound(prompt: 'Get the rocket ready.', info: {_C: 'COUNTDOWN CARD: close the hatch, check the fuel, then say GO.', _A: 'Do each step when CAPCOM says it.'}, actions: [_a('fuel', 'Check the fuel'), _a('hatch', 'Close the hatch'), _a('go', 'Say GO!', _C)], answer: ['hatch', 'fuel', 'go'], success: 'Rocket ready!'),
      CoopRound(prompt: 'Engines!', info: {_C: 'COUNTDOWN CARD: pumps ON, then engines ON.', _A: 'Two big switches.'}, actions: [_a('engines', 'Engines ON'), _a('pumps', 'Pumps ON')], answer: ['pumps', 'engines'], success: 'Engines roaring!'),
      CoopRound(prompt: '3, 2, 1...', info: {_C: 'Press LIFT OFF after the Astronaut lets go of the clamps.', _A: 'Let go of the clamps!'}, actions: [_a('clamps', 'Let go of the clamps'), _a('lift', 'LIFT OFF!', _C)], answer: ['clamps', 'lift'], success: 'Lift off!'),
    ],
  ),
  CoopMission(
    id: 'coop-06', n: 6, title: 'Rock Collectors', age: 0, template: CoopTemplate.identify, roles: _two,
    brief: 'Scientists on Earth want special rocks. CAPCOM knows which. The Astronaut picks them up.',
    lesson: 'Ask questions until you are sure. Scientists love details!',
    nasaDoes: 'Scientists on Earth tell astronauts which rocks to bring home.',
    rounds: [
      CoopRound(prompt: 'Pick the 2 rocks the scientists want.', info: {_C: 'SCIENCE LIST: the DARK rock and the rock with HOLES.', _A: 'Four rocks: dark, shiny white, with holes, round grey.'}, actions: [_a('dark', 'Dark rock'), _a('white', 'Shiny white rock'), _a('holes', 'Rock with holes'), _a('round', 'Round grey rock')], answer: ['dark', 'holes'], ordered: false, success: 'Great samples!'),
      CoopRound(prompt: 'Now the bright ones.', info: {_C: 'SCIENCE LIST: the SPARKLY rock and the WHITE rock.', _A: 'Four rocks: sparkly, black, white, sandy.'}, actions: [_a('sparkly', 'Sparkly rock'), _a('black', 'Black rock'), _a('white', 'White rock'), _a('sandy', 'Sandy rock')], answer: ['sparkly', 'white'], ordered: false, success: 'Bright and beautiful!'),
      CoopRound(prompt: 'Bag them in order.', info: {_C: 'Bag ORDER: label first, then bag, then seal.', _A: 'Three steps.'}, actions: [_a('seal', 'Seal the bag'), _a('label', 'Write the label'), _a('bag', 'Put rock in bag')], answer: ['label', 'bag', 'seal'], success: 'Ready for Earth!'),
    ],
  ),
  // ================================================================ EXPLORER
  CoopMission(
    id: 'coop-07', n: 7, title: 'Lander Doctor', age: 1, template: CoopTemplate.identify, roles: _three,
    brief: 'The lander will not start. The Flight Engineer reads the meters, CAPCOM has the repair manual, the Astronaut fixes it.',
    lesson: 'Measure, look it up, then act: never guess with a spacecraft.',
    nasaDoes: 'Apollo 13 was saved by engineers on the ground reading data and writing new procedures.',
    rounds: [
      CoopRound(prompt: 'Which part is faulty?', info: {_E: 'METERS: Bus A 28 V · Bus B 0 V · Fuse 3 OPEN · Pump 28 V', _C: 'MANUAL: an OPEN fuse means replace the fuse. 0 V after it is normal.', _A: 'You can replace: fuse 3, bus B, pump, battery.'}, actions: [_a('fuse', 'Replace fuse 3'), _a('bus', 'Replace bus B'), _a('pump', 'Replace pump'), _a('batt', 'Replace battery')], answer: ['fuse'], success: 'Fuse replaced, bus B back to 28 V.'),
      CoopRound(prompt: 'Engine valve test.', info: {_E: 'VALVES: V1 opens 100% · V2 opens 40% · V3 opens 100%', _C: 'MANUAL: a valve under 90% must be cleaned, then tested.', _A: 'Clean or test a valve.'}, actions: [_a('c2', 'Clean V2'), _a('c1', 'Clean V1'), _a('t2', 'Test V2', _E)], answer: ['c2', 't2'], success: 'V2 at 100%.'),
      CoopRound(prompt: 'Start-up sequence.', info: {_C: 'START CARD: guidance ON, then pumps ON, then ignition armed.', _E: 'Engineer arms ignition when pumps read 28 V.', _A: 'Guidance and pumps switches.'}, actions: [_a('pumps', 'Pumps ON'), _a('guid', 'Guidance ON'), _a('arm', 'Arm ignition', _E)], answer: ['guid', 'pumps', 'arm'], success: 'The lander is healthy!'),
    ],
  ),
  CoopMission(
    id: 'coop-08', n: 8, title: 'Airlock Leak', age: 1, template: CoopTemplate.sequence, roles: _three,
    brief: 'Pressure is dropping in the airlock. Find the leak and fix it safely, in the right order.',
    lesson: 'In an emergency, make the people safe first, then fix the problem.',
    nasaDoes: 'ISS crews isolate a leaking module by closing hatches, then hunt for the leak.',
    rounds: [
      CoopRound(prompt: 'Make the crew safe first.', seconds: 60, info: {_C: 'LEAK PROCEDURE: 1 crew into the habitat · 2 close the inner hatch · 3 report.', _E: 'Airlock pressure: 96 kPa and falling 1 kPa/min.', _A: 'You are in the airlock.'}, actions: [_a('report', 'Report to Houston', _C), _a('hatch', 'Close inner hatch'), _a('enter', 'Move into the habitat')], answer: ['enter', 'hatch', 'report'], success: 'Crew safe, airlock isolated.'),
      CoopRound(prompt: 'Find the leaking seal.', info: {_E: 'SEAL SENSORS: door −0.1 · window −0.2 · valve −3.1 · hull −0.1 kPa/min', _C: 'Patch the seal that leaks the most.', _A: 'Patch kit ready.'}, actions: [_a('door', 'Patch door seal'), _a('window', 'Patch window'), _a('valve', 'Patch the valve'), _a('hull', 'Patch hull seam')], answer: ['valve'], success: 'Leak found at the valve.'),
      CoopRound(prompt: 'Back to normal.', info: {_C: 'RE-PRESS: patch cures 5 min · re-pressurise · Engineer confirms.', _A: 'Wait, then re-pressurise.', _E: 'Confirm when pressure holds.'}, actions: [_a('wait', 'Wait 5 minutes'), _a('press', 'Re-pressurise'), _a('ok', 'Pressure holding', _E)], answer: ['wait', 'press', 'ok'], success: 'Airlock holding at 101 kPa.'),
    ],
  ),
  CoopMission(
    id: 'coop-09', n: 9, title: 'Power Down', age: 1, template: CoopTemplate.consoles, roles: _three,
    brief: 'A panel failed: only 3 kW for the night. Switch off loads in the right order until you are under budget.',
    lesson: 'Share fairly by priority: life support last, science first to go.',
    nasaDoes: 'ISS flight controllers follow a load-shed table when power runs short.',
    rounds: [
      CoopRound(prompt: 'Get from 6 kW to 3 kW.', info: {_E: 'LOADS: Science 1.5 · Rover charger 1.2 · Greenhouse 0.6 · Heaters 1.4 · Life support 1.3 kW', _C: 'RULE: switch off the least important first. Never life support.', _A: 'Switches for every load.'}, actions: [_a('sci', 'Science OFF'), _a('rov', 'Rover charger OFF'), _a('life', 'Life support OFF'), _a('heat', 'Heaters OFF')], answer: ['sci', 'rov'], success: '3.3 kW... close!'),
      CoopRound(prompt: 'Still 0.3 kW too much.', info: {_E: 'NOW: Greenhouse 0.6 · Heaters 1.4 · Life support 1.3 kW', _C: 'RULE: plants survive a night on low light. People need heat.', _A: 'Choose one.'}, actions: [_a('gh', 'Greenhouse to low'), _a('heat', 'Heaters OFF'), _a('life', 'Life support to low')], answer: ['gh'], success: '2.7 kW. Under budget!'),
      CoopRound(prompt: 'Morning: bring things back.', info: {_C: 'RESTORE in reverse: greenhouse, rover charger, science.', _E: 'Sun is up: 6 kW available.', _A: 'Switch them back on.'}, actions: [_a('sci', 'Science ON'), _a('gh', 'Greenhouse ON'), _a('rov', 'Rover charger ON')], answer: ['gh', 'rov', 'sci'], success: 'Base back to full power.'),
    ],
  ),
  CoopMission(
    id: 'coop-10', n: 10, title: 'Storm Shelter', age: 1, template: CoopTemplate.sequence, roles: _three,
    brief: 'NASA\'s space weather office warns of a solar storm. You have minutes to get everyone shielded.',
    lesson: 'Courage is acting calmly and quickly, in order.',
    nasaDoes: 'NASA\'s DONKI tracks solar storms; Orion has a storm shelter made from cargo bags.',
    rounds: [
      CoopRound(prompt: 'Alert!', seconds: 45, info: {_C: 'DONKI ALERT: protons arrive in 20 minutes. Crew outside: 1.', _E: 'Shelter: walls 60% shielded.', _A: 'You are 300 m away.'}, actions: [_a('walk', 'Head back now'), _a('photo', 'Take one more photo'), _a('call', 'Call everyone inside', _C)], answer: ['call', 'walk'], success: 'Everyone heading in.'),
      CoopRound(prompt: 'Thicken the shelter.', info: {_E: 'Shield needs: water bags on the roof side, food bags on the wall side.', _C: 'Water first: it stops more radiation per bag.', _A: 'Move the bags.'}, actions: [_a('food', 'Food bags to wall'), _a('water', 'Water bags to roof'), _a('check', 'Check shield 100%', _E)], answer: ['water', 'food', 'check'], success: 'Shelter at 100%.'),
      CoopRound(prompt: 'Ride it out.', info: {_E: 'Dose rate falling. Storm over in 2 h.', _C: 'Stay inside until DONKI says ALL CLEAR.', _A: 'Wait inside.'}, actions: [_a('out', 'Go out now'), _a('wait', 'Stay in the shelter'), _a('clear', 'ALL CLEAR', _C)], answer: ['wait', 'clear'], success: 'Storm survived. Dose: 2 mSv.'),
    ],
  ),
  CoopMission(
    id: 'coop-11', n: 11, title: 'Rover Convoy', age: 1, template: CoopTemplate.consoles, roles: _three,
    brief: 'Two rovers drive to the ice crater. The Engineer watches batteries, CAPCOM the map, the Astronaut drives.',
    lesson: 'Plan the way back before you go further.',
    nasaDoes: 'Apollo crews never drove farther than they could walk back.',
    rounds: [
      CoopRound(prompt: 'Choose the route.', info: {_C: 'MAP: Route A 8 km smooth · Route B 5 km but 25° slope · Route C 12 km', _E: 'Battery for 18 km in total (there and back).', _A: 'Pick a route.'}, actions: [_a('a', 'Route A (8 km)'), _a('b', 'Route B (steep)'), _a('c', 'Route C (12 km)')], answer: ['a'], success: '16 km round trip. Safe.'),
      CoopRound(prompt: 'Rover 2 is draining fast.', info: {_E: 'Rover 1: 70% · Rover 2: 35% · a wheel motor runs hot', _C: 'RULE: if one rover drops below 40%, both turn back together.', _A: 'What now?'}, actions: [_a('back', 'Both turn back'), _a('split', 'Rover 2 goes home alone'), _a('on', 'Keep going')], answer: ['back'], success: 'Convoy heading home together.'),
      CoopRound(prompt: 'Tow home.', info: {_C: 'TOW CARD: stop · connect tow bar · Engineer limits speed to 5 km/h.', _A: 'You do the tow bar.', _E: 'Speed limiter.'}, actions: [_a('stop', 'Stop both rovers'), _a('tow', 'Connect tow bar'), _a('lim', 'Limit to 5 km/h', _E)], answer: ['stop', 'tow', 'lim'], success: 'Home safe. The crater can wait.'),
    ],
  ),
  CoopMission(
    id: 'coop-12', n: 12, title: 'Greenhouse Shift', age: 1, template: CoopTemplate.consoles, roles: _three,
    brief: 'Take a shift in the greenhouse. Read the sensors, follow the guide, adjust the system.',
    lesson: 'Change one thing at a time, then check what happened.',
    nasaDoes: 'ISS plant experiments like Veggie and APH are watched by scientists on Earth.',
    rounds: [
      CoopRound(prompt: 'Morning check.', info: {_E: 'CO₂ 1 900 ppm · light 220 · humidity 60%', _C: 'GUIDE: CO₂ healthy 400–1 500 ppm. Above: run the scrubber.', _A: 'Controls: scrubber, lights, misters.'}, actions: [_a('scrub', 'Run CO₂ scrubber'), _a('light', 'More light'), _a('mist', 'Misters ON')], answer: ['scrub'], success: 'CO₂ back to 900 ppm.'),
      CoopRound(prompt: 'Noon check.', info: {_E: 'CO₂ 900 · light 80 (low) · humidity 58%', _C: 'GUIDE: lettuce wants light 200+.', _A: 'Same controls.'}, actions: [_a('scrub', 'Run CO₂ scrubber'), _a('light', 'More light'), _a('mist', 'Misters ON')], answer: ['light'], success: 'Light at 210.'),
      CoopRound(prompt: 'Harvest.', info: {_C: 'HARVEST CARD: clean gloves · cut outer leaves only · bag and label.', _A: 'Do the harvest.', _E: 'Log the mass.'}, actions: [_a('cut', 'Cut outer leaves'), _a('gloves', 'Clean gloves'), _a('bag', 'Bag and label'), _a('log', 'Log 140 g', _E)], answer: ['gloves', 'cut', 'bag', 'log'], success: 'Fresh salad for the crew!'),
    ],
  ),
  // ================================================================ ENGINEER
  CoopMission(
    id: 'coop-13', n: 13, title: 'Go/No-Go Poll', age: 2, template: CoopTemplate.consoles, roles: _four,
    brief: 'CAPCOM polls every station before ascent. Each of you owns a console. Answer GO or NO-GO from your own data only.',
    lesson: 'Every voice counts. One honest NO-GO saves a mission.',
    nasaDoes: 'The launch director polls each station; any one can stop the count.',
    rounds: [
      CoopRound(prompt: 'Poll 1. CAPCOM: call each station in order.', info: {_C: 'POLL ORDER: Propulsion (Engineer) · Crew (Astronaut) · Medical (Surgeon). Then say "GO for ascent".', _E: 'Propulsion: tanks 100%, valves good.', _A: 'Crew: strapped in, hatch locked.', _S: 'Medical: heart rates normal, suits 100%.'}, actions: [_a('ego', 'Propulsion GO', _E), _a('eno', 'Propulsion NO-GO', _E), _a('ago', 'Crew GO'), _a('sgo', 'Medical GO', _S), _a('sno', 'Medical NO-GO', _S), _a('cgo', 'GO for ascent', _C)], answer: ['ego', 'ago', 'sgo', 'cgo'], success: 'All GO. Ascent in 10 minutes.'),
      CoopRound(prompt: 'Poll 2, five minutes later.', info: {_C: 'Same order. If anyone says NO-GO, call HOLD.', _E: 'Propulsion: helium pressure 82% and dropping.', _A: 'Crew: ready.', _S: 'Medical: normal.'}, actions: [_a('ego', 'Propulsion GO', _E), _a('eno', 'Propulsion NO-GO', _E), _a('ago', 'Crew GO'), _a('sgo', 'Medical GO', _S), _a('hold', 'HOLD the count', _C), _a('cgo', 'GO for ascent', _C)], answer: ['eno', 'hold'], success: 'Count held. Good call.'),
      CoopRound(prompt: 'Fix and re-poll.', info: {_E: 'Fix: switch to backup helium tank, then report GO.', _C: 'Re-poll in order once the Engineer reports.', _A: 'Crew still ready.', _S: 'Medical normal.'}, actions: [_a('fix', 'Switch to backup helium', _E), _a('ego', 'Propulsion GO', _E), _a('ago', 'Crew GO'), _a('sgo', 'Medical GO', _S), _a('cgo', 'GO for ascent', _C)], answer: ['fix', 'ego', 'ago', 'sgo', 'cgo'], success: 'Lift-off! Phase error 0.6°.'),
    ],
  ),
  CoopMission(
    id: 'coop-14', n: 14, title: 'Rover Rescue', age: 2, template: CoopTemplate.identify, roles: _four,
    brief: 'A rover is stuck 6 km out with two crew. Oxygen is limited. Plan and run the rescue.',
    lesson: 'Use everyone\'s numbers before deciding: time, oxygen, energy.',
    nasaDoes: 'NASA plans every moonwalk with consumables margins and rescue options.',
    rounds: [
      CoopRound(prompt: 'How long do they have?', info: {_S: 'Suits: 4 h 10 min of O₂ left (plus 30 min reserve).', _E: 'Rescue rover: 6 km at 8 km/h, 15 min to prepare.', _C: 'Decide: drive now, wait for daylight (6 h), or let them walk (2 h).', _A: 'Stuck crew can walk at 3 km/h.'}, actions: [_a('drive', 'Send the rescue rover now', _C), _a('wait', 'Wait for daylight', _C), _a('walk', 'Tell them to walk back', _C)], answer: ['drive'], success: 'Rescue rover out in 15 minutes.'),
      CoopRound(prompt: 'Prepare the rover.', info: {_E: 'Rescue checklist: battery swap · tow cable · spare O₂ bottles.', _S: 'Bring 2 spare O₂ bottles, one per crew.', _A: 'You load the rover.', _C: 'Confirm when all loaded.'}, actions: [_a('batt', 'Swap in a full battery'), _a('tow', 'Load tow cable'), _a('o2', 'Load 2 O₂ bottles'), _a('conf', 'Confirm loaded', _C)], answer: ['batt', 'tow', 'o2', 'conf'], ordered: false, success: 'Rover ready.'),
      CoopRound(prompt: 'At the stuck rover.', info: {_S: 'Crew member 2: O₂ 18%, breathing fast.', _E: 'Stuck rover: wheel in loose dust.', _C: 'People first, then the rover.', _A: 'What first?'}, actions: [_a('o2', 'Give crew 2 the O₂ bottle'), _a('dig', 'Dig the wheel out'), _a('tow', 'Tow the rover'), _a('ok', 'Crew stable', _S)], answer: ['o2', 'ok', 'dig', 'tow'], success: 'Everyone home safe.'),
    ],
  ),
  CoopMission(
    id: 'coop-15', n: 15, title: 'Cascade Control', age: 2, template: CoopTemplate.sequence, roles: _four,
    brief: 'A short circuit knocked out the main bus. Systems are failing in a chain. Restore them in dependency order.',
    lesson: 'Help the most vulnerable first, and fix what everything else depends on.',
    nasaDoes: 'Engineers map system dependencies so they know what to restore first.',
    rounds: [
      CoopRound(prompt: 'What depends on what?', seconds: 90, info: {_E: 'DEPENDENCIES: everything needs the power bus · pumps need the bus · heaters need pumps (coolant) · CO₂ scrubber needs the bus.', _C: 'Restore in dependency order.', _S: 'Crew CO₂ rising: 0.6% and climbing.', _A: 'You have the breakers.'}, actions: [_a('bus', 'Reset main bus'), _a('pumps', 'Restart pumps'), _a('scrub', 'Restart CO₂ scrubber'), _a('heat', 'Heaters ON')], answer: ['bus', 'scrub', 'pumps', 'heat'], success: 'Systems back in order.'),
      CoopRound(prompt: 'Find the short.', info: {_E: 'Current: branch A 4 A · B 4 A · C 31 A (rated 10 A) · D 3 A', _C: 'Isolate the faulty branch before the bus trips again.', _A: 'Branch switches.', _S: 'Crew fine.'}, actions: [_a('a', 'Isolate A'), _a('b', 'Isolate B'), _a('c', 'Isolate C'), _a('d', 'Isolate D')], answer: ['c'], success: 'Branch C isolated.'),
      CoopRound(prompt: 'Report.', info: {_C: 'REPORT: what happened, what we did, what is still off.', _E: 'Branch C feeds the lab only.', _S: 'CO₂ back to 0.3%.', _A: 'Confirm the lab is unpowered.'}, actions: [_a('lab', 'Lab confirmed off'), _a('rep', 'Send report to Houston', _C)], answer: ['lab', 'rep'], success: 'Houston copies. Nice work.'),
    ],
  ),
  CoopMission(
    id: 'coop-16', n: 16, title: 'Gateway Docking', age: 2, template: CoopTemplate.consoles, roles: _four,
    brief: 'Dock with the Gateway. The Engineer reads range and rate, CAPCOM gives clearance, the Astronaut flies.',
    lesson: 'Slow is smooth and smooth is fast. Small corrections, checked often.',
    nasaDoes: 'Orion and Gateway dock automatically, with crews ready to take over by hand.',
    rounds: [
      CoopRound(prompt: 'Approach: 200 m.', info: {_E: 'Range 200 m · closing 1.4 m/s (limit 0.5 m/s at this range)', _C: 'Clearance only when closing rate is under the limit.', _A: 'Thrusters: brake, forward, hold.', _S: 'Crew heart rates up a little.'}, actions: [_a('brake', 'Brake burn'), _a('fwd', 'Forward burn'), _a('clear', 'Cleared to 30 m', _C)], answer: ['brake', 'clear'], success: 'Closing 0.4 m/s. Cleared to 30 m.'),
      CoopRound(prompt: 'Line up: 30 m.', info: {_E: 'Offset: 0.8 m LEFT, 0.0 m up/down.', _C: 'Fix the offset before the 10 m hold point.', _A: 'Translate left, right, up, down.', _S: 'Crew fine.'}, actions: [_a('l', 'Translate left'), _a('r', 'Translate right'), _a('u', 'Translate up')], answer: ['r'], success: 'Centred on the port.'),
      CoopRound(prompt: 'Contact.', info: {_C: 'FINAL: hold at 10 m · cleared to dock · capture · hard dock.', _E: 'Report capture when the latches close.', _A: 'Final approach.', _S: 'Report crew status after hard dock.'}, actions: [_a('hold', 'Hold at 10 m'), _a('go', 'Cleared to dock', _C), _a('cap', 'Capture confirmed', _E), _a('crew', 'Crew fine', _S)], answer: ['hold', 'go', 'cap', 'crew'], success: 'Hard dock. Welcome to Gateway.'),
    ],
  ),
  CoopMission(
    id: 'coop-17', n: 17, title: 'Moonquake Response', age: 2, template: CoopTemplate.sequence, roles: _four,
    brief: 'A magnitude 4.6 moonquake just stopped. Run the response: people, air, power, structure.',
    lesson: 'Follow the plan in order. Calm teams are fast teams.',
    nasaDoes: 'Apollo seismometers found shallow moonquakes up to magnitude 5.5.',
    rounds: [
      CoopRound(prompt: 'Right after the quake.', seconds: 60, info: {_S: 'Crew: one with a cut hand, all conscious.', _E: 'Pressure 101 kPa stable · power OK.', _C: 'ORDER: crew check, then pressure, then power.', _A: 'You have the first-aid kit.'}, actions: [_a('crew', 'Crew check', _S), _a('aid', 'Bandage the cut'), _a('press', 'Pressure check', _E), _a('pwr', 'Power check', _E)], answer: ['crew', 'aid', 'press', 'pwr'], success: 'Crew OK, air OK, power OK.'),
      CoopRound(prompt: 'Structure.', info: {_E: 'Strain: joint A–B 91% (limit 80%) · others under 40%', _C: 'Clamp anything above 80%, then re-check.', _A: 'Clamps ready.', _S: 'Crew fine.'}, actions: [_a('ab', 'Clamp joint A–B'), _a('bc', 'Clamp joint B–C'), _a('re', 'Re-check strain', _E)], answer: ['ab', 're'], success: 'Joint A–B at 44%.'),
      CoopRound(prompt: 'Aftershock plan.', info: {_C: 'Brief the crew: where to hold on, who checks what.', _S: 'Assign medical checks.', _E: 'Assign system checks.', _A: 'Secure loose items.'}, actions: [_a('secure', 'Secure loose items'), _a('med', 'Medical checks assigned', _S), _a('sys', 'System checks assigned', _E), _a('brief', 'Crew briefed', _C)], answer: ['secure', 'med', 'sys', 'brief'], ordered: false, success: 'Ready for aftershocks.'),
    ],
  ),
  CoopMission(
    id: 'coop-18', n: 18, title: 'Medical Evacuation', age: 2, template: CoopTemplate.consoles, roles: _four,
    brief: 'A crew member is sick. The Flight Surgeon reads vitals, everyone else gets them home safely.',
    lesson: 'Trust the expert for their part, and keep the whole team informed.',
    nasaDoes: 'ISS crews have a medical officer, with flight surgeons on call 24/7.',
    rounds: [
      CoopRound(prompt: 'Treat or evacuate?', info: {_S: 'Vitals: temperature 39.5 °C, heart 120, O₂ saturation 91% and falling.', _C: 'RULE: saturation under 92% and falling means evacuate.', _E: 'Ascent vehicle ready in 6 hours.', _A: 'Patient is with you.'}, actions: [_a('evac', 'Evacuate', _S), _a('treat', 'Treat on base', _S)], answer: ['evac'], success: 'Evacuation decided.'),
      CoopRound(prompt: 'Stabilise.', info: {_S: 'Give oxygen first, then fever medicine.', _C: 'Report each step to Houston.', _A: 'Med kit open.', _E: 'Prep the ascent vehicle.'}, actions: [_a('o2', 'Give oxygen'), _a('med', 'Give fever medicine'), _a('prep', 'Prep ascent vehicle', _E), _a('rep', 'Report to Houston', _C)], answer: ['o2', 'med', 'prep', 'rep'], success: 'Saturation back to 96%.'),
      CoopRound(prompt: 'Launch.', info: {_C: 'Poll: Medical, Propulsion, Crew. Then launch.', _S: 'Patient stable for flight.', _E: 'Propulsion ready.', _A: 'Patient strapped in.'}, actions: [_a('s', 'Medical GO', _S), _a('e', 'Propulsion GO', _E), _a('a', 'Crew GO'), _a('go', 'Launch!', _C)], answer: ['s', 'e', 'a', 'go'], success: 'On the way to Gateway. Patient stable.'),
    ],
  ),
];

CoopMission? coopMission(String id) => coopMissions.where((m) => m.id == id).firstOrNull;
