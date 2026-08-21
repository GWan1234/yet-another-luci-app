// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/providers/entitlement_provider.dart';

void main() {
  group('Compile-Time Flavor Gating Unit Tests', () {
    test('AppConfig defaults to Community flavor when FLAVOR environment variable is omitted', () {
      expect(AppConfig.flavor, equals(AppFlavor.community));
      expect(AppConfig.isMonetizationEnabled, isFalse);
      expect(AppConfig.flavorName, equals('Community'));
      expect(AppConfig.isOfficialBuild, isFalse);
    });

    test('EntitlementNotifier in Community flavor defaults to Lifetime tier (Ad-Free, Unlimited Routers)', () {
      final notifier = EntitlementNotifier();
      final state = notifier.state;

      // Community flavor MUST be 100% ad-free with unlimited routers out of the box
      expect(state.tier, equals(EntitlementTier.lifetime));
      expect(state.isAdFree, isTrue);
      expect(state.routerLimit, greaterThanOrEqualTo(999));
      expect(state.canAddRouter(100), isTrue);
    });
  });
}
