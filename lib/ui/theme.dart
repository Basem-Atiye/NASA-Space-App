import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// The game's palette. Every interface colour comes from here.
///
/// Five brand colours (Frozen Water, Electric Sapphire, Strong Cyan,
/// Twilight Indigo, Evergreen) dress the interface. Real objects in the art
/// (Earth, the Moon, gold foil) keep their real colours, and one soft red is
/// kept only for real danger.
class C {
  C._();
  // brand
  static const frozen = Color(0xFFD9FCED); // Frozen Water
  static const sapphire = Color(0xFF405FFA); // Electric Sapphire
  static const cyan = Color(0xFF09BBC8); // Strong Cyan
  static const indigo = Color(0xFF3B3664); // Twilight Indigo
  static const evergreen = Color(0xFF07240F); // Evergreen

  // derived surfaces
  static const bg = Color(0xFF04120A); // Evergreen deepened toward black
  static const bgSoft = Color(0xFF06170C);
  static const panel = Color(0xD93B3664); // Indigo glass
  static const panelSolid = Color(0xFF2E2A52);
  static const panelDeep = Color(0xFF1D1B38);
  static const line = Color(0x29D9FCED); // Frozen Water at 16%
  static const lineSoft = Color(0x1AD9FCED);

  // text
  static const text = frozen;
  static const muted = Color(0xFFB9DCCD);
  static const dim = Color(0xFF7FA597);

  // meaning (kept within the palette, plus one red for danger)
  static const amber = Color(0xFF8FA2FF); // caution: light sapphire
  static const red = Color(0xFFFF4D5A); // danger only
  static const green = frozen; // success
  static const violet = Color(0xFF8FA2FF);
  static const gold = cyan; // stars
}

class F {
  F._();
  static const serif = 'Fraunces';
  static const display = 'Manrope';
  static const body = 'Manrope';
  static const mono = 'JetBrainsMono';
}

class T {
  T._();
  static const hero = TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 44, height: 0.98, letterSpacing: -0.5, color: C.text);
  static const h1 = TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 26, color: C.text, height: 1.15);
  static const h2 = TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w600, fontSize: 20, color: C.text, height: 1.2);
  static const h3 = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w700, fontSize: 15, color: C.text);
  static const label = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2, color: C.cyan);
  static const body = TextStyle(fontFamily: F.body, fontWeight: FontWeight.w500, fontSize: 14.5, height: 1.45, color: C.text);
  static const bodySmall = TextStyle(fontFamily: F.body, fontWeight: FontWeight.w500, fontSize: 13, height: 1.4, color: C.muted);
  static const button = TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.5, color: Colors.white);
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
    colorScheme: base.colorScheme.copyWith(primary: C.sapphire, secondary: C.cyan, surface: C.panelSolid, error: C.red),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text, fontFamily: F.body),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.cyan,
      inactiveTrackColor: C.lineSoft,
      thumbColor: C.frozen,
      overlayColor: Color(0x2209BBC8),
      trackHeight: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.frozen : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.sapphire : C.lineSoft),
      trackOutlineColor: WidgetStateProperty.all(C.line),
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
  if (frac < 0.35) return C.amber;
  return C.cyan;
}
