import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows destinations available through the device's native sharing apps.
///
/// This screen does not connect accounts or call cloud APIs. To share actual
/// content, open a note and use its Share or Export action.
class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final destinations = <_ShareDestination>[
      _ShareDestination(
        name: 'Google Drive',
        icon: Icons.add_to_drive_outlined,
        category: l10n.backupAndStorage,
      ),
      _ShareDestination(
        name: 'OneDrive',
        icon: Icons.cloud_outlined,
        category: l10n.backupAndStorage,
      ),
      _ShareDestination(
        name: 'Gmail',
        icon: Icons.mail_outline_rounded,
        category: l10n.shareEmail,
      ),
      _ShareDestination(
        name: 'Outlook',
        icon: Icons.mail_outline_rounded,
        category: l10n.shareEmail,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharingOptions)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(l10n.sharingPrivacy, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.share_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.shareNoteDescription,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final destination in destinations) ...[
            Card(
              child: ListTile(
                leading: Icon(
                  destination.icon,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                title: Text(destination.name),
                subtitle: Text(destination.category),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(l10n.shareAsFile, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.sharingPrivacy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareDestination {
  const _ShareDestination({
    required this.name,
    required this.icon,
    required this.category,
  });

  final String name;
  final IconData icon;
  final String category;
}
