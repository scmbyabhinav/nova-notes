import 'package:flutter/material.dart';

class PrivacyPledgeScreen extends StatelessWidget {
  const PrivacyPledgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Pledge'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 60,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Our Privacy Pledge',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your thoughts are personal. Orah is designed to keep your notes private and under your control.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PledgePoint(
                    icon: Icons.phone_android_outlined,
                    title: '100% Local',
                    description:
                        'Your notes are stored only on this device.',
                  ),
                  const SizedBox(height: 12),
                  _PledgePoint(
                    icon: Icons.cloud_off_outlined,
                    title: 'Zero Cloud',
                    description:
                        'Orah has no note-sync server. Notes stay on your device unless you choose to share or export them.',
                  ),
                  const SizedBox(height: 12),
                  _PledgePoint(
                    icon: Icons.smart_toy_outlined,
                    title: 'Zero AI',
                    description:
                        'Orah does not scan, read, or train AI on your notes.',
                  ),
                  const SizedBox(height: 12),
                  _PledgePoint(
                    icon: Icons.lock_outline_rounded,
                    title: 'Encrypted Vault',
                    description:
                        'Sensitive notes in the Vault are protected with AES-256-GCM encryption.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sharing, exporting, device services, and operating-system features may send information outside the app when you choose to use them.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PledgePoint extends StatelessWidget {
  const _PledgePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.primary),
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
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
