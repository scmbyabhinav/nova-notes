import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/local_note_repository.dart';

/// Registers per-test SQLite isolation for plain test() suites that exercise
/// LocalNoteRepository. Do not call from testWidgets suites.
void setUpIsolatedSqliteTestDatabase() {
  Directory? databaseDirectory;

  setUp(() async {
    await LocalNoteRepository.drainForTesting();
    await OrahDatabase.closeForTesting();
    databaseDirectory =
        await Directory.systemTemp.createTemp('orah_repository_test_');
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory!.path);
  });

  tearDown(() async {
    await LocalNoteRepository.drainForTesting();
    await OrahDatabase.closeForTesting();
    final directory = databaseDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    databaseDirectory = null;
  });
}
