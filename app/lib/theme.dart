import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the "ShotScout Android App" mockup.
class C {
  static const bg = Color(0xFF0A0A12);
  static const surface = Color(0xFF14141F);
  static const surfaceHigh = Color(0xFF1C1C2A);
  static const border = Color(0xFF2A2A3A);
  static const text = Color(0xFFF5F5F7);
  static const muted = Color(0xFFA0A0B4);
  static const accent = Color(0xFFE5243B);
  static const gold = Color(0xFFF5A04A);
  static const blue = Color(0xFF5B7BD8);
  static const chip = Color(0x8C6E6E82);
}

/// Spacing scale: every gap and padding is one of these.
class S {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

/// Motion: short for feedback, medium for content arriving.
class Motion {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

/// Bebas Neue: poster titles.
TextStyle display(double size) =>
    GoogleFonts.bebasNeue(fontSize: size, height: 0.95, letterSpacing: 0.3, color: C.text);

/// Courier Prime: anything from the screenplay.
TextStyle script({double size = 13, bool bold = true, Color color = C.text}) => GoogleFonts.courierPrime(
    fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color);

/// Small caps-style label, e.g. "SCENE 4 OF 12".
const eyebrow = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.9, color: C.text);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final text = GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: C.bg),
    }),
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: Colors.white,
      secondary: C.gold,
      surface: C.surface,
      onSurface: C.text,
      outline: C.border,
    ),
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      bodySmall: text.bodySmall?.copyWith(color: C.muted, fontSize: 13),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: display(30),
    ),
    cardTheme: const CardThemeData(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: C.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.text,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      labelStyle: const TextStyle(color: C.muted),
      floatingLabelStyle: const TextStyle(color: C.text),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.accent, width: 1.5),
      ),
    ),
    dividerColor: C.border,
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(backgroundColor: C.surfaceHigh, contentTextStyle: TextStyle(color: C.text)),
  );
}
