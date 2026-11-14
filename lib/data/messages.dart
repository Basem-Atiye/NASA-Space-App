import '../engine/mission.dart';
import '../engine/simulation.dart';

enum Speaker { nova, capcom, lina, aria, jun, tomas, home }

enum Mood { calm, happy, tired, worried, scared }

class Reply {
  final String label;
  final String response; // Nova's answer
  const Reply(this.label, this.response);
}

class GameMessage {
  final Speaker speaker;
  final String text;
  final Mood mood;
  final bool important; // pauses the game and needs a tap
  final List<Reply> replies;

  const GameMessage(this.speaker, this.text, {this.mood = Mood.calm, this.important = false, this.replies = const []});
}

String speakerName(Speaker s, {String characterName = 'Nova Haddad'}) {
  switch (s) {
    case Speaker.nova:
      return 'Cmdr. $characterName';
    case Speaker.capcom:
      return 'CAPCOM Sami';
    case Speaker.lina:
      return 'Dr. Lina Rahme';
    case Speaker.aria:
      return 'ARIA';
    case Speaker.jun:
      return 'Jun Park';
    case Speaker.tomas:
      return 'Tomas Rivera';
    case Speaker.home:
      return 'Message from Earth';
  }
}

/// Personalizes scripted dialogue while keeping the story text as the source of truth.
String personalizeCharacterName(String text, String characterName) {
  if (characterName == 'Nova' || characterName == 'Nova Haddad') return text;
  return text
      .replaceAll('Commander Nova Haddad', 'Commander $characterName')
      .replaceAll('Cmdr. Nova Haddad', 'Cmdr. $characterName')
      .replaceAll('Nova Haddad', characterName)
      .replaceAll('Commander Nova', 'Commander $characterName')
      .replaceAll('Nova', characterName);
}

String speakerRole(Speaker s) {
  switch (s) {
    case Speaker.nova:
      return 'Commander, Shackleton Station';
    case Speaker.capcom:
      return 'Mission Control, Houston';
    case Speaker.lina:
      return 'Flight surgeon';
    case Speaker.aria:
      return 'Base computer';
    case Speaker.jun:
      return 'Geologist';
    case Speaker.tomas:
      return 'Engineer';
    case Speaker.home:
      return 'Personal channel';
  }
}

// --------------------------------------------------------------------------
// Scripted lines: they play at a given mission hour (tutorial steps, story).
// --------------------------------------------------------------------------

class Scripted {
  final int hour;
  final GameMessage message;
  const Scripted(this.hour, this.message);
}

