// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:yet_another_luci_app/config/app_config.dart';

/// Manages Google UMP (User Messaging Platform) consent for GDPR/UK regions
/// and initializes the Google Mobile Ads SDK prior to requesting any ads.
class AdConsentService {
  static bool _isInitialized = false;

  /// Initializes Google Mobile Ads SDK with GDPR/UK UMP consent check.
  static Future<void> initializeConsentAndAds() async {
    if (!AppConfig.isAdsEnabled || !AppConfig.isMonetizationEnabled) {
      // Zero ad/consent SDK activity when ads or monetization are disabled
      return;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // Mobile Ads SDK is strictly supported on Android platforms (Phones, Tablets, Chromebooks)
      return;
    }

    if (_isInitialized) return;

    final params = ConsentRequestParameters();

    try {
      final completer = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('Consent form error: ${formError.message}');
              }
              _initMobileAds();
              if (!completer.isCompleted) completer.complete();
            });
          } catch (e) {
            debugPrint('ConsentForm exception: $e');
            _initMobileAds();
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError error) {
          debugPrint('Consent info update error: ${error.message}');
          _initMobileAds();
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Timeout safety after 5s to avoid blocking app start if consent network call stalls
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _initMobileAds();
        },
      );
    } catch (e) {
      debugPrint('AdConsentService initialization exception: $e');
      _initMobileAds();
    }
  }

  static void _initMobileAds() {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization exception: $e');
    }
  }
}
