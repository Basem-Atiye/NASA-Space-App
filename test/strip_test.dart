import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/base/base_strip.dart';

void run(BaseStrip s, double secs, {bool shelter = false, void Function(Spot)? onArrive}) {
  for (var t = 0.0; t < secs; t += 1 / 60) {
    final a = s.update(1 / 60, shelter: shelter);
    if (a != null) onArrive?.call(a);
  }
}

void main() {
  test('buildings sit in order along the strip and do not overlap', () {
    final xs = Spot.values.map((s) => spotX[s]!).toList();
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]));
      final gap = (spotX[Spot.values[i]]! - spotHalf[Spot.values[i]]!) - (spotX[Spot.values[i - 1]]! + spotHalf[Spot.values[i - 1]]!);
      expect(gap, greaterThan(1.5));
    }
    expect(spotX[Spot.power]! - spotHalf[Spot.power]!, greaterThan(1.5));
    expect(spotX[Spot.lab]! + spotHalf[Spot.lab]!, lessThan(stripLength - 1.5));
  });

  test('walking to a building arrives there and reports it once', () {
    final s = BaseStrip(start: 30);
    final got = <Spot>[];
    s.goTo(Spot.lab);
    run(s, 12, onArrive: got.add);
    expect(got.length, 1);
    expect(got.first, Spot.lab);
    expect((s.x - spotX[Spot.lab]!).abs(), lessThan(1.5));
    expect(s.nearIn(Spot.values.toSet()), Spot.lab);
  });

  test('the joystick walks; at its edge she bounds faster and leaves prints and dust', () {
    final a = BaseStrip(start: 10);
    a.steer(0.6);
    run(a, 2);
    final walked = a.x - 10;
    final b = BaseStrip(start: 10);
    b.steer(1);
    b.setSprint(true);
    run(b, 2);
    expect(b.x - 10, greaterThan(walked * 1.3));
    expect(b.prints, isNotEmpty);
    expect(b.world.sprinting, isTrue);
  });

  test('she never leaves the strip', () {
    final s = BaseStrip(start: 55);
    s.steer(1);
    s.setSprint(true);
    run(s, 10);
    expect(s.x, lessThanOrEqualTo(stripLength - 1.5));
    s.steer(-1);
    run(s, 30);
    expect(s.x, greaterThanOrEqualTo(1.5));
  });

  test('the joystick cancels a walk to a building', () {
    final s = BaseStrip(start: 30);
    final got = <Spot>[];
    s.goTo(Spot.lab);
    run(s, 0.5, onArrive: got.add);
    s.steer(-1);
    run(s, 1, onArrive: got.add);
    s.steer(0);
    run(s, 6, onArrive: got.add);
    expect(got, isEmpty);
  });

  test('a Moon jump is slow and high', () {
    final s = BaseStrip(start: 30);
    expect(s.jump(), isTrue);
    expect(s.jump(), isFalse);
    var t = 0.0, top = 0.0;
    while (t < 5) {
      s.update(1 / 60);
      t += 1 / 60;
      if (s.world.novaY > top) top = s.world.novaY;
      if (t > 0.1 && !s.airborne) break;
    }
    expect(top, greaterThan(1));
    expect(t, greaterThan(2));
  });

  test('in a storm she goes into the habitat, then comes back out', () {
    final s = BaseStrip(start: 54);
    run(s, 12, shelter: true);
    expect(s.inside, isTrue);
    expect(s.visible, lessThan(0.05));
    expect(s.jump(), isFalse);
    run(s, 1);
    expect(s.inside, isFalse);
    expect(s.visible, greaterThan(0.9));
  });

  test('the camera follows her and stays inside the strip', () {
    final s = BaseStrip(start: 3);
    run(s, 2);
    expect(s.cam, greaterThanOrEqualTo(13 / 2 - 0.01));
    s.goTo(Spot.lab);
    run(s, 14);
    expect((s.cam - s.x).abs(), lessThan(4));
    expect(s.cam, lessThanOrEqualTo(stripLength - 13 / 2 + 0.01));
  });

  test('a tap finds the building under it', () {
    final all = Spot.values.toSet();
    expect(BaseStrip.spotAt(30, all), Spot.habitat);
    expect(BaseStrip.spotAt(11, all), isNull);
    expect(BaseStrip.spotAt(17, {Spot.power}), isNull);
  });
}
