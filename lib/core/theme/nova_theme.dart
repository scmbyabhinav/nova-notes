import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaTheme {
  NovaTheme._();

  static const _lightBackground = Color(0xFFFAFAFA);
  static const _darkBackground = Color(0xFF121212);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _darkSurface = Color(0xFF1C1C1E);
  static const _accent = Color(0xFF2A1B3D);
  static const _darkAccent = Color(0xFF34D399);

  static ThemeData light({Color? seed}) {
    final accent = seed ?? _accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: _lightSurface,
    ).copyWith(primary: accent, onPrimary: Colors.white);
    final baseText = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _lightBackground,
      textTheme: baseText.copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineSmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          textStyle: baseText.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(textStyle: baseText.bodyLarge?.copyWith(fontSize: 15, height: 1.55)),
        bodyMedium: GoogleFonts.inter(textStyle: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.45)),
        bodySmall: GoogleFonts.inter(textStyle: baseText.bodySmall?.copyWith(fontSize: 12, height: 1.4)),
        labelLarge: GoogleFonts.inter(textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        surfaceTintColor: Colors.transparent,
        color: _lightSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ThemeData dark({Color? seed}) {
    final accent = seed ?? _darkAccent;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: _darkSurface,
    ).copyWith(primary: accent, onPrimary: Colors.white);
    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,
      textTheme: baseText.copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineLarge?.copyWith(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.7),
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          textStyle: baseText.headlineSmall?.copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          textStyle: baseText.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(textStyle: baseText.bodyLarge?.copyWith(fontSize: 15, height: 1.55)),
        bodyMedium: GoogleFonts.inter(textStyle: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.45)),
        bodySmall: GoogleFonts.inter(textStyle: baseText.bodySmall?.copyWith(fontSize: 12, height: 1.4)),
        labelLarge: GoogleFonts.inter(textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        color: _darkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
