/// Every mission has its own mood: the colour of the sky and the light, what
/// floats in the air, and the accent colour of the buttons. The theme is
/// chosen from what is happening in the level (a storm, the night, the ice
/// crater...) so it always matches the story.
library;

import 'package:flutter/material.dart';

enum Ambient { none, frost, alarm, aurora, night, spores, embers, quakeDust, dustDrift }

class MissionTheme {
  final String id;

  /// A short name shown when the level starts ("ICE CRATER").
  final String name;

  /// Sky from the top of the screen to the horizon.
  final Color skyTop, skyMid, skyLow;

  /// The low Sun: its colour and how strong its glow is (0 hides it).
  final Color sun;
  final double sunGlow;

  /// The light on Nova's sunny side and the shade on the other.
  final Color rim;
  final Color shade;

  /// Ground: lit top, middle, far bottom.
  final Color groundTop, groundMid, groundLow;

  /// Hills: dark faces and lit faces (far, mid, near).
  final List<Color> ridgeDark, ridgeLit;

  /// What floats in the air.
  final Ambient ambient;

  /// Accent for the buttons, meters and cards in this mission.
  final Color accent;

  const MissionTheme({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyMid,
    required this.skyLow,
    required this.sun,
    required this.sunGlow,
    required this.rim,
    required this.shade,
    required this.groundTop,
    required this.groundMid,
    required this.groundLow,
    required this.ridgeDark,
    required this.ridgeLit,
    required this.ambient,
    required this.accent,
  });

  /// Sky colour at height t (0 top, 1 horizon), eased so it never bands.
  Color skyAt(double t) {
    final e = t.clamp(0.0, 1.0);
    final k = e * e * (3 - 2 * e); // smoothstep
    if (k < 0.62) return Color.lerp(skyTop, skyMid, k / 0.62)!;
    return Color.lerp(skyMid, skyLow, (k - 0.62) / 0.38)!;
  }
}

const _ridgeDark = [Color(0xFF3E4448), Color(0xFF6F6C68), Color(0xFF8E8A84)];
const _ridgeLit = [Color(0xFF6B6E6C), Color(0xFFA9A59E), Color(0xFFCAC6BE)];

/// The golden low Sun of the south pole: the default look.
const themeDawn = MissionTheme(
  id: 'dawn',
  name: 'SOUTH POLE MORNING',
  skyTop: Color(0xFF020308),
  skyMid: Color(0xFF080C16),
  skyLow: Color(0xFF1E1C24),
  sun: Color(0xFFFFE6B8),
  sunGlow: 1,
  rim: Color(0x44FFE9C4),
  shade: Color(0x30000000),
  groundTop: Color(0xFFDCD5C8),
  groundMid: Color(0xFFB9B2A6),
  groundLow: Color(0xFF8C867C),
  ridgeDark: _ridgeDark,
  ridgeLit: [Color(0xFF79726A), Color(0xFFB8AC9C), Color(0xFFD6CBBB)],
  ambient: Ambient.dustDrift,
  accent: Color(0xFF09BBC8),
);

/// Bright, silver, sharp shadows: building and engineering missions.
const themeSilver = MissionTheme(
  id: 'silver',
  name: 'CLEAR SKY',
  skyTop: Color(0xFF010204),
  skyMid: Color(0xFF060A12),
  skyLow: Color(0xFF151C26),
  sun: Color(0xFFF4F8FF),
  sunGlow: 0.85,
  rim: Color(0x40F2F7FF),
  shade: Color(0x34000000),
  groundTop: Color(0xFFDAD8D4),
  groundMid: Color(0xFFB7B5B0),
  groundLow: Color(0xFF8B8985),
  ridgeDark: _ridgeDark,
  ridgeLit: _ridgeLit,
  ambient: Ambient.none,
  accent: Color(0xFF405FFA),
);

/// A crash, a leak, a fire: red warning light.
const themeAlarm = MissionTheme(
  id: 'alarm',
  name: 'EMERGENCY',
  skyTop: Color(0xFF060205),
  skyMid: Color(0xFF12070C),
  skyLow: Color(0xFF2A1218),
  sun: Color(0xFFFFC9A8),
  sunGlow: 0.8,
  rim: Color(0x48FFB49C),
  shade: Color(0x3A12000A),
  groundTop: Color(0xFFD6CBC4),
  groundMid: Color(0xFFB0A49D),
  groundLow: Color(0xFF857973),
  ridgeDark: [Color(0xFF443C40), Color(0xFF6E6366), Color(0xFF8E8384)],
  ridgeLit: [Color(0xFF79676A), Color(0xFFB09A98), Color(0xFFCDB8B4)],
  ambient: Ambient.alarm,
  accent: Color(0xFFFF6B5E),
);

