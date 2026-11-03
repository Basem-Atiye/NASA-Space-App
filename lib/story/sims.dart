/// Engineering models for the SIM mini-game: sliders in, live numbers out.
///
/// Every model uses real figures (NASA life-support rates, solar flux at the
/// lunar south pole, lunar orbit periods...) and says how the numbers are
/// calculated, so Engineer players see the formula, not just the answer.
/// Pure Dart: tests check every model can be solved and does not start solved.
library;

import 'dart:math' as math;

class SimSlider {
  final String label;
  final double min;
  final double max;
  final double step;
  final double start;
  final String unit;
  const SimSlider(this.label, this.min, this.max, this.step, this.start, this.unit);

  int get divisions => ((max - min) / step).round();
}

class SimOutput {
  final String label;
  final double value;
  final String unit;

  /// Null when the number is information only.
  final bool? ok;
  final String need;
  const SimOutput(this.label, this.value, this.unit, {this.ok, this.need = ''});

  String get text => value.abs() >= 100 || value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(value.abs() >= 10 ? 1 : 2);
}

class SimModel {
  final String id;
  final String title;
  final List<SimSlider> sliders;
  final List<SimOutput> Function(List<double> v) compute;

  /// How engineers calculate it (shown under the numbers).
  final String formula;

  /// A known good setting (used by the tests and by the hint for Cadets).
  final List<double> solution;

  const SimModel({required this.id, required this.title, required this.sliders, required this.compute, required this.formula, required this.solution});

  List<double> get start => [for (final s in sliders) s.start];

  /// Solved when every output that has a target is ok.
  bool solved(List<double> v) => compute(v).every((o) => o.ok != false);
}

// ---- constants (NASA figures used across the models)
const o2PerPersonKg = 0.84; // kg O2 per person per day
const waterPerPersonKg = 2.37; // drinking + food prep, kg/day
const foodPerPersonKg = 0.62; // dry food, kg/day
const co2PerPersonKg = 1.0; // kg CO2 exhaled per day
const solarFluxW = 1361.0; // W/m² at 1 AU
const lunarNightHoursPole = 100.0; // longest dark period on the crater rim, hours (about 4 days)
const earthMoonLightS = 1.28; // one-way light time, seconds