const Map<int, List<Scripted>> scripted = {
  1: [
    Scripted(0, GameMessage(Speaker.nova, 'Contact light. Engine stop. Flight, I\'m on the Moon. Tell my mom.',
        mood: Mood.happy, important: true, replies: [
          Reply('Welcome to the Moon, Nova', 'Thanks, Flight. The view is... I don\'t have words. Earth is sitting right on the horizon.'),
          Reply('Your mom is crying', 'Ha! Tell her I packed the zaatar she gave me.'),
        ])),
    Scripted(1, GameMessage(Speaker.capcom,
        'Flight Director, you\'re in charge now. Nova breathes about 0.84 kg of oxygen a day. Tap the O₂ gauge on the left to see how long it lasts.',
        important: true)),
    Scripted(2, GameMessage(Speaker.capcom,
        'The oxygen generator splits water into oxygen using power. Open POWER and raise its rate if the O₂ time-left gets short.',
        important: true)),
    Scripted(5, GameMessage(Speaker.nova, 'Habitat\'s warm, lights are on. I\'m going to rest and let you watch the gauges, okay?')),
    Scripted(11, GameMessage(Speaker.capcom,
        'Dust settled on the solar panels after landing. Dirty panels make less power. You can set Nova\'s task to CLEAN PANELS.')),
    Scripted(20, GameMessage(Speaker.nova, 'Almost a full day. I keep looking at Earth. It\'s so small from here.', mood: Mood.happy)),
  ],
  2: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Week one, Flight. The crater rim casts long shadows at the pole. At hour 28 the base goes dark for about 12 hours. Fill the battery before then.',
        important: true)),
    Scripted(3, GameMessage(Speaker.nova, 'O₂ store is low this week. I trust you to keep the generator running.', mood: Mood.calm)),
    Scripted(26, GameMessage(Speaker.aria, 'NOTICE. SHADOW PERIOD IN 2 HOURS. BATTERY WILL BE THE ONLY POWER SOURCE.')),
  ],
  3: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Water check, Flight. Only 5 kg left in the tanks. The recycler is OFF to save power. Without it, most of Nova\'s water is lost every day.',
        important: true)),
    Scripted(1, GameMessage(Speaker.capcom, 'Open POWER and switch the water recycler ON. Watch what happens to the water time-left.', important: true)),
    Scripted(12, GameMessage(Speaker.nova, 'Fun fact: on the ISS, yesterday\'s coffee becomes tomorrow\'s coffee. Recycled water is cleaner than most tap water.',
        mood: Mood.happy)),
  ],
  4: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Food is short, Flight: barely a day and a half. The greenhouse can grow more, but it needs power for its lights and a little water.',
        important: true)),
    Scripted(1, GameMessage(Speaker.lina,
        'Dr. Rahme here, flight surgeon. I\'ll be watching Nova\'s health. Exercise keeps her bones and muscles strong in low gravity.')),
    Scripted(2, GameMessage(Speaker.nova, 'If you set my task to GREENHOUSE, the plants grow twice as fast. I talk to them. It helps. Probably.',
        mood: Mood.happy)),
  ],
  5: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Today we go ice hunting. Shadow Crater has not seen sunlight in billions of years, and it holds frozen water.',
        important: true)),
    Scripted(1, GameMessage(Speaker.capcom,
        'Tap EVA and choose Shadow Crater. Outside, Nova uses more oxygen and gets more radiation, so don\'t stay longer than needed.',
        important: true)),
    Scripted(2, GameMessage(Speaker.nova, 'Suit check complete. Visor down. Let\'s go find some water.', mood: Mood.happy)),
  ],
  6: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Busy schedule: 4 rock samples, 8 kg of ice and the spare solar panel on the ridge. Nova needs rest between EVAs.',
        important: true)),
    Scripted(2, GameMessage(Speaker.nova, 'I made a list. I love a list. Ice, rocks, panel. Coffee somewhere in between.', mood: Mood.happy)),
  ],
  7: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Flight, radiation is invisible. The Moon has no magnetic field and no air to block it. Watch the DOSE gauge.',
        important: true)),
    Scripted(1, GameMessage(Speaker.lina,
        'On the open surface Nova gets about 1.4 mSv a day from cosmic rays. That\'s about 2.6 times more than on the ISS. Solar storms can add much more.')),
    Scripted(8, GameMessage(Speaker.nova, 'Quiet day. I keep glancing at the Sun anyway.', mood: Mood.calm)),
  ],
  8: [
    Scripted(0, GameMessage(Speaker.jun, 'Jun Park, geologist, reporting for duty. I promise not to lick any rocks. Probably.',
        mood: Mood.happy, important: true)),
    Scripted(1, GameMessage(Speaker.capcom,
        'Space weather forecasters expect active days. Build regolith shielding early: piling Moon soil on the habitat cuts the dose inside.',
        important: true)),
  ],
  9: [
    Scripted(0, GameMessage(Speaker.capcom,
        'Flight, a lunar night lasts about two Earth weeks. We\'ll compress it, but the rules are real: at hour 10 the Sun sets, and solar power ends.',
        important: true)),
    Scripted(1, GameMessage(Speaker.capcom,
        'Charge the battery to full before sunset. After that, turn off everything that isn\'t keeping Nova alive. Heaters stay ON.',
        important: true)),
    Scripted(9, GameMessage(Speaker.nova, 'Last light on the ridge. It\'s beautiful and a bit scary.', mood: Mood.worried)),
  ],
  10: [
    Scripted(0, GameMessage(Speaker.tomas, 'Tomas Rivera, engineer. If it breaks, I\'ll fix it. If it doesn\'t break, I\'ll improve it until it does.',
        mood: Mood.happy, important: true)),
    Scripted(1, GameMessage(Speaker.capcom,
        'This is it, Flight: three crew, five days, a storm and a long night. Three people use three times the oxygen, water and food.',
        important: true)),
    Scripted(60, GameMessage(Speaker.aria, 'NOTICE. SUNSET IN 4 HOURS. NIGHT DURATION 40 HOURS.')),
  ],
};

