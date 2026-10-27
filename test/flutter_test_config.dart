import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialize SQLite FFI for Flutter tests so repository tests use the same
/// SQLite implementation without requiring Android/iOS platform channels.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
