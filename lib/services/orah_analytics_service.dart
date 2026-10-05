import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Privacy-conscious usage analytics for ORAH.
///
/// Custom events intentionally contain no note content or personal profile data.
/// Analytics is best-effort and must never block local note-taking.
class OrahAnalyticsService {
  OrahAnalyticsService._();

  static final OrahAnalyticsService instance = OrahAnalyticsService._();

  FirebaseAnalytics? _analytics;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.logEvent(name: 'orah_app_opened');
    } catch (_) {
      // Keep ORAH usable offline or when Firebase configuration is unavailable.
      _analytics = null;
    }
  }

  Future<void> logNoteCreated({required String noteType}) async {
    await _logEvent(
      'note_created',
      parameters: <String, Object>{'note_type': noteType},
    );
  }

  Future<void> logProUpgradeViewed() async {
    await _logEvent('view_pro_upgrade');
  }

  Future<void> _logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics failures are non-fatal and should not interrupt note-taking.
    }
  }
}
