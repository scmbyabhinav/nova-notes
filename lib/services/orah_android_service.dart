import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';

class OrahAndroidService {
  OrahAndroidService._();
  static final instance = OrahAndroidService._();

  final QuickActions _quickActions = const QuickActions();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _quickActions.initialize(_handleShortcut);
    await _quickActions.setShortcutItems(const [
      ShortcutItem(
        type: 'new_note',
        localizedTitle: 'New note',
        localizedSubtitle: 'Capture a thought',
        icon: 'ic_launcher',
      ),
      ShortcutItem(
        type: 'new_checklist',
        localizedTitle: 'New checklist',
        localizedSubtitle: 'Capture a task list',
        icon: 'ic_launcher',
      ),
      ShortcutItem(
        type: 'search',
        localizedTitle: 'Search Orah',
        localizedSubtitle: 'Find a note',
        icon: 'ic_launcher',
      ),
    ]);

    await HomeWidget.saveWidgetData<String>('orah_quick_action', 'new_note');
    await updateWidgetSnapshot();
  }

  Future<void> _handleShortcut(String type) async {
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;

    if (type == 'search') {
      await _openSearch(navigator);
      return;
    }

    final repository = await NoteRepositoryProvider.instance();
    final noteType = type == 'new_checklist' ? NoteType.checklist : NoteType.text;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialType: noteType,
        ),
      ),
    );
  }

  Future<void> _openSearch(NavigatorState navigator) async {
    // Keep the shortcut dependency-light: the shell's search surface can be
    // opened by the normal app navigation without a second native activity.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> updateWidgetSnapshot() async {
    try {
      final repository = await NoteRepositoryProvider.instance();
      final notes = (await repository.getNotes())
          .where((note) => !note.isTrashed && !note.isArchived)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final recent = notes.take(3).toList();
      await HomeWidget.saveWidgetData<String>(
        'orah_recent_titles',
        recent.map((note) => note.isLocked ? 'Private note' : (note.title.trim().isEmpty ? 'Untitled note' : note.title.trim())).join('\n'),
      );
      await HomeWidget.saveWidgetData<int>('orah_note_count', notes.length);
      await HomeWidget.updateWidget(
        name: 'OrahWidgetProvider',
        iOSName: 'OrahWidget',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Orah widget update skipped: $e');
    }
  }
}
