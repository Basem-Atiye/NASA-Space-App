import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/supply/supply_game.dart';

void main() {
  test('a heavier rocket burns more fuel; a full hold burns twice as fast', () {
    final g = SupplyGame();
    final empty = g.burnRate;
    g.hold.addAll(List.filled(SupplyGame.holdSize, PodKind.water));
    expect(g.burnRate, closeTo(empty * 2, 1e-9));
  });

  test('the trip takes about a minute and ends with a landing', () {
    final g = SupplyGame();
    var t = 0.0;
    while (g.phase != RunPhase.landed && t < 200) {
      final ev = g.update(1 / 30);
      if (g.phase == RunPhase.cargoFull) g.skip();
      // steer towards the nearest pod, like a player would
      if (g.pods.isNotEmpty) {
        final p = g.pods.reduce((a, b) => (a.y - SupplyGame.rocketY).abs() < (b.y - SupplyGame.rocketY).abs() ? a : b);
        g.steerTo(p.x, 1 / 30);
      }
      expect(ev.length, lessThanOrEqualTo(3));
      t += 1 / 30;
    }
    expect(t, closeTo(60, 3));
    expect(g.phase, RunPhase.landed);
    expect(g.hold.isNotEmpty, isTrue);
  });

  test('cargo full: swap a pod or skip it', () {
    final g = SupplyGame()..hold.addAll(List.filled(SupplyGame.holdSize, PodKind.oxygen));
    g.pods.add(Pod(99, PodKind.water, g.x, SupplyGame.rocketY));
    final ev = g.update(0.01);
    expect(ev.contains('full'), isTrue);
    expect(g.phase, RunPhase.cargoFull);
    g.swap(0);
    expect(g.count(PodKind.water), 1);
    expect(g.hold.length, SupplyGame.holdSize);
    expect(g.phase, RunPhase.flying);
  });

  test('landing without enough fuel breaks some pods', () {
    final g = SupplyGame()
      ..hold.addAll(List.filled(10, PodKind.food))
      ..fuel = 10
      ..progress = 0.999;
    g.update(0.2);
    expect(g.phase, RunPhase.landed);
    expect(g.roughLanding, isTrue);
    expect(g.hold.length, 7);
  });
}
