/// Base Commander: the day-by-day Moon base simulation behind the Figma
/// "Mission Control" screens. Pure Dart (no Flutter), so every rule is
/// tested in `test/base_test.dart`.
///
/// Everything is connected, as on a real base:
///  * the solar panels make power; dust, shadow and night make less;
///  * five systems share the power: Life Support (makes air), the Greenhouse
///    (makes food and a little air, but drinks water), the Water Recycler
///    (cleans water), Research and the Radiation Shield;
///  * when they ask for more than the panels make, the battery pays the
///    difference; when the battery is empty, systems get less power, with
///    Life Support served first;
///  * the crew breathes, drinks and eats every day; when a supply runs low
///    they get hurt; storms hurt them unless the shield is on.
///
/// Supplies are kept as percentages of the base's tanks (0–100), power in
/// kilowatts (kW), the battery as a percentage. One kilowatt missing for one
/// day costs 0.2 % of the battery.
library;

import 'dart:math' as math;

// ======================================================================= IDS

enum Res { oxygen, water, food, power, shield, crew }

enum Sys { lifeSupport, greenhouse, recycler, research, shield }

extension SysInfo on Sys {
  String get title => const ['Life Support', 'Greenhouse', 'Water Recycler', 'Research', 'Shield'][index];

  /// The most power this system can use (kW).
  double get maxKw => const [35.0, 25.0, 20.0, 10.0, 10.0][index];

  /// What it does, in simple words.
  String get job => const [
        'Makes the air your crew breathes',
        'Grows food for your crew',
        'Cleans used water so it can be drunk again',
        'Science experiments for Earth',
        'Protects your crew from radiation',
      ][index];
}

/// How hard the game is, from the player's age group.
enum Level { littleExplorer, explorer, engineer }

extension LevelInfo on Level {
  String get title => const ['Little Explorer', 'Explorer', 'Engineer'][index];
  String get ages => const ['ages 6–10', 'ages 11–14', 'ages 15–18'][index];

  /// How fast the crew uses supplies, compared with Explorer.
  double get use => const [0.7, 1.0, 1.15][index];

  /// How hard storms and leaks hit.
  double get harm => const [0.6, 1.0, 1.25][index];
}

// ======================================================================= CREW

class CrewMember {
  final String role;

  /// How much faster this person gets thirsty / hungry / cold (they work
  /// hard, or they are outside more).
  final double thirst, hunger, exposure;
  double health = 100;
  String status = 'OK';
  CrewMember(this.role, {this.thirst = 1, this.hunger = 1, this.exposure = 1});

  Map<String, dynamic> toJson() => {'role': role, 'health': health, 'status': status};
}

List<CrewMember> newCrew() => [
      CrewMember('Commander'),
      CrewMember('Pilot', exposure: 1.1),
      CrewMember('Engineer', thirst: 1.3, hunger: 1.1, exposure: 1.2),
      CrewMember('Scientist', hunger: 0.9),
    ];

// ======================================================================= LOG

/// One line in the mission log (and the "what happened" list).
class LogEntry {
  final int day;
  final String title;
  final String? action; // "Tap the Water Recycler"
  final List<Change> changes;
  final String kind; // alert, sprout, sun, danger, rocket, water, shield, power, fix, star
  final int score; // how good a decision this was (−3..+3), 0 for plain events
  final String? why; // for the best decision / main problem cards
  const LogEntry(this.day, this.title, {this.action, this.changes = const [], this.kind = 'alert', this.score = 0, this.why});

  Map<String, dynamic> toJson() => {'day': day, 'title': title, 'kind': kind, 'score': score};
}

/// A change shown on a chip: "+18% Food", "−12% Water", "−20 Power".
class Change {
  final String label;
  final bool good;
  final String icon; // power, water, food, oxygen, crew, research, shield, clock, up, down
  const Change(this.label, {required this.good, this.icon = ''});
}

// ======================================================================= EVENTS

/// What a choice does: some things happen now, some for a few days.
class Effect {
  final double oxygen, water, food, battery, research, crew, parts;
  final double dust; // added to the panels (0..1)
  final int days; // how long the "for a while" parts last
  final double leak; // air lost per day while active
  final double powerCost; // extra kW used per day while active
  final double sun; // sunlight multiplier while active (1 = no change)
  final bool shelter; // crew hides: safe from storms, research stops
  final double shieldBoost; // extra protection while active (0..1)
  final double recycler; // recycler efficiency change while active (−1..1)
  final double greenhouse; // greenhouse output change while active (−1..1)
  final bool fixesLeak;
  const Effect({
    this.oxygen = 0,
    this.water = 0,
    this.food = 0,
    this.battery = 0,
    this.research = 0,
    this.crew = 0,
    this.parts = 0,
    this.dust = 0,
    this.days = 0,
    this.leak = 0,
    this.powerCost = 0,
    this.sun = 1,
    this.shelter = false,
    this.shieldBoost = 0,
    this.recycler = 0,
    this.greenhouse = 0,
    this.fixesLeak = false,
  });
}

class EventOption {
  final String title;
  final List<Change> chips;
  final Effect effect;

  /// −3 (bad idea) .. +3 (the best thing to do).
  final int score;
  final String result; // what happens, in one or two short sentences
  final String logTitle;
  const EventOption(this.title, {required this.chips, required this.effect, required this.score, required this.result, required this.logTitle});
}

