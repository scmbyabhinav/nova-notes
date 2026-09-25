import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';
import '../services/orah_android_intent_service.dart';

class AndroidFeaturesScreen extends StatelessWidget {
  const AndroidFeaturesScreen({super.key});

  Future<void> _showWidgetHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add the ORAH widget'),
        content: const Text(
          'On your Android home screen, long-press an empty area, choose Widgets, find ORAH, then drag the ORAH widget onto the home screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
        ],
      ),
    );
  }

  Future<void> _setupQuickShortcuts(BuildContext context) async {
    try {
      await const QuickActions().setShortcutItems(const [
        ShortcutItem(type: 'new_note', localizedTitle: 'New note', icon: 'ic_launcher'),
        ShortcutItem(type: 'new_checklist', localizedTitle: 'New checklist', icon: 'ic_launcher'),
        ShortcutItem(type: 'search', localizedTitle: 'Search', icon: 'ic_launcher'),
      ]);
    } catch (_) {
      // The native static shortcuts remain available even if the plugin is unavailable.
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Note shortcut'),
        content: const Text(
          'Long-press the ORAH app icon on your Android home screen. Use New note or New checklist from the shortcut menu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _shareIntoOrah(BuildContext context) async {
    final ok = await OrahAndroidIntentService.instance.shareIntoOrah();
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Android share-to-ORAH is unavailable on this device.')),
    );
  }

  Future<void> _openReminderEditor(BuildContext context) async {
    final repository = await NoteRepositoryProvider.instance();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialType: NoteType.text,
          autoOpenReminder: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Android features')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'ORAH on Android',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fast capture, sharing and home-screen access are built into ORAH '
            'through native Android integrations.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _FeatureTile(
            icon: Icons.widgets_outlined,
            title: 'Home-screen widget',
            subtitle: 'Create a note, checklist or open search from your home screen.',
            onTap: () => _showWidgetHelp(context),
          ),
          _FeatureTile(
            icon: Icons.bolt_outlined,
            title: 'Quick Note shortcut',
            subtitle: 'Launch ORAH directly into instant capture.',
            onTap: () => _setupQuickShortcuts(context),
          ),
          _FeatureTile(
            icon: Icons.share_outlined,
            title: 'Share to ORAH',
            subtitle: 'Send supported text and content into a new ORAH note.',
            onTap: () => _shareIntoOrah(context),
          ),
          _FeatureTile(
            icon: Icons.notifications_active_outlined,
            title: 'Reminders',
            subtitle: 'Create note and checklist reminders without a backend.',
            onTap: () => _openReminderEditor(context),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These integrations are local Android features. '
                      'No backend is required for them.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
