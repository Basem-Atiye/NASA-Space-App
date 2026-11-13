/// Data classes describing a mission. Missions themselves live in
/// lib/data/missions.dart so writers can edit them without touching the engine.
library;

enum EventType { storm, failure, dust, night, day, cargo, home }

enum SystemId { electrolyzer, recycler, greenhouse }

enum CargoChoice { water, food, battery, panel, oxygen }

/// A real solar event from NASA's DONKI database that a mission replays.
class SolarEvent {
  final String donkiId;
  final String flareClass; // e.g. 'X3.3'
  final String date; // e.g. '9 Feb 2024'
  final String url;

  const SolarEvent({
    required this.donkiId,
    required this.flareClass,
    required this.date,
    required this.url,
  });
}

class MissionEvent {
  final int hour;
  final EventType type;
  final SystemId? system;
  final double amount;
  final SolarEvent? storm;
  final int warningHours;
  final int durationHours;
  final List<CargoChoice> cargoOptions;

  const MissionEvent({
    required this.hour,
    required this.type,
    this.system,
    this.amount = 0,
    this.storm,
    this.warningHours = 3,
    this.durationHours = 6,
    this.cargoOptions = const [],
  });
}

enum StarType { healthAtLeast, doseAtMost, o2DaysAtLeast, waterAtLeast, foodAtLeast }

class StarRule {
  final StarType type;
  final double value;

  const StarRule(this.type, this.value);

  String get label {
    switch (type) {
      case StarType.healthAtLeast:
        return 'Finish with health ${value.toStringAsFixed(0)}% or more';
      case StarType.doseAtMost:
        return 'Keep radiation dose at ${_n(value)} mSv or less';
      case StarType.o2DaysAtLeast:
        return 'Finish with ${_n(value)} days of oxygen in store';
      case StarType.waterAtLeast:
        return 'Finish with ${_n(value)} kg of water or more';
      case StarType.foodAtLeast:
        return 'Finish with ${_n(value)} kg of food or more';
    }
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class MissionConfig {
  final int id;
  final int chapter;
  final String title;
  final String subtitle;
  final String goalText;
  final String newThisMission;
  final int days;
  final int crew;
  final double o2;
  final double water;
  final double food;
  final double battery;
  final double batteryCap;
  final double solarKw;
  final double startDust;
  final double doseLimit;
  final bool hasGreenhouse;
  final bool recyclerStartsOff;
  final bool evaUnlocked;
  final bool berm;
  final int sparePanels;

  // objectives (all must be met by the end)
  final double iceGoal;
  final int samplesGoal;
  final bool panelGoal;
  final bool bermGoal;

  final List<MissionEvent> events;
  final StarRule star2;
  final StarRule star3;
  final bool isBoss;

  const MissionConfig({
    required this.id,
    required this.chapter,
    required this.title,
    required this.subtitle,
    required this.goalText,
    required this.newThisMission,
    required this.days,
    required this.crew,
    required this.o2,
    required this.water,
    required this.food,
    required this.battery,
    required this.batteryCap,
    required this.solarKw,
    this.startDust = 0.05,
    required this.doseLimit,
    this.hasGreenhouse = false,
    this.recyclerStartsOff = false,
    this.evaUnlocked = false,
    this.berm = false,
    this.sparePanels = 0,
    this.iceGoal = 0,
    this.samplesGoal = 0,
    this.panelGoal = false,
    this.bermGoal = false,
    this.events = const [],
    required this.star2,
    required this.star3,
    this.isBoss = false,
  });

  int get totalHours => days * 24;

  bool get hasObjectives => iceGoal > 0 || samplesGoal > 0 || panelGoal || bermGoal;
}
