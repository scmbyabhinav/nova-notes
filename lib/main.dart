import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'services/orah_reminder_service.dart';
import 'services/nova_attachment_service.dart';
import 'services/orah_share_intake_service.dart';
import 'services/orah_android_intent_service.dart';
import 'services/orah_entitlement_service.dart';
import 'services/orah_analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrahAnalyticsService.instance.initialize();
  FlutterCryptography.enable();
  tz.initializeTimeZones();
  await OrahReminderService.instance.initialize();
  final preferences = await SharedPreferences.getInstance();
  if (preferences.getBool('orah_daily_reflection_enabled') ?? false) {
    await OrahReminderService.instance.scheduleDailyReflection(
      time: TimeOfDay(
        hour: preferences.getInt('orah_daily_reflection_hour') ?? 20,
        minute: preferences.getInt('orah_daily_reflection_minute') ?? 0,
      ),
    );
  }
  // Resolve the cached/store entitlement before the first frame so existing
  // Pro users are not briefly treated as Free when opening premium features.
  await OrahEntitlementService.instance.initialize();
  runApp(const OrahApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    OrahReminderService.instance.openPendingNotification();
    OrahShareIntakeService.instance.initialize();
    OrahAndroidIntentService.instance.initialize();
  });
}
