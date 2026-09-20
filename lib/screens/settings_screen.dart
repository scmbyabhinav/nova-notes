
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../services/nova_backup_service.dart';
import '../services/nova_attachment_service.dart';
import '../data/repositories/note_repository_provider.dart';

import '../core/localization/nova_localizations.dart';
import 'security_settings_screen.dart';
import 'android_features_screen.dart';
import 'about_nova_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = NovaLocalizations.of(context);

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
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Appearance'),
                  subtitle: Text('System theme'),
                  trailing: Icon(Icons.chevron_right_rounded),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Security & Privacy'),
                  subtitle: const Text('PIN and biometric protection'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SecuritySettingsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('Backup & Export'),
                  subtitle: const Text('Local backup and portable data'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.android_outlined),
                  title: const Text('Android features'),
                  subtitle: const Text('Widgets, shortcuts and sharing'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AndroidFeaturesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About NOVA'),
              subtitle: const Text('Product information and privacy approach'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutNovaScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'NOVA Notes 1.0.0',
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
            leading: const Icon(Icons.upload_file_rounded),
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
        await Share.shareXFiles([XFile(file.path)], text: 'NOVA Notes portable backup');
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['nova'],
        );
        final path = result?.files.single.path;
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