class EventDef {
  final String id;
  final String title;
  final String text;
  final String icon; // sun, wind, alert, droplet, sprout, zap, quake, rocket, radio
  final String color; // orange, red, yellow, blue, green, cyan
  final List<EventOption> options;

  /// A real-science line shown with the result.
  final String science;

  /// Storm events: the storm arrives this many days after the warning.
  final int stormIn;
  final double stormHarm;
  const EventDef(this.id, {required this.title, required this.text, required this.icon, required this.color, required this.options, required this.science, this.stormIn = 0, this.stormHarm = 0});
}

// ======================================================================= MISSIONS

class StartSupplies {
  final double power, oxygen, water, food;

  /// Repair parts (only from Supply Runs).
  final double parts;
  const StartSupplies({this.power = 60, this.oxygen = 90, this.water = 70, this.food = 80, this.parts = 0});
}

class BaseMission {
  final int n;
  final String title;
  final String newThing; // "Power + Oxygen", "Water"
  final String goal;
  final String newTitle; // "NEW: WATER"
  final String newText;
  final int days;
  final StartSupplies start;
  final Set<Sys> systems;

  /// Scripted events: day → event id.
  final Map<int, String> script;

  /// Sunlight per day (1 = full sun). Missing days are full sun.
  final Map<int, double> sunlight;
  final String lesson; // the lesson if the mission is lost
  final double researchGoal;
  final bool mars;

  /// For the last mission: what the launch needs.
  final int partsToLaunch;
  const BaseMission({
    required this.n,
    required this.title,
    required this.newThing,
    required this.goal,
    required this.newTitle,
    required this.newText,
    required this.days,
    required this.start,
    required this.systems,
    required this.script,
    this.sunlight = const {},
    required this.lesson,
    this.researchGoal = 40,
    this.mars = false,
    this.partsToLaunch = 0,
  });
}

// ======================================================================= STATE

class Ongoing {
  final String source;
  final int option; // which answer of the event (−1: a repair)
  final Effect effect;
  int left;
  Ongoing(this.source, this.effect, this.left, {this.option = -1});

  Map<String, dynamic> toJson() => {'s': source, 'o': option, 'l': left};
}

/// One day of history (for the charts, ratings and the "main problem").
class DaySnap {
  final int day;
  final double oxygen, water, food, battery, crew, research, gen, demand;

  /// Where the water and food went today (for "what used too much").
  final Map<String, double> waterUse, foodUse, powerUse;
  DaySnap(this.day, this.oxygen, this.water, this.food, this.battery, this.crew, this.research, this.gen, this.demand, this.waterUse, this.foodUse, this.powerUse);
}

enum BaseOutcome { running, won, lost }

class BaseState {
  final BaseMission mission;
  final Level level;
  int day = 1;
  double oxygen, water, food, battery;
  double research = 0;
  double parts = 0;
  double dust = 0;
  final List<CrewMember> crew = newCrew();

  /// Each system's power setting, 0..1 of its maximum.
  final Map<Sys, double> setting = {Sys.lifeSupport: 1, Sys.greenhouse: 0.4, Sys.recycler: 1, Sys.research: 1, Sys.shield: 0.2};
  final List<Ongoing> ongoing = [];
  final List<LogEntry> log = [];
  final List<DaySnap> history = [];

  /// An event waiting for the player's choice.
  EventDef? pendingEvent;

  /// A storm coming: days until it hits, and how hard.
  int stormIn = 0;
  double stormHarm = 0;
  bool stormHasHit = false;
  int stormsSurvived = 0;
  int stormsShielded = 0;
  int problemsFixed = 0;
  bool leaking = false;
  BaseOutcome outcome = BaseOutcome.running;
  String? lostCause; // 'oxygen', 'crew', 'power', 'water', 'food', 'launch'
  int brownoutDays = 0;
  final Set<String> seenEvents = {};
  double lowestCrew = 100;

  BaseState(this.mission, {this.level = Level.explorer, StartSupplies? bonus})
      : oxygen = mission.start.oxygen,
        water = mission.start.water,
        food = mission.start.food,
        battery = mission.start.power {
    if (bonus != null) {
      oxygen = math.min(100, oxygen + bonus.oxygen);
      water = math.min(100, water + bonus.water);
      food = math.min(100, food + bonus.food);
      battery = math.min(100, battery + bonus.power);
      parts += bonus.parts;
    }
    for (final s in Sys.values) {
      if (!mission.systems.contains(s)) setting[s] = 0;
    }
    log.add(const LogEntry(1, 'Mission started', kind: 'rocket'));
  }

  // ---------------------------------------------------------------- power

  double get crewHealth => crew.map((c) => c.health).reduce((a, b) => a + b) / crew.length;

  /// Sunlight today (1 = full sun, less in shadow or at night).
  double sunToday([int? d]) {
    var s = mission.sunlight[d ?? day] ?? 1.0;
    for (final o in ongoing) {
      s *= o.effect.sun;
    }
    return s;
  }

  bool get isNight => sunToday() < 0.35;

  /// Power the panels make today (kW).
  double get generation => 100 * sunToday() * (1 - dust * 0.6);

  /// Power each system asks for (kW).
  double askKw(Sys s) => mission.systems.contains(s) ? setting[s]! * s.maxKw : 0;

