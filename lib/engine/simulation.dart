import 'dart:math' as math;

import 'constants.dart';
import 'mission.dart';

enum Activity { rest, repair, greenhouse, exercise, science, clean, shelter }

enum CrewLocation { habitat, shelter, eva }

enum EvaTarget { ice, science, ridge, berm }

enum StormPhase { warning, active }

enum Outcome { running, won, lost }

enum LossReason { oxygen, water, food, cold, radiation, exhaustion, doseLimit, objectives }

enum SignalType {
  stormWarning,
  stormStart,
  stormEnd,
  failure,
  repaired,
  harvest,
  evaComplete,
  evaRecalled,
  brownout,
  nightStart,
  dayStart,
  dustStorm,
  cargoArrived,
  homeMessage,
  won,
  lost,
}

class Signal {
  final SignalType type;
  final SystemId? system;
  final EvaTarget? eva;
  final SolarEvent? storm;
  final List<CargoChoice> cargo;

  const Signal(this.type, {this.system, this.eva, this.storm, this.cargo = const []});
}

class StormState {
  final SolarEvent event;
  StormPhase phase;
  int hoursLeft;
  final int duration;

  StormState(this.event, this.phase, this.hoursLeft, this.duration);

  String get flareClass => event.flareClass;
}

class LogEntry {
  final int hour;
  final String text;
  const LogEntry(this.hour, this.text);
}

int evaHours(EvaTarget t) {
  switch (t) {
    case EvaTarget.ice:
      return 6;
    case EvaTarget.science:
      return 5;
    case EvaTarget.ridge:
      return 6;
    case EvaTarget.berm:
      return 8;
  }
}

/// The whole mission simulation. Pure Dart: no widgets, no 3D.
/// The game controller calls [tick] once per game hour.
class MissionSim {
  final MissionConfig mission;

  int hour = 0;
  final int crew;
  double o2;
  double water;
  double food;
  double battery;
  double batteryCap;
  double solarKw;
  double dust;
  double dose = 0;
  double health = 100;
  double morale = 80;
  double fatigue = 10;

  bool electrolyzerOn = true;
  double electrolyzerRate = 0.25;
  bool recyclerOn;
  bool greenhouseOn;
  bool heatersOn = true;
  bool labOn = false;
  final Set<SystemId> broken = {};
  double growth = 0.3;

  CrewLocation location = CrewLocation.habitat;
  Activity activity = Activity.rest;
  EvaTarget? eva;
  int evaLeft = 0;
  SystemId? repairTarget;
  double repairProgress = 0;

  double iceMined = 0;
  int samples = 0;
  double science = 0;
  bool panelInstalled = false;
  bool berm;
  int sparePanels;

  bool sun = true;
  StormState? storm;
  bool brownout = false;
  Outcome outcome = Outcome.running;
  LossReason? lossReason;

  // for the debrief and for Nova's memory
  final List<LogEntry> log = [];
  final Map<LossReason, double> damage = {};
  double lowestO2Days = 99;
  double lowestWaterDays = 99;
  bool wasOutsideInStorm = false;
  bool shelteredInStorm = false;
  int stormsSurvived = 0;
  int brownouts = 0;
  int harvests = 0;
  List<CargoChoice>? pendingCargo;

  MissionSim(this.mission)
      : crew = mission.crew,
        o2 = mission.o2,
        water = mission.water,
        food = mission.food,
        battery = mission.battery,
        batteryCap = mission.batteryCap,
        solarKw = mission.solarKw,
        dust = mission.startDust,
        recyclerOn = !mission.recyclerStartsOff,
        greenhouseOn = mission.hasGreenhouse,
        berm = mission.berm,
        sparePanels = mission.sparePanels;

  // ------------------------------------------------------------------ getters

  double get day => hour / 24.0;
  int get hoursLeft => math.max(0, mission.totalHours - hour);
  bool get onEva => location == CrewLocation.eva;
  bool get stormActive => storm != null && storm!.phase == StormPhase.active;
  bool get stormWarning => storm != null && storm!.phase == StormPhase.warning;
  bool isBroken(SystemId s) => broken.contains(s);

  double get generationKw => sun ? solarKw * (1 - dust) : 0;

