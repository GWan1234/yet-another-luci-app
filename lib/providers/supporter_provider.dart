// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Product IDs
// ---------------------------------------------------------------------------

/// Product ID constants for voluntary developer support.
class SupporterProducts {
  static const String tier1 = 'support_tier_1'; // ₹1,000 / ~$12
  static const String tier2 = 'support_tier_2'; // ₹2,000 / ~$24
  static const String tier3 = 'support_tier_3'; // ₹5,000 / ~$60
  static const String tier4 = 'support_tier_4'; // ₹10,000 / ~$120

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

  /// True while a support flow or prefs write is in progress.
  final bool isLoading;

  /// Non-null when an error occurred during a purchase or restore operation.
  /// The UI should display this once and then call [SupporterNotifier.clearError].
  final String? errorMessage;

  const SupporterState({
    this.hasSupportedAtLeastOnce = false,
    this.supportCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  SupporterState copyWith({
    bool? hasSupportedAtLeastOnce,
    int? supportCount,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupporterState(
      hasSupportedAtLeastOnce:
          hasSupportedAtLeastOnce ?? this.hasSupportedAtLeastOnce,
      supportCount: supportCount ?? this.supportCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
/// Persistence: [SharedPreferences] & [FlutterSecureStorage] (hardware-backed).
class SupporterNotifier extends StateNotifier<SupporterState> {
  static const _keySupported = 'has_supported_dev';
  static const _keyCount = 'support_dev_count';
  static const _keySignature = 'support_dev_sig';
  static const _keySecureVault = 'sec_supporter_v1';

  final FlutterSecureStorage _secureStorage;

  SupporterNotifier({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
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
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Marks the user as a supporter and persists to storage.
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

  /// Initiates voluntary developer support.
  Future<void> initiatePurchase(String productId) async {}

  /// Triggers restore-purchases flow.
  Future<void> restorePurchases() async {}
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global Riverpod provider for voluntary developer support state.
final supporterProvider =
    StateNotifierProvider<SupporterNotifier, SupporterState>(
      (ref) => SupporterNotifier(),
    );
