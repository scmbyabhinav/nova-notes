import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrahEntitlementService extends ChangeNotifier {
  OrahEntitlementService._();
  static final instance = OrahEntitlementService._();
  static const monthlyId = 'orah_pro_monthly';
  static const yearlyId = 'orah_pro_yearly';
  static const lifetimeId = 'orah_pro_lifetime';
  static const _entitledKey = 'orah_pro_entitled_v1';
  static const _productKey = 'orah_pro_entitlement_product_v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false, _available = false, _pro = false;
  String? _entitlementProduct;
  List<ProductDetails> _products = const [];

  bool get isInitialized => _initialized;
  bool get storeAvailable => _available;
  bool get isPro => _pro;
  String? get entitlementProduct => _entitlementProduct;
  List<ProductDetails> get products => List.unmodifiable(_products);
  ProductDetails? get monthly => _find(monthlyId);
  ProductDetails? get yearly => _find(yearlyId);
  ProductDetails? get lifetime => _find(lifetimeId);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _pro = prefs.getBool(_entitledKey) ?? false;
    _entitlementProduct = prefs.getString(_productKey);
    _subscription = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    try {
      _available = await _iap.isAvailable();
      if (_available) {
        final response = await _iap.queryProductDetails(
          {monthlyId, yearlyId, lifetimeId},
        );
        _products = response.productDetails;
        await _iap.restorePurchases();
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<bool> buy(ProductDetails product) async {
    if (!_initialized) await initialize();
    if (!_available) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    if (!_initialized) await initialize();
    if (!_available) return;
    try { await _iap.restorePurchases(); } catch (_) {}
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final valid = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (valid && {monthlyId, yearlyId, lifetimeId}.contains(purchase.productID)) {
        _pro = true;
        _entitlementProduct = purchase.productID;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_entitledKey, true);
        await prefs.setString(_productKey, purchase.productID);
        notifyListeners();
      }
      if (purchase.pendingCompletePurchase) {
        try { await _iap.completePurchase(purchase); } catch (_) {}
      }
    }
  }

  ProductDetails? _find(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