  double get loadKw {
    double kw = Rates.baseKw;
    if (electrolyzerOn && !isBroken(SystemId.electrolyzer)) kw += Rates.electrolyzerKw * electrolyzerRate;
    if (recyclerOn && !isBroken(SystemId.recycler)) kw += Rates.recyclerKw;
    if (mission.hasGreenhouse && greenhouseOn && !isBroken(SystemId.greenhouse)) kw += Rates.greenhouseKw;
    if (heatersOn && !sun) kw += Rates.heaterKw;
    if (labOn) kw += Rates.labKw;
    return kw;
  }

  double get netKw => generationKw - loadKw;

  Activity get effectiveActivity => onEva ? Activity.rest : activity;

  double get _o2Multiplier {
    if (onEva) return 1.6;
    switch (activity) {
      case Activity.rest:
        return 0.85;
      case Activity.exercise:
        return 1.3;
      case Activity.shelter:
        return 0.9;
      default:
        return 1.0;
    }
  }

  bool get _isOutside => onEva || (activity == Activity.clean && location == CrewLocation.habitat);

  /// Dose rate right now, mSv per hour.
  double get doseRatePerHour {
    double outside = Rates.surfaceDosePerHour;
    if (stormActive) outside += Rates.stormDosePerHour(storm!.flareClass);
    if (_isOutside) return outside;
    if (location == CrewLocation.shelter) return outside * Rates.shelterShield;
    return outside * (berm ? Rates.habitatShieldWithBerm : Rates.habitatShield);
  }

  /// Net change per hour at current settings (used for "time left").
  double get o2NetPerHour {
    double net = -Rates.o2PerDay / 24 * crew * _o2Multiplier;
    if (electrolyzerOn && !isBroken(SystemId.electrolyzer) && water > 0) {
      net += Rates.electrolyzerMaxO2PerHour * electrolyzerRate;
    }
    return net;
  }

  double get waterNetPerHour {
    double use = Rates.waterPerDay / 24 * crew;
    if (recyclerOn && !isBroken(SystemId.recycler)) use *= (1 - Rates.recyclerEfficiency);
    double net = -use;
    if (electrolyzerOn && !isBroken(SystemId.electrolyzer)) {
      net -= Rates.electrolyzerMaxO2PerHour * electrolyzerRate * Rates.electrolyzerWaterPerKgO2;
    }
    if (mission.hasGreenhouse && greenhouseOn && !isBroken(SystemId.greenhouse)) net -= Rates.greenhouseWaterPerHour;
    return net;
  }

  double get foodNetPerHour => -Rates.foodPerDay / 24 * crew;

  /// Hours until a store runs out at the current rate, or null when stable.
  double? hoursLeftFor(double amount, double netPerHour) {
    if (netPerHour >= -1e-6) return null;
    return amount / -netPerHour;
  }

  double? get o2HoursLeft => hoursLeftFor(o2, o2NetPerHour);
  double? get waterHoursLeft => hoursLeftFor(water, waterNetPerHour);
  double? get foodHoursLeft => hoursLeftFor(food, foodNetPerHour);
  double? get batteryHoursLeft => hoursLeftFor(battery, netKw);

  double get o2Days => o2 / (Rates.o2PerDay * crew);
  double get waterDays => water / (Rates.waterPerDay * crew);
  double get foodDays => food / (Rates.foodPerDay * crew);

  bool get objectivesMet =>
      iceMined >= mission.iceGoal &&
      samples >= mission.samplesGoal &&
      (panelInstalled || !mission.panelGoal) &&
      (berm || !mission.bermGoal);

  // ------------------------------------------------------------------ actions

  void setActivity(Activity a) {
    if (onEva || outcome != Outcome.running) return;
    activity = a;
    location = a == Activity.shelter ? CrewLocation.shelter : CrewLocation.habitat;
    if (a == Activity.repair) {
      repairTarget ??= broken.isEmpty ? null : broken.first;
    }
    if (a == Activity.science && !labOn) labOn = true;
  }

  /// Returns null when the EVA started, otherwise a reason it can't.
  String? canStartEva(EvaTarget t) {
    if (!mission.evaUnlocked) return 'EVAs unlock in a later mission.';
    if (onEva) return 'Nova is already outside.';
    if (fatigue > 80) return 'Nova is too tired. Let her rest first.';
    if (t == EvaTarget.ridge && sparePanels <= 0) return 'No spare solar panel to install.';
    if (t == EvaTarget.berm && berm) return 'The shielding is already built.';
    if (o2 < Rates.o2PerDay * crew * 0.4) return 'Not enough oxygen to refill the suit.';
    return null;
  }

