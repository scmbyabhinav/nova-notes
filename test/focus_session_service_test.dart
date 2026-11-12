import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orah_notes/services/focus_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records a completed session only once', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = FocusSessionService(preferences);
    final started = DateTime(2026, 11, 12, 9);
    final completed = started.add(const Duration(minutes: 25));

    expect(await service.recordCompleted(
      id: 'session-1',
      startedAt: started,
      completedAt: completed,
      durationMinutes: 25,
    ), isTrue);
    expect(await service.recordCompleted(
      id: 'session-1',
      startedAt: started,
      completedAt: completed,
      durationMinutes: 25,
    ), isFalse);
    expect(await service.count(), 1);
    expect(await service.totalMinutes(), 25);
  });

  test('rejects invalid or incomplete sessions', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = FocusSessionService(preferences);
    final now = DateTime(2026, 11, 12, 9);

    expect(await service.recordCompleted(
      id: 'invalid',
      startedAt: now,
      completedAt: now,
      durationMinutes: 25,
    ), isFalse);
    expect(await service.recordCompleted(
      id: 'invalid-duration',
      startedAt: now,
      completedAt: now.add(const Duration(minutes: 25)),
      durationMinutes: 0,
    ), isFalse);
    expect(await service.count(), 0);
  });

  test('exports and merges focus history during restore', () async {
    final preferences = await SharedPreferences.getInstance();
    final source = FocusSessionService(preferences);
    final started = DateTime(2026, 11, 12, 9);
    await source.recordCompleted(
      id: 'session-backup',
      startedAt: started,
      completedAt: started.add(const Duration(minutes: 25)),
      durationMinutes: 25,
      noteId: 'note-1',
    );
    final backup = await source.exportJson();

    SharedPreferences.setMockInitialValues({});
    final restoredPreferences = await SharedPreferences.getInstance();
    final restored = FocusSessionService(restoredPreferences);
    expect(await restored.importJson(backup), 1);
    expect(await restored.importJson(backup), 0);
    final sessions = await restored.getSessions();
    expect(sessions.single.noteId, 'note-1');
    expect(await restored.totalMinutes(), 25);
  });
}
