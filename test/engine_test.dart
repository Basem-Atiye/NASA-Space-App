import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/data/missions.dart';
import 'package:shackleton_station/engine/mission.dart';
import 'package:shackleton_station/engine/simulation.dart';

/// Runs a mission to the end. [strategy] is called before every hour.
MissionSim play(int id, [void Function(MissionSim s)? strategy]) {
  final s = MissionSim(missionById(id));
  while (s.outcome == Outcome.running) {
    s.pendingCargo = null;
    strategy?.call(s);
    s.tick();
  }
  return s;
}

/// A careful player, the same logic used to balance the missions.
void careful(MissionSim s) {
  if (s.onEva) {
    if (s.storm != null) {
      s.recallEva();
      s.setActivity(Activity.shelter);
    }
    return;
  }
  final st = s.storm;
  if (st != null && (st.phase == StormPhase.active || st.hoursLeft <= 2)) {
    s.setActivity(Activity.shelter);
    return;
  }
  if (s.location == CrewLocation.shelter) s.setActivity(Activity.rest);
  final remaining = s.mission.days - s.hour / 24;
  s.electrolyzerOn = true;
  s.electrolyzerRate = ((0.84 / 24 * s.crew * 1.05) / 0.15 + (s.o2Days < 1.5 ? 0.3 : 0)).clamp(0.0, 1.0).toDouble();
  s.recyclerOn = true;
  s.heatersOn = true;
  if (!s.sun && s.o2Days > remaining + 0.4) s.electrolyzerOn = false;
  if (!s.sun && s.waterDays > remaining + 0.3) s.recyclerOn = false;
  if (s.mission.hasGreenhouse) {
    s.greenhouseOn = s.sun ? true : s.battery > 0.7 * s.batteryCap;
  }
  if (s.broken.isNotEmpty) {
    s.setActivity(Activity.repair);
    return;
  }
  if (s.fatigue > 60) {
    s.setActivity(Activity.rest);
    return;
  }
  if (s.dust > 0.3 && s.sun) {
    s.setActivity(Activity.clean);
    return;
  }
  final m = s.mission;
  if (st == null && s.fatigue < 40) {
    if (m.bermGoal && !s.berm && s.startEva(EvaTarget.berm)) return;
    if (s.iceMined < m.iceGoal && s.startEva(EvaTarget.ice)) return;
    if (s.samples < m.samplesGoal && s.startEva(EvaTarget.science)) return;
    if (m.panelGoal && !s.panelInstalled && s.startEva(EvaTarget.ridge)) return;
  }
  s.setActivity(m.hasGreenhouse && s.greenhouseOn ? Activity.greenhouse : Activity.rest);
}

void main() {
  test('every mission is winnable by a careful player', () {
    for (final m in missions) {
      final s = play(m.id, careful);
      expect(s.outcome, Outcome.won, reason: 'mission ${m.id} ${m.title}: ${s.lossReason}');
    }
  });

  test('ignoring the storm in mission 7 breaks the dose limit', () {
    final s = play(7);
    expect(s.outcome, Outcome.lost);
    expect(s.lossReason, LossReason.doseLimit);
  });

  test('leaving the recycler off in mission 3 is fatal', () {
    final s = play(3);
    expect(s.outcome, Outcome.lost);
    expect(s.lossReason, LossReason.water);
  });

  test('an unrepaired oxygen generator ends mission 2', () {
    final s = play(2);
    expect(s.outcome, Outcome.lost);
  });

  test('NASA oxygen rate: one crew member uses 0.84 kg per day', () {
    final s = MissionSim(missionById(1));
    s.electrolyzerOn = false;
    s.activity = Activity.science; // multiplier 1.0
    final before = s.o2;
    for (int i = 0; i < 24; i++) {
      s.tick();
    }
    expect(before - s.o2, closeTo(0.84, 0.001));
  });

  test('the shelter cuts storm dose by 90%', () {
    final s = MissionSim(missionById(7));
    s.storm = StormState(Storms.x33Feb2024, StormPhase.active, 5, 5);
    s.setActivity(Activity.rest);
    final inside = s.doseRatePerHour;
    s.setActivity(Activity.shelter);
    expect(s.doseRatePerHour, closeTo(inside / 0.6 * 0.1, 1e-9));
  });

  test('stars follow the star rules', () {
    final s = play(1, careful);
    expect(s.starsEarned(), greaterThanOrEqualTo(2));
    expect(const StarRule(StarType.doseAtMost, 3).label, contains('3 mSv'));
  });
}
