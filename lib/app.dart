import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'l10n/app_localizations.dart';

import 'core/theme/nova_theme.dart';
import 'core/theme/orah_theme_controller.dart';
import 'core/widgets/orah_asset_icon.dart';
import 'data/repositories/note_repository_provider.dart';
import 'models/note.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/folders_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/note_editor_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/calendar_history_screen.dart';
import 'core/navigation/orah_navigation.dart';
import 'services/speech_to_text_service.dart';
import 'services/orah_user_profile_service.dart';
import 'screens/orah_registration_screen.dart' as registration;

class OrahApp extends StatefulWidget {
  const OrahApp({super.key, this.speechService, this.requestMicrophonePermission, this.skipRegistrationForTesting = false});

  final VoiceSpeechService? speechService;
  final Future<PermissionStatus> Function()? requestMicrophonePermission;
  final bool skipRegistrationForTesting;

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
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: _theme.mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorKey: orahNavigatorKey,
      navigatorObservers: [orahRouteObserver],
      home: OrahEntryGate(themeController: _theme, speechService: widget.speechService, requestMicrophonePermission: widget.requestMicrophonePermission, skipRegistrationForTesting: widget.skipRegistrationForTesting),
    );
  }
}

class OrahEntryGate extends StatefulWidget {
  const OrahEntryGate({super.key, required this.themeController, this.speechService, this.requestMicrophonePermission, this.skipRegistrationForTesting = false});

  final OrahThemeController themeController;
  final VoiceSpeechService? speechService;
  final Future<PermissionStatus> Function()? requestMicrophonePermission;
  final bool skipRegistrationForTesting;

  @override
  State<OrahEntryGate> createState() => _OrahEntryGateState();
}

class _OrahEntryGateState extends State<OrahEntryGate> {
  OrahUserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.skipRegistrationForTesting) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await OrahUserProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skipRegistrationForTesting) {
      return NovaShell(
        themeController: widget.themeController,
        speechService: widget.speechService,
        requestMicrophonePermission: widget.requestMicrophonePermission,
        profile: const OrahUserProfile(fullName: 'Test User', email: 'test@example.com'),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return registration.OrahRegistrationScreen(
        onRegistered: (value) => setState(() => _profile = value),
      );
    }
    return NovaShell(
      themeController: widget.themeController,
      speechService: widget.speechService,
      profile: profile,
    );
  }
}

class NovaShell extends StatefulWidget {
  const NovaShell({super.key, required this.themeController, required this.profile, this.speechService, this.requestMicrophonePermission});

  final OrahThemeController themeController;
  final VoiceSpeechService? speechService;
  final Future<PermissionStatus> Function()? requestMicrophonePermission;
  final OrahUserProfile profile;

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
    _greetUserAtStartup();
  }

  Future<void> _greetUserAtStartup() async {
    final voiceEnabled = await OrahUserProfileService.instance.voiceGreetingEnabled();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hello, ${widget.profile.fullName}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (voiceEnabled) {
        OrahUserProfileService.instance.speakGreeting(widget.profile.fullName).catchError((_) {});
      }
    });
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
          onChecklist: () => _openEditor(NoteType.checklist),
          onSettings: () => setState(() => _index = 3),
          onNotes: () => setState(() => _index = 0),
          onFolders: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoldersScreen())),
          onFavorites: () => setState(() => _index = 2),
          onStatistics: _openStatistics,
          onCalendarHistory: _openCalendarHistory,
        ),
        CalendarScreen(onNotes: () => setState(() => _index = 0)),
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
          requestMicrophonePermission: widget.requestMicrophonePermission,
        ),
      ),
    );

    // Re-publish the persisted snapshot after the editor route closes so the
    // Home stream receives the latest state even if a broadcast was missed.
    await repository.refresh();
  }

  Future<void> _openStatistics() async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.refresh();
    final notes = await repository.getNotes();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StatisticsScreen(notes: notes)),
    );
  }

  Future<void> _openCalendarHistory() async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.refresh();
    final notes = await repository.getNotes();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CalendarHistoryScreen(notes: notes)),
    );
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
                leading: const CircleAvatar(child: OrahAssetIcon('compose', size: 24, color: Colors.white)),
                title: const Text('Quick note'),
                subtitle: const Text('Start typing immediately'),
                onTap: () => Navigator.pop(sheetContext, 'text'),
              ),
              ListTile(
                leading: const CircleAvatar(child: OrahAssetIcon('checklist', size: 24, color: Colors.white)),
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
        final theme = Theme.of(context);
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
                heroTag: 'orah_checklist_fab',
                tooltip: 'Daily checklist',
                onPressed: () => _openEditor(NoteType.checklist),
                child: const Icon(Icons.checklist_rounded),
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
                    child: OrahAssetIcon('microphone', color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop ? null : NavigationBar(
            selectedIndex: switch (_index) {
              0 => 0, // Notes / Home
              1 => 1, // Calendar
              2 => 3, // Favorites
              _ => 4, // Settings
            },
            onDestinationSelected: (value) {
              switch (value) {
                case 0:
                  setState(() => _index = 0);
                  break;
                case 1:
                  setState(() => _index = 1);
                  break;
                case 2:
                  _openEditor(NoteType.text);
                  break;
                case 3:
                  setState(() => _index = 2);
                  break;
                case 4:
                  setState(() => _index = 3);
                  break;
              }
            },
            destinations: [
              NavigationDestination(
                icon: OrahAssetIcon('notes', color: theme.colorScheme.onSurfaceVariant),
                selectedIcon: OrahAssetIcon('notes', color: theme.colorScheme.onSecondaryContainer),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: SvgPicture.asset('assets/calendar_icon.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
                selectedIcon: SvgPicture.asset('assets/calendar_icon.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(theme.colorScheme.onSecondaryContainer, BlendMode.srcIn)),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                selectedIcon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                label: 'Add',
              ),
              NavigationDestination(
                icon: OrahAssetIcon('star', color: theme.colorScheme.onSurfaceVariant),
                selectedIcon: OrahAssetIcon('star', color: theme.colorScheme.onSecondaryContainer),
                label: 'Favorites',
              ),
              NavigationDestination(
                icon: OrahAssetIcon('settings', color: theme.colorScheme.onSurfaceVariant),
                selectedIcon: OrahAssetIcon('settings', color: theme.colorScheme.onSecondaryContainer),
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
