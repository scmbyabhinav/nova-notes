import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../core/widgets/orah_asset_icon.dart';
import 'package:quick_actions/quick_actions.dart';

import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';
import '../services/orah_android_intent_service.dart';

class AndroidFeaturesScreen extends StatelessWidget {
  const AndroidFeaturesScreen({super.key});

  Future<void> _showWidgetHelp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.androidWidgetSetupTitle),
        content: Text(l10n.androidWidgetSetupBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.androidGotIt)),
        ],
      ),
    );
  }

  Future<void> _setupQuickShortcuts(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await const QuickActions().setShortcutItems([
        ShortcutItem(type: 'new_note', localizedTitle: l10n.androidShortcutNewNote, icon: 'ic_launcher'),
        ShortcutItem(type: 'new_checklist', localizedTitle: l10n.androidShortcutNewChecklist, icon: 'ic_launcher'),
        ShortcutItem(type: 'search', localizedTitle: l10n.androidShortcutSearch, icon: 'ic_launcher'),
      ]);
    } catch (_) {
      // The native static shortcuts remain available even if the plugin is unavailable.
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.androidQuickShortcutDialogTitle),
        content: Text(l10n.androidQuickShortcutDialogBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.androidDone)),
        ],
      ),
    );
  }

  Future<void> _shareIntoOrah(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await OrahAndroidIntentService.instance.shareIntoOrah();
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.androidShareUnavailable)),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.androidFeatures)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.androidFeatureHeading,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.androidFeatureIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _FeatureTile(
            icon: Icons.widgets_outlined,
            title: l10n.androidWidgetTitle,
            subtitle: l10n.androidWidgetDescription,
            onTap: () => _showWidgetHelp(context),
          ),
          _FeatureTile(
            icon: Icons.bolt_outlined,
            title: l10n.androidQuickCaptureTitle,
            subtitle: l10n.androidQuickCaptureDescription,
            onTap: () => _setupQuickShortcuts(context),
          ),
          _FeatureTile(
            assetIcon: 'share',
            title: l10n.androidShareTitle,
            subtitle: l10n.androidShareDescription,
            onTap: () => _shareIntoOrah(context),
          ),
          _FeatureTile(
            icon: Icons.notifications_active_outlined,
            title: l10n.androidRemindersTitle,
            subtitle: l10n.androidRemindersDescription,
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
                      l10n.androidLocalIntegrationsNote,
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
    this.icon,
    this.assetIcon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData? icon;
  final String? assetIcon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        child: assetIcon != null ? OrahAssetIcon(assetIcon!, color: Theme.of(context).colorScheme.onPrimaryContainer) : Icon(icon!),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
