/// Small pure-Dart rules behind the 2.0 mini-games (testable without Flutter).
library;

import 'dart:math' as math;

const moonG = 1.62; // m/s²
const earthG = 9.81;
const marsG = 3.71;

/// A standing jump that leaves the ground at [v0] m/s.
double jumpHeight(double v0, double g) => v0 * v0 / (2 * g);
double hangTime(double v0, double g) => 2 * v0 / g;

/// The runner in the jump game: moves at [speed] m/s, jumps at [v0].
class JumpRunner {
  final double g;
  final double speed;
  final double v0;
  double x = 0; // metres travelled
  double y = 0; // metres above the ground
  double vy = 0;
  bool airborne = false;

  JumpRunner({this.g = moonG, this.speed = 2.6, this.v0 = 2.3});

  bool jump() {
    if (airborne) return false;
    airborne = true;
    vy = v0;
    return true;
  }

  void step(double dt) {
    x += speed * dt;
    if (airborne) {
      vy -= g * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
        airborne = false;
      }
    }
  }

  /// Horizontal distance covered in one jump.
  double get jumpLength => speed * hangTime(v0, g);
}

/// Craters ahead of the runner: [start, end] in metres.
List<(double, double)> jumpCourse(int count, {int seed = 7, double first = 9}) {
  final r = math.Random(seed);
  final list = <(double, double)>[];
  var x = first;
  for (var i = 0; i < count; i++) {
    final w = 2.2 + r.nextDouble() * 1.6;
    list.add((x, x + w));
    x += w + 8 + r.nextDouble() * 6;
  }
  return list;
}

/// Counts a rep when the motion (m/s², gravity removed) peaks above [threshold]
/// and at least [refractoryMs] passed since the last one.
class RepCounter {
  final double threshold;
  final int refractoryMs;
  int reps = 0;
  int _lastMs = -100000;
  bool _armed = true;

  RepCounter({this.threshold = 3.2, this.refractoryMs = 450});

  /// Returns true when this sample counted a rep.
  bool sample(double x, double y, double z, int ms) {
    final m = math.sqrt(x * x + y * y + z * z);
    if (m < threshold * 0.45) _armed = true;
    if (_armed && m >= threshold && ms - _lastMs >= refractoryMs) {
      reps++;
      _lastMs = ms;
      _armed = false;
      return true;
    }
    return false;
  }
}

/// Rover lanes: rocks fall down three lanes; returns the lane (0..2) for a steer value -1..1.
int laneFor(double steer) => steer < -0.33 ? 0 : (steer > 0.33 ? 2 : 1);

/// Sort game: how many items are in the wrong bin.
int sortErrors(List<int> answer, Map<int, int> placed) => [for (final e in placed.entries) if (answer[e.key] != e.value) e.key].length;
