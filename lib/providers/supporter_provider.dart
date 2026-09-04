// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yet_another_luci_app/config/app_config.dart';

// ---------------------------------------------------------------------------
// Product IDs
// ---------------------------------------------------------------------------

/// Play Store consumable product IDs for voluntary developer support.
/// All products must be set up as consumable one-time purchases in the
/// Google Play Console before enabling [AppConfig.isMonetizationEnabled].
class SupporterProducts {
  static const String tier1 = 'support_tier_1'; // ₹1,000 / ~$12
  static const String tier2 = 'support_tier_2'; // ₹2,000 / ~$24
  static const String tier3 = 'support_tier_3'; // ₹5,000 / ~$60
  static const String tier4 = 'support_tier_4'; // ₹10,000 / ~$120
  // Custom amounts use external payment links, not a dedicated Play product.

  static const Set<String> allProductIds = {tier1, tier2, tier3, tier4};

  static String getProductIdForIndex(int index) {
    switch (index) {
      case 0:
        return tier1;
      case 1:
        return tier2;
      case 2:
        return tier3;
      case 3:
        return tier4;
      default:
        return tier1;
    }
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the voluntary developer support feature.
class SupporterState {
  /// Whether the user has completed at least one successful support payment.
  final bool hasSupportedAtLeastOnce;

  /// Number of successful support payments made across all sessions.
  final int supportCount;

  /// True while a Play Store purchase flow or prefs write is in progress.
  final bool isLoading;

  /// Non-null when an error occurred during a purchase or restore operation.
  /// The UI should display this once and then call [SupporterNotifier.clearError].
  final String? errorMessage;

  /// Available Play Store product details fetched from Google Play.
  /// Empty on community flavor or when Play Billing is unavailable.
  final List<ProductDetails> availableProducts;

  const SupporterState({
    this.hasSupportedAtLeastOnce = false,
    this.supportCount = 0,
    this.isLoading = false,
    this.errorMessage,
    this.availableProducts = const [],
  });

  SupporterState copyWith({
    bool? hasSupportedAtLeastOnce,
    int? supportCount,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ProductDetails>? availableProducts,
  }) {
    return SupporterState(
      hasSupportedAtLeastOnce:
          hasSupportedAtLeastOnce ?? this.hasSupportedAtLeastOnce,
      supportCount: supportCount ?? this.supportCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      availableProducts: availableProducts ?? this.availableProducts,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages voluntary developer support state.
///
/// Isolated from [EntitlementNotifier] by design — this feature is
/// purely opt-in and has no effect on feature access.
///
/// Persistence: [SharedPreferences] (non-sensitive keys).
/// IAP: [in_app_purchase] consumable products (Play Store flavor only).
class SupporterNotifier extends StateNotifier<SupporterState> {
  static const _keySupported = 'has_supported_dev';
  static const _keyCount = 'support_dev_count';
  static const _keySignature = 'support_dev_sig';
  static const _keySecureVault = 'sec_supporter_v1';

  final InAppPurchase _iap;
  final FlutterSecureStorage _secureStorage;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  SupporterNotifier({
    InAppPurchase? iap,
    FlutterSecureStorage? secureStorage,
  })  : _iap =
            iap ??
            (AppConfig.isMonetizationEnabled
                ? InAppPurchase.instance
                : NoOpInAppPurchase()),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(const SupporterState()) {
    _init();
  }

  // ── Anti-Tamper Security ──────────────────────────────────────────────────

  static String _computeSignature(bool supported, int count) {
    const salt = 'YET_ANOTHER_LUCI_APP_SUPPORTER_HMAC_SALT_2026_V1';
    final payload = '$salt:$supported:$count:$salt';
    final bytes = utf8.encode(payload);
    int hash = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadPersistedState();
    if (AppConfig.isMonetizationEnabled) {
      try {
        _listenToPurchaseStream();
        await _fetchProducts();
      } catch (e) {
        debugPrint('[SupporterNotifier] IAP init error: $e');
      }
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ── Persistence & Protection ───────────────────────────────────────────────

  Future<void> _loadPersistedState() async {
    try {
      // 1. Read from Android Keystore / iOS Keychain hardware vault
      bool secureSupported = false;
      int secureCount = 0;
      try {
        final secureVal = await _secureStorage.read(key: _keySecureVault);
        if (secureVal != null && secureVal.isNotEmpty) {
          final parts = secureVal.split(':');
          if (parts.length == 2) {
            secureSupported = parts[0] == 'true';
            secureCount = int.tryParse(parts[1]) ?? 0;
          }
        }
      } catch (e) {
        debugPrint('[SupporterNotifier] Secure storage read error: $e');
      }

      // 2. Read from SharedPreferences + verify signature
      final prefs = await SharedPreferences.getInstance();
      final prefsSupported = prefs.getBool(_keySupported) ?? false;
      final prefsCount = prefs.getInt(_keyCount) ?? 0;
      final storedSig = prefs.getString(_keySignature);
      final expectedSig = _computeSignature(prefsSupported, prefsCount);

      final bool validPrefs = storedSig != null && storedSig == expectedSig;
      if (!validPrefs && (prefsSupported || prefsCount > 0)) {
        debugPrint(
          '[SupporterNotifier] Tamper detected in SharedPreferences! Resetting unverified data.',
        );
      }

      // 3. Determine verified truth (hardware vault > signed prefs)
      final finalSupported = secureSupported || (validPrefs && prefsSupported);
      final finalCount = secureCount > (validPrefs ? prefsCount : 0)
          ? secureCount
          : (validPrefs ? prefsCount : 0);

      state = state.copyWith(
        hasSupportedAtLeastOnce:
            state.hasSupportedAtLeastOnce || finalSupported,
        supportCount:
            finalCount > state.supportCount ? finalCount : state.supportCount,
      );
    } catch (e) {
      debugPrint('[SupporterNotifier] Failed to load persisted state: $e');
    }
  }

  Future<void> _persistSupportedState(int newCount) async {
    try {
      final sig = _computeSignature(true, newCount);

      // Write to SharedPreferences with HMAC signature
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySupported, true);
      await prefs.setInt(_keyCount, newCount);
      await prefs.setString(_keySignature, sig);

      // Write to hardware-backed encrypted storage
      await _secureStorage.write(
        key: _keySecureVault,
        value: 'true:$newCount',
      );
    } catch (e) {
      debugPrint('[SupporterNotifier] Failed to persist support state: $e');
      // State is already true in memory — badge will still show this session.
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Marks the user as a supporter and persists to SharedPreferences.
  ///
  /// Called after:
  /// - A verified Play Store purchase completes, OR
  /// - The user manually confirms community payment ("Mark as Supported").
  Future<void> markAsSupported() async {
    final newCount = state.supportCount + 1;
    state = state.copyWith(
      hasSupportedAtLeastOnce: true,
      supportCount: newCount,
      isLoading: false,
      clearError: true,
    );
    await _persistSupportedState(newCount);
  }

  /// Clears a displayed error. Call after the UI has shown the error to the user.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Initiates a consumable Play Store purchase for [productId].
  ///
  /// Results arrive asynchronously via the purchase stream listener.
  /// Guards: no-ops silently when [AppConfig.isMonetizationEnabled] is false.
  Future<void> initiatePurchase(String productId) async {
    if (!AppConfig.isMonetizationEnabled) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Google Play is not available on this device. '
              'Please use a community payment method instead.',
        );
        return;
      }

      final response = await _iap.queryProductDetails({productId});

      if (response.error != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Failed to load product: ${response.error!.message}. '
              'Please try again.',
        );
        return;
      }

      if (response.productDetails.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Product not found in Play Store. '
              'Please try again later or use a community payment method.',
        );
        return;
      }

      final details = response.productDetails.first;
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
        autoConsume: true,
      );
      // Result arrives via _handlePurchaseUpdate — loading stays true until then.
    } on PlatformException catch (e) {
      debugPrint('[SupporterNotifier] PlatformException in initiatePurchase: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Google Play Billing service unavailable on local debug build. '
            'Please install the app via Google Play Internal Testing track to test billing.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Purchase failed: ${e.toString()}',
      );
    }
  }

  /// Triggers Play Store restore-purchases flow.
  ///
  /// No-op on community flavor.
  Future<void> restorePurchases() async {
    if (!AppConfig.isMonetizationEnabled) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _iap.restorePurchases();
      // Results arrive via stream; isLoading cleared in _handlePurchaseUpdate.
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Restore failed: ${e.toString()}',
      );
    }
  }

