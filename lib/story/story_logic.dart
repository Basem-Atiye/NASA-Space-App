/// Pure rules behind the Story Campaign mini-games. No Flutter here, so every
/// rule is covered by unit tests (test/story_test.dart).
library;

import 'dart:math' as math;

// ---------------------------------------------------------------- hold

/// Hold-to-fill games (inflate, torque, crimp). Released inside the band = good.
enum HoldVerdict { under, good, over }

HoldVerdict holdVerdict(double value, double low, double high) {
  if (value < low) return HoldVerdict.under;
  if (value > high) return HoldVerdict.over;
  return HoldVerdict.good;
}

// ---------------------------------------------------------------- tune

/// Solar panel output (0..1) for a dial angle, peaking at [best].
/// Output follows the cosine of the shortest angle between panel and Sun.
double panelOutput(double angle, double best) {
  var d = (angle - best) % 360;
  if (d < 0) d += 360;
  if (d > 180) d = 360 - d;
  return math.max(0, math.cos(d * math.pi / 180));
}

/// The dial is "aimed" within 8 degrees: cos(8°) = 99% of peak power.
/// Uses circular distance so 359° vs 1° is 2°, not 358°.
bool panelAimed(double angle, double best) {
  var d = (angle - best) % 360;
  if (d < 0) d += 360;
  if (d > 180) d = 360 - d;
  return d <= 8;
}

// ---------------------------------------------------------------- probe

/// Score a probe game: every faulty item marked, nothing healthy marked.
/// Returns the number of mistakes (wrong marks + missed faults + extra probes).
int scoreProbe({required Set<int> faulty, required Set<int> marked, required int probesUsed, required int probesAllowed}) {
  final wrong = marked.difference(faulty).length;
  final missed = faulty.difference(marked).length;
  final extra = probesUsed > probesAllowed ? 1 : 0;
  return wrong + missed + extra;
}

// ---------------------------------------------------------------- wire

/// A wire from left terminal to right terminal.
class Wire {
  final int left;
  final int right;
  const Wire(this.left, this.right);
}

/// True when the wire matches the answer (answer[left] == right).
bool wireOk(List<int> answer, Wire w) => w.left < answer.length && answer[w.left] == w.right;

// ---------------------------------------------------------------- allocate

/// Base materials split (Task 2): 10 units between shielding and spare parts.
/// Shielding protects the habitat in the solar storm (Task 6); spares are
/// needed for the propulsion repair (Task 8).
class MaterialsVerdict {
  final int shielding;
  final int spares;
  final List<String> warnings;
  const MaterialsVerdict(this.shielding, this.spares, this.warnings);
  bool get ok => warnings.isEmpty;
}

MaterialsVerdict materialsVerdict(int shielding, int total) {
  final spares = total - shielding;
  final w = <String>[];
  if (shielding < 5) w.add('Too little shielding: the habitat will not protect you in a solar storm.');
  if (spares < 3) w.add('Too few spare parts: you will not be able to repair the lander.');
  return MaterialsVerdict(shielding, spares, w);
}

/// Ration plan (Task 4). Amounts are kg per day for one astronaut.
class RationVerdict {
  final double daysFood;
  final double daysWater;
  final List<String> problems;
  const RationVerdict(this.daysFood, this.daysWater, this.problems);
  bool get ok => problems.isEmpty;
}

/// NASA plans 0.62 kg of food and 2.37 kg of water per crew member per day.
/// Survival minimums used in the game: 0.5 kg food, 2.0 kg water.
/// The stock must last until rescue ([days]) with a 10% reserve left over.
RationVerdict rationVerdict({
  required double foodPerDay,
  required double waterPerDay,
  required double foodStock,
  required double waterStock,
  required int days,
}) {
  final p = <String>[];
  if (foodPerDay < 0.5 - 1e-9) p.add('Below 0.5 kg of food a day Nova gets weak and makes mistakes.');
  if (waterPerDay < 2.0 - 1e-9) p.add('Below 2.0 kg of water a day Nova gets dehydrated.');
  final df = foodPerDay > 0 ? foodStock / foodPerDay : double.infinity;
  final dw = waterPerDay > 0 ? waterStock / waterPerDay : double.infinity;
  final need = days * 1.1;
  if (df < need) p.add('Food runs out on day ${df.floor()}: you need $days days plus a 10% reserve.');
  if (dw < need) p.add('Water runs out on day ${dw.floor()}: you need $days days plus a 10% reserve.');
  return RationVerdict(df, dw, p);
}