  bool startEva(EvaTarget t) {
    if (canStartEva(t) != null) return false;
    eva = t;
    evaLeft = evaHours(t);
    location = CrewLocation.eva;
    _log('EVA started: ${evaName(t)}');
    return true;
  }

  void recallEva() {
    if (!onEva) return;
    _log('EVA recalled early');
    eva = null;
    evaLeft = 0;
    location = CrewLocation.habitat;
    activity = Activity.rest;
  }

  void applyCargo(CargoChoice c) {
    switch (c) {
      case CargoChoice.water:
        water += 20;
        break;
      case CargoChoice.food:
        food += 6;
        break;
      case CargoChoice.battery:
        batteryCap += 15;
        battery += 15;
        break;
      case CargoChoice.panel:
        sparePanels += 1;
        break;
      case CargoChoice.oxygen:
        o2 += 8;
        break;
    }
    pendingCargo = null;
    _log('Cargo unpacked: ${cargoName(c)}');
  }

  // ------------------------------------------------------------------ tick

  List<Signal> tick() {
    final signals = <Signal>[];
    if (outcome != Outcome.running) return signals;

    // scheduled events
    for (final e in mission.events) {
      if (e.hour == hour) _applyEvent(e, signals);
    }

    // storm progression
    final st = storm;
    if (st != null) {
      st.hoursLeft -= 1;
      if (st.hoursLeft <= 0) {
        if (st.phase == StormPhase.warning) {
          st.phase = StormPhase.active;
          st.hoursLeft = st.duration;
          if (onEva) wasOutsideInStorm = true;
          if (location == CrewLocation.shelter) shelteredInStorm = true;
          _log('Solar particle storm hits (${st.flareClass} flare)');
          signals.add(Signal(SignalType.stormStart, storm: st.event));
        } else {
          storm = null;
          stormsSurvived += 1;
          _log('Storm passed');
          signals.add(Signal(SignalType.stormEnd, storm: st.event));
        }
      } else if (st.phase == StormPhase.active) {
        if (onEva || _isOutside) wasOutsideInStorm = true;
        if (location == CrewLocation.shelter) shelteredInStorm = true;
      }
    }

    // power, shedding loads in order if the battery would go below zero
    final gen = generationKw;
    double need = loadKw;
    final wasBrownout = brownout;
    brownout = false;
    final order = <String>['lab', 'greenhouse', 'electrolyzer', 'recycler', 'heaters'];
    while (battery + gen - need < 0 && order.isNotEmpty) {
      final k = order.removeAt(0);
      if (k == 'lab' && labOn) {
        labOn = false;
        brownout = true;
      } else if (k == 'greenhouse' && greenhouseOn && mission.hasGreenhouse) {
        greenhouseOn = false;
        brownout = true;
      } else if (k == 'electrolyzer' && electrolyzerOn) {
        electrolyzerOn = false;
        brownout = true;
      } else if (k == 'recycler' && recyclerOn) {
        recyclerOn = false;
        brownout = true;
      } else if (k == 'heaters' && heatersOn && !sun) {
        heatersOn = false;
        brownout = true;
      }
      need = loadKw;
    }
    if (brownout && !wasBrownout) {
      brownouts += 1;
      _log('Battery empty: systems shut down');
      signals.add(const Signal(SignalType.brownout));
    }
    battery = (battery + gen - need).clamp(0.0, batteryCap).toDouble();

    // crew needs
    o2 -= Rates.o2PerDay / 24 * crew * _o2Multiplier;
    double waterUse = Rates.waterPerDay / 24 * crew;
    if (recyclerOn && !isBroken(SystemId.recycler)) waterUse *= (1 - Rates.recyclerEfficiency);
    water -= waterUse;
    food -= Rates.foodPerDay / 24 * crew;

    if (electrolyzerOn && !isBroken(SystemId.electrolyzer) && water > 0) {
      final made = math.min(Rates.electrolyzerMaxO2PerHour * electrolyzerRate, water / Rates.electrolyzerWaterPerKgO2);
      o2 += made;
      water -= made * Rates.electrolyzerWaterPerKgO2;
    }

    if (mission.hasGreenhouse && greenhouseOn && !isBroken(SystemId.greenhouse) && water > 0) {
      water -= Rates.greenhouseWaterPerHour;
      growth += Rates.greenhouseGrowthPerHour * (!onEva && activity == Activity.greenhouse ? 2 : 1);
      if (growth >= 1) {
        growth -= 1;
        food += Rates.greenhouseHarvestKg;
        morale = math.min(100.0, morale + 8);
        harvests += 1;
        _log('Greenhouse harvest: +${Rates.greenhouseHarvestKg} kg food');
        signals.add(const Signal(SignalType.harvest));
      }
    }

    // activity effects
    if (onEva) {
      fatigue += 4;
      dust += Rates.dustPerEvaHour;
      evaLeft -= 1;
      if (evaLeft <= 0) _finishEva(signals);
    } else {
      switch (activity) {
        case Activity.rest:
          fatigue -= 5;
          morale += 0.4;
          break;
        case Activity.exercise:
          fatigue += 2;
          health += 0.6;
          break;
        case Activity.science:
          fatigue += 1.5;
          if (labOn) {
            science += 1;
            morale += 0.4;
          }
          break;
        case Activity.greenhouse:
          fatigue += 1.2;
          morale += 0.3;
          break;
        case Activity.clean:
          fatigue += 2;
          dust = math.max(0.0, dust - Rates.cleanPerHour);
          break;
        case Activity.repair:
          {
            fatigue += 2;
            repairTarget ??= broken.isEmpty ? null : broken.first;
            final target = repairTarget;
            if (target != null) {
              repairProgress += (1 / 3) * (morale < 30 ? 0.6 : 1.0);
              if (repairProgress >= 1) {
                broken.remove(target);
                repairTarget = null;
                repairProgress = 0;
                _log('Repaired: ${systemName(target)}');
                signals.add(Signal(SignalType.repaired, system: target));
                if (target == SystemId.electrolyzer) electrolyzerOn = true;
                if (target == SystemId.recycler) recyclerOn = true;
              }
            }
          }
          break;
        case Activity.shelter:
          fatigue -= 2;
          morale -= 0.4;
          break;
      }
    }
    dust = math.min(Rates.maxDust, dust + Rates.dustPerHour);

    // radiation
    final d = doseRatePerHour;
    dose += d;
    _hurt(LossReason.radiation, d * Rates.healthPerMSv);

    // damage from empty stores and cold
    if (o2 <= 0) {
      o2 = 0;
      _hurt(LossReason.oxygen, Rates.noO2HealthPerHour);
    }
    if (water <= 0) {
      water = 0;
      _hurt(LossReason.water, Rates.noWaterHealthPerHour);
    }
    if (food <= 0) {
      food = 0;
      _hurt(LossReason.food, Rates.noFoodHealthPerHour);
    }
    if (!sun && !heatersOn) {
      _hurt(LossReason.cold, Rates.coldHealthPerHour);
      morale -= 1;
    }
    if (fatigue > 85) _hurt(LossReason.exhaustion, 0.5);
    if (morale < 25) _hurt(LossReason.exhaustion, 0.2);
    morale -= 0.25;

    fatigue = fatigue.clamp(0.0, 100.0).toDouble();
    morale = morale.clamp(0.0, 100.0).toDouble();
    health = math.min(100.0, health);

    lowestO2Days = math.min(lowestO2Days, o2Days);
    lowestWaterDays = math.min(lowestWaterDays, waterDays);

    hour += 1;

    // outcome
    if (health <= 0) {
      health = 0;
      outcome = Outcome.lost;
      lossReason = _worstDamage();
      signals.add(const Signal(SignalType.lost));
    } else if (dose > mission.doseLimit) {
      outcome = Outcome.lost;
      lossReason = LossReason.doseLimit;
      signals.add(const Signal(SignalType.lost));
    } else if (hour >= mission.totalHours) {
      if (objectivesMet) {
        outcome = Outcome.won;
        signals.add(const Signal(SignalType.won));
      } else {
        outcome = Outcome.lost;
        lossReason = LossReason.objectives;
        signals.add(const Signal(SignalType.lost));
      }
    }
    return signals;
  }