  // ── IAP Stream ────────────────────────────────────────────────────────────

  Future<void> _fetchProducts() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return;
      final response = await _iap.queryProductDetails(
        SupporterProducts.allProductIds,
      );
      if (response.error == null) {
        state = state.copyWith(availableProducts: response.productDetails);
      } else {
        debugPrint('[SupporterNotifier] Product query error: ${response.error}');
      }
    } catch (e) {
      debugPrint('[SupporterNotifier] fetchProducts error: $e');
    }
  }

  void _listenToPurchaseStream() {
    _purchaseSub?.cancel();
    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () => _purchaseSub?.cancel(),
        onError: (e) {
          debugPrint('[SupporterNotifier] purchase stream error: $e');
          state = state.copyWith(isLoading: false);
        },
      );
    } catch (e) {
      debugPrint('[SupporterNotifier] purchase stream listen error: $e');
    }
  }

  Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(isLoading: true);

        case PurchaseStatus.error:
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                purchase.error?.message ??
                'An error occurred during the purchase. Please try again.',
          );

        case PurchaseStatus.canceled:
          // User cancelled the billing dialog — silent, no error.
          state = state.copyWith(isLoading: false, clearError: true);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Complete the purchase with Google Play BEFORE granting entitlement.
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (e) {
              // Log but do not block — failing to complete is non-fatal.
              debugPrint('[SupporterNotifier] completePurchase error: $e');
            }
          }
          await markAsSupported();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global Riverpod provider for voluntary developer support state.
final supporterProvider =
    StateNotifierProvider<SupporterNotifier, SupporterState>(
      (ref) => SupporterNotifier(),
    );

// ---------------------------------------------------------------------------
// No-op IAP stub (community flavor / monetization disabled / testing)
// ---------------------------------------------------------------------------

class NoOpInAppPurchase implements InAppPurchase {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [],
    notFoundIDs: identifiers.toList(),
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      false;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => '';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() {
    throw UnimplementedError(
      'IAP platform additions unavailable when monetization is disabled.',
    );
  }
}
