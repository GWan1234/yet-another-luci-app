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

  static AppFlavor get flavor {
    if (_flavorStr.toLowerCase() == 'playstore') {
      return AppFlavor.playstore;
    }
    return AppFlavor.community;
  }

  /// Whether monetization features (AdMob, Play Billing, Paywalls, Router Gating) are enabled.
  /// Strictly `false` for community builds to ensure zero ad/billing SDK activity.
  static bool get isMonetizationEnabled => flavor == AppFlavor.playstore;

  /// Human-readable build channel description.
  static String get flavorName => flavor == AppFlavor.playstore ? 'Play Store' : 'Community';
}
