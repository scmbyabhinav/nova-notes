
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../core/widgets/orah_wordmark.dart';
import '../core/widgets/orah_logo.dart';

class AboutNovaScreen extends StatelessWidget {
  const AboutNovaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutOrahTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const OrahLogo(size: 88),
            ),
          ),
          const SizedBox(height: 20),
          const OrahWordmark(fontSize: 38, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.homeTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.bolt_outlined),
                  title: Text(l10n.aboutFast),
                  subtitle: Text(l10n.aboutFastDescription),
                ),
                ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text(l10n.aboutOfflineFirst),
                  subtitle: Text(l10n.aboutOfflineFirstDescription),
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(l10n.aboutPrivate),
                  subtitle: Text(l10n.aboutPrivateDescription),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.aboutSummary,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E4F5)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 100,
                      child: Image.asset(
                        'assets/developer_signature.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        semanticLabel: l10n.developerSignatureLabel,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text(
                            'Abhinav Bajpai',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF123B78),
                              fontSize: 36,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Abhinav Bajpai',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF123B78),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.aboutFeedback,
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
            l10n.aboutCopyright,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aboutLegalNotice,
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
