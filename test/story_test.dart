import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/data/story.dart';
import 'package:shackleton_station/story/story_logic.dart';
import 'package:shackleton_station/story/story_model.dart';
import 'package:shackleton_station/story/story_run.dart';

/// Plays a step perfectly, the way a careful player would.
void playStepWell(StoryRun r) {
  final s = r.step;
  switch (s.kind) {
    case StepKind.talk:
      r.continueTalk();
      break;
    case StepKind.goTo:
      r.arrive(s.target);
      r.use();
      break;
    case StepKind.collect:
      for (final i in s.items) {
        r.arrive(i.startsWith('site:') ? i : 'pickup:$i');
      }
      break;
    case StepKind.choice:
      r.choose(s.options.firstWhere((o) => !o.mistake).id);
      break;
    case StepKind.game:
      final data = <String, Object>{};
      if (s.id == 't2_materials') data['shielding'] = 6;
      if (s.id == 't4_rations') {
        data['food'] = 0.55;
        data['water'] = 2.1;
      }
      r.finishGame(GameResult(mistakes: 0, data: data));
      break;
  }
}

StoryRun playTask(int n, Carry carry) {
  final r = StoryRun(storyTask(n), carry);
  var guard = 0;
  while (!r.finished && guard++ < 100) {
    playStepWell(r);
  }
  return r;
}

