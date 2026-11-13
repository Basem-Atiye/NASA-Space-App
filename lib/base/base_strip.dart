/// The Base Commander base as a side-scrolling 2D strip, like the story
/// world: Nova walks along the ground past the solar panels, the greenhouse,
/// the habitat, the water recycler and the lab.
///
/// Pure Dart (no Flutter) so it can be tested. Positions are in metres along
/// the ground. Walking, sprinting and jumping use the story's [WorldModel],
/// so Nova moves exactly the same way in both games.
library;

import 'dart:math' as math;

import '../world/world_model.dart';

/// The buildings along the strip.
enum Spot { power, greenhouse, habitat, recycler, lab }

/// How long the strip is (metres).
const stripLength = 60.0;

/// Where each building stands (its middle, metres from the left).
const spotX = <Spot, double>{
  Spot.power: 6,
  Spot.greenhouse: 17,
  Spot.habitat: 30,
  Spot.recycler: 43,
  Spot.lab: 54,
};

/// Half the width of each building (metres): close enough to use it.
const spotHalf = <Spot, double>{
  Spot.power: 3.4,
  Spot.greenhouse: 4.0,
  Spot.habitat: 5.0,
  Spot.recycler: 3.8,
  Spot.lab: 3.4,
};

/// What Nova does for a moment (working, cheering, waving).
enum StripEmote { work, kneel, cheer, wave }

/// A dust grain kicked up by a boot: it flies on its own arc and lands
/// (there is no air on the Moon to make a cloud).
class Grain {
  double x, y, vx, vy, life;
  final double size;
  Grain(this.x, this.y, this.vx, this.vy, this.size) : life = 1.4;
}

class BaseStrip {
  final WorldModel world;

  /// The camera's middle (metres), easing after Nova.
  double cam;

  /// The building Nova is walking to (its panel opens when she gets there).
  Spot? goingTo;

  /// What Nova is doing for a moment, and for how long.
  StripEmote? emote;
  double emoteLeft = 0;

  /// 1 just after a landing, fading (knees soak it up).
  double landLeft = 0;

  /// Boot prints: (x, facing, age in seconds).
  final List<(double, int, double)> prints = [];
  final List<Grain> grains = [];

  /// A short line in a speech bubble.
  String? saying;
  double sayFor = 0, sayAge = 0;

  /// Inside the habitat (storm shelter): she fades through the door.
  bool inside = false;
  double visible = 1;

  final math.Random _rnd;
  int _seenSteps = 0, _seenLandings = 0;

  /// Auto-travel: where she is heading (she bounds when it is far).
  double? _autoX;
  bool _settling = false;

  BaseStrip({double start = 30, int seed = 3})
      : world = WorldModel(novaX: start),
        cam = start,
        _rnd = math.Random(seed);

  double get x => world.novaX;
  bool get walking => world.walking;
  bool get airborne => world.airborne;

  /// The building Nova is standing at (close enough to use), if any.
  Spot? nearIn(Set<Spot> spots) {
    Spot? best;
    var bd = double.infinity;
    for (final s in spots) {
      final d = (spotX[s]! - x).abs();
      if (d <= spotHalf[s]! + 0.6 && d < bd) {
        bd = d;
        best = s;
      }
    }
    return best;
  }

