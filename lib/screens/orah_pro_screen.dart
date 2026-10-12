import 'dart:async';

import 'package:flutter/material.dart';

import '../services/orah_analytics_service.dart';
import '../services/orah_entitlement_service.dart';

class OrahProScreen extends StatefulWidget {
  const OrahProScreen({super.key});

  @override
  State<OrahProScreen> createState() => _OrahProScreenState();
}

class _OrahProScreenState extends State<OrahProScreen> {
  final service = OrahEntitlementService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(OrahAnalyticsService.instance.logProUpgradeViewed());
    service.addListener(_refresh);
    service.initialize();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plans = [
      (OrahEntitlementService.yearlyId, 'Yearly', 'Best value', true),
      (OrahEntitlementService.monthlyId, 'Monthly', 'Pay month to month', false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORAH Pro'),
        actions: [
          TextButton(
            onPressed: service.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primaryContainer,
                  colors.surfaceContainerHighest,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'YOUR NOTES, WITH MORE POWER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Make every note\nwork harder.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Turn paper into searchable knowledge, find the detail you need, and take your notes wherever work takes you.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upgrade when you need the extra power. Your everyday notes stay yours.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'More than notes',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.document_scanner_rounded,
            title: 'OCR that makes images searchable',
            description:
                'Extract text from supported images and documents instead of retyping it.',
          ),
          _BenefitTile(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Export in the format you need',
            description:
                'Take notes beyond ORAH with premium PDF, Word and Excel exports.',
          ),
          _BenefitTile(
            icon: Icons.manage_search_rounded,
            title: 'Find the needle in the haystack',
            description:
                'Use advanced search and filters to get back to important details faster.',
          ),
          _BenefitTile(
            icon: Icons.dashboard_customize_rounded,
            title: 'A more organised workspace',
            description:
                'Unlock premium templates and advanced productivity tools as they become available in your build.',
          ),
          const SizedBox(height: 14),
          if (service.isPremium)
            Card(
              child: ListTile(
                leading: Icon(Icons.verified_rounded, color: colors.primary),
                title: Text(service.planLabel),
                subtitle: const Text('Your Pro entitlement is active.'),
                trailing: TextButton(
                  onPressed: service.restore,
                  child: const Text('Restore'),
                ),
              ),
            )
          else ...[
            Text(
              'Choose your Pro plan',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Prices are supplied by Google Play for your region.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final plan in plans)
              _PlanCard(
                title: plan.$2,
                subtitle: plan.$3,
                highlighted: plan.$4,
                price: service.product(plan.$1)?.price,
                loading: service.loading,
                onChoose: service.product(plan.$1) == null
                    ? null
                    : () => service.buy(plan.$1),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.card_giftcard_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Have an ORAH offer from your employer or the developer? Redeem it through the Google Play offer link or code provided with your invitation, then return here and tap Restore.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!service.loading && service.error != null) ...[
            const SizedBox(height: 10),
            Text(
              service.error!,
              style: TextStyle(color: colors.error),
            ),
          ],
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: service.restore,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore purchases'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Subscriptions renew automatically unless cancelled in Google Play. Review the price, billing period and any trial terms shown by Google Play before confirming. You can manage or cancel a subscription in your Play Store account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.55)),
        ),
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
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.price,
    required this.loading,
    required this.onChoose,
  });

  final String title;
  final String subtitle;
  final bool highlighted;
  final String? price;
  final bool loading;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlighted ? colors.primaryContainer.withValues(alpha: 0.5) : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? colors.primary : colors.outlineVariant,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              highlighted ? Icons.workspace_premium_rounded : Icons.calendar_month_rounded,
              color: colors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      if (highlighted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 5),
                  Text(
                    price ?? (loading ? 'Loading price…' : 'Currently unavailable'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onChoose,
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }
}
