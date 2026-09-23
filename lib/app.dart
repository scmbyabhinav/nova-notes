import 'package:flutter/material.dart';
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

class OrahApp extends StatefulWidget {
  const OrahApp({super.key});

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
      home: NovaShell(themeController: _theme),
    );
  }
}

class NovaShell extends StatefulWidget {
  const NovaShell({super.key, required this.themeController});

  final OrahThemeController themeController;

  @override
  State<NovaShell> createState() => _NovaShellState();
}

class _NovaShellState extends State<NovaShell> {
  int _index = 0;

  final _pages = const <Widget>[
    HomeScreen(),
    FoldersScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  Future<void> _openEditor(NoteType type) async {
    final repository = await NoteRepositoryProvider.instance();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialType: type,
        ),
      ),
    );
  }

  Future<void> _quickCapture() async {
    await showModalBottomSheet<void>(
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
                  'Quick capture',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Capture the thought first. Organize it later.',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.edit_note_rounded),
                ),
                title: const Text('Quick note'),
                subtitle: const Text('Start typing immediately'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditor(NoteType.text);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.checklist_rounded),
                ),
                title: const Text('Quick checklist'),
                subtitle: const Text('Capture tasks without setup'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditor(NoteType.checklist);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickCapture,
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Quick capture'),
      ),
      bottomNavigationBar: NavigationBar(
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
  }
}