  /// Power everything asks for, including repairs (kW).
  double get demand => Sys.values.fold(0.0, (a, s) => a + askKw(s)) + ongoing.fold(0.0, (a, o) => a + o.effect.powerCost);

  /// The power to share between the systems (the Power tab's 100 kW).
  static const double shareKw = 100;

  /// Power actually delivered to each system today. When the battery is
  /// empty and the panels make less than asked, Life Support is served
  /// first, then water, food, the shield and research.
  Map<Sys, double> delivered() {
    final gen = generation;
    final need = demand;
    var avail = battery > 0 ? double.infinity : gen;
    final out = <Sys, double>{};
    if (avail >= need) {
      for (final s in Sys.values) {
        out[s] = askKw(s);
      }
      return out;
    }
    avail -= ongoing.fold(0.0, (a, o) => a + o.effect.powerCost);
    for (final s in const [Sys.lifeSupport, Sys.recycler, Sys.greenhouse, Sys.shield, Sys.research]) {
      final give = math.max(0.0, math.min(askKw(s), avail));
      out[s] = give;
      avail -= give;
    }
    return out;
  }

  /// Set a system's power (0..1) on the Power tab. The total can't go over
  /// [shareKw]: giving more to one takes it from the others (research
  /// first, life support last).
  void setPower(Sys s, double v) {
    if (!mission.systems.contains(s)) return;
    setting[s] = v.clamp(0.0, 1.0);
    var over = Sys.values.fold(0.0, (a, x) => a + askKw(x)) - shareKw;
    for (final o in const [Sys.research, Sys.shield, Sys.greenhouse, Sys.recycler, Sys.lifeSupport]) {
      if (over <= 0) break;
      if (o == s) continue;
      final take = math.min(over, askKw(o));
      setting[o] = (askKw(o) - take) / o.maxKw;
      over -= take;
    }
  }

  // ---------------------------------------------------------------- flows

  double _ongoingSum(double Function(Effect e) f) => ongoing.fold(0.0, (a, o) => a + f(o.effect));
  bool get sheltering => ongoing.any((o) => o.effect.shelter);

  /// A day's numbers for a given set of settings (used by the day step and
  /// by the module panel's "what changes" preview).
  Flows flows([Map<Sys, double>? override]) {
    final saved = Map<Sys, double>.from(setting);
    if (override != null) setting.addAll(override);
    final got = delivered();
    final askedNow = demand;
    setting
      ..clear()
      ..addAll(saved);
    double frac(Sys s) => s.maxKw == 0 ? 0 : got[s]! / s.maxKw;
    final use = level.use;
    final ls = frac(Sys.lifeSupport), gh = (frac(Sys.greenhouse) * (1 + _ongoingSum((e) => e.greenhouse))).clamp(0.0, 1.0);
    final wr = (frac(Sys.recycler) * (1 + _ongoingSum((e) => e.recycler))).clamp(0.0, 1.0);
    final f = Flows();
    // air: the crew breathes 5 % a day; life support makes up to 5.5 %;
    // plants give a little back
    f.oxygenMade = 5.5 * ls + 0.8 * gh;
    f.oxygenUsed = 5.0 * use + (leaking ? 7.0 * level.harm : 0) + _ongoingSum((e) => e.leak) * level.harm;
    // water: the crew drinks and washes 5 %; the recycler gets most of it back;
    // the greenhouse drinks up to 4 %
    // (before the recycler and greenhouse arrive, the crew lives on packed
    // supplies that run down slowly)
    final hasRecycler = mission.systems.contains(Sys.recycler), hasGreenhouse = mission.systems.contains(Sys.greenhouse);
    f.waterMade = 4.7 * wr;
    f.waterUse = {'crew': (hasRecycler ? 5.0 : 1.2) * use, 'greenhouse': 3.5 * gh};
    // food: the crew eats 3.5 %; the greenhouse grows up to 6 %
    f.foodMade = 6.0 * gh;
    f.foodUse = {'crew': (hasGreenhouse ? 3.5 : 1.0) * use};
    f.researchMade = sheltering ? 0 : 3.0 * frac(Sys.research);
    f.protection = (frac(Sys.shield) + _ongoingSum((e) => e.shieldBoost)).clamp(0.0, 1.0);
    f.gen = generation;
    f.demand = askedNow;
    f.powerUse = {for (final s in Sys.values) s.title: got[s]!};
    return f;
  }

  // ---------------------------------------------------------------- the day