// --------------------------------------------------------------------------
// Lines triggered by engine signals.
// --------------------------------------------------------------------------

GameMessage? messageForSignal(Signal s, MissionSim sim) {
  switch (s.type) {
    case SignalType.stormWarning:
      final ev = s.storm;
      return GameMessage(
        Speaker.capcom,
        'FLARE DETECTED. Replaying a real ${ev?.flareClass ?? ''} flare from ${ev?.date ?? ''}. Protons arrive soon. Get Nova to the STORM SHELTER${sim.onEva ? ' and RECALL the EVA now' : ''}.',
        mood: Mood.worried,
        important: true,
      );
    case SignalType.stormStart:
      if (sim.onEva) {
        return const GameMessage(Speaker.nova, 'Flight, I\'m still outside and my dosimeter is screaming! Bring me home!', mood: Mood.scared);
      }
      if (sim.location == CrewLocation.shelter) {
        return const GameMessage(Speaker.nova, 'I\'m in the shelter. Water tanks all around me. I can hear the counter clicking, but slowly. Good call, Flight.',
            mood: Mood.calm);
      }
      return const GameMessage(Speaker.nova, 'The storm is here and I\'m not in the shelter. The walls only stop part of it.', mood: Mood.worried);
    case SignalType.stormEnd:
      return const GameMessage(Speaker.capcom, 'Proton levels are back to normal. The storm has passed. Nova can leave the shelter.', mood: Mood.happy);
    case SignalType.failure:
      switch (s.system) {
        case SystemId.electrolyzer:
          return const GameMessage(Speaker.nova, 'Flight, the oxygen generator just died. I heard it cough and stop. Set my task to REPAIR?',
              mood: Mood.worried, important: true);
        case SystemId.recycler:
          return const GameMessage(Speaker.nova, 'Water recycler pump failed. Without it we lose most of our water. I can fix it in about 3 hours.',
              mood: Mood.worried, important: true);
        case SystemId.greenhouse:
          return const GameMessage(Speaker.nova, 'The greenhouse lights shorted out. My poor plants!', mood: Mood.worried, important: true);
        case null:
          return null;
      }
    case SignalType.repaired:
      return GameMessage(Speaker.nova, '${systemName(s.system ?? SystemId.electrolyzer)} is running again. I\'m getting good with a wrench.',
          mood: Mood.happy);
    case SignalType.harvest:
      return const GameMessage(Speaker.nova, 'Harvest! Fresh lettuce and radishes on the Moon. It\'s the best thing I\'ve ever eaten.', mood: Mood.happy);
    case SignalType.evaComplete:
      switch (s.eva) {
        case EvaTarget.ice:
          return const GameMessage(Speaker.nova, 'Back inside with 8 kg of ancient ice. That\'s water nobody had to launch from Earth.', mood: Mood.happy);
        case EvaTarget.science:
          return const GameMessage(Speaker.jun, 'Two beautiful samples. One of them might be older than the oceans on Earth.', mood: Mood.happy);
        case EvaTarget.ridge:
          return const GameMessage(Speaker.nova, 'New panel installed on the ridge. It catches sunlight almost all the time up there.', mood: Mood.happy);
        case EvaTarget.berm:
          return const GameMessage(Speaker.nova, 'Shielding done. Half a meter of Moon dirt on the roof. Ugly, but it works.', mood: Mood.happy);
        case null:
          return null;
      }
    case SignalType.evaRecalled:
      return const GameMessage(Speaker.nova, 'Coming back in. Airlock cycling.');
    case SignalType.brownout:
      return const GameMessage(Speaker.aria, 'WARNING. BATTERY EMPTY. NON-ESSENTIAL SYSTEMS SHUT DOWN.', mood: Mood.worried, important: true);
    case SignalType.nightStart:
      return const GameMessage(Speaker.nova, 'And... the Sun is gone. Only the base lights now. Running on battery.', mood: Mood.worried);
    case SignalType.dayStart:
      return const GameMessage(Speaker.nova, 'SUNRISE! The panels are waking up. I could cry. I might be crying.', mood: Mood.happy);
    case SignalType.dustStorm:
      return const GameMessage(Speaker.aria, 'NOTICE. DUST ON SOLAR ARRAY. POWER OUTPUT REDUCED.');
    case SignalType.cargoArrived:
      return const GameMessage(Speaker.capcom, 'A cargo lander just touched down. There\'s room for ONE crate. Choose carefully.',
          important: true);
    case SignalType.homeMessage:
      return const GameMessage(Speaker.home,
          'From Maya (Nova\'s sister): "The whole family watched the landing on TV. Teta made man\'oushe for the neighbours. Come home safe. We love you."',
          mood: Mood.happy);
    case SignalType.won:
    case SignalType.lost:
      return null;
  }
}

