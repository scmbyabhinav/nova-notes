import 'dart:async';

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

  // Keep only synchronous, essential setup before the first Flutter frame.
  // Optional platform services must never hold Android's launch screen open.
  FlutterCryptography.enable();
  tz.initializeTimeZones();

  runApp(const OrahApp());

  // These services are best-effort. Their failures are logged but cannot stop
  // the registration screen or local note-taking UI from appearing.
  unawaited(_runStartupTask(
    'analytics',
    () => OrahAnalyticsService.instance.initialize(),
  ));
  unawaited(_runStartupTask(
    'entitlements',
    () => OrahEntitlementService.instance.initialize(),
  ));
  unawaited(_runStartupTask('reminders', () async {
    await OrahReminderService.instance
        .initialize()
        .timeout(const Duration(seconds: 8));

    final preferences = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 8));
    if (preferences.getBool('orah_daily_reflection_enabled') ?? false) {
      await OrahReminderService.instance
          .scheduleDailyReflection(
            time: TimeOfDay(
              hour: preferences.getInt('orah_daily_reflection_hour') ?? 20,
              minute: preferences.getInt('orah_daily_reflection_minute') ?? 0,
            ),
          )
          .timeout(const Duration(seconds: 8));
    }

    await OrahReminderService.instance
        .openPendingNotification()
        .timeout(const Duration(seconds: 5));
  }));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runStartupTask(
      'share intake',
      () => OrahShareIntakeService.instance.initialize(),
    ));
    unawaited(_runStartupTask(
      'Android intents',
      () => OrahAndroidIntentService.instance.initialize(),
    ));
  });
}

Future<void> _runStartupTask(
  String name,
  Future<void> Function() task,
) async {
  try {
    await task().timeout(const Duration(seconds: 12));
  } catch (error, stackTrace) {
    debugPrint('ORAH optional startup task [$name] failed: $error\\n$stackTrace');
    // Intentionally non-fatal: the core app must remain usable.
  }
}
