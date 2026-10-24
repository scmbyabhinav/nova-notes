import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';

/// Configure a native SQLite implementation and give every test its own
/// database directory. Without per-test isolation, concurrently executing
/// test files can open the same orah_notes.db and contaminate or lock each
/// other's data, making stream and widget tests flaky or appear to hang.
Future<void> testExecutable(Future<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Directory? isolatedDatabaseDirectory;

  setUp(() async {
    await OrahDatabase.closeForTesting();
    isolatedDatabaseDirectory =
        await Directory.systemTemp.createTemp('orah_test_db_');
    await databaseFactoryFfi
        .setDatabasesPath(isolatedDatabaseDirectory!.path);
  });

  tearDown(() async {
    await OrahDatabase.closeForTesting();
    final directory = isolatedDatabaseDirectory;
    isolatedDatabaseDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  await testMain();
}
