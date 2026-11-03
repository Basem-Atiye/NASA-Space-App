/// Every playable level and co-op mission, with the ids the cloud uses.
///
/// This list is the single source for the `levels` table: the SQL in
/// backend/prisma/migrations/0003_catalogue is generated from it by
/// tools/gen_catalogue_sql.py, and a test checks the two match.
library;

enum Skill { prioritise, systems, rootCause, resourceMath, procedure, teamwork }

extension SkillInfo on Skill {
  /// Database value (enum public.skill).
  String get db => const ['prioritise', 'systems', 'root_cause', 'resource_math', 'procedure', 'teamwork'][index];
  String get title => const ['Prioritise', 'Systems thinking', 'Root cause', 'Resource maths', 'Procedure', 'Teamwork'][index];
  String get short => const ['Priority', 'Systems', 'Root cause', 'Maths', 'Procedure', 'Teamwork'][index];
  String get blurb => const [
        'Deal with what is most dangerous first.',
        'See how one part affects the others.',
        'Find the real reason, not the first guess.',
        'Count, measure and budget what you have.',
        'Follow steps in order and check your work.',
        'Share information and decide together.',
      ][index];

  static Skill? parse(String? s) {
    for (final k in Skill.values) {
      if (k.db == s || k.name == s) return k;
    }
    return null;
  }
}

/// The campaigns in the database (enum public.campaign).
enum CampaignId { cadet, explorer, engineer, coop, survival }

class CatalogueEntry {
  final String id;
  final CampaignId campaign;
  final int number;
  final String title;
  final List<Skill> skills;
  final int minutes;

  /// For co-op missions: the age level it is written for (0 cadet, 1 explorer, 2 engineer).
  final int? coopAge;

  const CatalogueEntry(this.id, this.campaign, this.number, this.title, this.skills, {this.minutes = 10, this.coopAge});

  bool get isCoop => campaign == CampaignId.coop;
}

String levelId(CampaignId c, int n) => '${c.name}-${n.toString().padLeft(2, '0')}';

const _p = Skill.prioritise, _s = Skill.systems, _r = Skill.rootCause, _m = Skill.resourceMath, _o = Skill.procedure, _t = Skill.teamwork;
const _ca = CampaignId.cadet, _ex = CampaignId.explorer, _en = CampaignId.engineer, _co = CampaignId.coop, _su = CampaignId.survival;