  /// Ends today and starts the next. Returns what happened.
  DayReport nextDay() {
    if (outcome != BaseOutcome.running || pendingEvent != null) return DayReport(day, const []);
    final notes = <String>[];
    final f = flows();
    final before = (oxygen, water, food, battery);

    // battery: surplus charges it, deficit drains it (1 kW·day = 0.2 %)
    battery = (battery + (f.gen - f.demand) * 0.2).clamp(0.0, 100.0);
    if (battery <= 0 && f.gen < f.demand) brownoutDays++;

    oxygen = (oxygen + f.oxygenMade - f.oxygenUsed).clamp(0.0, 100.0);
    water = (water + f.waterMade - f.waterUse.values.fold(0.0, (a, b) => a + b)).clamp(0.0, 100.0);
    food = (food + f.foodMade - f.foodUse.values.fold(0.0, (a, b) => a + b)).clamp(0.0, 100.0);
    research += f.researchMade;
    // dust slowly settles on the panels
    dust = math.min(0.8, dust + 0.004);

    // the crew
    final cold = battery <= 0 && isNight;
    for (final c in crew) {
      var hurt = 0.0;
      final problems = <String>[];
      if (oxygen < 25) {
        hurt += (25 - oxygen) * 0.4 * c.exposure;
        problems.add('Short of air');
      }
      if (water < 20) {
        hurt += (20 - water) * 0.35 * c.thirst;
        problems.add('Thirsty');
      }
      if (food < 20) {
        hurt += (20 - food) * 0.25 * c.hunger;
        problems.add('Hungry');
      }
      if (cold) {
        hurt += 3 * c.exposure;
        problems.add('Cold');
      }
      if (hurt > 0) {
        c.health = math.max(0, c.health - hurt * level.harm);
      } else {
        c.health = math.min(100, c.health + 2);
      }
      // early warnings, before anyone is hurt
      if (problems.isEmpty) {
        if (water < 32 * c.thirst) problems.add('Thirsty');
        if (food < 30 * c.hunger) problems.add('Hungry');
      }
      c.status = problems.isEmpty ? (c.health < 60 ? 'Resting' : 'OK') : problems.first;
    }

    // a storm arrives
    if (stormIn > 0) {
      stormIn--;
      if (stormIn == 0) {
        final shelter = sheltering;
        final protect = shelter ? 1.0 : f.protection;
        final dmg = stormHarm * (1 - protect * 0.9) * level.harm;
        for (final c in crew) {
          c.health = math.max(0, c.health - dmg * c.exposure);
          if (dmg > 6) c.status = 'Sick';
        }
        stormsSurvived++;
        if (dmg <= stormHarm * 0.25) stormsShielded++;
        stormHasHit = true;
        notes.add(dmg > 6 ? 'The storm hit. The crew got ${dmg.round()}% sicker.' : 'The storm passed. The crew was safe.');
        log.add(LogEntry(day, dmg > 6 ? 'Solar storm hit the base' : 'The solar storm passed safely', kind: dmg > 6 ? 'danger' : 'shield', changes: [Change(dmg > 6 ? '−${dmg.round()}% Crew' : 'Crew safe', good: dmg <= 6, icon: 'crew')], score: dmg > 6 ? -2 : 2));
      }
    }

    lowestCrew = math.min(lowestCrew, crewHealth);
    history.add(DaySnap(day, oxygen, water, food, battery, crewHealth, research, f.gen, f.demand, f.waterUse, f.foodUse, f.powerUse));

    // warnings in the log (only the first time something runs low)
    void low(String what, double now, double was, String action, String kind) {
      if (now < 35 && was >= 35) log.add(LogEntry(day, '$what is running low', action: action, kind: kind, score: -1));
    }

    low('Water', water, before.$2, 'Tap the Water Recycler', 'alert');
    low('Food', food, before.$3, 'Turn up the Greenhouse', 'alert');
    low('Air', oxygen, before.$1, 'Give Life Support more power', 'alert');
    if (battery < 15 && before.$4 >= 15) log.add(LogEntry(day, 'Batteries are almost empty', action: 'Use less power', kind: 'alert', score: -1, why: f.gen < 60 ? 'not enough sun to recharge' : null));

    // ongoing effects tick down
    for (final o in ongoing) {
      o.left--;
    }
    ongoing.removeWhere((o) => o.left <= 0);

    // lost?
    if (oxygen <= 0) {
      _lose('oxygen');
    } else if (crewHealth <= 20) {
      _lose(water <= 5 ? 'water' : (food <= 5 ? 'food' : (battery <= 0 ? 'power' : 'crew')));
    }
    if (outcome == BaseOutcome.running && day >= mission.days) {
      if (mission.partsToLaunch > 0 && parts < mission.partsToLaunch) {
        _lose('launch');
      } else {
        outcome = BaseOutcome.won;
        log.add(LogEntry(day, mission.partsToLaunch > 0 ? 'Lift-off! The crew is flying home' : 'Mission complete', kind: 'rocket', score: 0));
      }
    }
    if (outcome == BaseOutcome.running) {
      day++;
      _maybeEvent();
    }
    return DayReport(day, notes);
  }

  void _lose(String cause) {
    outcome = BaseOutcome.lost;
    lostCause = cause;
    final text = switch (cause) {
      'oxygen' => 'Life support lost power and oxygen ran out',
      'water' => 'The water ran out and the crew got too weak',
      'food' => 'The food ran out and the crew got too weak',
      'power' => 'The batteries ran flat and the base went cold',
      'launch' => 'Not enough repair parts to launch',
      _ => 'The crew got too sick to go on',
    };
    log.add(LogEntry(day, text, kind: 'danger', score: -3));
  }

  // ---------------------------------------------------------------- events

  void _maybeEvent() {
    final id = mission.script[day];
    if (id != null) {
      final e = eventById(id);
      if (e != null) {
        pendingEvent = e;
        // some events change the base the moment they happen
        if (id == 'dust') dust = math.max(dust, 0.33);
        if (id == 'leak') leaking = true;
        return;
      }
    }
    // dust builds up: a reminder to clean the panels (not more than once a week)
    if (dust > 0.35 && !seenEvents.contains('dust-$day') && day % 7 == 0 && mission.systems.length > 1) {
      pendingEvent = eventById('dust');
    }
  }

