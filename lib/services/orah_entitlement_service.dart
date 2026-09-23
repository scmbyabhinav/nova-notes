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

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = const [];
  OrahPlan plan = OrahPlan.free;
  bool loading = true;
  String? error;

  bool get isPremium => plan != OrahPlan.free;
  bool get isLifetime => plan == OrahPlan.lifetime;
  bool get isSubscription => plan == OrahPlan.monthly || plan == OrahPlan.yearly;

  bool canUse(String feature) => isPremium;

  Future<bool> requirePro(String feature) async {
    if (isPremium) return true;
    error = '$feature is a Pro feature. Open Settings → ORAH Pro to unlock it.';
    notifyListeners();
    return false;
  }

  Future<void> initialize() async {
    if (!loading) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_entitlementKey);
    plan = switch (stored) {
      'monthly' => OrahPlan.monthly,
      'yearly' => OrahPlan.yearly,
      'lifetime' => OrahPlan.lifetime,
      _ => OrahPlan.free,
    };

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
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ProductDetails? product(String id) {
    for (final item in products) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> buy(String productId) async {
    final item = product(productId);
    if (item == null) {
      error = 'This plan is not available in the current store.';
      notifyListeners();
      return;
    }
    final param = PurchaseParam(productDetails: item);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    final prefs = await SharedPreferences.getInstance();
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final next = switch (purchase.productID) {
          monthlyId => OrahPlan.monthly,
          yearlyId => OrahPlan.yearly,
          lifetimeId => OrahPlan.lifetime,
          _ => plan,
        };
        if (next != OrahPlan.free) {
          plan = next;
          await prefs.setString(_entitlementKey, next.name);
          await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());
        }
      } else if (purchase.status == PurchaseStatus.error) {
        error = purchase.error?.message ?? 'Purchase failed.';
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  String get planLabel => switch (plan) {
    OrahPlan.monthly => 'Pro Monthly',
    OrahPlan.yearly => 'Pro Yearly',
    OrahPlan.lifetime => 'Pro Lifetime',
    OrahPlan.free => 'Free',
  };

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