/// The ice crater: cold blue light and frost glints.
const themeIce = MissionTheme(
  id: 'ice',
  name: 'ICE CRATER',
  skyTop: Color(0xFF01040A),
  skyMid: Color(0xFF061224),
  skyLow: Color(0xFF12304A),
  sun: Color(0xFFDDF4FF),
  sunGlow: 0.7,
  rim: Color(0x40BFEAFF),
  shade: Color(0x38001024),
  groundTop: Color(0xFFD3DCE2),
  groundMid: Color(0xFFA9B6C0),
  groundLow: Color(0xFF7A8792),
  ridgeDark: [Color(0xFF2E3D4A), Color(0xFF55636E), Color(0xFF76848E)],
  ridgeLit: [Color(0xFF5C7486), Color(0xFF9DB2C0), Color(0xFFC4D4DE)],
  ambient: Ambient.frost,
  accent: Color(0xFF6FE3FF),
);

/// A solar storm: violet sky, proton streaks and aurora light.
const themeStorm = MissionTheme(
  id: 'storm',
  name: 'SOLAR STORM',
  skyTop: Color(0xFF05020C),
  skyMid: Color(0xFF130A2A),
  skyLow: Color(0xFF2C1B4A),
  sun: Color(0xFFF2DCFF),
  sunGlow: 1.2,
  rim: Color(0x48D9C4FF),
  shade: Color(0x3A0A0020),
  groundTop: Color(0xFFD2CCD8),
  groundMid: Color(0xFFADA5B6),
  groundLow: Color(0xFF7F7789),
  ridgeDark: [Color(0xFF3A3248), Color(0xFF625872), Color(0xFF857B92)],
  ridgeLit: [Color(0xFF6B5D84), Color(0xFFA596BC), Color(0xFFC9BEDA)],
  ambient: Ambient.aurora,
  accent: Color(0xFFB9A8FF),
);

/// The long lunar night: only the helmet lamp and the stars.
const themeNight = MissionTheme(
  id: 'night',
  name: 'LUNAR NIGHT',
  skyTop: Color(0xFF000105),
  skyMid: Color(0xFF02050E),
  skyLow: Color(0xFF070D1C),
  sun: Color(0xFFFFFFFF),
  sunGlow: 0,
  rim: Color(0x2296B4FF),
  shade: Color(0x40000010),
  groundTop: Color(0xFF8D93A0),
  groundMid: Color(0xFF6C7180),
  groundLow: Color(0xFF4B505C),
  ridgeDark: [Color(0xFF1A1F2A), Color(0xFF2C3240), Color(0xFF3C4352)],
  ridgeLit: [Color(0xFF2E3546), Color(0xFF4A5368), Color(0xFF606A80)],
  ambient: Ambient.night,
  accent: Color(0xFF7FA4FF),
);

/// The greenhouse: soft green grow-light glow and floating spores.
const themeGarden = MissionTheme(
  id: 'garden',
  name: 'GREEN HOUSE',
  skyTop: Color(0xFF010503),
  skyMid: Color(0xFF06140E),
  skyLow: Color(0xFF14301F),
  sun: Color(0xFFF1FFE0),
  sunGlow: 0.9,
  rim: Color(0x40D8FFC8),
  shade: Color(0x34001208),
  groundTop: Color(0xFFD8D9CC),
  groundMid: Color(0xFFB2B4A6),
  groundLow: Color(0xFF85887B),
  ridgeDark: [Color(0xFF34403A), Color(0xFF5D6A62), Color(0xFF7E8A80)],
  ridgeLit: [Color(0xFF63766A), Color(0xFFA2B4A6), Color(0xFFC6D4C8)],
  ambient: Ambient.spores,
  accent: Color(0xFF5BE38A),
);

