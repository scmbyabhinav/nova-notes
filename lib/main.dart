import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'services/orah_reminder_service.dart';
import 'services/orah_share_intake_service.dart';
import 'services/orah_android_intent_service.dart';
import 'services/orah_entitlement_service.dart';
import 'services/orah_analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep synchronous framework setup before the first frame, but do not make
  // the first screen depend on plugins, storage, notifications, or the store.
  FlutterCryptography.enable();
  tz.initializeTimeZones();

  runApp(const OrahApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeStartupServices();
  });
}

/// Initialize optional/platform services after the UI is visible.
///
/// A failure in analytics, notifications, preferences, or Play Billing must
/// not prevent ORAH from showing its first screen or taking local notes.
Future<void> _initializeStartupServices() async {
  try {
    await OrahAnalyticsService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('ORAH analytics initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await OrahReminderService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('ORAH reminder initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('orah_daily_reflection_enabled') ?? false) {
      await OrahReminderService.instance.scheduleDailyReflection(
        time: TimeOfDay(
          hour: preferences.getInt('orah_daily_reflection_hour') ?? 20,
          minute: preferences.getInt('orah_daily_reflection_minute') ?? 0,
        ),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('ORAH startup preferences initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await OrahEntitlementService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('ORAH entitlement initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // These handlers depend on the app's navigator being mounted.
  try {
    await OrahReminderService.instance.openPendingNotification();
  } catch (error, stackTrace) {
    debugPrint('ORAH pending notification handling failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await OrahShareIntakeService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('ORAH share-intake initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await OrahAndroidIntentService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('ORAH Android intent initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
