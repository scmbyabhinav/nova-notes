import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/note_repository_provider.dart';
import 'package:orah_notes/data/repositories/orah_preferences_provider.dart';
import 'support/orah_test_diagnostics.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Directory? databaseDirectory;
  setUp(() async {
    OrahTestDiagnostics.beginCycle('flutter-test');
    OrahTestDiagnostics.log('registered setup callback ENTER');
    try {
      await OrahTestDiagnostics.bounded('setup: NoteRepositoryProvider.resetForTesting', NoteRepositoryProvider.resetForTesting);
      await OrahTestDiagnostics.bounded('setup: OrahPreferencesProvider.resetForTesting', OrahPreferencesProvider.resetForTesting);
      await OrahTestDiagnostics.bounded('setup: OrahDatabase.closeForTesting (setup reset, not final teardown)', OrahDatabase.closeForTesting);
      databaseDirectory = await OrahTestDiagnostics.bounded('setup: create isolated SQLite temporary directory', () => Directory.systemTemp.createTemp('orah_test_db_'));
      await OrahTestDiagnostics.bounded('setup: set SQLite databases path', () => databaseFactoryFfi.setDatabasesPath(databaseDirectory!.path));
    } catch (error, stackTrace) {
      OrahTestDiagnostics.log('registered setup callback FAILED error=$error');
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      OrahTestDiagnostics.log('registered setup callback EXIT');
    }
  });
  tearDown(() async {
    OrahTestDiagnostics.setPhase('teardown');
    OrahTestDiagnostics.log('registered config teardown callback ENTER; later-registered test callbacks execute first (LIFO)');
    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> attemptCleanup(String checkpoint, Future<void> Function() operation) async {
      try { await OrahTestDiagnostics.bounded(checkpoint, operation); }
      catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        OrahTestDiagnostics.log('cleanup failure recorded; continuing diagnostic cleanup: $checkpoint');
      }
    }
    try {
      await attemptCleanup('final teardown: NoteRepositoryProvider.resetForTesting', NoteRepositoryProvider.resetForTesting);
      await attemptCleanup('final teardown: OrahPreferencesProvider.resetForTesting', OrahPreferencesProvider.resetForTesting);
      await attemptCleanup('final teardown: OrahDatabase.closeForTesting (final teardown, not setup)', OrahDatabase.closeForTesting);
      final directory = databaseDirectory;
      databaseDirectory = null;
      if (directory != null) {
        await attemptCleanup('final teardown: temporary SQLite directory deletion', () async {
          if (await directory.exists()) await directory.delete(recursive: true);
        });
      }
    } finally {
      OrahTestDiagnostics.log('registered config teardown callback EXIT');
      OrahTestDiagnostics.log('final teardown completion checkpoint reached');
    }
    if (firstError != null) Error.throwWithStackTrace(firstError!, firstStackTrace!);
  });
  await testMain();
}
