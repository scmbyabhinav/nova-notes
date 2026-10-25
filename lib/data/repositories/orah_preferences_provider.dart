import 'package:shared_preferences/shared_preferences.dart';

/// Single-flight access to the platform preferences plugin.
///
/// Multiple tabs are mounted together in NovaShell. Serializing the first
/// platform-channel read prevents note and folder repositories from racing
/// separate SharedPreferences initialization calls. A failed attempt is not
/// cached, so Retry can make a fresh attempt.
class OrahPreferencesProvider {
  OrahPreferencesProvider._();

  static SharedPreferences? _instance;
  static Future<SharedPreferences>? _pending;
  static int _generation = 0;

  static Future<SharedPreferences> instance() async {
    final cached = _instance;
    if (cached != null) {
      return cached;
    }

    final generation = _generation;
    final pending = _pending ??= SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 8));
    try {
      final preferences = await pending;
      if (generation == _generation) _instance = preferences;
      return preferences;
    } catch (_) {
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }
  static Future<void> resetForTesting() async {
    _generation++;
    final pending = _pending;
    if (pending != null) { try { await pending; } catch (_) {} }
    _instance = null;
    _pending = null;
  }
}
