import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/note_repository_provider.dart';
import 'package:orah_notes/data/repositories/orah_preferences_provider.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Directory? databaseDirectory;
  setUp(() async {
    await NoteRepositoryProvider.resetForTesting();
    await OrahPreferencesProvider.resetForTesting();
    await OrahDatabase.closeForTesting();
    databaseDirectory = await Directory.systemTemp.createTemp('orah_test_db_');
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory!.path);
  });
  tearDown(() async {
    await NoteRepositoryProvider.resetForTesting();
    await OrahPreferencesProvider.resetForTesting();
    await OrahDatabase.closeForTesting();
    final directory = databaseDirectory;
    databaseDirectory = null;
    if (directory != null && await directory.exists()) await directory.delete(recursive: true);
  });
  await testMain();
}
