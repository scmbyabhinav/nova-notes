
import 'package:flutter/material.dart';
import '../core/widgets/orah_wordmark.dart';
import '../core/widgets/orah_logo.dart';

class AboutNovaScreen extends StatelessWidget {
  const AboutNovaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About Orah')),
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
              color: Colors.white,
              child: const OrahLogo(size: 88),
            ),
          ),
          const SizedBox(height: 20),
          const OrahWordmark(fontSize: 38, textAlign: TextAlign.center),
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
            'Orah is built to stay out of the way: open, capture, organize, find.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                children: [
                  Image.asset(
                    'assets/abhinav_bajpai_signature.png',
                    fit: BoxFit.contain,
                    width: 300,
                    height: 100,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Abhinav Bajpai — Developer signature',
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.draw_outlined,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Developer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Abhinav Bajpai',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'For feature suggestions, feedback, or ideas:',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    'vajpaiabhinav@gmail.com',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Copyright © 2026 Abhinav Bajpai. All rights reserved.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Orah application code, original branding, artwork and product assets are owned by Abhinav Bajpai. Third-party components remain subject to their respective licenses.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
