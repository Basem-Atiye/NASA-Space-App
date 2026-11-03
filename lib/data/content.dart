/// Learning content: debrief facts, "What would NASA do?", quizzes,
/// teacher mode and the Mission Data sources.

class NasaFact {
  final String text;
  const NasaFact(this.text);
}

/// One real fact shown on each mission's debrief.
const Map<int, String> debriefFacts = {
  1: 'An astronaut breathes about 0.84 kg of oxygen every day. NASA plans life support around this number.',
  2: 'At the Moon\'s south pole the Sun stays low. So crater edges make very long shadows. Some spots get sunlight most of the time; others are in shadow for days.',
  3: 'The space station turns sweat, breath and pee back into drinking water.',
  4: 'Astronauts on the ISS have grown and eaten lettuce, greens and peppers.',
  5: 'Some craters near the lunar poles never see sunlight. Instruments on NASA missions have found evidence of water ice in them.',
  6: 'Every rock brought back from the Moon tells scientists about the history of the solar system. Apollo astronauts returned 382 kg of lunar samples.',
  7: 'China\'s Chang\'e 4 lander measured about 1.37 mSv of radiation a day on the Moon. That is about 2.6 times more than inside the ISS.',
  8: 'NASA\'s DONKI database records every major solar flare and particle storm. The storms in this mission really happened.',
  9: 'A lunar night lasts about two Earth weeks. Without sunlight, solar-powered landers must survive on stored energy and heaters, or shut down.',
  10: 'NASA\'s Artemis program wants people to stay near the Moon\'s south pole. Sunlight and ice there make long stays possible.',
};

class NasaComparison {
  final String title;
  final String body;
  const NasaComparison(this.title, this.body);
}

/// Shown after boss missions.
const Map<int, List<NasaComparison>> whatWouldNasaDo = {
  2: [
    NasaComparison('Plan for the dark', 'Planners map when each place will be in shadow. Then they pick batteries big enough for every dark time, with extra to spare.'),
    NasaComparison('Carry spares and fix fast', 'ISS crews spend hours every week on maintenance. A broken oxygen generator is treated as urgent because the margin is small.'),
  ],
  4: [
    NasaComparison('Close the loop', 'Long missions recycle as much water and air as possible. Every kilogram recycled is a kilogram that never has to be launched.'),
    NasaComparison('Food as backup, not plan A', 'Plant growth on the ISS is still experimental. Missions carry packed food and treat fresh crops as a bonus and a morale boost.'),
  ],
  6: [
    NasaComparison('Plan every EVA', 'Every spacewalk has a timeline and extra oxygen. There is a rule to turn back early if anything goes wrong.'),
    NasaComparison('Rest is a mission task', 'Crew schedules include sleep and rest, because tired astronauts make mistakes outside.'),
  ],
  8: [
    NasaComparison('Watch space weather', 'NASA and NOAA forecasters watch the Sun around the clock and warn crews before particle storms arrive.'),
    NasaComparison('Use mass as a shield', 'Water, food and soil all block radiation. Future bases may cover habitats with lunar soil, called regolith.'),
  ],
  10: [
    NasaComparison('Keep the crew in the loop', 'Mission Control and astronauts decide together. Clear warnings and fast decisions keep a crew safe.'),
    NasaComparison('Margins everywhere', 'Real missions carry extra oxygen, water, food and power, because something always goes wrong.'),
  ],
};

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correct;
  final String why;
  const QuizQuestion(this.question, this.options, this.correct, this.why);
}

