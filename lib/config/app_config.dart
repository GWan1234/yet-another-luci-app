/// Flavor types supported by the build pipeline
enum AppFlavor {
  community,
  playstore,
}

/// Central configuration for build flavor detection and compile-time feature toggling.
class AppConfig {
  // GitHub repository URL - update this with your actual repository
  static const String githubRepositoryUrl =
      'https://github.com/nightcodex7/yet-another-luci-app';

  // GitHub issues URL
  static const String githubIssuesUrl = '$githubRepositoryUrl/issues';

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

  /// Explicit compile-time toggle for ads SDK.
  /// Set via `--dart-define=ENABLE_ADS=true`. Defaults to `false`.
  /// When false, AdMob and UMP consent SDK are not initialized and no ad widgets render.
  static const bool _enableAdsFlag = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: false,
  );

  /// Explicit compile-time toggle for voluntary Support the Developer UI.
  /// Set via `--dart-define=ENABLE_SUPPORT_DEV=true`. Defaults to `false`.
  /// When false, the Support the Developer tile does not render in any screen.
  static const bool _enableSupportDevFlag = bool.fromEnvironment(
    'ENABLE_SUPPORT_DEV',
    defaultValue: false,
  );

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

  /// Whether the ads SDK should be compiled, initialized, and rendered.
  /// Requires BOTH playstore flavor AND explicit `ENABLE_ADS=true` dart-define.
  static bool get isAdsEnabled => flavor == AppFlavor.playstore && _enableAdsFlag;

  /// Whether voluntary Support the Developer feature is enabled in UI.
  /// Defaults to false in all release builds unless explicitly enabled via `ENABLE_SUPPORT_DEV=true`.
  static bool get isSupportDevEnabled => _enableSupportDevFlag;

  /// Whether monetization features (Play Billing, Paywalls, Router Gating) are enabled.
  /// Strictly `false` for community builds to ensure zero billing SDK activity.
  /// Note: Ads are separately gated by [isAdsEnabled].
  static bool get isMonetizationEnabled => flavor == AppFlavor.playstore;

  /// Whether the current build is the FOSS community flavor.
  static bool get isCommunityFlavor => flavor == AppFlavor.community;

  /// Human-readable build channel description.
  static String get flavorName => flavor == AppFlavor.playstore ? 'Play Store' : 'Community';
}
