import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';
import '../screens/search_screen.dart';

class OrahAndroidIntentService {
  OrahAndroidIntentService._();
  static final instance = OrahAndroidIntentService._();
  static const _channel = MethodChannel('orah_notes/android');
  bool _initialized = false;
  String? _pendingAction;

  Future<bool> shareIntoOrah() async {
    try {
      return await _channel.invokeMethod<bool>('shareIntoOrah') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'launchAction') {
        await _handle(call.arguments?.toString());
      }
    });
    try {
      final action = await _channel.invokeMethod<String>('getLaunchAction');
      if (action != null) {
        await _handle(action);
      }
    } catch (_) {}
    final pending = _pendingAction;
    _pendingAction = null;
    if (pending != null) await _handle(pending);
  }

  Future<void> _handle(String? action) async {
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) {
      _pendingAction = action;
      return;
    }
    final repository = await NoteRepositoryProvider.instance();
    switch (action) {
      case 'new_note':
        await navigator.push(MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            repository: repository,
            initialType: NoteType.text,
          ),
        ));
        break;
      case 'new_checklist':
        await navigator.push(MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            repository: repository,
            initialType: NoteType.checklist,
          ),
        ));
        break;
      case 'search':
        await navigator.push(MaterialPageRoute(builder: (_) => const SearchScreen()));
        break;
    }
  }
}
