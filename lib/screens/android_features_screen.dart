
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
          Text('NOVA on Android', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Fast capture, sharing and home-screen access are being prepared '
            'as native Android integrations.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _FeatureTile(
            icon: Icons.widgets_outlined,
            title: 'Home-screen widget',
            subtitle: 'Quickly create a note without opening the full app.',
          ),
          _FeatureTile(
            icon: Icons.bolt_outlined,
            title: 'Quick Note shortcut',
            subtitle: 'A launcher shortcut for instant capture.',
          ),
          _FeatureTile(
            icon: Icons.share_outlined,
            title: 'Share to NOVA',
            subtitle: 'Send text and supported content into a new note.',
          ),
          _FeatureTile(
            icon: Icons.notifications_none_outlined,
            title: 'Reminder-ready architecture',
            subtitle: 'Prepared for Android notification/reminder integration.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Native Android wiring happens after Flutter generates '
                      'the Android platform project. No backend is required.',
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
