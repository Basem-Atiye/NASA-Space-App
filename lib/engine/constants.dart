/// Every number the simulation uses, in one place.
///
/// Values marked NASA come from published sources and are shown on the
/// in-game Mission Data screen. Values marked GAME are simplified engineering
/// numbers chosen so that missions fit into a few minutes of play.
class Rates {
  Rates._();

  // ---- NASA: per crew member per day ----
  /// Oxygen use, kg per crew member per day (NASA life support baseline).
  static const double o2PerDay = 0.84;

  /// Drinking + food-preparation water, kg per crew member per day (NASA).
  static const double drinkWaterPerDay = 2.37;

  /// Hygiene water, kg per crew member per day (GAME, simplified).
  static const double hygieneWaterPerDay = 0.63;

  static const double waterPerDay = drinkWaterPerDay + hygieneWaterPerDay;

  /// Food solids, kg per crew member per day (NASA).
  static const double foodPerDay = 0.62;

  /// Carbon dioxide produced, kg per crew member per day (NASA).
  static const double co2PerDay = 1.00;

  /// Radiation dose equivalent on the open lunar surface from cosmic rays,
  /// mSv per day (Chang'e 4 LND measurement, 2020).
  static const double surfaceDosePerDay = 1.369;
  static const double surfaceDosePerHour = surfaceDosePerDay / 24.0;

  // ---- GAME: engineering values ----
  static const double electrolyzerMaxO2PerHour = 0.15; // kg O2 per hour at 100%
  static const double electrolyzerWaterPerKgO2 = 1.125; // kg water per kg O2 (chemistry)
  static const double electrolyzerKw = 1.2;
  static const double recyclerKw = 0.3;
  static const double recyclerEfficiency = 0.85;
  static const double greenhouseKw = 1.5;
  static const double greenhouseGrowthPerHour = 1 / 60.0;
  static const double greenhouseHarvestKg = 2.5;
  static const double greenhouseWaterPerHour = 0.03;
  static const double heaterKw = 0.8;
  static const double baseKw = 0.6;
  static const double labKw = 0.4;

  static const double habitatShield = 0.6;
  static const double habitatShieldWithBerm = 0.3;
  static const double shelterShield = 0.1;

  /// Extra dose rate outside during the active phase of a solar particle
  /// event, mSv per hour, by the class of the flare that caused it (GAME).
  static double stormDosePerHour(String flareClass) {
    switch (flareClass.isEmpty ? 'M' : flareClass[0]) {
      case 'X':
        return 1.6;
      case 'M':
        return 0.7;
      default:
        return 0.25;
    }
  }

  static const double dustPerHour = 0.003;
  static const double dustPerEvaHour = 0.01;
  static const double cleanPerHour = 0.12;
  static const double maxDust = 0.9;

  static const double healthPerMSv = 1.2;
  static const double noO2HealthPerHour = 25;
  static const double noWaterHealthPerHour = 6;
  static const double noFoodHealthPerHour = 1;
  static const double coldHealthPerHour = 2.5;

  static const double iceKgPerEva = 8;
  static const int samplesPerEva = 2;
  static const double ridgePanelKw = 1.5;
}

/// Real-time pacing: how many real seconds one game hour lasts at 1x speed.
const double secondsPerGameHour = 1.2;
