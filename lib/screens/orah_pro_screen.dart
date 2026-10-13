import 'dart:async';

import 'package:flutter/material.dart';

import '../services/orah_analytics_service.dart';
import '../services/orah_entitlement_service.dart';
import '../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final plans = [
      (OrahEntitlementService.yearlyId, l10n.proPlanYearly, l10n.proBestValue, true),
      (OrahEntitlementService.monthlyId, l10n.proPlanMonthly, l10n.proMonthlySubtitle, false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orahPro),
        actions: [
          TextButton(
            onPressed: service.restore,
            child: Text(l10n.proRestore),
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
                    l10n.proHeroEyebrow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.proHeroHeadline,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.proHeroDescription,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.proHeroFootnote,
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
            l10n.proMoreThanNotes,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.document_scanner_rounded,
            title: l10n.proOcrTitle,
            description:
                l10n.proOcrDescription,
          ),
          _BenefitTile(
            icon: Icons.picture_as_pdf_rounded,
            title: l10n.proExportTitle,
            description:
                l10n.proExportDescription,
          ),
          _BenefitTile(
            icon: Icons.manage_search_rounded,
            title: l10n.proSearchTitle,
            description:
                l10n.proSearchDescription,
          ),
          _BenefitTile(
            icon: Icons.dashboard_customize_rounded,
            title: l10n.proWorkspaceTitle,
            description:
                l10n.proWorkspaceDescription,
          ),
          const SizedBox(height: 14),
          if (service.isPremium)
            Card(
              child: ListTile(
                leading: Icon(Icons.verified_rounded, color: colors.primary),
                title: Text(service.planLabel),
                subtitle: Text(l10n.proEntitlementActive),
                trailing: TextButton(
                  onPressed: service.restore,
                  child: const Text('Restore'),
                ),
              ),
            )
          else ...[
            Text(
              l10n.proChoosePlan,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.proPricesFromPlay,
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
                      l10n.proOfferInstruction,
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
            label: Text(l10n.proRestorePurchases),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.proRenewalDisclosure,
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
                            l10n.proBestValueBadge,
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
                    price ?? (loading ? AppLocalizations.of(context)!.proLoadingPrice : AppLocalizations.of(context)!.proUnavailable),
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
              child: Text(AppLocalizations.of(context)!.proChooseButton),
            ),
          ],
        ),
      ),
    );
  }
}
