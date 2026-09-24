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

  List<Widget> get _pages => [
        const HomeScreen(),
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
        ),
      ),
    );
  }

  Future<void> _quickCapture() async {
    // Return the user's choice from the sheet first, then push the editor
    // after the sheet route has fully closed. This avoids competing route
    // transitions and the Flutter InheritedElement dependents assertion.
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quick capture',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Capture first. Organize later.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _QuickCaptureCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Quick note',
                  subtitle: 'A clean blank note, ready to type.',
                  onTap: () => Navigator.pop(sheetContext, 'note'),
                ),
                const SizedBox(height: 10),
                _QuickCaptureCard(
                  icon: Icons.checklist_rounded,
                  title: 'Quick checklist',
                  subtitle: 'Start adding tasks immediately.',
                  onTap: () => Navigator.pop(sheetContext, 'checklist'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'checklist') {
      await _openEditor(NoteType.checklist);
    } else {
      await _openEditor(NoteType.text);
    }
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
