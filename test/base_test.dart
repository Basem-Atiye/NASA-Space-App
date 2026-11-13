import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/base/base_content.dart';
import 'package:shackleton_station/base/base_engine.dart';

/// A careful commander: picks the best answer, keeps water and food in
/// balance, cleans the panels and powers the shield before storms.
MissionResult playWell(BaseMission m, Level l) {
  final s = BaseState(m, level: l);
  for (var guard = 0; guard < 200 && s.outcome == BaseOutcome.running; guard++) {
    if (s.pendingEvent != null) {
      final e = s.pendingEvent!;
      var best = 0;
      for (var i = 0; i < e.options.length; i++) {
        if (e.options[i].score > e.options[best].score) best = i;
      }
      s.choose(best);
      continue;
    }
    if (s.dust > 0.25) s.cleanPanels();
    if (s.leaking) s.fixLeak();
    if (s.water < 50 && s.battery > 35) s.meltIce();
    if (s.battery < 40 && s.generation < s.demand && m.systems.contains(Sys.research)) s.adjust(Sys.research, 0);
    if (m.systems.contains(Sys.greenhouse)) {
      if (s.water < 40 && s.setting[Sys.greenhouse]! > 0.25) s.adjust(Sys.greenhouse, 0.25);
      if (s.food < 45 && s.water >= 40) s.adjust(Sys.greenhouse, 0.7);
      if (s.food > 75) s.adjust(Sys.greenhouse, 0.35);
    }
    if (m.systems.contains(Sys.shield)) s.adjust(Sys.shield, s.stormIn > 0 ? 1.0 : 0.3);
    if (s.battery < 25 && m.systems.contains(Sys.research)) s.adjust(Sys.research, 0);
    if (s.battery > 60 && m.systems.contains(Sys.research)) s.adjust(Sys.research, 1);
    s.nextDay();
  }
  return s.result();
}

/// A careless commander: always waits, never changes anything.
MissionResult playBadly(BaseMission m, Level l) {
  final s = BaseState(m, level: l);
  for (var guard = 0; guard < 200 && s.outcome == BaseOutcome.running; guard++) {
    if (s.pendingEvent != null) {
      s.choose(s.pendingEvent!.options.length - 1);
      continue;
    }
    s.nextDay();
  }
  return s.result();
}

void main() {
  ensureBaseContent();

  test('every scripted event exists and every event has 3 options', () {
    for (final m in [...moonMissions, ...marsMissions]) {
      for (final id in m.script.values) {
        expect(eventById(id) != null, isTrue, reason: '${m.title}: $id');
      }
    }
    for (final e in allBaseEvents) {
      expect(e.options.length, 3, reason: e.id);
      expect(e.science.isNotEmpty, isTrue, reason: e.id);
    }
  });

  test('a careful commander wins every mission at every level', () {
    for (final l in Level.values) {
      for (final m in [...moonMissions, ...marsMissions]) {
        final r = playWell(m, l);
        expect(r.won, isTrue, reason: '${l.title} ${m.title}: lost (${r.headline}, day ${r.dayReached})');
        expect(r.stars, greaterThanOrEqualTo(m.mars ? 1 : 2), reason: '${l.title} ${m.title}: ${r.stars} stars ${r.ratings}');
      }
    }
  });

  test('a careless commander never does well', () {
    var lost = 0;
    for (final m in moonMissions) {
      final r = playBadly(m, Level.explorer);
      if (!r.won) lost++;
      expect(r.stars, lessThanOrEqualTo(m.n == 1 ? 2 : 1), reason: m.title);
    }
    expect(lost, greaterThanOrEqualTo(2));
  });

  test('power: the total can never go over 100 kW', () {
    final s = BaseState(moonMissions[3]);
    s.setPower(Sys.greenhouse, 1);
    s.setPower(Sys.shield, 1);
    s.setPower(Sys.lifeSupport, 1);
    s.setPower(Sys.recycler, 1);
    s.setPower(Sys.research, 1);
    final total = Sys.values.fold(0.0, (a, x) => a + s.askKw(x));
    expect(total, lessThanOrEqualTo(100.001));
    // the system just raised keeps its value
    expect(s.setting[Sys.research], 1.0);
  });

  test('more food uses more water (the greenhouse trade-off)', () {
    final s = BaseState(moonMissions[1]);
    final a = s.flows({Sys.greenhouse: 0.4}), b = s.flows({Sys.greenhouse: 0.7});
    expect(b.foodMade, greaterThan(a.foodMade));
    expect(b.waterUse['greenhouse']!, greaterThan(a.waterUse['greenhouse']!));
    expect(b.demand, greaterThan(a.demand));
  });

  test('an empty battery serves life support first', () {
    final s = BaseState(moonMissions[3])..battery = 0;
    s.ongoing.add(Ongoing('night', const Effect(sun: 0.4, days: 3), 3));
    final got = s.delivered();
    expect(got[Sys.lifeSupport], Sys.lifeSupport.maxKw);
    expect(got[Sys.research]!, lessThan(Sys.research.maxKw));
  });

  test('the shield protects the crew from a storm', () {
    int crewAfter(int option) {
      final s = BaseState(moonMissions[3]);
      while (s.pendingEvent?.id != 'storm') {
        if (s.pendingEvent != null) {
          s.choose(0);
        } else {
          s.nextDay();
        }
      }
      s.choose(option);
      for (var i = 0; i < 3; i++) {
        s.nextDay();
      }
      return s.crewHealth.round();
    }

    expect(crewAfter(0), greaterThan(crewAfter(2) + 15));
  });

  test('results: best decision, main problem and lesson are filled in', () {
    final good = playWell(moonMissions[1], Level.explorer);
    expect(good.best != null, isTrue);
    expect(good.mainProblem.isNotEmpty, isTrue);
    final bad = playBadly(moonMissions[1], Level.explorer);
    expect(bad.won, isFalse);
    expect(bad.whatHappened.isNotEmpty, isTrue);
    expect(bad.lesson.isNotEmpty, isTrue);
    expect(bad.subline.contains('Day'), isTrue);
  });

  test('the last mission needs 3 parts to launch', () {
    final s = BaseState(moonMissions[4]);
    for (var guard = 0; guard < 200 && s.outcome == BaseOutcome.running; guard++) {
      if (s.pendingEvent != null) {
        // skip every chance to get parts
        final e = s.pendingEvent!;
        s.choose(e.id == 'parts' || e.id == 'printer' || e.id == 'ship' ? 2 : 0);
        continue;
      }
      s.nextDay();
    }
    expect(s.outcome, BaseOutcome.lost);
    expect(s.lostCause, 'launch');
  });

  test('a saved game comes back exactly', () {
    final s = BaseState(moonMissions[3], level: Level.engineer);
    for (var i = 0; i < 9; i++) {
      if (s.pendingEvent != null) {
        s.choose(1);
      } else {
        s.nextDay();
      }
    }
    s.adjust(Sys.greenhouse, 0.8);
    final back = BaseState.fromJson(s.toJson(), baseMission)!;
    expect(back.toJson().toString(), s.toJson().toString());
    // and both go on the same way
    for (var i = 0; i < 6; i++) {
      for (final x in [s, back]) {
        if (x.pendingEvent != null) {
          x.choose(0);
        } else {
          x.nextDay();
        }
      }
    }
    expect(back.toJson().toString(), s.toJson().toString());
  });
}
