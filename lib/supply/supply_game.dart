/// Supply Run: fly a cargo rocket from Earth to the Moon base. Pure Dart
/// rules (tested in test/supply_test.dart).
///
/// The real science: a heavier rocket needs more fuel. Every pod in the
/// hold makes the engine burn faster; a full hold burns twice as fast as an
/// empty one. You need fuel left to land.
library;

import 'dart:math' as math;

enum PodKind { oxygen, water, food, power, parts }

extension PodInfo on PodKind {
  String get title => const ['Oxygen', 'Water', 'Food', 'Power', 'Parts'][index];

  /// What one pod adds to the next mission.
  String get gain => const ['+5% Oxygen', '+5% Water', '+5% Food', '+6% Battery', '+1 Repair kit'][index];
}

class Pod {
  final int id;
  final PodKind kind;
  double x, y;
  final double r;
  Pod(this.id, this.kind, this.x, this.y, {this.r = 0.045});
}

class Rock {
  final int id;
  double x, y, spin;
  final double r;
  final double drift;
  Rock(this.id, this.x, this.y, this.r, this.drift) : spin = 0;
}

enum RunPhase { flying, cargoFull, landed }

class SupplyGame {
  final math.Random _rnd;
  static const holdSize = 10;
  static const landFuel = 22.0;

  /// Distance flown, 0 (Earth) .. 1 (Moon).
  double progress = 0;
  double fuel = 100;
  double x = 0.5; // the rocket, 0..1 across the screen
  static const rocketY = 0.8;
  final List<PodKind> hold = [];
  final List<Pod> pods = [];
  final List<Rock> rocks = [];
  int _id = 0;
  double _podTimer = 0.6, _rockTimer = 1.8;
  double boostLeft = 0;
  double hitCooldown = 0;
  int hits = 0;
  RunPhase phase = RunPhase.flying;

  /// The pod waiting while the hold is full.
  Pod? waiting;
  final List<(PodKind, double)> popups = []; // "+1 Water" labels: kind, time left
  bool roughLanding = false;
  final List<PodKind> lostOnLanding = [];

  SupplyGame({int seed = 3}) : _rnd = math.Random(seed);

  /// Fuel burned per second: more cargo, more fuel.
  double get burnRate => 0.75 * (1 + hold.length / holdSize);

  /// How fast the world scrolls (screens per second).
  double get speed => 0.22 * (boostLeft > 0 ? 1.8 : 1);

  /// Fuel needed to reach the Moon at this weight, plus the landing.
  double get fuelNeeded => (1 - progress) * 60 * burnRate + landFuel;

  void steer(double dir, double dt) {
    if (phase != RunPhase.flying) return;
    x = (x + dir * dt * 0.9).clamp(0.08, 0.92);
  }

  void steerTo(double target, double dt) {
    if (phase != RunPhase.flying) return;
    final d = target - x;
    x = (x + d.clamp(-dt * 1.6, dt * 1.6)).clamp(0.08, 0.92);
  }

  bool boost() {
    if (phase != RunPhase.flying || fuel < landFuel + 5 || boostLeft > 0) return false;
    fuel -= 5;
    boostLeft = 2.0;
    return true;
  }

  /// One step of the flight. Returns what happened ('pod', 'rock', 'full', 'landed').
  List<String> update(double dt) {
    final out = <String>[];
    for (var i = popups.length - 1; i >= 0; i--) {
      final p = popups[i];
      popups[i] = (p.$1, p.$2 - dt);
      if (popups[i].$2 <= 0) popups.removeAt(i);
    }
    if (phase != RunPhase.flying) return out;
    boostLeft = math.max(0, boostLeft - dt);
    hitCooldown = math.max(0, hitCooldown - dt);
    // the trip takes about a minute at normal speed
    progress = math.min(1, progress + dt * speed / 0.22 / 60);
    fuel = math.max(0, fuel - dt * burnRate);

    // new pods and rocks come from the top
    _podTimer -= dt * (speed / 0.22);
    if (_podTimer <= 0 && progress < 0.95) {
      _podTimer = 1.1 + _rnd.nextDouble() * 0.9;
      final kinds = PodKind.values;
      final k = _rnd.nextDouble() < 0.12 ? PodKind.parts : kinds[_rnd.nextInt(4)];
      pods.add(Pod(_id++, k, 0.12 + _rnd.nextDouble() * 0.76, -0.06));
    }
    _rockTimer -= dt * (speed / 0.22);
    if (_rockTimer <= 0 && progress < 0.95) {
      _rockTimer = 1.6 + _rnd.nextDouble() * 1.4 - progress * 0.6;
      rocks.add(Rock(_id++, 0.1 + _rnd.nextDouble() * 0.8, -0.1, 0.05 + _rnd.nextDouble() * 0.05, (_rnd.nextDouble() - 0.5) * 0.08));
    }
    for (final p in pods) {
      p.y += speed * dt;
    }
    for (final r in rocks) {
      r.y += speed * dt * 0.8;
      r.x += r.drift * dt;
      r.spin += dt * 0.6;
    }
    // catch pods
    for (final p in [...pods]) {
      if ((p.x - x).abs() < 0.08 && (p.y - rocketY).abs() < 0.07) {
        pods.remove(p);
        if (hold.length < holdSize) {
          hold.add(p.kind);
          popups.add((p.kind, 1.2));
          out.add('pod');
        } else {
          waiting = p;
          phase = RunPhase.cargoFull;
          out.add('full');
          return out;
        }
      }
    }
    // rocks
    if (hitCooldown <= 0) {
      for (final r in rocks) {
        if ((r.x - x).abs() < r.r + 0.04 && (r.y - rocketY).abs() < r.r + 0.05) {
          hitCooldown = 1.2;
          hits++;
          if (hold.isNotEmpty) hold.removeLast(); // a hit damages your cargo
          out.add('rock');
          break;
        }
      }
    }
    pods.removeWhere((p) => p.y > 1.1);
    rocks.removeWhere((r) => r.y > 1.2);
    if (progress >= 1 || fuel <= 0) {
      _land();
      out.add('landed');
    }
    return out;
  }

  void _land() {
    phase = RunPhase.landed;
    pods.clear();
    rocks.clear();
    // not enough fuel for a soft landing: some pods break
    if (fuel < landFuel) {
      roughLanding = true;
      final lose = (hold.length * 0.3).ceil();
      for (var i = 0; i < lose && hold.isNotEmpty; i++) {
        lostOnLanding.add(hold.removeLast());
      }
    }
  }

  /// Cargo full: drop the pod in [slot] and take the waiting one.
  void swap(int slot) {
    final w = waiting;
    if (w == null || slot < 0 || slot >= hold.length) return;
    hold[slot] = w.kind;
    popups.add((w.kind, 1.2));
    waiting = null;
    phase = RunPhase.flying;
  }

  void skip() {
    waiting = null;
    phase = RunPhase.flying;
  }

  int count(PodKind k) => hold.where((h) => h == k).length;

  int get stars {
    if (phase != RunPhase.landed) return 0;
    final n = hold.length;
    if (n >= 8 && !roughLanding) return 3;
    if (n >= 5) return 2;
    return n > 0 ? 1 : 0;
  }
}
