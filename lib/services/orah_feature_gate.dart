import 'package:flutter/foundation.dart';
import 'orah_entitlement_service.dart';

enum OrahFeature {
  ocr,
  advancedSearch,
  smartCapture,
  advancedReminders,
  premiumTemplates,
  advancedExport,
  attachmentTools,
  encryptedBackup,
  futureSync,
}

class OrahFeatureGate {
  const OrahFeatureGate._();

  static bool isPremium(OrahFeature feature) {
    switch (feature) {
      case OrahFeature.ocr:
      case OrahFeature.advancedSearch:
      case OrahFeature.smartCapture:
      case OrahFeature.advancedReminders:
      case OrahFeature.premiumTemplates:
      case OrahFeature.advancedExport:
      case OrahFeature.attachmentTools:
      case OrahFeature.encryptedBackup:
      case OrahFeature.futureSync:
        return true;
    }
  }

  static bool allowed(OrahFeature feature) {
    if (!isPremium(feature)) return true;
    return OrahEntitlementService.instance.isPremium;
  }

  static Future<bool> requirePremium(OrahFeature feature) async {
    if (allowed(feature)) return true;
    return false;
  }

  static String label(OrahFeature feature) => switch (feature) {
    OrahFeature.ocr => 'OCR & smart capture',
    OrahFeature.advancedSearch => 'Advanced search',
    OrahFeature.smartCapture => 'Smart capture',
    OrahFeature.advancedReminders => 'Advanced reminders',
    OrahFeature.premiumTemplates => 'Premium templates',
    OrahFeature.advancedExport => 'Advanced export',
    OrahFeature.attachmentTools => 'Attachment tools',
    OrahFeature.encryptedBackup => 'Encrypted backup',
    OrahFeature.futureSync => 'ORAH Sync',
  };

  static ValueListenable<bool> get premiumStatus =>
      OrahEntitlementService.instance;
}
