/// The three campaigns, one per age level. Each has its own levels, lessons
/// and pacing; the class's age level (set by the teacher) picks the campaign.
library;

import '../data/cadet.dart';
import '../data/catalogue.dart';
import '../data/engineer.dart';
import '../data/explorer_s2.dart';
import '../data/levels.dart';
import '../data/story.dart';
import 'story_model.dart';
import 'story_run.dart';

class Season {
  final String name;
  final int first;
  final int last;
  const Season(this.name, this.first, this.last);
  bool contains(int n) => n >= first && n <= last;
}

class Campaign {
  final CampaignId id;
  final AgeMode mode;
  final String title;
  final String tagline;
  final List<StoryTask> tasks;
  final List<LevelInfo> infos;
  final List<Season> seasons;

  /// The "Day 4 of 12" line on the map and title screens.
  final String Function(int n) dayLabel;

  const Campaign({
    required this.id,
    required this.mode,
    required this.title,
    required this.tagline,
    required this.tasks,
    required this.infos,
    required this.seasons,
    required this.dayLabel,
  });

  int get length => tasks.length;

  StoryTask task(int n) => tasks.firstWhere((t) => t.n == n, orElse: () => tasks.first);
  LevelInfo info(int n) => infos.firstWhere((l) => l.n == n, orElse: () => infos.first);
  String levelIdFor(int n) => levelId(id, n);
  Season seasonOf(int n) => seasons.firstWhere((s) => s.contains(n), orElse: () => seasons.first);
  bool isLast(int n) => n >= length;

  /// The carried numbers when a level is started without a saved run.
  Carry carryDefaults(int n) {
    if (id == CampaignId.explorer) {
      if (n <= 10) return Carry.defaultsFor(n);
      // Season 2: the station is built, the crew is bigger
      return Carry(health: 95, battery: 70, spares: 4, shielding: 10, o2Kg: 40, waterKg: 160, foodKg: 80, flags: {'kit', 'radio', 'tools', 'habitat', 'habSealed', 'panelsUp', 'cable', 'wired', 'generator', 'sensors', 'controller'});
    }
    return Carry(health: 95, battery: 60, spares: 3, shielding: 6, o2Kg: 30, waterKg: 120, foodKg: 60, flags: {'radio', 'habitat', 'habSealed', 'cable', 'generator'});
  }
}

final List<Campaign> campaigns = [
  Campaign(
    id: CampaignId.cadet,
    mode: AgeMode.cadet,
    title: 'Moon Cadets',
    tagline: '12 short Moon missions with Nova! 🚀🌕 Lots of emoji. No timers.',
    tasks: cadetTasks,
    infos: cadetInfos,
    seasons: const [Season('Moon Cadet training', 1, 12)],
    dayLabel: (n) => 'Training day $n of 12',
  ),
  Campaign(
    id: CampaignId.explorer,
    mode: AgeMode.explorer,
    title: 'Stranded at Shackleton',
    tagline: 'Season 1: survive 12 days and fly home. Season 2: come back and build the station.',
    tasks: [...storyTasks, ...explorerS2Tasks],
    infos: [...levelInfos, ...explorerS2Infos],
    seasons: const [Season('Season 1 · Stranded', 1, 10), Season('Season 2 · The Second Crew', 11, 15)],
    dayLabel: (n) => n <= 10 ? 'Day ${levelDay(n)} of $rescueDays' : 'Season 2 · week ${n - 10}',
  ),
  Campaign(
    id: CampaignId.engineer,
    mode: AgeMode.engineer,
    title: 'Artemis Base Camp',
    tagline: 'Fifteen engineering problems with real NASA numbers, from launch windows to Mars.',
    tasks: engineerTasks,
    infos: engineerInfos,
    seasons: const [Season('Build the base', 1, 7), Season('Run the base', 8, 13), Season('Look to Mars', 14, 15)],
    dayLabel: (n) => 'Sol ${const [1, 4, 6, 9, 12, 14, 16, 18, 21, 25, 28, 31, 33, 38, 40][(n - 1).clamp(0, 14)]} of 40',
  ),
];

Campaign campaignFor(AgeMode m) => campaigns[m.index];

Campaign campaignById(CampaignId id) => campaigns.firstWhere((c) => c.id == id, orElse: () => campaigns[1]);
