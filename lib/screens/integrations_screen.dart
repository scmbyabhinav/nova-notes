import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/app_localizations.dart';
import '../services/orah_google_connect_service.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  GoogleSignInAccount? _googleAccount;
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    _restoreGoogleSession();
  }

  Future<void> _restoreGoogleSession() async {
    try {
      final account =
          await OrahGoogleConnectService.instance.restoreSession();
      if (mounted) setState(() => _googleAccount = account);
    } catch (_) {
      // A failed silent restore should not block the offline-first app.
    }
  }

  Future<void> _connectGoogleDrive() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      final account = await OrahGoogleConnectService.instance.connect();
      if (!mounted) return;
      if (account != null) {
        setState(() => _googleAccount = account);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.integrationsConnected)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      await OrahGoogleConnectService.instance.disconnect();
      if (mounted) setState(() => _googleAccount = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final providers = <_IntegrationProvider>[
      _IntegrationProvider(
        name: 'Google Drive',
        category: l10n.integrationsCloudFiles,
        icon: Icons.add_to_drive_outlined,
        isGoogleDrive: true,
      ),
      _IntegrationProvider(
        name: 'OneDrive',
        category: l10n.integrationsCloudFiles,
        icon: Icons.cloud_outlined,
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
                      if (provider.isGoogleDrive && _googleAccount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _googleAccount!.email,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Text(l10n.integrationsSetupPending),
                      ],
                    ],
                  ),
                ),
                trailing: provider.isGoogleDrive
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _googleAccount == null
                                ? l10n.integrationsNotConnected
                                : l10n.integrationsConnected,
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          _googleBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _googleAccount == null
                                      ? _connectGoogleDrive
                                      : _disconnectGoogleDrive,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _googleAccount == null
                                        ? l10n.integrationsConnect
                                        : l10n.integrationsDisconnect,
                                  ),
                                ),
                        ],
                      )
                    : Container(
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
    this.isGoogleDrive = false,
  });

  final String name;
  final String category;
  final IconData icon;
  final bool isGoogleDrive;
}
