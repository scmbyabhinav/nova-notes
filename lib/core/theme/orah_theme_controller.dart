import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrahThemeController extends ChangeNotifier {
  static const _modeKey = 'orah_theme_mode';
  static const _accentKey = 'orah_accent_color';

  ThemeMode _mode = ThemeMode.system;
  int _accent = 0xFF2563EB;

  ThemeMode get mode => _mode;
  int get accent => _accent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey);
    final accent = prefs.getInt(_accentKey);
    if (mode != null) {
      _mode = ThemeMode.values.firstWhere((m) => m.name == mode, orElse: () => ThemeMode.system);
    }
    if (accent != null) _accent = accent;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.name);
  }

  Future<void> setAccent(Color value) async {
    _accent = value.value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, _accent);
  }
}
