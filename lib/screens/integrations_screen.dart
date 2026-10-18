import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final providers = <_IntegrationProvider>[
      _IntegrationProvider(
        name: 'Google Drive',
        category: l10n.integrationsCloudFiles,
        icon: Icons.add_to_drive_outlined,
      ),
      _IntegrationProvider(
        name: 'Gmail',
        category: l10n.integrationsScheduledMessages,
        icon: Icons.mail_outline_rounded,
      ),
      _IntegrationProvider(
        name: 'Outlook',
        category: l10n.integrationsScheduledMessages,
        icon: Icons.mail_outline_rounded,
      ),
      _IntegrationProvider(
        name: 'Microsoft Teams',
        category: l10n.integrationsScheduledMessages,
        icon: Icons.groups_2_outlined,
      ),
      _IntegrationProvider(
        name: 'WhatsApp',
        category: l10n.integrationsScheduledMessages,
        icon: Icons.chat_bubble_outline_rounded,
      ),
      _IntegrationProvider(
        name: 'OneDrive',
        category: l10n.integrationsCloudFiles,
        icon: Icons.cloud_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.integrationsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(l10n.integrationsSubtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          for (final provider in providers) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  provider.icon,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  provider.name,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.category),
                      const SizedBox(height: 6),
                      Text(l10n.integrationsSetupPending),
                    ],
                  ),
                ),
                trailing: Container(
                  constraints: const BoxConstraints(maxWidth: 112),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.integrationsNotConnected,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.integrationsSecurityNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.integrationsComingNext,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationProvider {
  const _IntegrationProvider({
    required this.name,
    required this.category,
    required this.icon,
  });

  final String name;
  final String category;
  final IconData icon;
}
