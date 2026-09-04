// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  bool get isAdFree => true;
}

/// State model representing user's current entitlements.
class EntitlementState {
  final EntitlementTier tier;
  final bool isLoading;
  final String? errorMessage;

  const EntitlementState({
    required this.tier,
    this.isLoading = false,
    this.errorMessage,
  });

  int get routerLimit => tier.routerLimit;
  bool get isAdFree => true;

  bool canAddRouter(int currentRouterCount) {
    return true;
  }

  EntitlementState copyWith({
    EntitlementTier? tier,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EntitlementState(
      tier: tier ?? this.tier,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
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

/// Riverpod StateNotifier managing active entitlement tier and local persistence.
class EntitlementNotifier extends StateNotifier<EntitlementState> {
  static const _storageKey = 'app_entitlement_tier';
  final FlutterSecureStorage _secureStorage;

  EntitlementNotifier({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      super(
        const EntitlementState(
          tier: EntitlementTier.free,
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    await loadCachedEntitlement();
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

  Future<void> fetchBillingProducts() async {}

  Future<void> purchaseProduct(String productId) async {}

  Future<void> restorePurchases() async {}
}

/// Global Riverpod provider for app monetization state and entitlements.
final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, EntitlementState>(
      (ref) => EntitlementNotifier(),
    );
