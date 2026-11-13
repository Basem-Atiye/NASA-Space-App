import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// The game's palette, taken from the Figma design ("Junior Astronaut
/// Mission Trainer"). Every interface colour comes from here.
///
/// The brand colours (Frozen Water, Electric Sapphire, Strong Cyan, Twilight
/// Indigo) dress the interface on a deep navy night sky. Each supply has its
/// own colour (air cyan, water blue, food green, power orange) and three
/// state colours say how things are going (green fine, yellow low, red danger).
class C {
  C._();
  // brand
  static const frozen = Color(0xFFDAFCEE); // Frozen Water: text
  static const sapphire = Color(0xFF405FFA); // Electric Sapphire
  static const cyan = Color(0xFF0ABCCA); // Strong Cyan: main buttons
  static const cyanEdge = Color(0xFF067F89); // the 3D edge under cyan buttons
  static const indigo = Color(0xFF3C3664); // Twilight Indigo: cards
  static const evergreen = Color(0xFF07240F); // kept for older art

  // night sky and surfaces
  static const bg = Color(0xFF0A1331); // top of the sky
  static const bgSoft = Color(0xFF171B41); // lower sky
  static const ink = Color(0xFF091230); // tab bar, dark chips, empty bars, text on cyan
  static const panel = Color(0xFF3C3664); // cards
  static const panelSolid = Color(0xFF3C3664);
  static const raised = Color(0xFF4A4378); // raised cards and secondary buttons, the ground hill
  static const raisedEdge = Color(0xFF2F2A55); // the 3D edge under secondary buttons
  static const panelDeep = Color(0xFF1C1D43); // inset rows inside a card
  static const locked = Color(0xFF36325F); // locked rows
  static const info = Color(0xFF272C69); // "new idea" cards (sapphire border)
  static const line = Color(0xFF5E5690); // borders
  static const lineSoft = Color(0x335E5690);

  // text
  static const text = frozen;
  static const muted = Color(0xFFA3C4BA);
  static const dim = Color(0xFF8A86B3);

  // supplies
  static const air = Color(0xFF0ABCCA);
  static const water = Color(0xFF5B7BFF);
  static const food = Color(0xFF3DDC97);
  static const power = Color(0xFFFF8A3D);
  static const shield = Color(0xFFFFD23F);
  static const research = Color(0xFFDAFCEE);

  // states
  static const green = Color(0xFF3DDC97); // fine, success
  static const yellow = Color(0xFFFFD23F); // low, careful, stars
  static const amber = yellow;
  static const red = Color(0xFFFF5470); // danger
  static const orange = Color(0xFFFF8A3D);
  static const violet = Color(0xFF8FA2FF);
  static const gold = yellow; // stars
  static const progress = Color(0xFF2B84E8); // the day progress bar
}

class F {
  F._();
  static const display = 'Fredoka'; // titles, numbers, buttons
  static const serif = display; // older call sites
  static const body = 'Nunito';
  static const mono = 'JetBrainsMono';
}

class T {
  T._();
  static const hero = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 46, height: 1.0, color: C.text);
  static const h1 = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 30, color: C.text, height: 1.12);
  static const h2 = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 22, color: C.text, height: 1.2);
  static const h3 = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 18, color: C.text, height: 1.2);
  static const label = TextStyle(fontFamily: F.body, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.8, color: C.cyan);
  static const body = TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 15, height: 1.45, color: C.text);
  static const bodySmall = TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.4, color: C.muted);
  static const button = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 20, color: C.ink);
  static const number = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w600, fontSize: 30, height: 1, color: C.text);
  static const mono = TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w500, fontSize: 13, color: C.text, fontFeatures: [FontFeature.tabularFigures()]);
  static const monoSmall = TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w500, fontSize: 11, color: C.muted, fontFeatures: [FontFeature.tabularFigures()]);
}

/// Standard motion: short, soft ease-out (see the plan's animation rules).
class Motion {
  Motion._();
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: F.body);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: base.colorScheme.copyWith(primary: C.cyan, onPrimary: C.ink, secondary: C.sapphire, surface: C.panel, error: C.red),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text, fontFamily: F.body),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.cyan,
      inactiveTrackColor: C.ink,
      thumbColor: C.frozen,
      overlayColor: Color(0x220ABCCA),
      trackHeight: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.frozen : C.frozen),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.cyan : C.ink),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
    snackBarTheme: const SnackBarThemeData(backgroundColor: C.panelSolid, contentTextStyle: T.body),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Color for a fraction where low is bad (stores, power).
Color levelColor(double frac) {
  if (frac < 0.15) return C.red;
  if (frac < 0.35) return C.yellow;
  return C.green;
}
