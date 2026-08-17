// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:luci_mobile/config/app_config.dart';

/// Available subscription / purchase tiers.
enum EntitlementTier {
  free,
  plus,
  pro,
  lifetime;

  String get displayName {
    switch (this) {
      case EntitlementTier.free:
        return 'Free Tier';
      case EntitlementTier.plus:
        return 'Plus Tier';
      case EntitlementTier.pro:
        return 'Pro Tier';
      case EntitlementTier.lifetime:
        return 'Lifetime Pass';
    }
  }

  /// Router count limit enforced by this tier.
  int get routerLimit => 999999;

  /// Whether banner ads are hidden for this tier.
  bool get isAdFree => this != EntitlementTier.free;
}

/// State model representing user's current monetization entitlements.
class EntitlementState {
  final EntitlementTier tier;
  final bool isLoading;
  final String? errorMessage;
  final List<ProductDetails> availableProducts;

  const EntitlementState({
    required this.tier,
    this.isLoading = false,
    this.errorMessage,
    this.availableProducts = const [],
  });

  int get routerLimit => tier.routerLimit;
  bool get isAdFree => tier.isAdFree;

  bool canAddRouter(int currentRouterCount) {
    return true;
  }

  EntitlementState copyWith({
    EntitlementTier? tier,
    bool? isLoading,
    String? errorMessage,
    List<ProductDetails>? availableProducts,
  }) {
    return EntitlementState(
      tier: tier ?? this.tier,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      availableProducts: availableProducts ?? this.availableProducts,
    );
  }
}

/// Product ID constants matching Google Play Console setup.
class PlayBillingProducts {
  static const String plusMonthly = 'plus_monthly';
  static const String proMonthly = 'pro_monthly';
  static const String lifetimeUnlimited = 'lifetime_unlimited';

  static const Set<String> allProductIds = {
    plusMonthly,
    proMonthly,
    lifetimeUnlimited,
  };
}

/// Riverpod StateNotifier managing billing products, active entitlement tier,
/// local persistence, and Google Play Store purchase/restore streams.
class EntitlementNotifier extends StateNotifier<EntitlementState> {
  static const _storageKey = 'app_entitlement_tier';
  final FlutterSecureStorage _secureStorage;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  EntitlementNotifier({
    FlutterSecureStorage? secureStorage,
    InAppPurchase? iap,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _iap = iap ?? (AppConfig.isMonetizationEnabled ? InAppPurchase.instance : _DisabledInAppPurchase()),
        super(
          EntitlementState(
            tier: AppConfig.isMonetizationEnabled
                ? EntitlementTier.free
                : EntitlementTier.lifetime,
          ),
        ) {
    if (AppConfig.isMonetizationEnabled) {
      _init();
    }
  }

  Future<void> _init() async {
    if (!AppConfig.isMonetizationEnabled) return;
    await loadCachedEntitlement();
    _listenToPurchaseUpdates();
    await fetchBillingProducts();
  }

  /// Loads cached entitlement tier from local secure storage.
  Future<void> loadCachedEntitlement() async {
    try {
      final cachedStr = await _secureStorage.read(key: _storageKey);
      if (cachedStr != null) {
        final cachedTier = EntitlementTier.values.firstWhere(
          (t) => t.name == cachedStr,
          orElse: () => EntitlementTier.free,
        );
        state = state.copyWith(tier: cachedTier);
      }
    } catch (e) {
      debugPrint('Error reading cached entitlement: $e');
    }
  }

  /// Updates active entitlement tier and immediately persists it locally.
  Future<void> updateEntitlement(EntitlementTier newTier) async {
    state = state.copyWith(tier: newTier, errorMessage: null);
    try {
      await _secureStorage.write(key: _storageKey, value: newTier.name);
    } catch (e) {
      debugPrint('Error caching entitlement tier: $e');
    }
  }

  /// Loads products configured in Google Play Console.
  Future<void> fetchBillingProducts() async {
    try {
      final bool isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        return;
      }
      final response = await _iap.queryProductDetails(PlayBillingProducts.allProductIds);
      if (response.error == null) {
        state = state.copyWith(availableProducts: response.productDetails);
      } else {
        debugPrint('Play Billing query error: ${response.error}');
      }
    } catch (e) {
      debugPrint('Error querying billing products: $e');
    }
  }

  /// Listens to Play Store purchase stream to handle real-time purchase completions and restores.
  void _listenToPurchaseUpdates() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      (purchaseList) {
        _handlePurchaseUpdates(purchaseList);
      },
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (e) {
        debugPrint('Purchase stream error: $e');
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        state = state.copyWith(isLoading: true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: purchaseDetails.error?.message ?? 'Purchase failed',
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final verifiedTier = _verifyAndMapProductToTier(purchaseDetails.productID);
          if (verifiedTier != null) {
            // Update entitlement synchronously before returning control
            await updateEntitlement(verifiedTier);
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          state = state.copyWith(isLoading: false);
        }
      }
    }
  }

  /// Maps Google Play product ID to corresponding EntitlementTier.
  EntitlementTier? _verifyAndMapProductToTier(String productId) {
    switch (productId) {
      case PlayBillingProducts.plusMonthly:
        return EntitlementTier.plus;
      case PlayBillingProducts.proMonthly:
        return EntitlementTier.pro;
      case PlayBillingProducts.lifetimeUnlimited:
        return EntitlementTier.lifetime;
      default:
        return null;
    }
  }

  /// Initiates purchase flow for a product.
  Future<void> buyProduct(ProductDetails productDetails) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      if (productDetails.id == PlayBillingProducts.lifetimeUnlimited) {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Triggers Play Store restore purchases flow required by Play Store policy.
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _iap.restorePurchases();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

/// Global Riverpod Provider for Entitlement State.
final entitlementProvider = StateNotifierProvider<EntitlementNotifier, EntitlementState>(
  (ref) => EntitlementNotifier(),
);

/// No-op dummy InAppPurchase implementation used for Community build flavor
/// to ensure zero billing SDK calls or platform channel bindings.
class _DisabledInAppPurchase implements InAppPurchase {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(productDetails: [], notFoundIDs: identifiers.toList());
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => false;

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => '';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() {
    throw UnimplementedError('Play Billing platform additions unavailable in Community build flavor.');
  }
}
