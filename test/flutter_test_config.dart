import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialize SQLite FFI for plain database/repository tests. Widget tests
/// must inject in-memory repositories and must not close a shared database.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
