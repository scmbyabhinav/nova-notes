
import 'package:flutter/material.dart';

class AboutNovaScreen extends StatelessWidget {
  const AboutNovaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About NOVA')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 44,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'NOVA Notes',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Think it. Write it. Keep it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.bolt_outlined),
                  title: Text('Fast'),
                  subtitle: Text('Designed for instant capture.'),
                ),
                ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Offline-first'),
                  subtitle: Text('Your notes work without an account.'),
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Private'),
                  subtitle: Text('Local data with optional device protection.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'NOVA is built to stay out of the way: open, capture, organize, find.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
