// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/providers/entitlement_provider.dart';

void main() {
  group('Compile-Time Flavor Gating Unit Tests', () {
    test(
      'AppConfig defaults to Community flavor when FLAVOR environment variable is omitted',
      () {
        expect(AppConfig.flavor, equals(AppFlavor.community));
        expect(AppConfig.isMonetizationEnabled, isFalse);
        expect(AppConfig.flavorName, equals('Community'));
        expect(AppConfig.isOfficialBuild, isFalse);
      },
    );

    test(
      'EntitlementNotifier defaults to free tier (fail closed) with zero paywalls or limits',
      () {
        final notifier = EntitlementNotifier();
        final state = notifier.state;

        // Entitlement state defaults to free tier (fail closed) without hardcoding unlocked/pro/lifetime tags
        expect(state.tier, equals(EntitlementTier.free));
        expect(state.routerLimit, greaterThanOrEqualTo(999));
        expect(state.canAddRouter(100), isTrue);
      },
    );
  });
}
