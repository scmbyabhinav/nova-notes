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

  static Future<SharedPreferences> instance() async {
    print('[ORAH-DIAG] preferences.instance entered');
    final cached = _instance;
    if (cached != null) {
      print('[ORAH-DIAG] preferences.instance using cached preferences');
      return cached;
    }

    print('[ORAH-DIAG] preferences: calling SharedPreferences.getInstance');
    final pending = _pending ??= SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 8));
    try {
      final preferences = await pending;
      print('[ORAH-DIAG] preferences: SharedPreferences ready');
      _instance = preferences;
      return preferences;
    } catch (error, stackTrace) {
      print('[ORAH-DIAG] preferences initialization failed: $error\n$stackTrace');
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }
}
