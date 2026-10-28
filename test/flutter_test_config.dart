import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/local_note_repository.dart';

/// Initialize SQLite FFI and give each test an isolated on-disk database.
///
/// A unique directory per test prevents persistent rows from one test leaking
/// into another. The database is closed before changing paths and before the
/// temporary directory is removed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Directory? databaseDirectory;
  setUp(() async {
    await LocalNoteRepository.drainForTesting();
    await OrahDatabase.closeForTesting();
    databaseDirectory =
        await Directory.systemTemp.createTemp('orah_test_db_');
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory!.path);
  });

  tearDown(() async {
    // Let any save/read already started by a widget finish before SQLite closes.
    await LocalNoteRepository.drainForTesting();
    await OrahDatabase.closeForTesting();
    final directory = databaseDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    databaseDirectory = null;
  });

  await testMain();
}
