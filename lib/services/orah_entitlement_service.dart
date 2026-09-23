import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OrahPlan { free, monthly, yearly, lifetime }

class OrahEntitlementService extends ChangeNotifier {
  OrahEntitlementService._();
  static final instance = OrahEntitlementService._();

  static const monthlyId = 'orah_pro_monthly';
  static const yearlyId = 'orah_pro_yearly';
  static const lifetimeId = 'orah_pro_lifetime';
  static const _entitlementKey = 'orah_entitlement';
  static const _purchaseDateKey = 'orah_purchase_date';
  static const _expiryKey = 'orah_entitlement_expiry';

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = const [];
  OrahPlan plan = OrahPlan.free;
  DateTime? expiresAt;
  bool loading = true;
  String? error;

  bool get isPremium {
    if (plan == OrahPlan.lifetime) return true;
    if (plan == OrahPlan.free) return false;
    return expiresAt == null || expiresAt!.isAfter(DateTime.now());
  }

  bool get isLifetime => plan == OrahPlan.lifetime;
  String get planLabel => switch (plan) {
    OrahPlan.monthly => 'Pro Monthly',
    OrahPlan.yearly => 'Pro Yearly',
    OrahPlan.lifetime => 'Pro Lifetime',
    OrahPlan.free => 'Free',
  };

  Future<void> initialize() async {
    if (!loading) return;
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
          {monthlyId, yearlyId, lifetimeId},
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
      'lifetime' => OrahPlan.lifetime,
      _ => OrahPlan.free,
    };
    final rawExpiry = prefs.getString(_expiryKey);
    expiresAt = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    if (plan != OrahPlan.lifetime && expiresAt != null &&
        !expiresAt!.isAfter(DateTime.now())) {
      plan = OrahPlan.free;
      expiresAt = null;
      prefs.remove(_entitlementKey);
      prefs.remove(_expiryKey);
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

    // A restore can contain several purchases. Resolve the strongest entitlement
    // first so a restored monthly purchase can never accidentally downgrade
    // an existing lifetime entitlement.
    OrahPlan? restoredPlan;
    String? restoredTransactionDate;

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
        lifetimeId => OrahPlan.lifetime,
        _ => null,
      };
      if (candidate == null) continue;

      final currentRank = _planRank(restoredPlan);
      final candidateRank = _planRank(candidate);
      if (candidateRank > currentRank) {
        restoredPlan = candidate;
        restoredTransactionDate = purchase.transactionDate;
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }

    if (restoredPlan != null) {
      final now = DateTime.now();
      plan = restoredPlan!;
      final transactionDate = restoredTransactionDate == null
          ? null
          : DateTime.tryParse(restoredTransactionDate!);

      // Keep the entitlement date anchored to the store transaction when the
      // plugin supplies one. This avoids extending a restored subscription
      // simply because the user reopened ORAH.
      final anchor = transactionDate ?? now;
      expiresAt = switch (restoredPlan) {
        OrahPlan.monthly => anchor.add(const Duration(days: 31)),
        OrahPlan.yearly => anchor.add(const Duration(days: 366)),
        OrahPlan.lifetime => null,
        OrahPlan.free => null,
      };

      // Never turn a restored expired subscription into a fresh subscription.
      // A production billing backend should replace this client-side fallback
      // with Google Play server-side subscription verification.
      if (restoredPlan != OrahPlan.lifetime &&
          expiresAt != null &&
          !expiresAt!.isAfter(now)) {
        plan = OrahPlan.free;
        expiresAt = null;
        await prefs.remove(_entitlementKey);
        await prefs.remove(_expiryKey);
      } else {
        await prefs.setString(_entitlementKey, plan.name);
        await prefs.setString(_purchaseDateKey, anchor.toIso8601String());
        if (expiresAt == null) {
          await prefs.remove(_expiryKey);
        } else {
          await prefs.setString(_expiryKey, expiresAt!.toIso8601String());
        }
        error = null;
      }
    }

    notifyListeners();
  }

  int _planRank(OrahPlan? value) {
    switch (value) {
      case OrahPlan.lifetime:
        return 3;
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
