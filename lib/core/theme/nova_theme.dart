import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/nova_constants.dart';

enum OrahThemeMode { system, light, dark, amoled }

class OrahThemeController extends ChangeNotifier {
  OrahThemeController._();
  static final instance = OrahThemeController._();
  ThemeMode mode = ThemeMode.system;
  bool amoled = false;
  Color seedColor = const Color(NovaConstants.primaryBlue);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString('orah_theme_mode') ?? 'system';
    final colorValue = prefs.getInt('orah_accent_color');
    mode = switch (modeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    amoled = modeName == 'amoled';
    if (colorValue != null) seedColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setMode(OrahThemeMode value) async {
    mode = switch (value) {
      OrahThemeMode.light => ThemeMode.light,
      OrahThemeMode.dark || OrahThemeMode.amoled => ThemeMode.dark,
      OrahThemeMode.system => ThemeMode.system,
    };
    amoled = value == OrahThemeMode.amoled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orah_theme_mode', value.name);
    notifyListeners();
  }

  Future<void> setAccent(Color color) async {
    seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('orah_accent_color', color.value);
    notifyListeners();
  }
}

class NovaTheme {
  NovaTheme._();

  static ThemeData light({Color seedColor = const Color(NovaConstants.primaryBlue)}) {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(NovaConstants.backgroundLight),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 0, backgroundColor: Colors.transparent),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(NovaConstants.surfaceLight),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(height: 72, elevation: 0, indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    );
  }

  static ThemeData dark({Color seedColor = const Color(NovaConstants.primaryBlue), bool amoled = false}) {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: amoled ? Colors.black : const Color(NovaConstants.backgroundDark),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 0, backgroundColor: Colors.transparent),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled ? const Color(0xFF080808) : const Color(NovaConstants.surfaceDark),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: amoled ? const Color(0xFF080808) : const Color(NovaConstants.surfaceDark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(height: 72, elevation: 0, indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}
