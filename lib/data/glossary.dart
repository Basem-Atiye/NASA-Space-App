/// Word tips: hard words in the story are underlined. Tapping one makes Pip
/// say what it means in simple words, and the word goes into the
/// encyclopedia under "Words".
library;

class WordTip {
  final String word;
  final String meaning;
  const WordTip(this.word, this.meaning);

  /// Saved with the player's facts (lower case, no spaces, so it syncs).
  String get id => 'word:${word.toLowerCase().replaceAll(' ', '_')}';
}

/// Simple meanings (one short sentence each, for ages 6 and up).
const glossary = <WordTip>[
  WordTip('regolith', 'Moon soil: sharp, grey dust and small rocks.'),
  WordTip('radiation', 'Tiny fast bits of energy from the Sun and space. Too much can hurt your body.'),
  WordTip('oxygen', 'The gas we breathe in to stay alive.'),
  WordTip('carbon dioxide', 'The gas we breathe out. Too much of it is dangerous.'),
  WordTip('habitat', 'A home for astronauts, with air inside.'),
  WordTip('airlock', 'A small room with two doors, so air stays in when you go outside.'),
  WordTip('lander', 'The spaceship that lands on the Moon.'),
  WordTip('rover', 'A car for driving on the Moon.'),
  WordTip('crater', 'A round hole made when a space rock hit the ground.'),
  WordTip('lunar', 'About the Moon. "Lunar soil" means Moon soil.'),
  WordTip('gravity', 'The pull that makes things fall down.'),
  WordTip('orbit', 'The path something takes going round and round a planet or moon.'),
  WordTip('solar', 'About the Sun. Solar panels turn sunlight into electricity.'),
  WordTip('battery', 'A box that stores electricity to use later.'),
  WordTip('circuit', 'A loop that electricity travels around.'),
  WordTip('fuse', 'A small safety part that breaks if too much electricity flows.'),
  WordTip('polarity', 'Which side is plus (+) and which is minus (−).'),
  WordTip('voltage', 'How hard electricity is pushed. Measured in volts (V).'),
  WordTip('current', 'How much electricity flows. Measured in amps (A).'),
  WordTip('multimeter', 'A tool that measures electricity.'),
  WordTip('sensor', 'A part that measures something, like heat or air.'),
  WordTip('antenna', 'A dish or rod that sends and receives radio messages.'),
  WordTip('shielding', 'Material that blocks radiation, like a thick wall.'),
  WordTip('electrolysis', 'Using electricity to split water into hydrogen and oxygen.'),
  WordTip('hydrogen', 'The lightest gas. Water is made of hydrogen and oxygen.'),
  WordTip('recycle', 'To clean something and use it again.'),
  WordTip('ration', 'To use only a small, planned amount each day.'),
  WordTip('reserve', 'Extra that you keep for an emergency.'),
  WordTip('procedure', 'A list of steps you follow in the right order.'),
  WordTip('root cause', 'The real reason something went wrong.'),
  WordTip('hysteresis', 'A gap between the ON and OFF levels, so a switch does not flick on and off.'),
  WordTip('cosine', 'Maths that tells how much light hits a panel when it is tilted.'),
  WordTip('torque', 'How hard you twist something, like a bolt.'),
  WordTip('moonquake', 'When the Moon\'s ground shakes, like an earthquake.'),
  WordTip('micrometeoroid', 'A space rock smaller than a grain of sand, moving very fast.'),
  WordTip('meteorite', 'A space rock that hits the ground.'),
  WordTip('neutron', 'A tiny part of an atom. A neutron scanner can find hidden ice.'),
  WordTip('Mission Control', 'The team on Earth that helps astronauts.'),
  WordTip('CAPCOM', 'The person at Mission Control who talks to the astronauts.'),
  WordTip('Artemis', 'NASA\'s program to take people back to the Moon.'),
  WordTip('inflatable', 'Something you fill with air to make it big, like a balloon.'),
  WordTip('pressure', 'How hard air pushes. Your body needs air pressure to live.'),
  WordTip('kilowatt', 'A unit of power. 1 kW can run a small heater.'),
  WordTip('kW', 'Kilowatt: a unit of power. 1 kW can run a small heater.'),
  WordTip('mSv', 'Millisievert: a unit for how much radiation your body gets.'),
  WordTip('kPa', 'Kilopascal: a unit of pressure. Air on Earth is about 101 kPa.'),
  WordTip('ISS', 'The International Space Station, a big lab that circles Earth.'),
  WordTip('spacewalk', 'Going outside in a spacesuit.'),
];

final Map<String, WordTip> _byLower = {for (final w in glossary) w.word.toLowerCase(): w};

WordTip? tipById(String id) => id.startsWith('word:') ? _byLower[id.substring(5).replaceAll('_', ' ')] : null;

/// A hard word found in a text: where it is and its tip.
class TipHit {
  final int start, end;
  final WordTip tip;
  const TipHit(this.start, this.end, this.tip);
}

/// Every spelling we underline (plurals too), to its tip.
final Map<String, WordTip> _forms = () {
  final m = <String, WordTip>{};
  for (final w in glossary) {
    final l = w.word.toLowerCase();
    m[l] = w;
    m.putIfAbsent('${l}s', () => w);
    if (l.endsWith('y')) m.putIfAbsent('${l.substring(0, l.length - 1)}ies', () => w);
  }
  return m;
}();

final RegExp _pattern = () {
  final forms = _forms.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(r'\b(' + forms.map(RegExp.escape).join('|') + r')\b', caseSensitive: false);
}();

/// The hard words in [text], each one only the first time it appears.
List<TipHit> findTips(String text) {
  final hits = <TipHit>[];
  final seen = <String>{};
  for (final m in _pattern.allMatches(text)) {
    final tip = _forms[m.group(1)!.toLowerCase()];
    if (tip == null || !seen.add(tip.id)) continue;
    // short codes (kW, mSv, ISS...) must match their case exactly
    if (tip.word.length <= 6 && tip.word.toUpperCase() == tip.word && m.group(1) != tip.word) continue;
    hits.add(TipHit(m.start, m.end, tip));
  }
  return hits;
}