  /// The player chose option [i] of the pending event.
  EventOption choose(int i) {
    final e = pendingEvent!;
    final o = e.options[i];
    pendingEvent = null;
    seenEvents
      ..add(e.id)
      ..add('${e.id}-$day');
    apply(o.effect, source: e.id, option: i);
    if (e.stormIn > 0) {
      stormIn = e.stormIn;
      stormHarm = e.stormHarm;
    }
    if (e.id == 'leak') leaking = !o.effect.fixesLeak;
    if (o.effect.fixesLeak) leaking = false;
    if (o.score >= 2) problemsFixed++;
    log.add(LogEntry(day, o.logTitle, kind: e.icon == 'sun' ? 'sun' : (o.score >= 0 ? 'fix' : 'danger'), changes: o.chips, score: o.score, why: o.result));
    return o;
  }

  void apply(Effect e, {String source = '', int option = -1}) {
    oxygen = (oxygen + e.oxygen).clamp(0.0, 100.0);
    water = (water + e.water).clamp(0.0, 100.0);
    food = (food + e.food).clamp(0.0, 100.0);
    battery = (battery + e.battery).clamp(0.0, 100.0);
    research = math.max(0, research + e.research);
    parts = math.max(0, parts + e.parts);
    dust = (dust + e.dust).clamp(0.0, 0.8);
    if (e.crew != 0) {
      for (final c in crew) {
        c.health = (c.health + e.crew).clamp(0.0, 100.0);
      }
    }
    if (e.days > 0) ongoing.add(Ongoing(source, e, e.days, option: option));
  }

  /// The player changed a system's level in its panel (logged once a day).
  void adjust(Sys s, double v) {
    final old = setting[s]!;
    setPower(s, v);
    final now = setting[s]!;
    if ((now - old).abs() < 0.01) return;
    // one log line per system per day
    log.removeWhere((l) => l.day == day && l.kind == 'adjust-${s.index}');
    final f0 = flows({s: old}), f1 = flows();
    final changes = <Change>[];
    if (s == Sys.greenhouse) {
      changes.add(Change('${_signed(f1.foodMade - f0.foodMade, 10)}% Food', good: f1.foodMade >= f0.foodMade, icon: 'up'));
      changes.add(Change('${_signed(-(f1.waterUse['greenhouse']! - f0.waterUse['greenhouse']!), 10)}% Water', good: f1.waterUse['greenhouse']! <= f0.waterUse['greenhouse']!, icon: 'down'));
    }
    if (s == Sys.recycler) changes.add(Change('${_signed(f1.waterMade - f0.waterMade, 10)}% Water', good: f1.waterMade >= f0.waterMade, icon: 'up'));
    if (s == Sys.lifeSupport) changes.add(Change('${_signed(f1.oxygenMade - f0.oxygenMade, 10)}% Air', good: f1.oxygenMade >= f0.oxygenMade, icon: 'up'));
    log.add(LogEntry(
      day,
      'You turned the ${s.title.toLowerCase()} ${now > old ? 'up' : 'down'} to ${(now * 100).round()}%',
      kind: 'adjust-${s.index}',
      changes: changes,
      score: _adjustScore(s, old, now),
    ));
  }

  /// Was that a good change, given what is low right now?
  int _adjustScore(Sys s, double old, double now) {
    final up = now > old;
    switch (s) {
      case Sys.recycler:
        return water < 45 ? (up ? 2 : -2) : 0;
      case Sys.greenhouse:
        if (food < 40) return up ? 2 : -1;
        if (water < 35) return up ? -2 : 2;
        return 0;
      case Sys.lifeSupport:
        return oxygen < 50 ? (up ? 2 : -2) : (up ? 0 : -1);
      case Sys.shield:
        return stormIn > 0 ? (up ? 2 : -2) : 0;
      case Sys.research:
        return battery < 30 ? (up ? -1 : 1) : 0;
    }
  }

  // ---------------------------------------------------------------- warnings