  void _hurt(LossReason why, double amount) {
    if (amount <= 0) return;
    health -= amount;
    damage[why] = (damage[why] ?? 0) + amount;
  }

  LossReason _worstDamage() {
    LossReason worst = LossReason.oxygen;
    double most = -1;
    damage.forEach((k, v) {
      if (v > most) {
        most = v;
        worst = k;
      }
    });
    return worst;
  }

  void _finishEva(List<Signal> signals) {
    final t = eva;
    if (t == null) return;
    switch (t) {
      case EvaTarget.ice:
        iceMined += Rates.iceKgPerEva;
        water += Rates.iceKgPerEva;
        break;
      case EvaTarget.science:
        samples += Rates.samplesPerEva;
        morale = math.min(100.0, morale + 6);
        break;
      case EvaTarget.ridge:
        if (sparePanels > 0) {
          sparePanels -= 1;
          solarKw += Rates.ridgePanelKw;
          panelInstalled = true;
        }
        break;
      case EvaTarget.berm:
        berm = true;
        break;
    }
    _log('EVA complete: ${evaName(t)}');
    signals.add(Signal(SignalType.evaComplete, eva: t));
    eva = null;
    location = CrewLocation.habitat;
    activity = Activity.rest;
  }

  void _applyEvent(MissionEvent e, List<Signal> signals) {
    switch (e.type) {
      case EventType.storm:
        {
          final ev = e.storm;
          if (ev == null) return;
          storm = StormState(ev, StormPhase.warning, e.warningHours, e.durationHours);
          _log('Flare detected: ${ev.flareClass}, replaying ${ev.date}');
          signals.add(Signal(SignalType.stormWarning, storm: ev));
        }
        break;
      case EventType.failure:
        {
          final sys = e.system;
          if (sys == null) return;
          broken.add(sys);
          _log('Failure: ${systemName(sys)}');
          signals.add(Signal(SignalType.failure, system: sys));
        }
        break;
      case EventType.dust:
        dust = math.min(Rates.maxDust, dust + e.amount);
        _log('Dust covered the solar panels');
        signals.add(const Signal(SignalType.dustStorm));
        break;
      case EventType.night:
        sun = false;
        _log('Sunset: the base is in darkness');
        signals.add(const Signal(SignalType.nightStart));
        break;
      case EventType.day:
        sun = true;
        _log('Sunrise: solar power is back');
        signals.add(const Signal(SignalType.dayStart));
        break;
      case EventType.cargo:
        pendingCargo = e.cargoOptions;
        _log('A cargo lander touched down');
        signals.add(Signal(SignalType.cargoArrived, cargo: e.cargoOptions));
        break;
      case EventType.home:
        morale = math.min(100.0, morale + 15);
        _log('Message from home');
        signals.add(const Signal(SignalType.homeMessage));
        break;
    }
  }

