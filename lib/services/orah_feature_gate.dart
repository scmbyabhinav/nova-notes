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

  static bool isPremium(OrahFeature feature) => switch (feature) {
    // These are the currently monetized advanced tools.
    OrahFeature.ocr ||
    OrahFeature.advancedSearch ||
    OrahFeature.smartCapture ||
    OrahFeature.advancedReminders ||
    OrahFeature.premiumTemplates ||
    OrahFeature.advancedExport ||
    OrahFeature.attachmentTools ||
    OrahFeature.encryptedBackup ||
    OrahFeature.futureSync => true,
  };

  static bool allowed(OrahFeature feature) =>
      !isPremium(feature) || OrahEntitlementService.instance.isPremium;

  static Future<bool> requirePremium(OrahFeature feature) async =>
      allowed(feature);

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
}