// --------------------------------------------------------------------------
// Rules checked every game hour. Each fires at most once per cooldown.
// --------------------------------------------------------------------------

class MessageRule {
  final String id;
  final int cooldown; // game hours
  final bool Function(MissionSim s) when;
  final GameMessage Function(MissionSim s) build;

  const MessageRule(this.id, this.cooldown, this.when, this.build);
}

final List<MessageRule> rules = [
  MessageRule('o2_low', 10, (s) => (s.o2HoursLeft ?? 999) < 12 && s.o2 > 0,
      (s) => const GameMessage(Speaker.nova, 'Flight, my O₂ time-left is under 12 hours. Can we push more power to the oxygen generator?',
          mood: Mood.worried, important: true)),
  MessageRule('o2_empty', 6, (s) => s.o2 <= 0.01,
      (s) => const GameMessage(Speaker.aria, 'CRITICAL. OXYGEN DEPLETED. CREW HEALTH FALLING FAST.', mood: Mood.scared, important: true)),
  MessageRule('water_low', 12, (s) => (s.waterHoursLeft ?? 999) < 12 && s.water > 0,
      (s) => const GameMessage(Speaker.nova, 'Water is getting low. Is the recycler on? Making oxygen uses water too.', mood: Mood.worried)),
  MessageRule('water_empty', 8, (s) => s.water <= 0.01,
      (s) => const GameMessage(Speaker.lina, 'Nova is dehydrating. Her health is dropping. She needs water, now.', mood: Mood.scared, important: true)),
  MessageRule('food_low', 16, (s) => (s.foodHoursLeft ?? 999) < 12 && s.food > 0,
      (s) => const GameMessage(Speaker.nova, 'I\'m counting crackers. Food runs out in less than half a day.', mood: Mood.worried)),
  MessageRule('battery_low', 10, (s) => s.battery < s.batteryCap * 0.2 && s.netKw < 0,
      (s) => const GameMessage(Speaker.aria, 'WARNING. BATTERY BELOW 20 PERCENT AND DRAINING.', mood: Mood.worried)),
  MessageRule('dust_high', 18, (s) => s.dust > 0.3 && s.sun,
      (s) => const GameMessage(Speaker.nova, 'The panels are filthy. Moon dust sticks to everything. Want me to go clean them?')),
  MessageRule('tired', 14, (s) => s.fatigue > 70,
      (s) => const GameMessage(Speaker.lina, 'Nova is exhausted. Tired astronauts make mistakes. Give her a REST shift.', mood: Mood.tired)),
  MessageRule('morale_low', 20, (s) => s.morale < 35,
      (s) => const GameMessage(Speaker.nova, 'Sorry, Flight. Just feeling far from home today.', mood: Mood.tired)),
  MessageRule('dose_high', 12, (s) => s.dose > s.mission.doseLimit * 0.7,
      (s) => GameMessage(Speaker.lina,
          'Radiation check: Nova is at ${s.dose.toStringAsFixed(1)} of ${s.mission.doseLimit.toStringAsFixed(0)} mSv allowed. Keep her inside.',
          mood: Mood.worried, important: true)),
  MessageRule('health_low', 12, (s) => s.health < 50,
      (s) => const GameMessage(Speaker.lina, 'Nova\'s health is below half. Find the cause and fix it, Flight.', mood: Mood.scared, important: true)),
  MessageRule('broken_waiting', 8, (s) => s.broken.isNotEmpty && s.activity != Activity.repair && !s.onEva,
      (s) => GameMessage(Speaker.nova, '${systemName(s.broken.first)} is still broken. Say the word and I\'ll grab my tools.',
          mood: Mood.worried)),
  MessageRule('cold', 6, (s) => !s.sun && !s.heatersOn,
      (s) => const GameMessage(Speaker.nova, 'It\'s freezing in here. I can see my breath. Can we turn the heaters back on?', mood: Mood.scared)),
  MessageRule('shelter_needless', 10, (s) => s.location == CrewLocation.shelter && s.storm == null,
      (s) => const GameMessage(Speaker.nova, 'It\'s quiet out there. Can I leave the shelter? It\'s really cramped.', mood: Mood.tired)),
];