  void _log(String text) => log.add(LogEntry(hour, text));

  // ------------------------------------------------------------------ results

  int starsEarned() {
    if (outcome != Outcome.won) return 0;
    int stars = 1;
    if (_meets(mission.star2)) stars++;
    if (_meets(mission.star3)) stars++;
    return stars;
  }

  bool meetsStar(StarRule r) => _meets(r);

  bool _meets(StarRule r) {
    switch (r.type) {
      case StarType.healthAtLeast:
        return health >= r.value;
      case StarType.doseAtMost:
        return dose <= r.value;
      case StarType.o2DaysAtLeast:
        return o2Days >= r.value;
      case StarType.waterAtLeast:
        return water >= r.value;
      case StarType.foodAtLeast:
        return food >= r.value;
    }
  }
}

String systemName(SystemId s) {
  switch (s) {
    case SystemId.electrolyzer:
      return 'Oxygen generator';
    case SystemId.recycler:
      return 'Water recycler';
    case SystemId.greenhouse:
      return 'Greenhouse';
  }
}

String evaName(EvaTarget t) {
  switch (t) {
    case EvaTarget.ice:
      return 'Ice mining in Shadow Crater';
    case EvaTarget.science:
      return 'Rock samples at Science Site';
    case EvaTarget.ridge:
      return 'Install solar panel on the ridge';
    case EvaTarget.berm:
      return 'Build regolith shielding';
  }
}

String cargoName(CargoChoice c) {
  switch (c) {
    case CargoChoice.water:
      return 'Water tanks (+20 kg)';
    case CargoChoice.food:
      return 'Food crate (+6 kg)';
    case CargoChoice.battery:
      return 'Battery pack (+15 kWh)';
    case CargoChoice.panel:
      return 'Spare solar panel';
    case CargoChoice.oxygen:
      return 'Oxygen tanks (+8 kg)';
  }
}

String activityName(Activity a) {
  switch (a) {
    case Activity.rest:
      return 'Rest';
    case Activity.repair:
      return 'Repair';
    case Activity.greenhouse:
      return 'Greenhouse';
    case Activity.exercise:
      return 'Exercise';
    case Activity.science:
      return 'Science';
    case Activity.clean:
      return 'Clean panels';
    case Activity.shelter:
      return 'Storm shelter';
  }
}