  /// The most urgent problem right now, for the yellow banner.
  Warning? get warning {
    if (stormIn > 0) return Warning('Solar storm in $stormIn day${stormIn == 1 ? '' : 's'}', 'Power up the shield or hide in the shelter', Sys.shield, 'red');
    if (leaking) return const Warning('Air is leaking', 'Fix the Habitat seal', Sys.lifeSupport, 'red');
    final items = <(double, Warning)>[
      if (mission.systems.contains(Sys.lifeSupport)) (oxygen, const Warning('Air is running low', 'Give Life Support more power', Sys.lifeSupport, 'yellow')),
      if (mission.systems.contains(Sys.recycler)) (water, const Warning('Water is running low', 'Tap the Water Recycler to fix it', Sys.recycler, 'yellow')),
      if (mission.systems.contains(Sys.greenhouse)) (food, const Warning('Food is running low', 'Turn up the Greenhouse', Sys.greenhouse, 'yellow')),
      (battery, Warning('Batteries are low', isNight ? 'Night: turn off what you do not need' : 'Clean the panels or use less power', Sys.research, 'yellow')),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final worst = items.first;
    if (worst.$1 < 35) return worst.$2;
    if (dust > 0.3) return const Warning('Dust on the solar panels', 'Tap the panels to clean them', null, 'yellow');
    if (isNight) return const Warning('Lunar night', 'The panels make little power. The battery keeps you going.', null, 'blue');
    return null;
  }

  /// Fix a leaking seal from the Habitat panel (if the player waited).
  bool fixLeak() {
    if (!leaking) return false;
    leaking = false;
    ongoing.add(Ongoing('fix', const Effect(powerCost: 10, days: 1), 1));
    problemsFixed++;
    log.add(LogEntry(day, 'You fixed the leaking seal', kind: 'fix', changes: const [Change('−10 Power', good: false, icon: 'power'), Change('Leak stops', good: true, icon: 'up')], score: 2));
    return true;
  }

  /// The day ice was last melted (the drill needs time to cool).
  int lastIce = -99;
  static const iceCooldown = 4;
  bool get canMeltIce => mission.systems.contains(Sys.recycler) && day - lastIce >= iceCooldown && battery >= 12 && outcome == BaseOutcome.running;
  int get iceReadyIn => math.max(0, iceCooldown - (day - lastIce));

  /// Drill ice from the shadowed crater and melt it into water. This is why
  /// bases are planned at the Moon's south pole: the ice is right there.
  bool meltIce() {
    if (!canMeltIce) return false;
    lastIce = day;
    battery -= 12;
    water = math.min(100, water + 14);
    log.add(LogEntry(day, 'You melted ice from the crater', kind: 'water', changes: const [Change('+14% Water', good: true, icon: 'up'), Change('−12% Battery', good: false, icon: 'power')], score: water < 60 ? 2 : 0));
    return true;
  }

  /// Clean the panels (an outside trip: uses a little suit air and a day's
  /// research). Only when there is dust.
  bool cleanPanels() {
    if (dust < 0.1 || outcome != BaseOutcome.running) return false;
    final gain = dust * 0.6 * 100;
    dust = 0;
    oxygen = math.max(0, oxygen - 2);
    problemsFixed++;
    log.add(LogEntry(day, 'You cleaned the solar panels', kind: 'sun', changes: [Change('+${gain.round()}% Power', good: true, icon: 'up')], score: 2));
    return true;
  }

  // ---------------------------------------------------------------- results

  MissionResult result() => MissionResult.of(this);

  // ---------------------------------------------------------------- saving

  /// Everything needed to carry on later ("Your progress is saved").
  Map<String, dynamic> toJson() => {
        'v': 1,
        'mission': mission.n,
        'level': level.index,
        'day': day,
        'o': oxygen,
        'w': water,
        'f': food,
        'b': battery,
        'r': research,
        'p': parts,
        'dust': dust,
        'set': {for (final e in setting.entries) e.key.name: e.value},
        'crew': [for (final c in crew) c.toJson()],
        'on': [for (final o in ongoing) o.toJson()],
        'log': [for (final l in log) _logJson(l)],
        'hist': [for (final h in history) _histJson(h)],
        'pending': pendingEvent?.id,
        'stormIn': stormIn,
        'stormHarm': stormHarm,
        'storms': [stormsSurvived, stormsShielded],
        'fixed': problemsFixed,
        'leak': leaking,
        'ice': lastIce,
        'seen': seenEvents.toList(),
        'brown': brownoutDays,
        'lowCrew': lowestCrew,
      };

  static Map<String, dynamic> _logJson(LogEntry l) => {
        'd': l.day,
        't': l.title,
        if (l.action != null) 'a': l.action,
        'k': l.kind,
        's': l.score,
        if (l.why != null) 'y': l.why,
        'c': [for (final c in l.changes) [c.label, c.good, c.icon]],
      };

  static Map<String, dynamic> _histJson(DaySnap h) => {
        'd': h.day,
        'v': [h.oxygen, h.water, h.food, h.battery, h.crew, h.research, h.gen, h.demand],
        'wu': h.waterUse,
        'fu': h.foodUse,
      };

  /// Rebuilds a saved game. [missionOf] finds the mission by number.
  static BaseState? fromJson(Map<String, dynamic> j, BaseMission Function(int n) missionOf) {
    try {
      final s = BaseState(missionOf((j['mission'] as num).toInt()), level: Level.values[(j['level'] as num).toInt()]);
      double d(String k) => (j[k] as num).toDouble();
      s
        ..day = (j['day'] as num).toInt()
        ..oxygen = d('o')
        ..water = d('w')
        ..food = d('f')
        ..battery = d('b')
        ..research = d('r')
        ..parts = d('p')
        ..dust = d('dust')
        ..stormIn = (j['stormIn'] as num).toInt()
        ..stormHarm = d('stormHarm')
        ..problemsFixed = (j['fixed'] as num).toInt()
        ..leaking = j['leak'] == true
        ..lastIce = (j['ice'] as num).toInt()
        ..brownoutDays = (j['brown'] as num).toInt()
        ..lowestCrew = d('lowCrew');
      final st = j['storms'] as List;
      s.stormsSurvived = (st[0] as num).toInt();
      s.stormsShielded = (st[1] as num).toInt();
      (j['set'] as Map).forEach((k, v) => s.setting[Sys.values.byName(k as String)] = (v as num).toDouble());
      final crew = j['crew'] as List;
      for (var i = 0; i < s.crew.length && i < crew.length; i++) {
        s.crew[i].health = (crew[i]['health'] as num).toDouble();
        s.crew[i].status = crew[i]['status'] as String;
      }
      for (final o in j['on'] as List) {
        final src = o['s'] as String, opt = (o['o'] as num).toInt(), left = (o['l'] as num).toInt();
        final e = eventById(src);
        final effect = (e != null && opt >= 0 && opt < e.options.length) ? e.options[opt].effect : const Effect(powerCost: 10, days: 1);
        s.ongoing.add(Ongoing(src, effect, left, option: opt));
      }
      s.log
        ..clear()
        ..addAll([
          for (final l in j['log'] as List)
            LogEntry((l['d'] as num).toInt(), l['t'] as String,
                action: l['a'] as String?,
                kind: l['k'] as String,
                score: (l['s'] as num).toInt(),
                why: l['y'] as String?,
                changes: [for (final c in l['c'] as List) Change(c[0] as String, good: c[1] as bool, icon: c[2] as String)]),
        ]);
      for (final h in j['hist'] as List) {
        final v = [for (final x in h['v'] as List) (x as num).toDouble()];
        Map<String, double> m(Object? x) => {for (final e in (x as Map).entries) e.key as String: (e.value as num).toDouble()};
        s.history.add(DaySnap((h['d'] as num).toInt(), v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], m(h['wu']), m(h['fu']), const {}));
      }
      s.seenEvents.addAll([for (final x in j['seen'] as List) x as String]);
      final p = j['pending'] as String?;
      if (p != null) s.pendingEvent = eventById(p);
      return s;
    } catch (_) {
      return null;
    }
  }
}

