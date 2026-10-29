import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/kanban/kanban_repository.dart';
import 'package:orah_notes/l10n/app_localizations.dart';
import 'package:orah_notes/screens/kanban_screen.dart';

Future<Database> _memoryDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''CREATE TABLE kanban_cards (
    id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'todo', priority TEXT NOT NULL DEFAULT 'medium', due_date TEXT,
    color_label TEXT, checklist_json TEXT NOT NULL DEFAULT '[]', goal_id TEXT, created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL, deleted_at TEXT, archived_at TEXT, sort_order INTEGER NOT NULL DEFAULT 0
  )''');
  await db.execute('''CREATE TABLE goals (
    id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
    target_date TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT,
    archived_at TEXT, sort_order INTEGER NOT NULL DEFAULT 0
  )''');
  await db.execute('''CREATE TABLE links (
    id TEXT PRIMARY KEY NOT NULL, source_type TEXT NOT NULL, source_id TEXT NOT NULL,
    target_type TEXT NOT NULL, target_id TEXT NOT NULL, link_kind TEXT NOT NULL,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT,
    UNIQUE(source_type, source_id, target_type, target_id, link_kind)
  )''');
  await db.execute('''CREATE TABLE time_entries (
    id TEXT PRIMARY KEY NOT NULL, card_id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT
  )''');
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tablet board shows all three columns at once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final db = await _memoryDatabase();
    final repo = KanbanRepository(db);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: KanbanScreen(repository: repo),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('To Do (0)'), findsOneWidget);
    expect(find.text('In Progress (0)'), findsOneWidget);
    expect(find.text('Done (0)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    tester.view.resetPhysicalSize();
    await repo.dispose();
    await db.close();
  });

  testWidgets('goal board shows all three columns and only linked cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final db = await _memoryDatabase();
    final repo = KanbanRepository(db);
    final goal = await repo.createGoal(title: 'Launch ORAH');
    await repo.createCard(title: 'Goal card', goalId: goal.id);
    await repo.createCard(title: 'Unlinked card');

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: KanbanScreen(repository: repo, initialGoalId: goal.id),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('To Do (1)'), findsOneWidget);
    expect(find.text('In Progress (0)'), findsOneWidget);
    expect(find.text('Done (0)'), findsOneWidget);
    expect(find.text('Goal card'), findsOneWidget);
    expect(find.text('Unlinked card'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    tester.view.resetPhysicalSize();
    await repo.dispose();
    await db.close();
  });

  testWidgets('card can be moved to Done with the quick-move menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final db = await _memoryDatabase();
    final repo = KanbanRepository(db);
    await repo.createCard(title: 'Ship Kanban');

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: KanbanScreen(repository: repo),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Done').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Done (1)'), findsOneWidget);
    expect(find.text('To Do (0)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    tester.view.resetPhysicalSize();
    await repo.dispose();
    await db.close();
  });

  testWidgets('linked card chip opens the linked item', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final db = await _memoryDatabase();
    final repo = KanbanRepository(db);
    final source = await repo.createCard(title: 'Source item');
    final target = await repo.createCard(title: 'Target item');
    await repo.addLink(sourceType: 'card', sourceId: source.id, targetType: 'card', targetId: target.id);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: KanbanScreen(repository: repo),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Linked card'), findsOneWidget);
    await tester.tap(find.text('Linked card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Target item'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    tester.view.resetPhysicalSize();
    await repo.dispose();
    await db.close();
  });
}
