import 'dart:convert';

import 'package:http/http.dart' as http;

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.valid,
    required this.productId,
    this.expiresAt,
  });

  final bool valid;
  final String productId;
  final DateTime? expiresAt;
}

class PurchaseVerificationService {
  PurchaseVerificationService._();
  static final instance = PurchaseVerificationService._();

  // Configure the deployed Firebase/HTTPS verification endpoint at build time:
  // flutter build appbundle --dart-define=ORAH_VERIFY_PURCHASE_URL=https://...
  static const _endpoint = String.fromEnvironment(
    'ORAH_VERIFY_PURCHASE_URL',
  );

  Future<PurchaseVerificationResult> verify({
    required String purchaseToken,
    required String productId,
  }) async {
    if (_endpoint.isEmpty) {
      throw StateError(
        'ORAH_VERIFY_PURCHASE_URL is not configured; purchase cannot be granted.',
      );
    }
    if (purchaseToken.trim().isEmpty) {
      throw StateError('Google Play purchase token is missing.');
    }

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode({
            'purchaseToken': purchaseToken,
            'productId': productId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Purchase verification failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid purchase verification response.');
    }

    final valid = decoded['valid'] == true;
    final verifiedProductId = decoded['productId'] as String?;
    final rawExpiry = decoded['expiresAt'] as String?;
    final expiresAt = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);

    if (!valid || verifiedProductId != productId) {
      return PurchaseVerificationResult(
        valid: false,
        productId: verifiedProductId ?? productId,
        expiresAt: expiresAt,
      );
    }

    return PurchaseVerificationResult(
      valid: true,
      productId: verifiedProductId,
      expiresAt: expiresAt,
    );
  }
}
