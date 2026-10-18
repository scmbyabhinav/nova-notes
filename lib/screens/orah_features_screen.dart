import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../l10n/app_localizations.dart';

class OrahFeaturesScreen extends StatelessWidget {
  const OrahFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final features = <_Feature>[
      _Feature(
        icon: Icons.lock_outline_rounded,
        title: l10n.privacyVaultTitle,
        description: l10n.privacyVaultDescription,
      ),
      _Feature(
        assetIcon: 'microphone',
        title: l10n.voiceCapture,
        description: l10n.featureVoiceCaptureDescription,
      ),
      _Feature(
        assetIcon: 'checklist',
        title: l10n.checklists,
        description: l10n.featureChecklistDescription,
      ),
      _Feature(
        icon: Icons.cloud_off_outlined,
        title: l10n.offlineAccess,
        description: l10n.privacyLocalDescription,
      ),
      _Feature(
        assetIcon: 'share',
        title: l10n.featureShareExportTitle,
        description: l10n.featureShareExportDescription,
      ),
      _Feature(
        icon: Icons.notifications_none_rounded,
        title: l10n.androidRemindersTitle,
        description: l10n.androidRemindersDescription,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orahFeatures)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: features.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final feature = features[index];
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: feature.assetIcon != null
                    ? OrahAssetIcon(
                        feature.assetIcon!,
                        color: theme.colorScheme.onPrimaryContainer,
                      )
                    : Icon(feature.icon),
              ),
              title: Text(
                feature.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(feature.description),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Feature {
  const _Feature({
    this.icon,
    this.assetIcon,
    required this.title,
    required this.description,
  });

  final IconData? icon;
  final String? assetIcon;
  final String title;
  final String description;
}