/// Two questions after each chapter's boss mission (keyed by chapter).
const Map<int, List<QuizQuestion>> quizzes = {
  1: [
    QuizQuestion('How does the base make oxygen?', ['From moon rocks', 'By splitting water with electricity', 'From the greenhouse only'], 1,
        'The generator uses electricity to split water (H₂O) into hydrogen and oxygen.'),
    QuizQuestion('Why does the base need batteries at the south pole?', ['To power the rover only', 'Crater shadows block sunlight for hours', 'Batteries make oxygen'], 1,
        'At the pole the Sun is low, so shadows can cover the base. Batteries keep it running in the dark.'),
  ],
  2: [
    QuizQuestion('What does the water recycler do?', ['Turns ice into rock', 'Recovers most of the water the crew uses', 'Makes food'], 1,
        'It cleans used water so it can be used again, saving most of it.'),
    QuizQuestion('What does the greenhouse need to grow food?', ['Power for lights and some water', 'Nothing at all', 'Only radiation'], 0,
        'Plants need light, which costs power, and water.'),
  ],
  3: [
    QuizQuestion('Where can astronauts find water on the Moon?', ['In rivers', 'As ice in permanently shadowed craters', 'In the atmosphere'], 1,
        'Craters near the poles that never see sunlight are cold enough to keep ice.'),
    QuizQuestion('Why should EVAs be short?', ['Suits use more oxygen and outside radiation is higher', 'The Moon gets dark every hour', 'Rocks are heavy'], 0,
        'Outside, the astronaut uses more oxygen and has less shielding from radiation.'),
  ],
  4: [
    QuizQuestion('What should the crew do when a solar flare is detected?', ['Go outside to watch', 'Move to the storm shelter', 'Turn off the heaters'], 1,
        'The shelter has the most shielding, so the dose is much lower there.'),
    QuizQuestion('What is regolith shielding?', ['A metal roof', 'Lunar soil piled on the habitat to block radiation', 'A force field'], 1,
        'Piling lunar soil on the habitat adds mass that absorbs radiation.'),
  ],
  5: [
    QuizQuestion('How long does a lunar night last?', ['About 12 hours', 'About two Earth weeks', 'One year'], 1,
        'The Moon rotates slowly, so a night lasts about 14 Earth days.'),
    QuizQuestion('During the night, what should stay ON?', ['The science lab', 'The greenhouse lights', 'The heaters'], 2,
        'Without heaters the habitat gets dangerously cold. Everything else can wait.'),
  ],
};

class TeacherChapter {
  final int chapter;
  final String goal;
  final String science;
  final List<String> questions;
  const TeacherChapter(this.chapter, this.goal, this.science, this.questions);
}

const teacherGuide = <TeacherChapter>[
  TeacherChapter(1, 'Students understand that oxygen must be produced or stored, and that producing it costs water and energy.',
      'Electrolysis uses electricity to split water into hydrogen and oxygen. Solar panels make power only in sunlight; batteries store it.',
      ['Why can\'t astronauts bring all their oxygen from Earth for a long mission?', 'What is the trade-off when you raise the oxygen generator rate?']),
  TeacherChapter(2, 'Students see recycling and food production as ways to reduce what must be launched from Earth.',
      'Water recovery systems clean used water. Plant growth needs light, water and time.',
      ['Which is easier: recycling water or growing food? Why?', 'How is a space station like a closed ecosystem on Earth?']),
  TeacherChapter(3, 'Students connect lunar resources (ice) with mission planning and EVA risk.',
      'Permanently shadowed craters near the poles can trap water ice. Spacewalks cost oxygen and add radiation exposure.',
      ['Why does NASA want to land near the lunar south pole?', 'How would you plan a safe EVA?']),
  TeacherChapter(4, 'Students understand space radiation, its sources, and shielding with mass.',
      'Galactic cosmic rays give a steady dose; solar particle events give sudden large doses. Mass (water, soil) absorbs radiation.',
      ['Why is radiation on the Moon higher than on Earth?', 'Why are real storm dates from NASA\'s DONKI used in the game?']),
  TeacherChapter(5, 'Students combine everything to manage a full mission and explain their decisions.',
      'A lunar night lasts about 14 Earth days. Energy storage and priority setting decide survival.',
      ['If you could add one technology to the base, what would it be and why?', 'Which decision in your mission mattered most?']),
];

