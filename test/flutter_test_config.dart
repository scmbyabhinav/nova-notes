import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Flutter runs this before each test file, so repository tests use the same
/// SQLite implementation as the database migration tests instead of failing
/// before reaching their assertions on hosts without the native sqflite plugin.
Future<void> testExecutable(Future<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
