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

  // Defer optional native plugins until the first screen has had time to
  // initialize local notes and folders. Start them sequentially to reduce
  // contention between platform-channel initializations on Android.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeOptionalServices());
  });
}


Future<void> _initializeOptionalServices() async {
  await Future<void>.delayed(const Duration(seconds: 2));

  await _runStartupTask(
    'analytics',
    () => OrahAnalyticsService.instance.initialize(),
  );
  await _runStartupTask(
    'entitlements',
    () => OrahEntitlementService.instance.initialize(),
  );
  await _runStartupTask('reminders', () async {
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
  });
  await _runStartupTask(
    'share intake',
    () => OrahShareIntakeService.instance.initialize(),
  );
  await _runStartupTask(
    'Android intents',
    () => OrahAndroidIntentService.instance.initialize(),
  );
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