String _signed(double perDay, int days) {
  final v = (perDay * days).round();
  return v >= 0 ? '+$v' : '−${v.abs()}';
}

class Warning {
  final String title;
  final String action;
  final Sys? system;
  final String color;
  const Warning(this.title, this.action, this.system, this.color);
}

class Flows {
  double oxygenMade = 0, oxygenUsed = 0, waterMade = 0, foodMade = 0, researchMade = 0, protection = 0, gen = 0, demand = 0;
  Map<String, double> waterUse = {}, foodUse = {}, powerUse = {};
  double get waterNet => waterMade - waterUse.values.fold(0.0, (a, b) => a + b);
  double get foodNet => foodMade - foodUse.values.fold(0.0, (a, b) => a + b);
  double get oxygenNet => oxygenMade - oxygenUsed;
  double get batteryNet => (gen - demand) * 0.2;
}

class DayReport {
  final int day;
  final List<String> notes;
  const DayReport(this.day, this.notes);
}

// ======================================================================= RESULTS

/// The end-of-mission report: stars, one rating per system, the best
/// decision and the main problem (Figma 07), or what went wrong (Figma 08).
class MissionResult {
  final bool won;
  final int stars;
  final int days;
  final int dayReached;
  final Map<String, int> ratings; // Power, Crew, Food, Water, Research → 1..5
  final LogEntry? best;
  final String mainProblem;
  final List<LogEntry> whatHappened;
  final String lesson;
  final String headline;
  final String subline;
  final double crewHealth;
  final double research;
  final int problemsFixed;
  final int stormsSurvived, stormsShielded;
  final double minWater, minFood, minBattery, minOxygen, lowestCrew;

  const MissionResult({
    required this.won,
    required this.stars,
    required this.days,
    required this.dayReached,
    required this.ratings,
    required this.best,
    required this.mainProblem,
    required this.whatHappened,
    required this.lesson,
    required this.headline,
    required this.subline,
    required this.crewHealth,
    required this.research,
    required this.problemsFixed,
    required this.stormsSurvived,
    required this.stormsShielded,
    required this.minWater,
    required this.minFood,
    required this.minBattery,
    required this.minOxygen,
    required this.lowestCrew,
  });

  static int _rate(double avg, double min) {
    final v = avg * 0.6 + min * 0.4; // a low point counts too
    if (v >= 70) return 5;
    if (v >= 55) return 4;
    if (v >= 40) return 3;
    if (v >= 25) return 2;
    return 1;
  }