  /// The building at a point on the ground (a tap), if any.
  static Spot? spotAt(double mx, Set<Spot> spots) {
    for (final s in spots) {
      if ((spotX[s]! - mx).abs() <= spotHalf[s]!) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- orders

  /// The joystick: -1 (left) .. 1 (right). At the edge she bounds.
  void steer(double v) {
    if (inside) return;
    if (v.abs() > 0.08) {
      goingTo = null;
      _autoX = null;
      world.walkX = null;
      world.walkTarget = null;
    }
    if (_autoX == null) world.input = v;
  }

  void setSprint(bool on) => world.sprintHeld = on && !inside;

  /// A Moon jump. Returns false when she is already in the air.
  bool jump() => !inside && world.jump();

  /// Walks to a building. Returns the seconds it will take (about).
  double goTo(Spot s) {
    if (inside) return 0;
    goingTo = s;
    _autoX = _clamp(spotX[s]!);
    final d = (spotX[s]! - x).abs();
    return d > 7 ? d / WorldModel.sprintSpeed + 0.6 : d / WorldModel.walkSpeed;
  }

  /// Walks to a point on the ground.
  void goToX(double mx) {
    if (inside) return;
    goingTo = null;
    _autoX = _clamp(mx);
  }

  void say(String line, {double secs = 2.6}) {
    saying = line;
    sayFor = secs;
    sayAge = 0;
  }

  void doEmote(StripEmote e, double secs) {
    emote = e;
    emoteLeft = secs;
  }

  static double _clamp(double v) => v.clamp(2.0, stripLength - 2).toDouble();

  // ---------------------------------------------------------------- the clock

  /// Moves everything on by [dt] seconds. [view] is how many metres the
  /// screen shows. Returns the building she just reached, if any.
  Spot? update(double dt, {double view = 13, bool shelter = false}) {
    // storm shelter: hurry to the habitat door and go inside
    if (shelter && !inside && goingTo != Spot.habitat) {
      world.input = 0;
      goTo(Spot.habitat);
    } else if (!shelter && inside) {
      inside = false;
      world.sprintHeld = false;
    }
    visible += ((inside ? 0.0 : 1.0) - visible).clamp(-dt * 3, dt * 3);

    // auto-travel: bound when far, walk when close, then step up to the spot
    final ax = _autoX;
    if (ax != null) {
      final d = ax - x;
      // hand over to the gentle walk-up early when bounding fast: in the
      // air she cannot brake, and dust has little grip
      final v = world.velocity.abs();
      if (d.abs() > 3 + v * v * 0.5) {
        world.walkX = null;
        world.input = d.sign * (d.abs() > 7 ? 1.0 : 0.75);
        world.sprintHeld = d.abs() > 7;
      } else {
        world.input = 0;
        world.sprintHeld = false;
        world.walkToX(ax);
        _autoX = null;
      }
    }
    final hadTarget = world.walkX != null;
    world.update(dt);
    // the strip is shorter than the story world
    if (world.novaX < 1.5 || world.novaX > stripLength - 1.5) {
      world.novaX = world.novaX.clamp(1.5, stripLength - 1.5).toDouble();
      world.velocity = 0;
    }
    Spot? arrived;
    if (hadTarget && world.walkX == null && goingTo != null) _settling = true;
    if (_settling && world.walkX == null && _autoX == null && goingTo != null) {
      // plant the boots: brake on the ground, then she has arrived
      if (!world.airborne) world.velocity *= math.exp(-dt * 9);
      if (world.velocity.abs() < 0.3 && !world.airborne) {
        world.velocity = 0;
        arrived = goingTo;
        goingTo = null;
        _settling = false;
        final d = spotX[arrived]! - x;
        if (d.abs() > 0.2) world.facing = d > 0 ? 1 : -1;
        if (shelter && arrived == Spot.habitat) {
          inside = true;
          world.stop();
          arrived = null;
        }
      }
    } else if (goingTo == null) {
      _settling = false;
    }

    // steps and landings: boot prints and grains of dust
    if (world.landings != _seenLandings) landLeft = 1;
    if (world.steps != _seenSteps) {
      final landed = world.landings != _seenLandings;
      _seenSteps = world.steps;
      _seenLandings = world.landings;
      if (!world.airborne) {
        prints.add((x + world.facing * 0.1, world.facing, 0));
        if (prints.length > 80) prints.removeAt(0);
        final n = landed ? (world.sprinting ? 10 : 7) : 3;
        for (var i = 0; i < n; i++) {
          grains.add(Grain(
            x + (_rnd.nextDouble() - 0.5) * 0.4,
            0,
            -world.facing * (0.3 + _rnd.nextDouble() * 1.0) + world.velocity * 0.15,
            1.0 + _rnd.nextDouble() * (landed ? 1.6 : 0.8),
            0.6 + _rnd.nextDouble() * 0.8,
          ));
        }
      }
    }
    landLeft = math.max(0, landLeft - dt / 0.22);
    for (var i = 0; i < prints.length; i++) {
      final p = prints[i];
      prints[i] = (p.$1, p.$2, p.$3 + dt);
    }
    prints.removeWhere((p) => p.$3 > 14);
    for (final g in grains) {
      g.vy -= WorldModel.gravity * dt;
      g.x += g.vx * dt;
      g.y += g.vy * dt;
      g.life -= dt;
    }
    grains.removeWhere((g) => g.y < 0 || g.life <= 0);

    if (emoteLeft > 0) {
      emoteLeft -= dt;
      if (emoteLeft <= 0 || walking) emote = null;
    }
    if (sayFor > 0) {
      sayAge += dt;
      sayFor -= dt;
      if (sayFor <= 0) saying = null;
    }

    // the camera eases after her, looking ahead the way she is going
    final want = x + world.facing * (1.2 + world.velocity.abs() * 0.25) + world.velocity * 0.3;
    cam += (want - cam) * (1 - math.exp(-dt * 2.4));
    final half = view / 2;
    cam = half * 2 >= stripLength ? stripLength / 2 : cam.clamp(half, stripLength - half).toDouble();
    return arrived;
  }
}
