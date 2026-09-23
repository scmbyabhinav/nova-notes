import 'package:flutter/material.dart';
import '../services/orah_entitlement_service.dart';

class OrahProScreen extends StatefulWidget {
  const OrahProScreen({super.key});
  @override State<OrahProScreen> createState() => _OrahProScreenState();
}

class _OrahProScreenState extends State<OrahProScreen> {
  final e = OrahEntitlementService.instance;
  @override void initState() { super.initState(); e.addListener(_refresh); e.initialize(); }
  void _refresh() { if (mounted) setState(() {}); }
  @override void dispose() { e.removeListener(_refresh); super.dispose(); }

  Future<void> _buy(ProductDetails p) async {
    final started = await e.buy(p);
    if (!mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase could not be started. Try again later.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ORAH Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Icon(Icons.workspace_premium_rounded, size: 64, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text(e.isPro ? 'ORAH Pro is active' : 'Unlock ORAH Pro',
            textAlign: TextAlign.center,
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Choose a subscription or a one-time lifetime purchase. One Pro entitlement unlocks the premium feature set.',
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Card(child: Column(children: [
            for (final f in const [
              'Advanced OCR and document capture',
              'Advanced search and smart retrieval',
              'Premium templates and productivity tools',
              'Advanced export, backup and attachment tools',
              'Power-user reminders and organization',
              'Future premium ORAH features included',
            ]) ListTile(dense: true, leading: const Icon(Icons.check_circle_outline_rounded), title: Text(f)),
          ])),
          const SizedBox(height: 16),
          if (e.storeAvailable && e.products.isNotEmpty) ...[
            _plan('Monthly', e.monthly),
            _plan('Yearly', e.yearly),
            _plan('Lifetime', e.lifetime),
          ] else const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Store pricing will appear automatically when ORAH is connected to its production store products.'),
          )),
          OutlinedButton.icon(onPressed: e.restore, icon: const Icon(Icons.restore_rounded), label: const Text('Restore purchases')),
        ],
      ),
    );
  }

  Widget _plan(String label, ProductDetails? p) => Card(
    child: ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(p?.description ?? 'ORAH Pro'),
      trailing: FilledButton(
        onPressed: p == null || e.isPro ? null : () => _buy(p),
        child: Text(e.isPro ? 'Active' : (p?.price ?? label)),
      ),
    ),
  );
}
