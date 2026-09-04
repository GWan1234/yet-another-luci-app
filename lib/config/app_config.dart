// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';

/// Flavor types supported by the build pipeline
enum AppFlavor { community, playstore }

/// Central configuration for build flavor detection and compile-time feature toggling.
class AppConfig {
  // GitHub repository URL - update this with your actual repository
  static const String githubRepositoryUrl =
      'https://github.com/nightcodex7/yet-another-luci-app';

  // GitHub issues URL
  static const String githubIssuesUrl = '$githubRepositoryUrl/issues';

  // Legal & Privacy Policy URLs
  static const String privacyPolicyUrl =
      'https://nightcode.co.in/privacy-policy.html';
  static const String termsAndConditionsUrl =
      'https://nightcode.co.in/terms.html';
  static const String contactUrl =
      'https://nightcode.co.in/contact.html';

  // Community Direct Support Payment URLs
  static const String razorpayUrl = 'https://razorpay.me/@nightcode';
  static const String stripeUrl = '';
  static const String paypalUrl = '';
  static const String wiseUrl = '';
  /// UPI payment link — shown only for India-locale community builds.
  static const String upiUrl = '';


  // Maintainer & Contact Configuration
  static const String appAuthor = 'Tuhin Garai';
  static const String appAuthorGithub = '@nightcodex7';
  static const String supportEmail = 'tuhingarai.dev+support@gmail.com';
  static const String feedbackEmail = 'tuhingarai.dev+feedback@gmail.com';

  // Reviewer mode configuration
  static const String reviewerModeKey = 'reviewer_mode_enabled';
  static const String mockDataPath = 'assets/mock/';
  static const Duration reviewerModeActivationDuration = Duration(seconds: 5);
  static const String reviewerModeWatermark = 'Reviewer Mode';

  /// The current flavor set via compile-time `--dart-define=FLAVOR=community` or `playstore`.
  /// Defaults to `community` if unspecified.
  static const String _flavorStr = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'community',
  );

  /// Whether this build is verified as an official release build.
  /// Controlled via compile-time flag `--dart-define=OFFICIAL_BUILD=true`.
  /// Defaults to `false` for local developer builds, debug builds, and unofficial forks.
  static bool get isOfficialBuild =>
      const bool.fromEnvironment('OFFICIAL_BUILD', defaultValue: false);

  /// Whether voluntary Support the Developer feature is enabled in UI.
  /// Enabled via compile-time flag `--dart-define=ENABLE_SUPPORT_DEV=true` or in debug mode (`kDebugMode`).
  /// Disabled by default in release builds.
  static bool get isSupportDevEnabled =>
      const bool.fromEnvironment('ENABLE_SUPPORT_DEV', defaultValue: false) ||
      kDebugMode;

  /// Whether Google Play In-App Billing (IAP) is enabled.
  /// ONLY true when explicitly built for the Play Store flavor AND
  /// the `--dart-define=ENABLE_SUPPORT_DEV=true` flag is set.
  /// Never enabled by kDebugMode alone — avoids PlatformException crashes on
  /// non-Play-Store devices (community builds, side-loaded APKs, CI).
  static bool get isMonetizationEnabled =>
      const bool.fromEnvironment('ENABLE_SUPPORT_DEV', defaultValue: false) &&
      flavor == AppFlavor.playstore;

  /// Google Play Billing Licensing RSA public key (Base64-encoded).
  /// Used for purchase verification. Safe to include in binary — public key only.
  static const String playBillingPublicKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0P3voOSqF9BI6BoHfLbVGcZ8adRfmZwYAKZDUZCV6tmbDq37s3Ljc/a+PAtVZSH5Ks6opNj8JVcvZa0mAAu3aKAEd9TccqlCqiEYIkLx9/RVQGpVaMEsE40KQvmBHRIwJGcYVp8wc7MT7McHGqaW/q7fBQJBOtXl1IglJiw2mtIS0c6mtHFCmvMD+Nu97U4Rd3IgtoZ6t2zajmhcQh6OXC97xw4Xa61CMsGWeXaxG8CVIWlNumzlBODooCqISWTizHYwSi4HK+4dMCagWr+qoynomY4CS2PocvUtHcn+x30kJcR9oE3DPtuz78KT56kDfhLxVxm7tHL0sjjI4axDuwIDAQAB';

  static AppFlavor get flavor {
    if (_flavorStr.toLowerCase() == 'playstore') {
      return AppFlavor.playstore;
    }
    return AppFlavor.community;
  }

  /// Whether the current build is the FOSS community flavor.
  static bool get isCommunityFlavor => flavor == AppFlavor.community;

  /// Human-readable build channel description.
  static String get flavorName =>
      flavor == AppFlavor.playstore ? 'Play Store' : 'Community';
}
