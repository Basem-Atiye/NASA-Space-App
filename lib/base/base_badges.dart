/// The 12 badges of the Figma "Badges" screen, with real rules.
library;

import 'base_engine.dart';

class BadgeDef {
  final String id;
  final String title;
  final String how; // "Finish Mission 03 without food dropping below half."
  final String icon; // line icon name
  final String color; // cyan, blue, orange, yellow, green, red, white
  const BadgeDef(this.id, this.title, this.how, this.icon, this.color);
}

const badges = <BadgeDef>[
  BadgeDef('first_mission', 'First Mission', 'Finish any mission.', 'rocket', 'cyan'),
  BadgeDef('water_saver', 'Water Saver', 'Finish a mission with water never below 30%.', 'droplet', 'blue'),
  BadgeDef('power_master', 'Power Master', 'Finish a mission with 5 stars for Power.', 'zap', 'orange'),
  BadgeDef('supply_runner', 'Supply Runner', 'Get 3 stars in a Supply Run.', 'star', 'yellow'),
  BadgeDef('green_thumb', 'Green Thumb', 'Finish Mission 03 without food dropping below half.', 'sprout', 'green'),
  BadgeDef('solar_survivor', 'Solar Survivor', 'Keep your crew safe in a solar storm.', 'sun', 'orange'),
  BadgeDef('radiation_ready', 'Radiation Ready', 'Finish Mission 04 with every storm blocked.', 'radiation', 'yellow'),
  BadgeDef('perfect_crew', 'Perfect Crew', 'Finish a mission with crew health never below 90%.', 'heart', 'red'),
  BadgeDef('researcher', 'Researcher', 'Make 60 research points in one mission.', 'flask', 'white'),
  BadgeDef('fixer', 'Fixer', 'Fix 10 problems in total.', 'wrench', 'orange'),
  BadgeDef('lunar_commander', 'Lunar Commander', 'Finish all 5 Moon missions.', 'award', 'cyan'),
  BadgeDef('mars_pioneer', 'Mars Pioneer', 'Finish your first Mars mission.', 'rocket', 'red'),
];

BadgeDef badgeById(String id) => badges.firstWhere((b) => b.id == id);

/// Badges earned by this mission result. [won] lists every mission number
/// won so far (including this one); [fixedTotal] counts all repairs ever.
Set<String> badgesFor(MissionResult r, BaseMission m, {required Set<int> won, required int fixedTotal}) {
  final out = <String>{};
  if (fixedTotal >= 10) out.add('fixer');
  if (!r.won) return out;
  out.add('first_mission');
  if (m.systems.contains(Sys.recycler) && r.minWater >= 30) out.add('water_saver');
  if ((r.ratings['Power'] ?? 0) >= 5) out.add('power_master');
  if (m.n == 3 && r.minFood >= 50) out.add('green_thumb');
  if (r.stormsShielded > 0) out.add('solar_survivor');
  if (m.n == 4 && r.stormsSurvived > 0 && r.stormsShielded == r.stormsSurvived) out.add('radiation_ready');
  if (r.lowestCrew >= 90) out.add('perfect_crew');
  if (r.research >= 60) out.add('researcher');
  if ([1, 2, 3, 4, 5].every(won.contains)) out.add('lunar_commander');
  if (m.mars) out.add('mars_pioneer');
  return out;
}

/// The badge the player is closest to (for "Next badge: ..." on the screen).
BadgeDef? nextBadge(Set<String> earned, int nextMission) {
  const order = ['first_mission', 'green_thumb', 'water_saver', 'solar_survivor', 'radiation_ready', 'power_master', 'supply_runner', 'perfect_crew', 'researcher', 'fixer', 'lunar_commander', 'mars_pioneer'];
  // prefer the badge tied to the next mission
  final tied = {3: 'green_thumb', 4: 'radiation_ready', 2: 'water_saver'}[nextMission];
  if (tied != null && !earned.contains(tied)) return badgeById(tied);
  for (final id in order) {
    if (!earned.contains(id)) return badgeById(id);
  }
  return null;
}
