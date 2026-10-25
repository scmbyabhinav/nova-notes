import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';

/// Configure native SQLite and give each test its own database directory.
///
/// Do not delete these directories in tearDown: widget callbacks and debounced
/// autosaves may still be completing after a test's last pump. Removing an
/// open database file causes SQLite SQLITE_IOERR (1802) in the next async
/// transaction. The OS cleans these uniquely named temp directories later.
Future<void> testExecutable(Future<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await OrahDatabase.closeForTesting();
    final directory = await Directory.systemTemp.createTemp('orah_test_db_');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
  });

  tearDown(() async {
    // Close connections, but deliberately leave the directory on disk so any
    // late async operation cannot target a deleted SQLite file.
    await OrahDatabase.closeForTesting();
  });

  await testMain();
}
