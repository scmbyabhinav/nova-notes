import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchase_verification_service.dart';

enum OrahPlan { free, monthly, yearly }

class OrahEntitlementService extends ChangeNotifier {
  OrahEntitlementService._();
  static final instance = OrahEntitlementService._();

  static const monthlyId = 'orah_pro_monthly';
  static const yearlyId = 'orah_pro_yearly';
  static const _entitlementKey = 'orah_entitlement';
  static const _purchaseDateKey = 'orah_purchase_date';
  static const _expiryKey = 'orah_entitlement_expiry';
  static const _verifiedKey = 'orah_entitlement_verified';

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = const [];
  OrahPlan plan = OrahPlan.free;
  DateTime? expiresAt;
  bool loading = true;
  String? error;
  Future<void>? _initializationFuture;

  // ⚠️⚠️⚠️ CRITICAL: TEMPORARY TESTING MODE ⚠️⚠️⚠️
  // This unlocks all Pro features for QA testing when ORAH_QA_UNLOCK=true.
  // TODO: REVERT THIS FLAG BEFORE PLAY STORE RELEASE!
  static const _qaUnlock = bool.fromEnvironment(
    'ORAH_QA_UNLOCK',
    defaultValue: false,
  );

  bool get isPremium {
    if (_qaUnlock) return true;
    if (plan == OrahPlan.free) return false;
    return expiresAt == null || expiresAt!.isAfter(DateTime.now());
  }

  String get planLabel => switch (plan) {
    OrahPlan.monthly => 'Pro Monthly',
    OrahPlan.yearly => 'Pro Yearly',
    OrahPlan.free => 'Free',
  };

  Future<void> initialize() {
    final inFlight = _initializationFuture;
    if (inFlight != null) return inFlight;
    if (!loading) return Future<void>.value();

    final future = _initialize();
    _initializationFuture = future;
    return future.whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _loadCachedEntitlement(prefs);

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (Object e) {
        error = e.toString();
        notifyListeners();
      },
    );

    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (available) {
        final response = await InAppPurchase.instance.queryProductDetails(
          {monthlyId, yearlyId},
        );
        products = response.productDetails;
        if (response.error != null) error = response.error!.message;
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _loadCachedEntitlement(SharedPreferences prefs) {
    final stored = prefs.getString(_entitlementKey);
    plan = switch (stored) {
      'monthly' => OrahPlan.monthly,
      'yearly' => OrahPlan.yearly,
      _ => OrahPlan.free,
    };
    final rawExpiry = prefs.getString(_expiryKey);
    expiresAt = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    final verified = prefs.getBool(_verifiedKey) ?? false;
    if (!verified || (plan != OrahPlan.monthly && plan != OrahPlan.yearly)) {
      plan = OrahPlan.free;
      expiresAt = null;
      prefs.remove(_entitlementKey);
      prefs.remove(_expiryKey);
      prefs.remove(_verifiedKey);
    }
  }

  ProductDetails? product(String id) {
    for (final item in products) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> buy(String productId) async {
    if (loading) await initialize();
    final item = product(productId);
    if (item == null) {
      error = 'This plan is not available in the current store.';
      notifyListeners();
      return;
    }
    final param = PurchaseParam(productDetails: item);
    final launched = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: param,
    );
    if (!launched) {
      error = 'The store could not start this purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    final prefs = await SharedPreferences.getInstance();
    OrahPlan? verifiedPlan;
    DateTime? verifiedExpiry;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.error) {
        error = purchase.error?.message ?? 'Purchase failed.';
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      final candidate = switch (purchase.productID) {
        monthlyId => OrahPlan.monthly,
        yearlyId => OrahPlan.yearly,
        _ => null,
      };
      if (candidate == null) continue;

      try {
        final result = await PurchaseVerificationService.instance.verify(
          // Google Play serverVerificationData is the purchase token.
          // The backend must validate it with the Google Play Developer API.
          purchaseToken: purchase.verificationData.serverVerificationData,
          productId: purchase.productID,
        );
        final expiry = result.expiresAt;
        final active = result.valid &&
            result.productId == purchase.productID &&
            expiry != null &&
            expiry.isAfter(DateTime.now());

        if (active && _planRank(candidate) > _planRank(verifiedPlan)) {
          verifiedPlan = candidate;
          verifiedExpiry = expiry;
        }
      } catch (e) {
        error = 'Purchase verification unavailable: $e';
      }

      // Do not acknowledge/complete an unverified purchase. Keeping it pending
      // allows a later purchase-stream event to retry server verification.
      if (purchase.pendingCompletePurchase &&
          verifiedPlan == candidate &&
          verifiedExpiry != null) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }

    if (verifiedPlan != null && verifiedExpiry != null) {
      plan = verifiedPlan;
      expiresAt = verifiedExpiry;
      await prefs.setString(_entitlementKey, plan.name);
      await prefs.setString(_expiryKey, verifiedExpiry.toIso8601String());
      await prefs.setBool(_verifiedKey, true);
      await prefs.setString(
        _purchaseDateKey,
        DateTime.now().toIso8601String(),
      );
      error = null;
    } else if (plan != OrahPlan.free &&
        (expiresAt == null || !expiresAt!.isAfter(DateTime.now()))) {
      plan = OrahPlan.free;
      expiresAt = null;
      await prefs.remove(_entitlementKey);
      await prefs.remove(_expiryKey);
      await prefs.remove(_verifiedKey);
    }

    notifyListeners();
  }

  int _planRank(OrahPlan? value) {
    switch (value) {
      case OrahPlan.yearly:
        return 2;
      case OrahPlan.monthly:
        return 1;
      case OrahPlan.free:
      case null:
        return 0;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
