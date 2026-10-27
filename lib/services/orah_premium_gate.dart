import 'package:flutter/material.dart';
import 'orah_entitlement_service.dart';
import 'orah_feature_gate.dart';
import '../screens/orah_pro_screen.dart';

class OrahPremiumGate {
  const OrahPremiumGate._();

  static Future<bool> check(BuildContext context, OrahFeature feature) async {
    if (OrahFeatureGate.allowed(feature)) return true;
    if (!context.mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrahProScreen()),
    );
    return OrahFeatureGate.allowed(feature);
  }

  static Widget badge(OrahFeature feature) => Builder(
    builder: (context) => Chip(
      avatar: const Icon(Icons.workspace_premium_rounded, size: 17),
      label: Text(featureLabel(feature)),
      visualDensity: VisualDensity.compact,
    ),
  );

  static String featureLabel(OrahFeature feature) =>
      OrahFeatureGate.label(feature);
}
