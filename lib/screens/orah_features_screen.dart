import 'package:flutter/material.dart';

class OrahFeaturesScreen extends StatelessWidget {
  const OrahFeaturesScreen({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.lock_outline_rounded,
      title: 'Encrypted Vault',
      description: 'Protect private notes with encrypted local storage and biometric access.',
    ),
    _Feature(
      icon: Icons.mic_none_rounded,
      title: 'Voice Capture',
      description: 'Capture thoughts quickly with voice-first note creation.',
    ),
    _Feature(
      icon: Icons.checklist_rounded,
      title: 'Checklist',
      description: 'Turn notes into actionable checklists with completion tracking.',
    ),
    _Feature(
      icon: Icons.cloud_off_outlined,
      title: 'Offline Mode',
      description: 'Keep notes available locally so you can write without an internet connection.',
    ),
    _Feature(
      icon: Icons.ios_share_rounded,
      title: 'Share & Export',
      description: 'Share notes and export your content in portable formats.',
    ),
    _Feature(
      icon: Icons.notifications_none_rounded,
      title: 'Reminders',
      description: 'Add reminders to notes and checklist items so important tasks stay visible.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Orah Features')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: _features.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final feature = _features[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(feature.icon),
              ),
              title: Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