  factory MissionResult.of(BaseState s) {
    final h = s.history;
    double avg(double Function(DaySnap d) f) => h.isEmpty ? 0 : h.map(f).reduce((a, b) => a + b) / h.length;
    double low(double Function(DaySnap d) f) => h.isEmpty ? 0 : h.map(f).reduce(math.min);
    final sys = s.mission.systems;
    final ratings = <String, int>{
      'Power': _rate(avg((d) => d.battery), low((d) => d.battery)),
      'Crew': _rate(avg((d) => d.crew), low((d) => d.crew)),
      if (sys.contains(Sys.greenhouse)) 'Food': _rate(avg((d) => d.food), low((d) => d.food)),
      if (sys.contains(Sys.recycler)) 'Water': _rate(avg((d) => d.water), low((d) => d.water)),
      if (sys.contains(Sys.lifeSupport) && !sys.contains(Sys.recycler)) 'Air': _rate(avg((d) => d.oxygen), low((d) => d.oxygen)),
      if (sys.contains(Sys.research)) 'Research': ((s.research / s.mission.researchGoal) * 5).clamp(1, 5).round(),
    };
    final won = s.outcome == BaseOutcome.won;
    final meanRating = ratings.values.reduce((a, b) => a + b) / ratings.length;
    final mins = [low((d) => d.oxygen), if (sys.contains(Sys.recycler)) low((d) => d.water), if (sys.contains(Sys.greenhouse)) low((d) => d.food)].reduce(math.min);
    // 1 star for surviving, 2 for a healthy base, 3 for a base that never struggled
    final stars = !won
        ? 0
        : 1 + (meanRating >= 3.4 && s.lowestCrew >= 60 && mins >= 20 ? 1 : 0) + (meanRating >= 4.0 && s.lowestCrew >= 80 && mins >= 30 ? 1 : 0);

    // the best decision: the highest-scoring choice the player made
    final decisions = s.log.where((l) => l.score > 0).toList()..sort((a, b) => b.score.compareTo(a.score) != 0 ? b.score.compareTo(a.score) : a.day.compareTo(b.day));
    final best = decisions.isEmpty ? null : decisions.first;

    final problem = _mainProblem(s);
    final lost = s.log.where((l) => l.score < 0 || l.kind == 'danger').toList();
    final what = <LogEntry>[...lost.where((l) => l.kind != 'danger' || l == lost.last)];
    final whatHappened = what.length <= 3 ? what : what.sublist(what.length - 3);

    final lesson = switch (s.lostCause) {
      'oxygen' || 'power' => 'Every system in a space base shares the same power. Keep some energy saved in your batteries!',
      'water' => 'Water is used again and again on a base. Keep the recycler running and do not let plants drink it all.',
      'food' => 'Food takes days to grow. Turn the greenhouse up before you need the food, not after.',
      'launch' => 'A launch needs spare parts. Collect them early: fixing things takes time.',
      _ => 'Your crew needs air, water, food and protection every single day. Watch the yellow warnings!',
    };
    final headline = won ? 'You did it, Commander!' : switch (s.lostCause) { 'oxygen' => 'Life support stopped', 'power' => 'The base lost power', 'water' => 'The water ran out', 'food' => 'The food ran out', 'launch' => 'The rocket could not launch', _ => 'The crew needs help' };
    final subline = won
        ? '${s.mission.days} days survived · ${s.crewHealth >= 50 ? 'all 4 crew safe' : 'the crew made it'}'
        : 'Your base ${switch (s.lostCause) { 'oxygen' => 'ran out of air', 'power' => 'ran out of power', 'water' => 'ran out of water', 'food' => 'ran out of food', 'launch' => 'did not have enough parts', _ => 'could not keep the crew healthy' }} on Day ${s.day} of ${s.mission.days}.';
    return MissionResult(
      won: won,
      stars: stars,
      days: s.mission.days,
      dayReached: s.day,
      ratings: ratings,
      best: best,
      mainProblem: problem,
      whatHappened: whatHappened,
      lesson: lesson,
      headline: headline,
      subline: subline,
      crewHealth: s.crewHealth,
      research: s.research,
      problemsFixed: s.problemsFixed,
      stormsSurvived: s.stormsSurvived,
      stormsShielded: s.stormsShielded,
      minWater: low((d) => d.water),
      minFood: low((d) => d.food),
      minBattery: low((d) => d.battery),
      minOxygen: low((d) => d.oxygen),
      lowestCrew: s.lowestCrew,
    );
  }

  /// Finds the supply that was lowest for longest, when it was low, and
  /// what used the most of it then: "The greenhouse used too much water
  /// between Days 12 and 18."
  static String _mainProblem(BaseState s) {
    final h = s.history;
    if (h.isEmpty) return 'Nothing went wrong yet.';
    final sys = s.mission.systems;
    final checks = <String, double Function(DaySnap)>{
      if (sys.contains(Sys.recycler)) 'water': (d) => d.water,
      if (sys.contains(Sys.greenhouse)) 'food': (d) => d.food,
      'air': (d) => d.oxygen,
      'battery': (d) => d.battery,
    };
    String? worst;
    var worstScore = 0.0;
    for (final e in checks.entries) {
      final score = h.fold(0.0, (a, d) => a + math.max(0, 40 - e.value(d)));
      if (score > worstScore) {
        worstScore = score;
        worst = e.key;
      }
    }
    if (worst == null) return 'No supply ever ran low. Great planning!';
    final lowDays = h.where((d) => checks[worst]!(d) < 40).map((d) => d.day).toList();
    final a = lowDays.first, b = lowDays.last;
    final when = a == b ? 'on Day $a' : 'between Days $a and $b';
    final span = h.where((d) => d.day >= a && d.day <= b).toList();
    switch (worst) {
      case 'water':
        final gh = span.fold(0.0, (x, d) => x + (d.waterUse['greenhouse'] ?? 0));
        final crew = span.fold(0.0, (x, d) => x + (d.waterUse['crew'] ?? 0));
        return gh > crew * 0.55 ? 'The greenhouse used too much water $when.' : 'The recycler could not keep up with the crew\'s water $when.';
      case 'food':
        return 'The greenhouse did not grow enough food $when.';
      case 'air':
        return s.log.any((l) => l.title.contains('leak') || l.title.contains('Leak')) ? 'Air leaked out of the habitat $when.' : 'Life support did not get enough power $when.';
      default:
        final night = span.where((d) => d.gen < 50).length;
        return night > 0 ? 'The batteries drained at night $when: not enough sun to recharge.' : 'The base used more power than the panels made $when.';
    }
  }
}

// ======================================================================= LOOKUP

final Map<String, EventDef> _events = {};

/// Registers the content (missions and events). Done once by base_content.
void registerEvents(Iterable<EventDef> events) {
  for (final e in events) {
    _events[e.id] = e;
  }
}

EventDef? eventById(String id) => _events[id];
