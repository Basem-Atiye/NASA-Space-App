import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/data/encyclopedia.dart';
import 'package:shackleton_station/data/levels.dart';
import 'package:shackleton_station/data/story.dart';
import 'package:shackleton_station/story/story_model.dart';
import 'package:shackleton_station/world/world_model.dart';

void main() {
  test('every story target and pickup has a place in the world', () {
    for (final t in storyTasks) {
      for (final s in t.steps) {
        if (s.kind == StepKind.goTo) expect(worldLayout.containsKey(s.target) || worldAliases.containsKey(s.target), isTrue, reason: s.target);
        for (final i in s.items) {
          expect(worldLayout.containsKey(i), isTrue, reason: i);
        }
      }
    }
  });

  test('auto-walk reaches the object and reports arrival and nearness', () {
    final w = WorldModel(novaX: 26)..active = {'battery'};
    w.walkTo('battery');
    final events = <String>[];
    for (var i = 0; i < 600 && w.walkX != null; i++) {
      events.addAll(w.update(1 / 60).map((e) => '$e'));
    }
    expect(events.contains('arrived:battery'), isTrue);
    expect(events.contains('near:battery'), isTrue);
    expect(w.near, 'battery');
    expect((w.novaX - WorldModel.xOf('battery')).abs(), lessThanOrEqualTo(WorldModel.reach));
  });

  test('the joystick walks, turns and overrides auto-walk', () {
    final w = WorldModel(novaX: 50);
    w.walkTo('lander');
    w.input = 1;
    for (var i = 0; i < 60; i++) {
      w.update(1 / 60);
    }
    expect(w.novaX, greaterThan(51.5));
    expect(w.facing, 1);
    expect(w.walkTarget, isNull);
    w.input = -1;
    for (var i = 0; i < 90; i++) {
      w.update(1 / 60);
    }
    expect(w.facing, -1);
  });

  test('Nova never leaves the strip', () {
    final w = WorldModel(novaX: 3)..input = -1;
    for (var i = 0; i < 300; i++) {
      w.update(1 / 60);
    }
    expect(w.novaX, greaterThanOrEqualTo(1.5));
  });

  test('walking away clears what Nova is near', () {
    final w = WorldModel(novaX: WorldModel.xOf('crate'))..active = {'crate'};
    w.update(0.016);
    expect(w.near, 'crate');
    w.input = -1;
    for (var i = 0; i < 120; i++) {
      w.update(1 / 60);
    }
    expect(w.near, isNull);
  });

  test('tapping picks the closest object within reach', () {
    final w = WorldModel();
    expect(w.objectAt(54.5, ['battery', 'cable', 'habitat']), 'battery');
    expect(w.objectAt(110, ['battery', 'habitat']), isNull);
  });

  test('every level has its lesson, NASA card and journal; facts are unique', () {
    for (final t in storyTasks) {
      final l = levelInfo(t.n);
      expect(l.moral.isNotEmpty && l.nasaDoes.isNotEmpty && l.journal.isNotEmpty, isTrue, reason: '${t.n}');
      expect(l.minutes.length, 3);
    }
    final ids = encyclopedia.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(encyclopedia.length, greaterThanOrEqualTo(30));
  });

  test('age modes: timers and suit drain dials', () {
    expect(AgeMode.cadet.timerFor(20), 0);
    expect(AgeMode.explorer.timerFor(20), 30);
    expect(AgeMode.engineer.timerFor(20), 15);
    expect(AgeMode.engineer.timerFor(0), 0);
    expect(AgeMode.cadet.suitDrainScale, 0);
    expect(AgeModeInfo.parse('engineer'), AgeMode.engineer);
    expect(AgeModeInfo.parse(null), AgeMode.explorer);
  });

  test('Moon walk: sprinting is faster, steps and landings are reported', () {
    double run(bool sprint) {
      // a full push of the stick also sprints, so walking uses 0.85
      final w = WorldModel(novaX: 20)
        ..input = sprint ? 1 : 0.85
        ..sprintHeld = sprint;
      for (var i = 0; i < 240; i++) {
        w.update(1 / 60);
      }
      return w.novaX - 20;
    }

    final walk = run(false), sprint = run(true);
    expect(sprint, greaterThan(walk * 1.4));
    final w = WorldModel(novaX: 20)..input = 0.85;
    final ev = <String>[];
    for (var i = 0; i < 180; i++) {
      ev.addAll(w.update(1 / 60).map((e) => e.type));
    }
    expect(ev.contains('step'), isTrue);
  });

  test('a Moon jump is slow and high, then Nova lands', () {
    final w = WorldModel(novaX: 30);
    w.jump();
    var top = 0.0, t = 0.0;
    var landed = false;
    for (var i = 0; i < 600; i++) {
      final ev = w.update(1 / 60);
      t += 1 / 60;
      if (w.novaY > top) top = w.novaY;
      if (ev.any((e) => e.type == 'land')) {
        landed = true;
        break;
      }
    }
    expect(landed, isTrue);
    // v = 2 m/s, g = 1.62: about 1.2 m high and 2.5 s in the air (on Earth: 0.2 m, 0.4 s)
    expect(top, closeTo(2.0 * 2.0 / (2 * WorldModel.gravity), 0.08));
    expect(t, closeTo(2 * 2.0 / WorldModel.gravity, 0.1));
  });
}
