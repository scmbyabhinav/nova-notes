import 'package:flutter_test/flutter_test.dart';

import 'package:orah_notes/services/orah_entitlement_service.dart';
import 'package:orah_notes/services/orah_feature_gate.dart';

void main() {
  test('free plan starts without premium entitlements', () {
    final service = OrahEntitlementService.instance;
    expect(service.plan, OrahPlan.free);
    expect(service.isPremium, isFalse);
  });

  test('premium feature catalog is stable', () {
    expect(OrahFeatureGate.label(OrahFeature.ocr), 'OCR & smart capture');
    expect(OrahFeatureGate.label(OrahFeature.advancedSearch), 'Advanced search');
    expect(OrahFeatureGate.label(OrahFeature.futureSync), 'ORAH Sync');
  });
}
