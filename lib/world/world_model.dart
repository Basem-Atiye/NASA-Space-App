/// The 2D story world: a side-scrolling strip of the lunar south pole.
///
/// Pure Dart, so walking, reaching objects and auto-walk can be tested
/// without Flutter. Positions are in metres along the ground.
library;

import 'dart:math' as math;

/// Where everything stands along the strip (metres from the left edge).
const worldLayout = <String, double>{
  'radio': 6,
  'site:A': 10,
  'kit': 15,
  'lander': 26,
  'o2': 35,
  'aid': 40,
  'tools': 46,
  'battery': 54,
  'cable': 58.5,
  'habitat': 69,
  'site:B': 69,
  'antenna': 80,
  'crate': 86,
  'panels': 93,
  'site:C': 124,
  // Season 2, Cadet and Engineer levels
  'helmet': 21,
  'gloves': 31,
  'boots': 43,
  'pack': 49,
  'part': 51,
  'food': 62,
  'filter': 65,
  'seed': 74,
  'water': 77,
  'camera': 83,
  'sensor': 89,
  'battpack': 96,
  'rock1': 99,
  'flag': 102,
  'rover': 106,
  'rock2': 110,
  'greenhouse': 114,
  'drill': 120,
  'ice': 126,
  'rock3': 129,
  'pad': 134,
};

/// Ids that are the same place for the story (the habitat's airlock is the
/// habitat; the solar array is the panels).
const worldAliases = <String, String>{'airlock': 'habitat', 'solar': 'panels', 'rocket': 'pad', 'crater': 'site:C', 'rim': 'site:A', 'dish': 'antenna', 'base': 'habitat'};

class WorldEvent {
  /// near (id may be null: walked away), arrived.
  final String type;
  final String? id;
  const WorldEvent(this.type, this.id);
  @override
  String toString() => '$type:$id';
}

class WorldModel {
  static const length = 140.0;
  static const walkSpeed = 3.0; // m/s, a brisk low-gravity lope
  static const sprintSpeed = 5.2; // m/s, bounding like the Apollo crews
  static const reach = 2.6; // metres: close enough to use something
  static const gravity = 1.62; // m/s², the Moon
  /// Walking push-off: about 12 cm and 0.8 s in the air, one foot leading.
  static const lopeHop = 0.62;
  /// Sprint bound: about 34 cm and 1.3 s, both feet leaving together.
  static const boundSpeed = 1.05;
  static const jumpSpeed = 2.0; // m/s up for a jump: about 1.2 m high, 2.5 s in the air

  /// Height of Nova's feet above the ground (metres) and vertical speed.
  double novaY = 0;
  double vy = 0;

  /// The player is holding sprint (or pushing the stick to its edge).
  bool sprintHeld = false;

  /// Bounding right now (sprint held and running fast enough).
  bool sprinting = false;

  /// Bumped on every footstep and every landing (for dust, prints and sound).
  int steps = 0;
  int landings = 0;
  double lastLandSpeed = 0;
  double _lastStepPhase = 0;

  /// Seconds the boots stay in the dust after a landing, before the next push.
  double _plant = 0;

  bool get airborne => novaY > 0 || vy > 0;

  /// A Moon jump. Returns false when already in the air.
  bool jump() {
    if (airborne || frozen) return false;
    vy = jumpSpeed;
    return true;
  }

  double novaX;
  double velocity = 0;

  /// 1 facing right, -1 facing left.
  int facing = 1;

  /// Advances while walking; drives the leg cycle and the bounce.
  double walkPhase = 0;

  /// Joystick input, -1 (left) .. 1 (right).
  double input = 0;

  /// Auto-walk: an object id and/or a point to walk to.
  String? walkTarget;
  double? walkX;

  /// Objects that can be reached right now (the story decides).
  Set<String> active = {};

  /// Everything drawn in the world (for scanning and tapping).
  Set<String> present = {};

  String? near;

  /// Seconds Nova has stood still (for idle animation).
  double idle = 0;

  bool frozen = false;

  WorldModel({this.novaX = 26});

  static double xOf(String id) => worldLayout[id] ?? worldLayout[worldAliases[id]] ?? worldLayout[id.startsWith('pickup:') ? id.substring(7) : id] ?? 50;

  bool get walking => velocity.abs() > 0.05;

  void walkTo(String id) {
    walkTarget = id;
    walkX = xOf(id);
  }

  void walkToX(double x) {
    walkTarget = null;
    walkX = x.clamp(2, length - 2).toDouble();
  }

  void stop() {
    walkTarget = null;
    walkX = null;
    input = 0;
    velocity = 0;
    sprintHeld = false;
    sprinting = false;
    _plant = 0;
  }

