
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../services/nova_backup_service.dart';
import '../services/orah_user_profile_service.dart';
import '../services/nova_attachment_service.dart';
import '../data/repositories/note_repository_provider.dart';

import '../l10n/app_localizations.dart';
import '../core/theme/orah_theme_controller.dart';
import 'security_settings_screen.dart';
import 'android_features_screen.dart';
import 'about_nova_screen.dart';
import 'orah_pro_screen.dart';
import 'orah_features_screen.dart';
import 'trash_screen.dart';
import '../core/widgets/orah_wordmark.dart';
import '../core/widgets/orah_asset_icon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeController});

  final OrahThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            l10n.settings,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(theme, l10n.accountAndPro),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.workspace_premium_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.orahPro),
              subtitle: Text(l10n.proSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrahProScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, l10n.appearanceAndUi),
          Card(
            child: ListTile(
              leading: const OrahAssetIcon('settings'),
              title: Text(l10n.appearance),
              subtitle: Text(_appearanceLabel()),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAppearance(context),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Personalized greeting'),
          const Card(
            child: _VoiceGreetingSettingTile(),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Daily inspiration'),
          const Card(
            child: _DailyInspirationSettingTile(),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, l10n.securityAndPrivacy),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.securityAndPrivacy),
              subtitle: const Text('PIN and biometric protection'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SecuritySettingsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, l10n.androidFeatures),
          Card(
            child: ListTile(
              leading: const Icon(Icons.android_outlined),
              title: Text(l10n.androidFeatures),
              subtitle: const Text('Widgets, shortcuts and sharing'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AndroidFeaturesScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, l10n.backupAndStorage),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const OrahAssetIcon('folder'),
                  title: const Text('Backup & Export'),
                  subtitle: const Text('Local backup and portable data'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const OrahAssetIcon('trash'),
                  title: const Text('Trash'),
                  subtitle: const Text('Restore or permanently delete notes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, l10n.aboutAndFeatures),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Orah Features'),
                  subtitle: const Text('Explore what Orah can do'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrahFeaturesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About Orah'),
                  subtitle: const Text('Product information and privacy approach'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutNovaScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const OrahWordmark(fontSize: 28, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Think it. Write it. Keep it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  String _appearanceLabel() {
    final mode = switch (themeController.mode) {
      ThemeMode.system => 'System theme',
      ThemeMode.light => 'Light theme',
      ThemeMode.dark => 'Dark theme',
    };
    return '$mode • ' + Color(themeController.accent).value.toRadixString(16).toUpperCase();
  }

  Future<void> _showAppearance(BuildContext context) async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Theme')),
          for (final value in ThemeMode.values)
            RadioListTile<ThemeMode>(value: value, groupValue: themeController.mode, title: Text(switch (value) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' }), onChanged: (v) => Navigator.pop(sheet, v)),
        ]),
      ),
    );
    if (mode != null) await themeController.setMode(mode);
    if (!context.mounted) return;
    final accent = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        const colors = [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF059669), Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFF0891B2)];
        return SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 16, runSpacing: 16, children: [for (final color in colors) InkWell(onTap: () => Navigator.pop(sheet, color), borderRadius: BorderRadius.circular(30), child: CircleAvatar(radius: 25, backgroundColor: color, child: color.value == themeController.accent ? const Icon(Icons.check, color: Colors.white) : null))])));
      },
    );
    if (accent != null) await themeController.setAccent(accent);
  }

  Future<void> _showBackup(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('Portable Backup'),
            subtitle: Text('Notes, folders and attached files in one .nova package.'),
          ),
          ListTile(
            leading: const OrahAssetIcon('share'),
            title: const Text('Create backup'),
            onTap: () => Navigator.pop(context, 'create'),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore backup'),
            onTap: () => Navigator.pop(context, 'restore'),
          ),
        ]),
      ),
    );
    if (!context.mounted || action == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = NovaBackupService(prefs);
      if (action == 'create') {
        final file = await service.createBackup();
        await Share.shareXFiles([XFile(file.path)], text: 'Orah portable backup');
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['nova'],
        );
        final path = result.isEmpty ? null : result.single.path;
        if (path == null) return;
        final count = await service.restoreBackup(File(path));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored $count notes successfully.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e')),
        );
      }
    }
  }
  Future<void> _storageMaintenance(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = await NoteRepositoryProvider.instance();
    final notes = await repo.getNotes();
    final referenced = notes.expand((n) => n.attachments).toSet();
    final service = const NovaAttachmentService();
    final attachmentFiles = await service.listAttachments();
    final bytes = await service.totalSize();
    if (!context.mounted) return;
    final orphanCount = attachmentFiles.where((f) => !referenced.contains(f.path)).length;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('Storage maintenance'), subtitle: Text('${attachmentFiles.length} attachments • ${_formatBytes(bytes)}')),
          ListTile(leading: const Icon(Icons.cleaning_services_outlined), title: const Text('Clean orphan attachments'), subtitle: Text('$orphanCount unused files found'), onTap: () => Navigator.pop(context, 'clean')),
        ]),
      ),
    );
    if (!context.mounted || action != 'clean') return;
    final removed = await service.removeOrphans(referenced);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $removed orphan attachment${removed == 1 ? '' : 's'}.')));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
class _VoiceGreetingSettingTile extends StatefulWidget {
  const _VoiceGreetingSettingTile();

  @override
  State<_VoiceGreetingSettingTile> createState() => _VoiceGreetingSettingTileState();
}

class _VoiceGreetingSettingTileState extends State<_VoiceGreetingSettingTile> {
  late Future<bool> _enabledFuture;

  @override
  void initState() {
    super.initState();
    _enabledFuture = OrahUserProfileService.instance.voiceGreetingEnabled();
  }

  Future<void> _setEnabled(bool value) async {
    await OrahUserProfileService.instance.setVoiceGreetingEnabled(value);
    if (!value) await OrahUserProfileService.instance.stopGreeting();
    if (!mounted) return;
    setState(() => _enabledFuture = Future<bool>.value(value));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _enabledFuture,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? true;
        return SwitchListTile(
          secondary: const Icon(Icons.record_voice_over_rounded),
          title: const Text('Speak my name at startup'),
          subtitle: Text(enabled
              ? 'Orah will say “Hello, your name” when it opens.'
              : 'The greeting stays silent.'),
          value: enabled,
          onChanged: snapshot.connectionState == ConnectionState.waiting ? null : _setEnabled,
        );
      },
    );
  }
}
 
class _DailyInspirationSettingTile extends StatefulWidget {
  const _DailyInspirationSettingTile();

  @override
  State<_DailyInspirationSettingTile> createState() =>
      _DailyInspirationSettingTileState();
}

class _DailyInspirationSettingTileState
    extends State<_DailyInspirationSettingTile> {
  bool _showDailyInspiration = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showDailyInspiration =
          !(prefs.getBool('orah_hide_daily_prompt') ?? false);
      _loading = false;
    });
  }

  Future<void> _setVisible(bool visible) async {
    setState(() => _showDailyInspiration = visible);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('orah_hide_daily_prompt', !visible);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.auto_awesome_outlined),
      title: const Text('Show Daily Inspiration on Home Screen'),
      subtitle: const Text('Display a daily reflection prompt above your notes.'),
      value: _showDailyInspiration,
      onChanged: _loading ? null : _setVisible,
    );
  }
}