// ---------------------------------------------------------------- rules (WOW)

/// The life-support controller the player programs in Task 5.
/// Each rule is "IF sensor < on THEN actuator ON, IF sensor > off THEN OFF".
class ControllerRules {
  double o2On; // open O2 valve when O2 % drops below this
  double o2Off; // close it above this
  double pOn; // repressurise below (kPa)
  double pOff; // stop above (kPa)
  double heatOn; // heater on below (°C), off 2 °C above
  double fanOn; // fan on above (°C), off 2 °C below

  ControllerRules({
    this.o2On = 18.0,
    this.o2Off = 18.2,
    this.pOn = 80,
    this.pOff = 82,
    this.heatOn = 10,
    this.fanOn = 34,
  });

  ControllerRules copy() => ControllerRules(o2On: o2On, o2Off: o2Off, pOn: pOn, pOff: pOff, heatOn: heatOn, fanOn: fanOn);
}

/// Safe ranges for the crew. O2 above 23% is a fire risk; below 18.5% causes
/// hypoxia. Cabin pressure and temperature follow ISS-style comfort ranges.
class SafeRange {
  final String name;
  final String unit;
  final double low;
  final double high;
  const SafeRange(this.name, this.unit, this.low, this.high);
}

const safeO2 = SafeRange('Oxygen', '%', 18.5, 23.0);
const safePressure = SafeRange('Pressure', 'kPa', 88, 103);
const safeTemp = SafeRange('Temperature', '°C', 16, 27);

enum TestId { sleep, leak, chill, exercise }

class TestRun {
  final TestId id;
  final String title;
  final String sensor;
  final SafeRange safe;
  final List<double> values;
  final List<bool> actuator;
  final int switches;
  final bool passed;
  final String verdict;
  const TestRun(this.id, this.title, this.sensor, this.safe, this.values, this.actuator, this.switches, this.passed, this.verdict);
}

/// Above this many on/off switches in 2 hours the actuator is "chattering"
/// and would wear out. Leaving a gap between on and off (hysteresis) fixes it.
const maxSwitches = 12;