/// Launch day: a warm orange horizon and engine embers.
const themeLaunch = MissionTheme(
  id: 'launch',
  name: 'LAUNCH DAY',
  skyTop: Color(0xFF040208),
  skyMid: Color(0xFF140A10),
  skyLow: Color(0xFF3A1E18),
  sun: Color(0xFFFFC98A),
  sunGlow: 1.3,
  rim: Color(0x50FFC78E),
  shade: Color(0x38100400),
  groundTop: Color(0xFFDDCFC0),
  groundMid: Color(0xFFB8A898),
  groundLow: Color(0xFF8A7A6C),
  ridgeDark: [Color(0xFF443830), Color(0xFF6E6054), Color(0xFF8E7F72)],
  ridgeLit: [Color(0xFF86705E), Color(0xFFC0A68E), Color(0xFFDCC4AC)],
  ambient: Ambient.embers,
  accent: Color(0xFFFFA24C),
);

/// A moonquake: brown dust hanging in the air.
const themeQuake = MissionTheme(
  id: 'quake',
  name: 'MOONQUAKE',
  skyTop: Color(0xFF040303),
  skyMid: Color(0xFF110D0A),
  skyLow: Color(0xFF2A2219),
  sun: Color(0xFFFFE2B0),
  sunGlow: 0.9,
  rim: Color(0x44FFDDB0),
  shade: Color(0x3A0A0500),
  groundTop: Color(0xFFD6CDBE),
  groundMid: Color(0xFFB0A593),
  groundLow: Color(0xFF837867),
  ridgeDark: [Color(0xFF473F35), Color(0xFF6F6556), Color(0xFF8F8574)],
  ridgeLit: [Color(0xFF7D6E5C), Color(0xFFB5A38C), Color(0xFFD2C1AA)],
  ambient: Ambient.quakeDust,
  accent: Color(0xFFFFC857),
);

const allThemes = [themeDawn, themeSilver, themeAlarm, themeIce, themeStorm, themeNight, themeGarden, themeLaunch, themeQuake];

/// Picks the theme from what is on screen. The most dramatic thing wins;
/// quiet levels take turns between the morning and the clear-sky looks.
MissionTheme themeFor({
  required int task,
  bool night = false,
  bool storm = false,
  bool alarm = false,
  bool ice = false,
  bool garden = false,
  bool launch = false,
  bool quake = false,
}) {
  if (night) return themeNight;
  if (storm) return themeStorm;
  if (quake) return themeQuake;
  if (alarm) return themeAlarm;
  if (launch) return themeLaunch;
  if (ice) return themeIce;
  if (garden) return themeGarden;
  return task.isEven ? themeSilver : themeDawn;
}

/// Blends two themes (for a smooth change when the story changes the mood).
MissionTheme lerpTheme(MissionTheme a, MissionTheme b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  Color c(Color x, Color y) => Color.lerp(x, y, t)!;
  return MissionTheme(
    id: '${a.id}>${b.id}:${(t * 20).round()}',
    name: b.name,
    skyTop: c(a.skyTop, b.skyTop),
    skyMid: c(a.skyMid, b.skyMid),
    skyLow: c(a.skyLow, b.skyLow),
    sun: c(a.sun, b.sun),
    sunGlow: a.sunGlow + (b.sunGlow - a.sunGlow) * t,
    rim: c(a.rim, b.rim),
    shade: c(a.shade, b.shade),
    groundTop: c(a.groundTop, b.groundTop),
    groundMid: c(a.groundMid, b.groundMid),
    groundLow: c(a.groundLow, b.groundLow),
    ridgeDark: [for (var i = 0; i < 3; i++) c(a.ridgeDark[i], b.ridgeDark[i])],
    ridgeLit: [for (var i = 0; i < 3; i++) c(a.ridgeLit[i], b.ridgeLit[i])],
    ambient: t < 0.5 ? a.ambient : b.ambient,
    accent: c(a.accent, b.accent),
  );
}

/// The theme a mission will have, guessed from its title and story (for the
/// home screen and the map, before the level is loaded).
MissionTheme themeForText(String text, int n) {
  final t = text.toLowerCase();
  bool any(List<String> w) => w.any(t.contains);
  return themeFor(
    task: n,
    night: any(['night', 'dark', 'eclipse']),
    storm: any(['storm', 'flare', 'radiation', 'solar wind']),
    quake: any(['quake', 'shak']),
    alarm: any(['crash', 'leak', 'emergenc', 'alarm', 'fire', 'cascade', 'broken', 'failure']),
    launch: any(['launch', 'rocket', 'go home', 'liftoff', 'lift off']),
    ice: any(['ice', 'drill', 'water', 'crater', 'cold']),
    garden: any(['greenhouse', 'garden', 'plant', 'seed', 'grow']),
  );
}