void main() {
  test('the whole campaign can be won with 3 stars on every task', () {
    final carry = Carry();
    for (final t in storyTasks) {
      final r = playTask(t.n, carry);
      expect(r.outcome, TaskOutcome.complete, reason: 'task ${t.n}: ${r.failReason}');
      expect(r.stars, 3, reason: 'task ${t.n} health ${r.carry.health} mistakes ${r.mistakes}');
    }
    expect(carry.health, greaterThanOrEqualTo(80));
    expect(carry.o2Kg, greaterThan(0));
    expect(carry.foodKg, greaterThanOrEqualTo(0));
  });
  
  test('every task can also be started on its own', () {
    for (final t in storyTasks) {
      final r = playTask(t.n, Carry.defaultsFor(t.n));
      expect(r.outcome, TaskOutcome.complete, reason: 'task ${t.n}');
    }
  });

  test('mini-game specs are consistent', () {
    for (final t in storyTasks) {
      for (final s in t.steps) {
        final g = s.game;
        if (s.kind == StepKind.game) expect(g != null, isTrue, reason: s.id);
        if (s.kind == StepKind.choice) expect(s.options.where((o) => !o.mistake).length, greaterThanOrEqualTo(1), reason: s.id);
        if (g == null) continue;
        if (g.kind == GameKind.order) {
          expect(g.answer.length, g.items.length, reason: s.id);
          expect(g.answer.toSet().length, g.items.length, reason: s.id);
        }
        if (g.kind == GameKind.wire) {
          expect(g.answer.length, g.items.length, reason: s.id);
          expect(g.right.length, g.items.length, reason: s.id);
          expect(g.answer.toSet().length, g.items.length, reason: s.id);
        }
        if (g.kind == GameKind.probe || g.kind == GameKind.checklist) {
          expect(g.readings.length, g.items.length, reason: s.id);
          expect(g.faulty.every((i) => i < g.items.length), isTrue, reason: s.id);
        }
        if (g.kind == GameKind.hold) expect(g.low < g.high && g.high < g.max, isTrue, reason: s.id);
      }
    }
  });

  test('Houston vetoes a bad habitat site, and it counts as a mistake', () {
    final r = StoryRun(storyTask(2), Carry.defaultsFor(2));
    while (r.step.id != 't2_site') {
      playStepWell(r);
    }
    r.choose('A');
    expect(r.step.id, 't2_site');
    expect(r.mistakes, 1);
    r.choose('B');
    expect(r.step.id, 't2_deploy');
    expect(r.carry.flags.contains('siteB'), isTrue);
  });

  test('pickups have their effects', () {
    final r = StoryRun(storyTask(1), Carry());
    while (r.step.kind != StepKind.collect) {
      playStepWell(r);
    }
    final before = r.suitO2;
    r.arrive('pickup:o2');
    expect(r.suitO2, closeTo(before + 40, 0.001));
    r.arrive('pickup:radio');
    expect(r.carry.flags.contains('radio'), isTrue);
    r.arrive('pickup:radio'); // twice does nothing
    expect(r.done.length, 2);
  });

  test('USE only works when Nova is at the target', () {
    final r = StoryRun(storyTask(1), Carry());
    r.continueTalk();
    expect(r.step.kind, StepKind.goTo);
    expect(r.use(), isFalse);
    r.arrive('habitat');
    expect(r.use(), isFalse);
    r.arrive('lander');
    expect(r.use(), isTrue);
  });

  test('standing outside too long in Task 1 uses up the suit and hurts Nova', () {
    final r = StoryRun(storyTask(1), Carry());
    r.continueTalk();
    for (var i = 0; i < 800; i++) {
      r.tick(1);
    }
    expect(r.suitO2, 0);
    expect(r.outcome, TaskOutcome.failed);
  });

  void _reachHazardsDust(StoryRun r) {
    expect(r.step.id, 't6_to_panels');
    r.arrive('panels');
    r.use();
    expect(r.step.id, 't6_dust');
  }

  test('a timed hazard that runs out of time picks the risky option', () {
    final r = StoryRun(storyTask(6), Carry.defaultsFor(6));
    _reachHazardsDust(r);
    for (var i = 0; i < 25; i++) {
      r.tick(1);
    }
    expect(r.mistakes, 0, reason: 'Explorers get 30 seconds');
    for (var i = 0; i < 10; i++) {
      r.tick(1);
    }
    expect(r.mistakes, 1);
    expect(r.step.id, 't6_clean');
  });

  test('age modes: Engineers get 15 s, Cadets have no clock and no suit drain', () {
    final eng = StoryRun(storyTask(6), Carry.defaultsFor(6), mode: AgeMode.engineer);
    _reachHazardsDust(eng);
    expect(eng.timer, 15);
    final cadet = StoryRun(storyTask(6), Carry.defaultsFor(6), mode: AgeMode.cadet);
    _reachHazardsDust(cadet);
    expect(cadet.timer, 0);
    for (var i = 0; i < 100; i++) {
      cadet.tick(1);
    }
    expect(cadet.mistakes, 0);
    expect(cadet.step.id, 't6_dust');

    final c1 = StoryRun(storyTask(1), Carry(), mode: AgeMode.cadet);
    c1.continueTalk();
    for (var i = 0; i < 2000; i++) {
      c1.tick(1);
    }
    expect(c1.suitO2, greaterThan(50));
    expect(c1.outcome, TaskOutcome.running);
  });

  test('age modes: a Cadet mistake is retried, an Engineer one moves on', () {
    final cadet = StoryRun(storyTask(6), Carry.defaultsFor(6), mode: AgeMode.cadet);
    _reachHazardsDust(cadet);
    final bad = cadet.step.options.firstWhere((o) => o.mistake);
    cadet.choose(bad.id);
    expect(cadet.step.id, 't6_dust');
    expect(cadet.mistakes, 1);
    final eng = StoryRun(storyTask(6), Carry.defaultsFor(6), mode: AgeMode.engineer);
    _reachHazardsDust(eng);
    eng.choose(bad.id);
    expect(eng.step.id, isNot('t6_dust'));
  });

  test('hints cost one star for Explorers and Engineers, never for Cadets', () {
    for (final m in AgeMode.values) {
      final r = StoryRun(storyTask(3), Carry.defaultsFor(3), mode: m);
      r.useHint();
      r.useHint();
      var guard = 0;
      while (!r.finished && guard++ < 100) {
        playStepWell(r);
      }
      expect(r.stars, m == AgeMode.cadet ? 3 : 2, reason: m.name);
    }
  });

  test('thin shielding from Task 2 costs extra dose in the solar storm', () {
    StoryRun runWith(int shielding) {
      final c = Carry.defaultsFor(6)..shielding = shielding;
      final r = StoryRun(storyTask(6), c);
      while (r.step.id != 't6_spe') {
        playStepWell(r);
      }
      r.choose('shelter');
      return r;
    }

    final good = runWith(6), thin = runWith(3);
    expect(thin.carry.dose, greaterThan(good.carry.dose + 5));
    expect(thin.mistakes, 1);
    expect(good.mistakes, 0);
  });

  test('materials split carries over as shielding and spares', () {
    final r = StoryRun(storyTask(2), Carry.defaultsFor(2));
    while (r.step.id != 't2_materials') {
      playStepWell(r);
    }
    r.finishGame(const GameResult(mistakes: 0, data: {'shielding': 7}));
    expect(r.carry.shielding, 7);
    expect(r.carry.spares, 3);
    expect(materialsVerdict(4, 10).ok, isFalse);
    expect(materialsVerdict(6, 10).ok, isTrue);
    expect(materialsVerdict(9, 10).ok, isFalse);
  });

  test('stars: 3 for clean, 2 for up to 2 mistakes, else 1', () {
    expect(storyStars(0, 90), 3);
    expect(storyStars(0, 70), 2);
    expect(storyStars(2, 100), 2);
    expect(storyStars(3, 100), 1);
  });

  test('ration plan follows NASA numbers and the 12-day rescue window', () {
    final good = rationVerdict(foodPerDay: 0.55, waterPerDay: 2.1, foodStock: 8, waterStock: 30, days: rescueDays);
    expect(good.ok, isTrue);
    final hungry = rationVerdict(foodPerDay: 0.4, waterPerDay: 2.1, foodStock: 8, waterStock: 30, days: rescueDays);
    expect(hungry.ok, isFalse);
    final greedy = rationVerdict(foodPerDay: 0.62, waterPerDay: 2.37, foodStock: 8, waterStock: 30, days: rescueDays);
    expect(greedy.ok, isFalse);
  });

  test('controller: recommended rules pass all four tests', () {
    final r = ControllerRules(o2On: 19, o2Off: 20.5, pOn: 90, pOff: 98, heatOn: 18, fanOn: 26);
    for (final t in runAllTests(r)) {
      expect(t.passed, isTrue, reason: '${t.title}: ${t.verdict}');
    }
  });

  test('controller: the default rules fail, and no gap makes the valve chatter', () {
    expect(runAllTests(ControllerRules()).any((t) => !t.passed), isTrue);
    final chatter = runTest(TestId.sleep, ControllerRules(o2On: 19.5, o2Off: 19.5));
    expect(chatter.passed, isFalse);
    expect(chatter.switches, greaterThan(maxSwitches));
    expect(chatter.verdict, contains('gap'));
  });

  test('cascade spreads from the cable to everything downstream', () {
    final w = cascadeWaves(cascadeRoot);
    expect(w[0].join(), 'cable');
    expect(w[1].join(), 'bus');
    expect(w[2].length, 4);
    expect(w[2].contains('life'), isTrue);
    expect(cascadeWaves('solar').length, 5);
  });

  test('probe, hold and tune rules', () {
    expect(scoreProbe(faulty: {0, 1}, marked: {0, 1}, probesUsed: 3, probesAllowed: 4), 0);
    expect(scoreProbe(faulty: {0, 1}, marked: {0, 2}, probesUsed: 3, probesAllowed: 4), 2);
    expect(holdVerdict(95, 92, 98), HoldVerdict.good);
    expect(holdVerdict(100, 92, 98), HoldVerdict.over);
    expect(panelOutput(132, 132), closeTo(1, 1e-9));
    expect(panelOutput(192, 132), closeTo(0.5, 1e-9));
    expect(panelAimed(139, 132), isTrue);
    expect(panelAimed(145, 132), isFalse);
  });

  test('the final message is the one from the master task order', () {
    expect(finalMessage, 'Mission accomplished! Your engineering decisions helped you survive the Moon and return home safely.');
  });
}