// --------------------------------------------------------------------------
// Nova's memory: lines that refer back to earlier missions.
// --------------------------------------------------------------------------

class MemoryLine {
  final String flag;
  final GameMessage message;
  const MemoryLine(this.flag, this.message);
}

const memoryLines = <MemoryLine>[
  MemoryLine('o2_scare', GameMessage(Speaker.nova,
      'Last time my oxygen almost ran out, I didn\'t sleep for a day. Let\'s keep an eye on that gauge, okay?', mood: Mood.worried)),
  MemoryLine('water_dry', GameMessage(Speaker.nova,
      'I still remember being thirsty on this rock. Recycler first, everything else second.', mood: Mood.worried)),
  MemoryLine('brownout', GameMessage(Speaker.nova,
      'Remember when the batteries died and everything went quiet? I\'d rather not hear that silence again.', mood: Mood.worried)),
  MemoryLine('storm_outside', GameMessage(Speaker.nova,
      'The last storm caught me outside. If ARIA says "flare", I\'m running. Just so you know.', mood: Mood.scared)),
  MemoryLine('storm_perfect', GameMessage(Speaker.nova,
      'You got me into the shelter right on time during that flare. I trust your timing, Flight.', mood: Mood.happy)),
  MemoryLine('first_harvest', GameMessage(Speaker.nova,
      'I still think about that first lettuce harvest. Best salad in the solar system.', mood: Mood.happy)),
  MemoryLine('lost_mission', GameMessage(Speaker.nova,
      'We\'ve had a rough mission before. We learned from it. That\'s what NASA does too.', mood: Mood.calm)),
];

/// Flags to remember after a mission, based on what happened.
Set<String> memoryFlagsFrom(MissionSim s) {
  final flags = <String>{};
  if (s.lowestO2Days < 0.3) flags.add('o2_scare');
  if (s.damage.containsKey(LossReason.water)) flags.add('water_dry');
  if (s.brownouts > 0) flags.add('brownout');
  if (s.wasOutsideInStorm) flags.add('storm_outside');
  if (s.shelteredInStorm && !s.wasOutsideInStorm) flags.add('storm_perfect');
  if (s.harvests > 0) flags.add('first_harvest');
  if (s.outcome == Outcome.lost) flags.add('lost_mission');
  return flags;
}

/// Mood of Nova's portrait from the current state.
Mood moodFor(MissionSim s) {
  if (s.health < 35 || s.o2 <= 0 || (s.stormActive && s.onEva)) return Mood.scared;
  if (s.stormWarning || s.broken.isNotEmpty || (s.o2HoursLeft ?? 999) < 12 || s.health < 60 || s.brownout) return Mood.worried;
  if (s.fatigue > 70 || s.morale < 35) return Mood.tired;
  if (s.morale > 75) return Mood.happy;
  return Mood.calm;
}
