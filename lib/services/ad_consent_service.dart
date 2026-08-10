import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:luci_mobile/config/app_config.dart';

/// Manages Google UMP (User Messaging Platform) consent for GDPR/UK regions
/// and initializes the Google Mobile Ads SDK prior to requesting any ads.
class AdConsentService {
  static bool _isInitialized = false;

  /// Initializes Google Mobile Ads SDK with GDPR/UK UMP consent check.
  static Future<void> initializeConsentAndAds() async {
    if (!AppConfig.isMonetizationEnabled) {
      // Community build flavor: zero ad SDK activity
      return;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      // Mobile Ads SDK is supported on Android and iOS
      return;
    }

    if (_isInitialized) return;

    final params = ConsentRequestParameters();

    try {
      final completer = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          unawaited(
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('Consent form error: ${formError.message}');
              }
              _initMobileAds();
              if (!completer.isCompleted) completer.complete();
            }),
          );
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
    MobileAds.instance.initialize();
  }
}