class DataSource {
  final String quantity;
  final String realValue;
  final String inGame;
  final String source;
  final String url;
  const DataSource(this.quantity, this.realValue, this.inGame, this.source, this.url);
}

const missionData = <DataSource>[
  DataSource('Oxygen use', '0.84 kg per crew member per day', 'Same value, every game hour',
      'NASA life support requirements (NTRS 20040142395)', 'https://ntrs.nasa.gov/api/citations/20040142395/downloads/20040142395.pdf'),
  DataSource('Food', '0.62 kg of food solids per crew member per day', 'Same value',
      'NASA life support requirements (NTRS 20040142395)', 'https://ntrs.nasa.gov/api/citations/20040142395/downloads/20040142395.pdf'),
  DataSource('Drinking and food-prep water', '2.37 kg per crew member per day', '2.37 kg + 0.63 kg simplified hygiene',
      'NASA life support mass balance (NTRS 20100036823)', 'https://ntrs.nasa.gov/api/citations/20100036823/downloads/20100036823.pdf'),
  DataSource('Carbon dioxide produced', '1.00 kg per crew member per day', 'Shown for learning; scrubbers assumed',
      'NASA life support mass balance (NTRS 20100036823)', 'https://ntrs.nasa.gov/api/citations/20100036823/downloads/20100036823.pdf'),
  DataSource('Surface radiation', 'About 1.37 mSv per day (2.6 x ISS)', 'Same rate outside; reduced by habitat, shielding and shelter',
      'Chang\'e 4 LND, Science Advances 2020', 'https://www.science.org/doi/10.1126/sciadv.aaz1334'),
  DataSource('Solar storms', 'Real flares with linked proton events', 'X3.3 (9 Feb 2024), M3.3 (8 Jun 2024), X1.9 (18 Jan 2026)',
      'NASA DONKI space weather database', 'https://kauai.ccmc.gsfc.nasa.gov/DONKI/'),
  DataSource('Lunar night', 'About 14 Earth days', 'Compressed to a few game hours',
      'LND instrument team / NASA', 'https://science.nasa.gov/moon/'),
  DataSource('Moon surface', 'LRO camera and laser altimeter maps', 'Moon texture and terrain in 3D',
      'NASA SVS CGI Moon Kit', 'https://svs.gsfc.nasa.gov/4720'),
  DataSource('Earth', 'NASA Blue Marble and Black Marble (city lights)', 'Earth texture, night lights and oceans in 3D',
      'NASA Earth Observatory', 'https://earthobservatory.nasa.gov/features/BlueMarble'),
  DataSource('Earth clouds', 'Cloud map', 'Moving cloud layer on Earth',
      'Solar System Scope (CC BY 4.0)', 'https://www.solarsystemscope.com/textures/'),
  DataSource('Earth size', 'Earth is 3.67 times wider than the Moon (12,742 km vs 3,474 km)', 'Same ratio in the 3D scenes',
      'NASA Moon facts', 'https://science.nasa.gov/moon/facts/'),
  DataSource('Water from electrolysis', '1.125 kg of water per kg of oxygen', 'Same ratio (chemistry: H₂O → H₂ + ½O₂)',
      'Basic chemistry', 'https://science.nasa.gov/'),
];

const gameSimplifications = <String>[
  'Power values for machines (oxygen generator 1.2 kW, recycler 0.3 kW, greenhouse 1.5 kW, heaters 0.8 kW) are simplified game numbers.',
  'The recycler saves 85% of used water in the game.',
  'Storm dose rates are scaled so a storm is dangerous but survivable inside a few minutes of play.',
  'Time is compressed: one game hour lasts about one second.',
  'From the lunar surface Earth really looks about 2 degrees wide. The base view shows it larger, like a telephoto photo, so you can see it clearly.',
];
