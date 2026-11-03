/// The Readiness Check: 8 questions taken before a campaign and again after it.
/// The difference is the learning gain the teacher sees. Same questions both
/// times (answer order shuffled), one or two per skill.
library;

import 'catalogue.dart';

class ReadinessQ {
  final String id;
  final Skill skill;
  final String text;
  final List<String> options;
  final int answer;
  final String why;
  const ReadinessQ(this.id, this.skill, this.text, this.options, this.answer, this.why);
}

const _p = Skill.prioritise, _s = Skill.systems, _r = Skill.rootCause, _m = Skill.resourceMath, _o = Skill.procedure, _t = Skill.teamwork;

const readinessQuestions = <CampaignId, List<ReadinessQ>>{
  CampaignId.cadet: [
    ReadinessQ('c-q1', _p, 'Your suit says "Air low" and your tummy is hungry. What do you fix first?', ['Air', 'Food', 'Both at the same time'], 0, 'You can be hungry for hours, but you need air every minute.'),
    ReadinessQ('c-q2', _o, 'What do astronauts do before going outside?', ['Run out fast', 'Check every part of the suit with a friend', 'Take off their helmet'], 1, 'A buddy check catches mistakes before they become dangerous.'),
    ReadinessQ('c-q3', _s, 'Solar panels make the most power when they...', ['Face the Sun', 'Face the ground', 'Are covered in dust'], 0, 'Panels turn sunlight into electricity, so they must see the Sun.'),
    ReadinessQ('c-q4', _m, 'A rocket can carry 10 boxes. You have 12. How many must stay behind?', ['1', '2', '12'], 1, '12 − 10 = 2.'),
    ReadinessQ('c-q5', _s, 'Why do you jump higher on the Moon?', ['The Moon pulls less (weaker gravity)', 'Moon shoes are bouncy', 'There is more air'], 0, 'Moon gravity is about 6 times weaker than on Earth.'),
    ReadinessQ('c-q6', _r, 'A plant has wet soil but pale yellow leaves. What should you check?', ['More water', 'The lights', 'Nothing'], 1, 'The soil is already wet, so the problem is something else plants need: light.'),
    ReadinessQ('c-q7', _o, 'Which step comes first when cleaning water?', ['Drink it', 'Filter out the bits', 'Test it'], 1, 'Filter, clean, test, and only then drink.'),
    ReadinessQ('c-q8', _t, 'You talk to Earth on the radio but no one answers yet. What do you do?', ['Wait a little', 'Shout louder', 'Give up'], 0, 'Radio takes more than a second to travel between the Moon and Earth.'),
  ],
  CampaignId.explorer: [
    ReadinessQ('e-q1', _p, 'Four warnings: suit O₂ 55%, cabin pressure falling, battery low, radio down. Which first?', ['Radio', 'Battery', 'Suit oxygen', 'Cabin pressure'], 2, 'Without oxygen you have minutes; the others give you hours or days.'),
    ReadinessQ('e-q2', _m, 'One astronaut breathes 0.84 kg of O₂ a day. How much do 3 astronauts need for 10 days?', ['8.4 kg', '25.2 kg', '2.5 kg', '84 kg'], 1, '0.84 × 3 × 10 = 25.2 kg.'),
    ReadinessQ('e-q3', _s, 'The battery feeds the heater, and the heater stops the water pipes from freezing. If the battery fails, what happens?', ['Only the heater stops', 'The heater stops, then the water can freeze', 'Nothing happens'], 1, 'Systems depend on each other: one failure can cascade.'),
    ReadinessQ('e-q4', _r, 'A circuit reads 28 V before a fuse and 0 V after it. Where is the problem?', ['The battery', 'The fuse', 'The light bulb'], 1, 'The voltage disappears at the fuse, so the fuse opened.'),
    ReadinessQ('e-q5', _o, 'Before launch one checklist item says NO-GO. What do you do?', ['Launch anyway', 'Skip that item', 'Stop, fix it, then continue the checklist'], 2, 'Checklists only work if every item is GO.'),
    ReadinessQ('e-q6', _m, 'A panel 60° away from the Sun makes cos(60°) of its full power. That is...', ['100%', '87%', '50%', '0%'], 2, 'cos(60°) = 0.5, so half the power.'),
    ReadinessQ('e-q7', _p, 'There is only enough power for one: life support, lights or science. Which gets it?', ['Science', 'Lights', 'Life support'], 2, 'Keeping people alive always comes first.'),
    ReadinessQ('e-q8', _t, 'Two crewmates disagree about a repair. What makes the best decision?', ['The loudest wins', 'Hear both, check the data, decide and explain', 'Flip a coin'], 1, 'Good teams listen, use evidence and explain the choice.'),
  ],
  CampaignId.engineer: [
    ReadinessQ('g-q1', _m, 'A 4 kW base must survive 100 hours of darkness with a 20% margin. Battery size?', ['400 kWh', '480 kWh', '120 kWh', '4 800 kWh'], 1, '4 kW × 100 h = 400 kWh; +20% = 480 kWh.'),
    ReadinessQ('g-q2', _s, 'Three O₂ sensors read 21.2, 21.1 and 18.4 kPa. Which control logic is safest?', ['Average all three', 'Use the median', 'Use the lowest'], 1, 'The median ignores a single faulty sensor.'),
    ReadinessQ('g-q3', _r, 'A heater breaker keeps tripping. What is the root-cause fix?', ['Reset the breaker', 'Fit a bigger breaker', 'Find why it draws too much current and fix that'], 2, 'Ask "why" until you reach something you can change; bigger breakers create fire risk.'),
    ReadinessQ('g-q4', _m, 'Electrolysis turns water into oxygen at 8/9 of its mass. 9 kg of water gives...', ['1 kg O₂', '8 kg O₂', '9 kg O₂', '4.5 kg O₂'], 1, '9 × 8/9 = 8 kg of oxygen (and 1 kg of hydrogen).'),
    ReadinessQ('g-q5', _p, 'A solar storm will arrive in 30 minutes. Two crew are on a moonwalk 2 km away. Decision?', ['Finish the task', 'Recall them now to the shelter', 'Wait for more data'], 1, 'Protect people first: the samples can wait, the dose cannot be undone.'),
    ReadinessQ('g-q6', _o, 'At T−4 minutes a sensor reading drifts with 12 minutes of window left. Best action?', ['Launch', 'Hold and investigate', 'Scrub for a week'], 1, 'A short hold costs nothing; launching on an unexplained reading is how accidents start.'),
    ReadinessQ('g-q7', _s, 'Data rate on a radio link grows with dish diameter squared. Doubling the dish gives...', ['2× the rate', '4× the rate', 'No change'], 1, '(2D)² = 4D².'),
    ReadinessQ('g-q8', _t, 'Mars is 12 light-minutes away. Which is true for a Mars crew?', ['Earth can control every decision', 'The crew must decide urgent things alone', 'Delay does not matter'], 1, 'A 24-minute round trip means emergencies are the crew\'s call.'),
  ],
};

/// Score of a set of answers (index chosen per question, -1 = skipped).
int readinessScore(List<ReadinessQ> qs, List<int> answers) {
  var s = 0;
  for (var i = 0; i < qs.length && i < answers.length; i++) {
    if (answers[i] == qs[i].answer) s++;
  }
  return s;
}
