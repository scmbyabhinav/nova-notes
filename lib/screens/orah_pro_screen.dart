import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';
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
    service.addListener(_refresh);
    service.initialize();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only recurring Google Play subscriptions are offered.
    final plans = [
      (OrahEntitlementService.monthlyId, 'Monthly', 'Flexible access'),
      (OrahEntitlementService.yearlyId, 'Yearly', 'Best recurring value'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ORAH Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 42, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Capture more. Find faster.', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('ORAH Pro unlocks advanced tools while keeping the core local note experience free.'),
                  const SizedBox(height: 18),
                  for (final feature in const [
                    'OCR and smart capture',
                    'Advanced search and intelligence',
                    'Advanced capture, search and export tools',
                    'Premium templates and organization',
                    'Advanced export tools',
                    'Future cloud features will be added separately when available',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(children: [Icon(Icons.check_circle_outline_rounded, size: 20, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(feature))]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (service.isPremium)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_rounded),
                title: Text(service.planLabel),
                subtitle: const Text('Your Pro entitlement is active on this device.'),
                trailing: TextButton(onPressed: service.restore, child: const Text('Restore')),
              ),
            )
          else
            ...plans.map((entry) {
              final product = service.product(entry.$1);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const OrahAssetIcon('star'),
                  title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(product == null ? entry.$3 : product.price + ' • ' + entry.$3),
                  trailing: FilledButton(
                    onPressed: product == null ? null : () => service.buy(entry.$1),
                    child: const Text('Choose'),
                  ),
                ),
              );
            }),
          if (!service.loading && service.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(service.error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          TextButton.icon(
            onPressed: service.restore,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore purchases'),
          ),
          const SizedBox(height: 8),
          Text(
            'Store product IDs: orah_pro_monthly, orah_pro_yearly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
