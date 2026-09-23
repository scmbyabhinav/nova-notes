import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/services/orah_entitlement_service.dart';
import 'package:orah_notes/services/orah_feature_gate.dart';

void main() {
  test('ORAH Pro product IDs are stable', () {
    expect(OrahEntitlementService.monthlyId, 'orah_pro_monthly');
    expect(OrahEntitlementService.yearlyId, 'orah_pro_yearly');
    expect(OrahEntitlementService.lifetimeId, 'orah_pro_lifetime');
  });

  test('free entitlement starts locked', () {
    final service = OrahEntitlementService.instance;
    expect(service.plan, OrahPlan.free);
    expect(service.isLifetime, isFalse);
    expect(service.isPremium, isFalse);
  });

  test('free plan blocks premium features', () {
    final service = OrahEntitlementService.instance;
    expect(service.plan, OrahPlan.free);
    expect(service.isPremium, isFalse);
    for (final feature in OrahFeature.values) {
      expect(OrahFeatureGate.allowed(feature), isFalse);
    }
  });

  test('feature labels are stable', () {
    expect(OrahFeatureGate.label(OrahFeature.ocr), 'OCR & smart capture');
    expect(OrahFeatureGate.label(OrahFeature.advancedSearch), 'Advanced search');
    expect(OrahFeatureGate.label(OrahFeature.futureSync), 'ORAH Sync');
  });
}
