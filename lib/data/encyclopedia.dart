/// The Moon Encyclopedia: every fact Pip can scan, grouped by topic.
/// Facts are unlocked by scanning things in the story world.
library;

import 'glossary.dart';
import 'story.dart';

class Fact {
  final String id;
  final String title;
  final String topic;
  final String text;
  const Fact(this.id, this.title, this.topic, this.text);
}

const topics = ['The Moon', 'Earth and Sun', 'Base and gear', 'Life support', 'Spaceflight', 'Words'];

/// Facts Pip finds when scanning the ground or the sky (no object nearby).
const _extra = <Fact>[
  Fact('regolith', 'Regolith', 'The Moon', 'Moon soil is called regolith. It is sharp, glassy dust made by tiny space rocks hitting the Moon for billions of years. It sticks to everything.'),
  Fact('gravity', 'Moon gravity', 'The Moon', 'Gravity on the Moon is about one sixth of Earth\'s. Nova weighs 6 times less here, so she bounces when she walks.'),
  Fact('ice', 'Ice in the dark', 'The Moon', 'Craters near the south pole never see sunlight. Their floors stay below −170 °C and hold water ice, the main reason NASA is going there.'),
  Fact('sky', 'A black sky', 'Earth and Sun', 'With no air to scatter sunlight, the lunar sky is black even in the daytime. You can see stars next to the Sun.'),
  Fact('sun', 'The low Sun', 'Earth and Sun', 'At the south pole the Sun never rises high. It circles just above the horizon, making shadows many metres long.'),
  Fact('sound', 'Silence', 'The Moon', 'Sound needs air to travel. Outside, Nova hears only her breathing, her suit fans and the radio.'),
  Fact('temp', 'Hot and cold', 'The Moon', 'In sunlight the surface can reach 120 °C; in shadow it falls below −170 °C. Spacesuits heat and cool the astronaut.'),
  Fact('day', 'A long day', 'The Moon', 'One day on the Moon, from sunrise to sunrise, lasts about 29.5 Earth days.'),
  Fact('delay', 'Radio delay', 'Spaceflight', 'Radio signals take about 1.3 seconds to reach Earth. A question and its answer take at least 2.6 seconds.'),
  Fact('artemis', 'Artemis', 'Spaceflight', 'NASA\'s Artemis programme will land astronauts near the Moon\'s south pole. The plan is to stay there for a long time.'),
  Fact('gateway', 'Gateway', 'Spaceflight', 'Gateway is a small space station that will circle the Moon. Crews can change there between Orion and a lander.'),
  Fact('o2rate', 'Breathing', 'Life support', 'An astronaut uses about 0.84 kg of oxygen a day. NASA plans every mission around this number.'),
  Fact('water', 'Water', 'Life support', 'Each astronaut needs about 2.4 kg of water a day for drinking and food. The ISS recycles about 98% of it.'),
  Fact('food', 'Food', 'Life support', 'Astronauts eat about 0.6 kg of food a day, much of it dried to save weight.'),
  Fact('radiation', 'Radiation', 'Life support', 'Without Earth\'s magnetic field, solar storms can give a big radiation dose. Water, food and soil all make good shields.'),
  Fact('electrolysis', 'Making oxygen', 'Life support', 'Electrolysis splits water (H₂O) into hydrogen and oxygen using electricity. The ISS makes its oxygen this way.'),
  Fact('dust_eva', 'Dust on suits', 'Base and gear', 'Apollo astronauts found that lunar dust scratched visors, clogged zippers and smelled like spent gunpowder.'),
  Fact('apollo13', 'Apollo 13', 'Spaceflight', 'In 1970 an oxygen tank exploded on Apollo 13. The crew and Mission Control worked the problem for four days and all came home.'),
];

final List<Fact> encyclopedia = [
  for (final e in objectFacts.entries)
    if (e.key != 'solar')
      Fact(e.key, _titles[e.key] ?? e.key, e.key == 'earth' ? 'Earth and Sun' : (e.key == 'astronaut' ? 'Spaceflight' : 'Base and gear'), e.value),
  for (final p in pickupInfo.values) Fact('pickup:${p.id}', p.name, 'Base and gear', p.what),
  for (final s in siteInfo.values) Fact(s.id, s.name, 'The Moon', s.facts.join('. ')),
  ..._extra,
  // word tips the player tapped in the story
  for (final w in glossary) Fact(w.id, w.word, 'Words', w.meaning),
];

const _titles = {
  'earth': 'Earth from the Moon',
  'lander': 'The lander',
  'habitat': 'Inflatable habitat',
  'battery': 'Batteries',
  'panels': 'Solar panels',
  'antenna': 'Antenna',
  'shelter': 'Storm shelter',
  'crate': 'Cargo crates',
  'astronaut': 'The spacesuit',
  'rover': 'Pressurised rover',
  'greenhouse': 'Space greenhouse',
  'pad': 'Landing pad',
  'drill': 'Ice drill',
};

Fact? factById(String id) {
  for (final f in encyclopedia) {
    if (f.id == id) return f;
  }
  return null;
}

/// Ground and sky facts, in the order Pip offers them.
List<String> get groundFactIds => [for (final f in _extra) f.id];
