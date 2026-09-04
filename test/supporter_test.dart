// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yet_another_luci_app/providers/supporter_provider.dart';
import 'package:yet_another_luci_app/screens/support_the_dev_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SupporterNotifier Tests', () {
    test('SupporterProducts defines 4 tiers correctly', () {
      expect(SupporterProducts.allProductIds.length, equals(4));
      expect(SupporterProducts.allProductIds, contains('support_tier_1'));
      expect(SupporterProducts.allProductIds, contains('support_tier_2'));
      expect(SupporterProducts.allProductIds, contains('support_tier_3'));
      expect(SupporterProducts.allProductIds, contains('support_tier_4'));
      expect(SupporterProducts.getProductIdForIndex(0), equals('support_tier_1'));
      expect(SupporterProducts.getProductIdForIndex(1), equals('support_tier_2'));
      expect(SupporterProducts.getProductIdForIndex(2), equals('support_tier_3'));
      expect(SupporterProducts.getProductIdForIndex(3), equals('support_tier_4'));
    });

    test('Initial state has default values', () {
      final notifier = SupporterNotifier();
      expect(notifier.state.hasSupportedAtLeastOnce, isFalse);
      expect(notifier.state.supportCount, equals(0));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('markAsSupported updates state and increments support count', () async {
      final notifier = SupporterNotifier();
      await notifier.markAsSupported();

      expect(notifier.state.hasSupportedAtLeastOnce, isTrue);
      expect(notifier.state.supportCount, equals(1));

      await notifier.markAsSupported();
      expect(notifier.state.supportCount, equals(2));
    });

    test('Tampered SharedPreferences data without valid signature is rejected', () async {
      // Simulate malicious user editing SharedPreferences XML directly
      SharedPreferences.setMockInitialValues({
        'has_supported_dev': true,
        'support_dev_count': 999,
        'support_dev_sig': 'invalid_forged_hash',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final notifier = SupporterNotifier();
      // Allow async load to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // forged values should be rejected
      expect(notifier.state.hasSupportedAtLeastOnce, isFalse);
      expect(notifier.state.supportCount, equals(0));
    });

    test('clearError clears errorMessage', () {
      final notifier = SupporterNotifier();
      notifier.state = notifier.state.copyWith(errorMessage: 'Test Error');
      expect(notifier.state.errorMessage, equals('Test Error'));

      notifier.clearError();
      expect(notifier.state.errorMessage, isNull);
    });
  });

  group('SupportTheDevScreen Widget Tests', () {
    testWidgets('Renders header, preset chips, and custom amount section', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supporterProvider.overrideWith(
              (ref) => SupporterNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: SupportTheDevScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support Open-Source Development'), findsOneWidget);
      expect(find.text('Choose Support Amount'), findsOneWidget);
      expect(find.text('Custom Support Amount'), findsOneWidget);
    });

    testWidgets('Custom amount validation prevents amounts below threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supporterProvider.overrideWith(
              (ref) => SupporterNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: SupportTheDevScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '5');
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Minimum support amount is'), findsOneWidget);
    });
  });
}
