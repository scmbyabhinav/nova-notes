import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'services/orah_reminder_service.dart';
import 'services/nova_attachment_service.dart';
import 'services/orah_share_intake_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await OrahReminderService.instance.initialize();
  runApp(const OrahApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    OrahReminderService.instance.openPendingNotification();
    OrahShareIntakeService.instance.initialize();
  });
}