final Map<String, SimModel> sims = {
  for (final m in <SimModel>[
    // Engineer 1 · Launch Window
    SimModel(
      id: 'launch_window',
      title: 'Launch to meet the Gateway',
      sliders: const [SimSlider('Launch delay', 0, 360, 5, 40, 'min'), SimSlider('Burn time', 360, 520, 5, 380, 's')],
      compute: (v) {
        // the Gateway drifts 0.1° a minute against the launch site; the ideal moment is 3 h from now
        final phase = ((180 - v[0]) * 0.1).abs(); // degrees off the ideal
        final dv = 1850 + (v[1] - 430).abs() * 3.2; // m/s needed
        return [
          SimOutput('Phase error', phase, '°', ok: phase <= 5, need: '≤ 5°'),
          SimOutput('Δv needed', dv, 'm/s', ok: dv <= 1900, need: '≤ 1 900 m/s (fuel in the tanks)'),
          const SimOutput('Gateway orbit', 6.6, 'days'),
        ];
      },
      formula: 'The Gateway takes 6.6 days per orbit and drifts 0.1° a minute against the launch site. Launch when the phase error is under 5°, and burn just long enough: every extra second costs Δv.',
      solution: const [180, 430],
    ),
    // Engineer 2 · Power Budget
    SimModel(
      id: 'power_budget',
      title: 'Power for day and night',
      sliders: const [SimSlider('Solar panels', 10, 120, 5, 30, 'm²'), SimSlider('Battery', 50, 900, 25, 150, 'kWh'), SimSlider('Base load', 2, 8, 0.5, 6, 'kW')],
      compute: (v) {
        final generated = v[0] * solarFluxW * 0.28 * 0.9 / 1000; // 28% cells, 90% at a low Sun angle
        final surplus = generated - v[2];
        final nightNeed = v[2] * lunarNightHoursPole;
        return [
          SimOutput('Panels make', generated, 'kW'),
          SimOutput('Spare to charge', surplus, 'kW', ok: surplus >= 1, need: '≥ 1 kW'),
          SimOutput('Night needs', nightNeed, 'kWh'),
          SimOutput('Battery margin', v[1] - nightNeed, 'kWh', ok: v[1] >= nightNeed * 1.2, need: '≥ 20% extra'),
        ];
      },
      formula: 'Power = area × 1 361 W/m² × 28% efficiency × 90%. The darkest stretch on the rim is about 100 hours, so the battery must hold load × 100 h, plus 20% margin.',
      solution: const [40, 675, 4],
    ),
    // Engineer 3 · Life Support Balance
    SimModel(
      id: 'life_support',
      title: 'Air and water for the crew',
      sliders: const [SimSlider('Crew', 2, 6, 1, 4, 'people'), SimSlider('O₂ generator', 1, 6, 0.1, 2.0, 'kg/day'), SimSlider('Water recovery', 50, 98, 1, 70, '%')],
      compute: (v) {
        final o2Need = v[0] * o2PerPersonKg;
        final waterLoss = v[0] * waterPerPersonKg * (1 - v[2] / 100);
        return [
          SimOutput('O₂ needed', o2Need, 'kg/day'),
          SimOutput('O₂ balance', v[1] - o2Need, 'kg/day', ok: v[1] >= o2Need, need: '≥ 0'),
          SimOutput('Water lost', waterLoss, 'kg/day', ok: waterLoss <= 0.6, need: '≤ 0.6 kg/day (resupply)'),
          SimOutput('CO₂ to scrub', v[0] * co2PerPersonKg, 'kg/day'),
        ];
      },
      formula: 'Each person breathes 0.84 kg of O₂ and uses 2.37 kg of water a day (NASA). Water lost = crew × 2.37 × (1 − recovery). The ISS recovers about 98%.',
      solution: const [4, 3.4, 95],
    ),
    // Engineer 4 · Radiation Shield
    SimModel(
      id: 'radiation',
      title: 'Regolith shielding',
      sliders: const [SimSlider('Regolith cover', 0, 300, 10, 20, 'cm'), SimSlider('Days on surface', 30, 365, 5, 180, 'days')],
      compute: (v) {
        // Lunar surface ~1.37 mSv/day (Chang'e 4 LND); each 10 cm of regolith ~ -13%; storm reserve 50 mSv.
        final factor = math.pow(0.87, v[0] / 10).toDouble();
        final dose = 1.369 * v[1] * factor + 50 * factor;
        final mass = v[0] / 100 * 1.6 * 120; // tonnes over a 120 m² roof at 1.6 t/m³
        return [
          SimOutput('Dose kept', factor * 100, '%'),
          SimOutput('Mission dose', dose, 'mSv', ok: dose <= 150, need: '≤ 150 mSv'),
          SimOutput('Regolith to move', mass, 't', ok: mass <= 400, need: '≤ 400 t (one digger, one season)'),
        ];
      },
      formula: 'The surface gives about 1.37 mSv a day (Chang\'e 4). Each 10 cm of regolith cuts it by about 13%: dose × 0.87^(cm/10). Add 50 mSv for one big solar storm.',
      solution: const [100, 180],
    ),
    // Engineer 5 · Ice to Oxygen
    SimModel(
      id: 'ice_oxygen',
      title: 'Mining ice for oxygen',
      sliders: const [SimSlider('Regolith mined', 100, 2000, 50, 300, 'kg/day'), SimSlider('Ice content', 1, 10, 0.5, 5.5, '%'), SimSlider('Electrolyser power', 1, 15, 0.5, 4, 'kW')],
      compute: (v) {
        final water = v[0] * v[1] / 100;
        final maxSplit = v[2] * 24 / 50; // ~50 kWh to split 1 kg of water (with losses)
        final split = math.min(water, maxSplit);
        final o2 = split * 8 / 9;
        return [
          SimOutput('Water out', water, 'kg/day'),
          SimOutput('Water split', split, 'kg/day'),
          SimOutput('O₂ made', o2, 'kg/day', ok: o2 >= 4 * o2PerPersonKg, need: '≥ 3.36 kg (crew of 4)'),
          SimOutput('Energy use', v[2] * 24, 'kWh/day', ok: v[2] * 24 <= 240, need: '≤ 240 kWh/day'),
        ];
      },
      formula: 'Water = regolith × ice %. Splitting water (2 H₂O → 2 H₂ + O₂) gives 8/9 of its mass as oxygen and takes about 50 kWh per kg of water with real losses.',
      solution: const [900, 5.5, 9],
    ),
    // Engineer 6 · Rover Route
    SimModel(
      id: 'rover_route',
      title: 'Drive there and back',
      sliders: const [SimSlider('Speed', 2, 15, 0.5, 12, 'km/h'), SimSlider('Distance out', 2, 20, 0.5, 14, 'km')],
      compute: (v) {
        final kwhPerKm = 0.25 + 0.012 * v[0] * v[0]; // rolling + dust drag grows with speed²
        final need = kwhPerKm * v[1] * 2;
        final hours = v[1] * 2 / v[0];
        return [
          SimOutput('Energy / km', kwhPerKm, 'kWh'),
          SimOutput('Round trip', need, 'kWh', ok: need <= 20 * 0.8, need: '≤ 16 kWh (80% of the 20 kWh battery)'),
          SimOutput('Time driving', hours, 'h', ok: hours <= 6, need: '≤ 6 h (suit limit)'),
          SimOutput('Walk-back limit', 10, 'km', ok: v[1] <= 10, need: 'distance ≤ 10 km'),
        ];
      },
      formula: 'Energy per km = 0.25 + 0.012 × speed² (faster means more dust drag and bumps). Always keep 20% battery and stay within walking distance of the base.',
      solution: const [6, 9],
    ),
    // Engineer 7 · Comms Link
    SimModel(
      id: 'comms',
      title: 'Link budget to Earth',
      sliders: const [SimSlider('Dish diameter', 0.3, 3, 0.1, 0.6, 'm'), SimSlider('Transmit power', 5, 100, 5, 10, 'W')],
      compute: (v) {
        // data rate grows with dish area and power (simplified link budget, S-band to the DSN)
        final rate = 0.9 * v[0] * v[0] * v[1];
        final mass = 4 + v[0] * v[0] * 6 + v[1] * 0.15;
        return [
          SimOutput('Data rate', rate, 'Mbps', ok: rate >= 50, need: '≥ 50 Mbps (HD video)'),
          SimOutput('Mass', mass, 'kg', ok: mass <= 40, need: '≤ 40 kg'),
          const SimOutput('Delay', earthMoonLightS, 's one way'),
        ];
      },
      formula: 'Received power grows with dish area (diameter²) and transmit power, so data rate ∝ D² × P. A bigger dish weighs more. Light takes 1.28 s to reach Earth.',
      solution: const [2.0, 20],
    ),
    // Engineer 9 · Thermal Control
    SimModel(
      id: 'thermal',
      title: 'Keep the habitat at 21 °C',
      sliders: const [SimSlider('Radiator area', 5, 60, 1, 10, 'm²'), SimSlider('Night heater', 0, 6, 0.25, 0.5, 'kW')],
      compute: (v) {
        const dayHeatKw = 9.0; // electronics + people + sunlight on the hull
        final rejected = v[0] * 0.33; // kW per m² at 300 K into space
        final dayTemp = 21 + (dayHeatKw - rejected) * 1.8;
        final nightTemp = 21 + (v[1] - 2.5) * 6 - (rejected - 9) * 0.2;
        return [
          SimOutput('Heat out', rejected, 'kW'),
          SimOutput('Day temperature', dayTemp, '°C', ok: dayTemp >= 16 && dayTemp <= 27, need: '16–27 °C'),
          SimOutput('Night temperature', nightTemp, '°C', ok: nightTemp >= 16 && nightTemp <= 27, need: '16–27 °C'),
        ];
      },
      formula: 'A radiator sheds about 0.33 kW per m² into space (σT⁴ at 300 K). By day it must remove 9 kW; by night the heater must make up the heat the radiator still loses.',
      solution: const [27, 3],
    ),
    // Engineer 10 · Landing Pad
    SimModel(
      id: 'landing_pad',
      title: 'Where to put the pad',
      sliders: const [SimSlider('Pad radius', 5, 40, 1, 8, 'm'), SimSlider('Distance from base', 100, 3000, 50, 300, 'm')],
      compute: (v) {
        // ejecta from a landing engine fly far on an airless Moon; a sintered pad stops most of it
        final ejectaRisk = 100 * math.exp(-v[0] / 8) * (1000 / v[1]);
        final walk = v[1] / 1000 / 3.5 * 60; // minutes on foot
        final cost = v[0] * v[0] * 0.05;
        return [
          SimOutput('Ejecta hitting base', ejectaRisk, '%', ok: ejectaRisk <= 5, need: '≤ 5%'),
          SimOutput('Walk to base', walk, 'min', ok: walk <= 25, need: '≤ 25 min'),
          SimOutput('Sintering time', cost, 'days', ok: cost <= 40, need: '≤ 40 days'),
        ];
      },
      formula: 'Rocket exhaust blasts regolith at over 1 km/s with no air to stop it. A wider hard pad cuts ejecta (≈ e^(−r/8)); distance spreads what is left (∝ 1/d).',
      solution: const [24, 1000],
    ),
    // Engineer 11 · Moonquake Structures
    SimModel(
      id: 'quake',
      title: 'Ride out a shallow moonquake',
      sliders: const [SimSlider('Anchor depth', 0.5, 4, 0.1, 0.8, 'm'), SimSlider('Joint flexibility', 0, 100, 5, 10, '%')],
      compute: (v) {
        final sway = 12 / (1 + v[0] * 1.5) * (1 - v[1] / 160);
        final stress = 100 - v[1] * 0.9 + (4 - v[0]) * 3;
        return [
          SimOutput('Sway', sway, 'cm', ok: sway <= 3, need: '≤ 3 cm'),
          SimOutput('Joint stress', stress, '%', ok: stress <= 60, need: '≤ 60%'),
          const SimOutput('Quake length', 10, 'min'),
        ];
      },
      formula: 'Shallow moonquakes (Apollo seismometers) can last over 10 minutes because the dry Moon rings like a bell. Deep anchors stop sway; flexible joints take the strain.',
      solution: const [2.5, 60],
    ),
    // Engineer 14 · Design Your Base
    SimModel(
      id: 'base_design',
      title: 'Shackleton Station, version 1',
      sliders: const [
        SimSlider('Habitat modules', 1, 6, 1, 2, ''),
        SimSlider('Solar panels', 20, 200, 10, 40, 'm²'),
        SimSlider('Shielding', 0, 200, 10, 20, 'cm'),
        SimSlider('Crew', 2, 8, 1, 6, 'people'),
      ],
      compute: (v) {
        final mass = v[0] * 8 + v[1] * 0.02 * 10 + v[2] * 0.05; // tonnes landed
        final power = v[1] * solarFluxW * 0.28 * 0.9 / 1000;
        final need = 2 + v[0] * 1.2 + v[3] * 0.4;
        final space = v[0] * 25 / v[3]; // m³ per person
        final dose = 1.369 * 180 * math.pow(0.87, v[2] / 10);
        return [
          SimOutput('Landed mass', mass, 't', ok: mass <= 60, need: '≤ 60 t (3 cargo landers)'),
          SimOutput('Power spare', power - need, 'kW', ok: power >= need, need: '≥ 0'),
          SimOutput('Space each', space, 'm³', ok: space >= 10, need: '≥ 10 m³ per person'),
          SimOutput('6-month dose', dose, 'mSv', ok: dose <= 150, need: '≤ 150 mSv'),
        ];
      },
      formula: 'Every choice costs mass: 8 t per module, 0.2 t per m² of panels. Power must cover 2 kW base + 1.2 kW per module + 0.4 kW per person; NASA wants at least 10 m³ of room per person.',
      solution: const [4, 60, 60, 6],
    ),
    // Engineer 15 · Mars Forward
    SimModel(
      id: 'mars_delay',
      title: 'Talking to Mars',
      sliders: const [SimSlider('Earth–Mars distance', 55, 400, 5, 225, 'million km'), SimSlider('Crew autonomy', 0, 100, 5, 20, '%')],
      compute: (v) {
        final delayMin = v[0] * 1e9 / 299792458 / 60;
        final round = delayMin * 2;
        final decisionsAlone = (round > 10 ? 80.0 : 40.0);
        return [
          SimOutput('One-way delay', delayMin, 'min'),
          SimOutput('Question and answer', round, 'min'),
          SimOutput('Autonomy needed', decisionsAlone, '%'),
          SimOutput('Crew autonomy gap', v[1] - decisionsAlone, '%', ok: v[1] >= decisionsAlone, need: '≥ 0'),
        ];
      },
      formula: 'Delay = distance ÷ speed of light. From the Moon it is 1.3 s; from Mars 3 to 22 minutes one way, so the crew must decide most things alone.',
      solution: const [225, 85],
    ),
    // Explorer 11 · Ice Hunt
    SimModel(
      id: 'ice_yield',
      title: 'How much water in the crater?',
      sliders: const [SimSlider('Area dug', 10, 200, 5, 20, 'm²'), SimSlider('Depth', 0.1, 1, 0.05, 0.2, 'm')],
      compute: (v) {
        final regolith = v[0] * v[1] * 1600; // kg at 1.6 t/m³
        final water = regolith * 0.055; // 5.5% ice (LCROSS)
        return [
          SimOutput('Regolith', regolith, 'kg'),
          SimOutput('Water', water, 'kg', ok: water >= 2000, need: '≥ 2 000 kg (a crew of 4 for 6 months)'),
          SimOutput('Digging days', regolith / 2500, 'days', ok: regolith / 2500 <= 20, need: '≤ 20 days'),
        ];
      },
      formula: 'LCROSS measured about 5.5% water in the regolith of a shadowed crater. Water = area × depth × 1 600 kg/m³ × 5.5%.',
      solution: const [60, 0.5],
    ),
    // Explorer 12 · Rover Expedition
    SimModel(
      id: 'rover_energy',
      title: 'Battery for the trip',
      sliders: const [SimSlider('Distance out', 1, 12, 0.5, 9, 'km'), SimSlider('Spare batteries', 0, 3, 1, 0, '')],
      compute: (v) {
        final need = v[0] * 2 * 1.1;
        final have = 18 + v[1] * 4;
        return [
          SimOutput('Energy needed', need, 'kWh'),
          SimOutput('Energy carried', have, 'kWh'),
          SimOutput('Left on return', have - need, 'kWh', ok: have - need >= have * 0.2, need: '≥ 20% reserve'),
          SimOutput('Load', v[1] * 30, 'kg', ok: v[1] <= 2, need: '≤ 2 spare packs'),
        ];
      },
      formula: 'The rover uses about 1.1 kWh per km. Out and back doubles the distance. Always come home with at least 20% left.',
      solution: const [7, 1],
    ),
    // Explorer 15 · The Second Crew
    SimModel(
      id: 'crew_supplies',
      title: 'Supplies for the new crew',
      sliders: const [SimSlider('Crew', 2, 6, 1, 4, 'people'), SimSlider('Days until resupply', 10, 60, 5, 30, 'days'), SimSlider('Food packed', 20, 200, 5, 50, 'kg')],
      compute: (v) {
        final need = v[0] * v[1] * foodPerPersonKg;
        return [
          SimOutput('Food needed', need, 'kg'),
          SimOutput('Spare food', v[2] - need, 'kg', ok: v[2] >= need * 1.1, need: '≥ 10% reserve'),
          SimOutput('O₂ needed', v[0] * v[1] * o2PerPersonKg, 'kg'),
        ];
      },
      formula: 'Food = crew × days × 0.62 kg (NASA). Pack 10% extra in case the next rocket is late.',
      solution: const [4, 30, 85],
    ),
  ])
    m.id: m,
};

SimModel? simModel(String id) => sims[id];
