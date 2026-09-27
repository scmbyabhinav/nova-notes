import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/localization/nova_localizations.dart';

import 'core/theme/nova_theme.dart';
import 'core/theme/orah_theme_controller.dart';
import 'data/repositories/note_repository_provider.dart';
import 'models/note.dart';
import 'screens/home_screen.dart';
import 'screens/folders_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/note_editor_screen.dart';
import 'core/navigation/orah_navigation.dart';
import 'services/speech_to_text_service.dart';

class OrahApp extends StatefulWidget {
  const OrahApp({super.key, this.speechService});

  final VoiceSpeechService? speechService;

  @override
  State<OrahApp> createState() => _OrahAppState();
}

class _OrahAppState extends State<OrahApp> {
  final OrahThemeController _theme = OrahThemeController();

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onThemeChanged);
    _theme.load();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = NovaTheme.light(seed: Color(_theme.accent));
    final dark = NovaTheme.dark(seed: Color(_theme.accent));
    return MaterialApp(
      title: 'Orah',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: _theme.mode,
      localizationsDelegates: const [
        NovaLocalizationsDelegate(),
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: NovaLocalizations.supportedLocales,
      navigatorKey: orahNavigatorKey,
      home: NovaShell(themeController: _theme, speechService: widget.speechService),
    );
  }
}

class NovaShell extends StatefulWidget {
  const NovaShell({super.key, required this.themeController, this.speechService});

  final OrahThemeController themeController;
  final VoiceSpeechService? speechService;

  @override
  State<NovaShell> createState() => _NovaShellState();
}

class _NovaShellState extends State<NovaShell> {
  int _index = 0;
  Timer? _quickCaptureLongPressTimer;
  bool _quickCaptureLongPressTriggered = false;
  bool _showQuickCaptureHint = false;
  final GlobalKey<TooltipState> _quickCaptureHintKey = GlobalKey<TooltipState>();

  static const _quickCaptureHintDismissedKey = 'orah_quick_capture_hint_dismissed';
  static const _quickCaptureHintVisitsKey = 'orah_quick_capture_hint_visits';

  @override
  void initState() {
    super.initState();
    _loadQuickCaptureHint();
  }

  Future<void> _loadQuickCaptureHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_quickCaptureHintDismissedKey) == true || !mounted) return;
    final visits = prefs.getInt(_quickCaptureHintVisitsKey) ?? 0;
    if (visits >= 2) return;
    await prefs.setInt(_quickCaptureHintVisitsKey, visits + 1);
    if (!mounted) return;
    setState(() => _showQuickCaptureHint = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showQuickCaptureHint) {
        _quickCaptureHintKey.currentState?.ensureTooltipVisible();
      }
    });
  }

  Future<void> _dismissQuickCaptureHint() async {
    if (!_showQuickCaptureHint) return;
    if (mounted) setState(() => _showQuickCaptureHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quickCaptureHintDismissedKey, true);
  }

  List<Widget> get _pages => [
        HomeScreen(
          onNewNote: () => _openEditor(NoteType.text),
          onVoiceCapture: _openVoiceEditor,
          onSettings: () => setState(() => _index = 3),
        ),
        const FoldersScreen(),
        const FavoritesScreen(),
        SettingsScreen(themeController: widget.themeController),
      ];

  Future<void> _openEditor(NoteType type) async {
    final repository = await NoteRepositoryProvider.instance();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialType: type,
          speechService: widget.speechService,
        ),
      ),
    );

    // Re-publish the persisted snapshot after the editor route closes so the
    // Home stream receives the latest state even if a broadcast was missed.
    await repository.refresh();
  }

  Future<void> _openVoiceEditor() async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialType: NoteType.text,
          speechService: widget.speechService,
          autoStartVoice: true,
        ),
      ),
    );

    await repository.refresh();
  }

  Future<void> _quickCapture() async {
    // The long-press path is driven by the outer Listener. Suppress the
    // FloatingActionButton tap callback when the long-press has fired.
    if (_quickCaptureLongPressTriggered) {
      _quickCaptureLongPressTriggered = false;
      return;
    }
    // Main capture action is instant: open a blank note directly.
    await _openEditor(NoteType.text);
  }

  void _startQuickCaptureLongPress() {
    _dismissQuickCaptureHint();
    _quickCaptureLongPressTimer?.cancel();
    _quickCaptureLongPressTriggered = false;
    _quickCaptureLongPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _quickCaptureLongPressTriggered = true;
      _showCaptureOptions();
    });
  }

  void _cancelQuickCaptureLongPress() {
    _quickCaptureLongPressTimer?.cancel();
    _quickCaptureLongPressTimer = null;
  }

  Future<void> _showCaptureOptions() async {
    final capture = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Capture',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose what you want to capture.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.edit_note_rounded)),
                title: const Text('Quick note'),
                subtitle: const Text('Start typing immediately'),
                onTap: () => Navigator.pop(sheetContext, 'text'),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.checklist_rounded)),
                title: const Text('Quick checklist'),
                subtitle: const Text('Capture tasks without setup'),
                onTap: () => Navigator.pop(sheetContext, 'checklist'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || capture == null) return;

    // showModalBottomSheet completes from the route's pop future. Waiting for
    // the next frame keeps the sheet's inherited/overlay subtree fully
    // deactivated before the editor route is pushed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _openEditor(
      capture == 'checklist' ? NoteType.checklist : NoteType.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1100;
        return Scaffold(
          body: IndexedStack(
        index: _index,
        children: _pages,
      ),
          floatingActionButton: desktop ? null : Row(
            mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'orah_new_note_fab',
            onPressed: () => _openEditor(NoteType.text),
            tooltip: null,
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
          Tooltip(
            key: _quickCaptureHintKey,
            message: 'Tap to write • Long-press for checklist & quick options',
            triggerMode: TooltipTriggerMode.manual,
            excludeFromSemantics: true,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _startQuickCaptureLongPress(),
              onPointerUp: (_) => _cancelQuickCaptureLongPress(),
              onPointerCancel: (_) => _cancelQuickCaptureLongPress(),
              child: FloatingActionButton(
                heroTag: 'orah_voice_capture_fab',
                onPressed: _quickCapture,
                tooltip: 'Quick capture. Long-press for checklist and quick options.',
                child: const Icon(Icons.mic_none_rounded),
              ),
            ),
          ),
        ],
      ),
          bottomNavigationBar: desktop ? null : NavigationBar(
            selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Folders',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
          ],
        ),
      );
    },
  );
  }
}

class _QuickCaptureCard extends StatelessWidget {
  const _QuickCaptureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