TestRun runTest(TestId id, ControllerRules r) {
  const steps = 120; // minutes
  final values = <double>[];
  final act = <bool>[];
  var on = false;
  var switches = 0;
  double v;
  late final SafeRange safe;
  late final String title, sensor;
  switch (id) {
    case TestId.sleep:
      title = 'Crew asleep: oxygen slowly used up';
      sensor = 'O2';
      safe = safeO2;
      v = 20.0;
      break;
    case TestId.leak:
      title = 'Slow leak: pressure drops';
      sensor = 'P';
      safe = safePressure;
      v = 96;
      break;
    case TestId.chill:
      title = 'Lunar night: cabin cools';
      sensor = 'T';
      safe = safeTemp;
      v = 20;
      break;
    case TestId.exercise:
      title = 'Exercise: cabin heats up';
      sensor = 'T';
      safe = safeTemp;
      v = 22;
      break;
  }
  var ok = true;
  for (var i = 0; i < steps; i++) {
    final was = on;
    switch (id) {
      case TestId.sleep:
        if (v < r.o2On) on = true;
        if (v > r.o2Off) on = false;
        v += -0.03 + (on ? 0.12 : 0);
        break;
      case TestId.leak:
        if (v < r.pOn) on = true;
        if (v > r.pOff) on = false;
        v += -0.15 + (on ? 0.6 : 0);
        break;
      case TestId.chill:
        if (v < r.heatOn) on = true;
        if (v > r.heatOn + 2) on = false;
        v += -0.09 + (on ? 0.3 : 0);
        break;
      case TestId.exercise:
        if (v > r.fanOn) on = true;
        if (v < r.fanOn - 2) on = false;
        v += 0.1 - (on ? 0.32 : 0);
        break;
    }
    if (on != was) switches++;
    values.add(v);
    act.add(on);
    if (v < safe.low || v > safe.high) ok = false;
  }
  String verdict;
  if (!ok) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    verdict = lo < safe.low
        ? '${safe.name} fell to ${lo.toStringAsFixed(1)} ${safe.unit}, below the safe ${safe.low.toStringAsFixed(1)}. Switch on earlier.'
        : '${safe.name} rose to ${hi.toStringAsFixed(1)} ${safe.unit}, above the safe ${safe.high.toStringAsFixed(1)}. Switch off sooner.';
  } else if (switches > maxSwitches) {
    ok = false;
    verdict = 'Safe, but the actuator switched $switches times in 2 hours. Leave a bigger gap between ON and OFF so it does not wear out.';
  } else {
    verdict = 'Pass: stayed between ${safe.low.toStringAsFixed(1)} and ${safe.high.toStringAsFixed(1)} ${safe.unit}, $switches switches.';
  }
  return TestRun(id, title, sensor, safe, values, act, switches, ok, verdict);
}

List<TestRun> runAllTests(ControllerRules r) => [for (final t in TestId.values) runTest(t, r)];

// ---------------------------------------------------------------- cascade (WOW)

/// The power system as a dependency graph (Task 9). Each node depends on the
/// nodes listed for it; when a node fails, everything downstream fails next.
class SysNode {
  final String id;
  final String label;
  final List<String> dependsOn;
  final double x; // layout, 0..1
  final double y;
  const SysNode(this.id, this.label, this.dependsOn, this.x, this.y);
}

const systemGraph = <SysNode>[
  SysNode('solar', 'Solar panels', [], 0.06, 0.25),
  SysNode('battery', 'Battery', ['solar'], 0.24, 0.5),
  SysNode('cable', 'Battery → bus cable', ['battery'], 0.44, 0.5),
  SysNode('bus', 'Main power bus', ['cable'], 0.62, 0.5),
  SysNode('life', 'Life support', ['bus'], 0.84, 0.14),
  SysNode('heat', 'Heaters', ['bus'], 0.84, 0.38),
  SysNode('comms', 'Comms', ['bus'], 0.84, 0.62),
  SysNode('lander', 'Lander charging', ['bus'], 0.84, 0.86),
];

SysNode sysNode(String id) => systemGraph.firstWhere((n) => n.id == id);

/// Everything that fails, in order, when [root] fails (breadth first).
List<List<String>> cascadeWaves(String root) {
  final waves = <List<String>>[
    [root]
  ];
  final seen = {root};
  while (true) {
    final next = <String>[];
    for (final n in systemGraph) {
      if (seen.contains(n.id)) continue;
      if (n.dependsOn.any(waves.last.contains)) next.add(n.id);
    }
    if (next.isEmpty) break;
    seen.addAll(next);
    waves.add(next);
  }
  return waves;
}

/// The root cause in Task 9.
const cascadeRoot = 'cable';

/// Restore order after the cable is fixed: life support first, then heat,
/// then comms, then the lander. Returns the number of out-of-order picks.
const restoreOrder = ['life', 'heat', 'comms', 'lander'];

// ---------------------------------------------------------------- stars

/// 3 stars = no mistakes and health ≥ 80; 2 stars = up to 2 mistakes; else 1.
int storyStars(int mistakes, double health) {
  if (mistakes == 0 && health >= 80) return 3;
  if (mistakes <= 2) return 2;
  return 1;
}
