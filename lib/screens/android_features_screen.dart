import 'package:flutter/material.dart';

class AndroidFeaturesScreen extends StatelessWidget {
  const AndroidFeaturesScreen({super.key});

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
          ),
          _FeatureTile(
            icon: Icons.bolt_outlined,
            title: 'Quick Note shortcut',
            subtitle: 'Launch ORAH directly into instant capture.',
          ),
          _FeatureTile(
            icon: Icons.share_outlined,
            title: 'Share to ORAH',
            subtitle: 'Send supported text and content into a new ORAH note.',
          ),
          _FeatureTile(
            icon: Icons.notifications_active_outlined,
            title: 'Reminders',
            subtitle: 'Create note and checklist reminders without a backend.',
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