  /// The object at [x] (a tap on the ground), from [ids], within [tolerance].
  String? objectAt(double x, Iterable<String> ids, {double tolerance = 3.2}) {
    String? best;
    var bestD = tolerance;
    for (final id in ids) {
      final d = (xOf(id) - x).abs();
      if (d < bestD) {
        bestD = d;
        best = id;
      }
    }
    return best;
  }

  /// The closest of [ids] to Nova, within [range].
  String? nearestOf(Iterable<String> ids, {double range = 9}) {
    String? best;
    var bestD = range;
    for (final id in ids) {
      final d = (xOf(id) - novaX).abs();
      if (d < bestD) {
        bestD = d;
        best = id;
      }
    }
    return best;
  }

  List<WorldEvent> update(double dt) {
    final events = <WorldEvent>[];
    var target = 0.0;
    final wantSprint = (sprintHeld || input.abs() >= 0.93) && input.abs() > 0.08 && !frozen;
    if (!frozen) {
      if (input.abs() > 0.08) {
        // the joystick always wins over auto-walk
        walkTarget = null;
        walkX = null;
        target = wantSprint ? input.sign * sprintSpeed : input.clamp(-1.0, 1.0) * walkSpeed;
      } else if (walkX != null) {
        final d = walkX! - novaX;
        // stop just short of the object, not inside it
        final stopAt = walkTarget != null ? 1.1 : 0.15;
        if (d.abs() <= stopAt) {
          final id = walkTarget;
          walkTarget = null;
          walkX = null;
          if (id != null) events.add(WorldEvent('arrived', id));
        } else {
          target = d.sign * walkSpeed * math.min(1.0, d.abs() / 1.5 + 0.35);
        }
      }
    }
    // Dust has little grip, so stopping slides. Speed is made on the push-off;
    // in the air she mostly keeps the speed she already has.
    final air = airborne;
    final settling = walkX != null && (walkX! - novaX).abs() < 2.4;
    final rate = air ? 0.35 : (settling ? 5.5 : (target.abs() > velocity.abs() ? 3.4 : 2.4));
    velocity += (target - velocity) * (1 - math.exp(-dt * rate));
    if (velocity.abs() < 0.02 && target == 0) velocity = 0;
    novaX = (novaX + velocity * dt).clamp(1.5, length - 1.5).toDouble();
    if (velocity.abs() > 0.1 && !air) facing = velocity > 0 ? 1 : -1;

    sprinting = wantSprint && velocity.abs() > walkSpeed * 0.85;

    // Moon gravity, then a push only after the knees have finished the landing.
    if (airborne) {
      vy -= gravity * dt;
      novaY += vy * dt;
      if (novaY <= 0) {
        lastLandSpeed = -vy;
        novaY = 0;
        vy = 0;
        landings++;
        steps++;
        events.add(const WorldEvent('land', null));
        _plant = sprinting ? 0.12 : 0.1;
      }
    } else if (_plant > 0) {
      _plant = math.max(0, _plant - dt);
    }

    // One smooth stride per hop. The phase keeps moving in the air and
    // on the ground, so the legs never snap to a new pose.
    if (walking || airborne) {
      final period = sprinting ? 1.48 : 0.92;
      walkPhase += dt / period;
    }

    final grounded = !airborne && _plant <= 0;
    if (!frozen && grounded && !settling && velocity.abs() > 0.5) {
      // The push is where the speed comes from: one foot for a walk, both for a bound.
      velocity += (target - velocity) * (sprinting ? 0.28 : 0.22);
      vy = sprinting ? boundSpeed : lopeHop;
      _lastStepPhase = (walkPhase * 2).floorToDouble();
      steps++;
      events.add(const WorldEvent('step', null));
    } else if (walking && !airborne && (settling || velocity.abs() <= 0.5)) {
      // Creeping up to an object: short steps, boots stay down.
      final half = (walkPhase * 2).floorToDouble();
      if (half != _lastStepPhase) {
        _lastStepPhase = half;
        steps++;
        events.add(const WorldEvent('step', null));
      }
    }

    if (walking) {
      idle = 0;
    } else {
      idle += dt;
    }

    // what is Nova standing next to?
    String? n;
    var best = reach;
    for (final id in active) {
      final d = (xOf(id) - novaX).abs();
      if (d <= best) {
        best = d;
        n = id;
      }
    }
    if (n != near) {
      near = n;
      events.add(WorldEvent('near', n));
    }
    return events;
  }

  /// Face toward an object (when talking about it or using it).
  void face(String id) {
    final d = xOf(id) - novaX;
    if (d.abs() > 0.2) facing = d > 0 ? 1 : -1;
  }
}