const catalogue = <CatalogueEntry>[
  // Cadet · ages 6–10 · "Moon Cadets"
  CatalogueEntry('cadet-01', _ca, 1, 'Suit Up', [_o, _p], minutes: 6),
  CatalogueEntry('cadet-02', _ca, 2, 'Pack the Rocket', [_m, _p], minutes: 6),
  CatalogueEntry('cadet-03', _ca, 3, 'Countdown', [_o], minutes: 5),
  CatalogueEntry('cadet-04', _ca, 4, 'Moon Jump', [_s], minutes: 6),
  CatalogueEntry('cadet-05', _ca, 5, 'Light the Base', [_s, _o], minutes: 7),
  CatalogueEntry('cadet-06', _ca, 6, 'Space Garden', [_m, _s], minutes: 7),
  CatalogueEntry('cadet-07', _ca, 7, 'Clean Water', [_s, _o], minutes: 7),
  CatalogueEntry('cadet-08', _ca, 8, 'Rock Detective', [_r], minutes: 7),
  CatalogueEntry('cadet-09', _ca, 9, 'Rover Ride', [_p, _s], minutes: 7),
  CatalogueEntry('cadet-10', _ca, 10, 'Day and Night', [_s], minutes: 6),
  CatalogueEntry('cadet-11', _ca, 11, 'Astronaut Fitness', [_o], minutes: 6),
  CatalogueEntry('cadet-12', _ca, 12, 'Message Home', [_t], minutes: 6),

  // Explorer · ages 11–14 · Season 1 "Stranded at Shackleton", Season 2 "The Second Crew"
  CatalogueEntry('explorer-01', _ex, 1, 'Crash Landing', [_p, _r]),
  CatalogueEntry('explorer-02', _ex, 2, 'Shelter', [_m, _p]),
  CatalogueEntry('explorer-03', _ex, 3, 'Electricity', [_s, _m]),
  CatalogueEntry('explorer-04', _ex, 4, 'Air, Water, Food', [_m, _s]),
  CatalogueEntry('explorer-05', _ex, 5, 'Smart Life Support', [_s, _o], minutes: 12),
  CatalogueEntry('explorer-06', _ex, 6, 'Hazards', [_p]),
  CatalogueEntry('explorer-07', _ex, 7, 'Diagnose the Lander', [_r]),
  CatalogueEntry('explorer-08', _ex, 8, 'Repair', [_o]),
  CatalogueEntry('explorer-09', _ex, 9, 'Cascade', [_s, _p], minutes: 12),
  CatalogueEntry('explorer-10', _ex, 10, 'Launch', [_o, _t]),
  CatalogueEntry('explorer-11', _ex, 11, 'Ice Hunt', [_r, _m]),
  CatalogueEntry('explorer-12', _ex, 12, 'Rover Expedition', [_m, _p]),
  CatalogueEntry('explorer-13', _ex, 13, 'Greenhouse Crisis', [_s, _r]),
  CatalogueEntry('explorer-14', _ex, 14, 'Moonquake', [_p, _o]),
  CatalogueEntry('explorer-15', _ex, 15, 'The Second Crew', [_t, _m]),

  // Engineer · ages 15–18 · "Artemis Base Camp"
  CatalogueEntry('engineer-01', _en, 1, 'Launch Window', [_m], minutes: 12),
  CatalogueEntry('engineer-02', _en, 2, 'Power Budget', [_m, _s], minutes: 14),
  CatalogueEntry('engineer-03', _en, 3, 'Life Support Balance', [_m, _s], minutes: 14),
  CatalogueEntry('engineer-04', _en, 4, 'Radiation Shield', [_m, _p], minutes: 12),
  CatalogueEntry('engineer-05', _en, 5, 'Ice to Oxygen', [_m, _s], minutes: 14),
  CatalogueEntry('engineer-06', _en, 6, 'Rover Route', [_p, _m], minutes: 12),
  CatalogueEntry('engineer-07', _en, 7, 'Comms Link', [_s, _r], minutes: 12),
  CatalogueEntry('engineer-08', _en, 8, 'Fault Tree', [_r], minutes: 14),
  CatalogueEntry('engineer-09', _en, 9, 'Thermal Control', [_s], minutes: 12),
  CatalogueEntry('engineer-10', _en, 10, 'Landing Pad', [_o, _m], minutes: 12),
  CatalogueEntry('engineer-11', _en, 11, 'Moonquake Structures', [_s, _r], minutes: 12),
  CatalogueEntry('engineer-12', _en, 12, 'Dust Mitigation', [_r, _o], minutes: 12),
  CatalogueEntry('engineer-13', _en, 13, 'Medical Emergency', [_p, _o], minutes: 12),
  CatalogueEntry('engineer-14', _en, 14, 'Design Your Base', [_s, _m], minutes: 16),
  CatalogueEntry('engineer-15', _en, 15, 'Mars Forward', [_t, _s], minutes: 14),

  // Co-op missions · 2–4 players · 6 per age level
  CatalogueEntry('coop-01', _co, 1, 'Suit Up Together', [_t, _o], minutes: 5, coopAge: 0),
  CatalogueEntry('coop-02', _co, 2, 'Find Pip', [_t, _r], minutes: 5, coopAge: 0),
  CatalogueEntry('coop-03', _co, 3, 'Colour Circuit', [_t, _s], minutes: 5, coopAge: 0),
  CatalogueEntry('coop-04', _co, 4, 'Garden Rescue', [_t, _m], minutes: 6, coopAge: 0),
  CatalogueEntry('coop-05', _co, 5, 'Rocket Countdown', [_t, _o], minutes: 5, coopAge: 0),
  CatalogueEntry('coop-06', _co, 6, 'Rock Collectors', [_t, _r], minutes: 6, coopAge: 0),
  CatalogueEntry('coop-07', _co, 7, 'Lander Doctor', [_t, _r], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-08', _co, 8, 'Airlock Leak', [_t, _p], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-09', _co, 9, 'Power Down', [_t, _m], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-10', _co, 10, 'Storm Shelter', [_t, _p], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-11', _co, 11, 'Rover Convoy', [_t, _m], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-12', _co, 12, 'Greenhouse Shift', [_t, _s], minutes: 8, coopAge: 1),
  CatalogueEntry('coop-13', _co, 13, 'Go/No-Go Poll', [_t, _o], minutes: 10, coopAge: 2),
  CatalogueEntry('coop-14', _co, 14, 'Rover Rescue', [_t, _p], minutes: 10, coopAge: 2),
  CatalogueEntry('coop-15', _co, 15, 'Cascade Control', [_t, _s], minutes: 10, coopAge: 2),
  CatalogueEntry('coop-16', _co, 16, 'Gateway Docking', [_t, _m], minutes: 10, coopAge: 2),
  CatalogueEntry('coop-17', _co, 17, 'Moonquake Response', [_t, _r], minutes: 10, coopAge: 2),
  CatalogueEntry('coop-18', _co, 18, 'Medical Evacuation', [_t, _p], minutes: 10, coopAge: 2),

  // Survival (Flight Director missions)
  CatalogueEntry('survival-01', _su, 1, 'Contact Light', [_m]),
  CatalogueEntry('survival-02', _su, 2, 'First Week', [_m, _p]),
  CatalogueEntry('survival-03', _su, 3, 'Every Drop', [_m]),
  CatalogueEntry('survival-04', _su, 4, 'Self-Sufficient', [_m, _s]),
  CatalogueEntry('survival-05', _su, 5, 'Ice Hunters', [_m, _p]),
  CatalogueEntry('survival-06', _su, 6, 'Field Campaign', [_m, _p]),
  CatalogueEntry('survival-07', _su, 7, 'Invisible Danger', [_p]),
  CatalogueEntry('survival-08', _su, 8, 'The Big One', [_p, _s]),
  CatalogueEntry('survival-09', _su, 9, 'Sunset', [_m, _s]),
  CatalogueEntry('survival-10', _su, 10, 'Shackleton Station', [_m, _s, _p]),
];

CatalogueEntry? catalogueEntry(String id) {
  for (final e in catalogue) {
    if (e.id == id) return e;
  }
  return null;
}

List<CatalogueEntry> campaignEntries(CampaignId c) => [for (final e in catalogue) if (e.campaign == c) e];
