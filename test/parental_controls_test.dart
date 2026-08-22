// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/modules/parental_controls/models/parental_profile.dart';
import 'package:yet_another_luci_app/modules/parental_controls/models/parental_controls_store.dart';
import 'package:yet_another_luci_app/modules/parental_controls/widgets/parental_profile_card.dart';
import 'package:yet_another_luci_app/modules/parental_controls/widgets/add_edit_profile_dialog.dart';

void main() {
  group('ParentalControlsStore Tests', () {
    late ParentalControlsStore store;

    setUp(() {
      store = ParentalControlsStore.instance;
      // Clean up previous profiles
      for (final p in store.profiles.toList()) {
        store.deleteProfile(p.id);
      }
      store.clearActivityLog();
    });

    test('Add, update, and delete profile', () {
      final profile = ParentalProfile(
        id: 'test_1',
        name: 'Kids Tablet',
        icon: '👦',
        color: '#F97316',
        macAddresses: const ['AA:BB:CC:DD:EE:11'],
        dailyTimeLimitMinutes: 120,
        contentFilter: ContentFilterDns.cloudflareFamilySafe,
      );

      final id = store.addProfile(profile);
      expect(id, 'test_1');
      expect(store.profiles.length, 1);
      expect(store.profiles.first.name, 'Kids Tablet');
      expect(store.activityLog.first.eventType, ParentalEventType.profileCreated);

      final updated = profile.copyWith(name: 'Kids Tablet (Updated)');
      store.updateProfile(updated);
      expect(store.profiles.first.name, 'Kids Tablet (Updated)');
      expect(store.activityLog.first.eventType, ParentalEventType.profileUpdated);

      store.deleteProfile('test_1');
      expect(store.profiles, isEmpty);
      expect(store.activityLog.first.eventType, ParentalEventType.profileDeleted);
    });

    test('Pause and resume state management', () {
      final profile = ParentalProfile(
        id: 'test_pause',
        name: 'Gaming Console',
        icon: '🎮',
        color: '#3B82F6',
        macAddresses: const ['11:22:33:44:55:66'],
      );
      store.addProfile(profile);

      final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
      store.markProfilePaused('test_pause', expiresAt: expiry);

      final p = store.getProfile('test_pause')!;
      expect(p.isPaused, isTrue);
      expect(p.pauseExpiresAt, equals(expiry));
      expect(store.isMacPaused('11:22:33:44:55:66'), isTrue);

      store.markProfileResumed('test_pause');
      final resumed = store.getProfile('test_pause')!;
      expect(resumed.isPaused, isFalse);
      expect(resumed.pauseExpiresAt, null);
      expect(store.isMacPaused('11:22:33:44:55:66'), isFalse);
    });

    test('Serialization and deserialization', () {
      final profile = ParentalProfile(
        id: 'test_ser',
        name: 'Teen Phone',
        icon: '📱',
        color: '#EF4444',
        macAddresses: const ['00:11:22:33:44:55'],
        schedule: const TimeSchedule(
          activeDays: {ScheduleDay.monday, ScheduleDay.friday},
          blockHour: 23,
          blockMinute: 30,
          resumeHour: 6,
          resumeMinute: 0,
        ),
        contentFilter: ContentFilterDns.openDnsFamilyShield,
      );
      store.addProfile(profile);

      final jsonStr = store.toJsonString();
      expect(jsonStr, contains('Teen Phone'));
      expect(jsonStr, contains('00:11:22:33:44:55'));
      expect(jsonStr, contains('opendns_family'));

      store.loadFromString(jsonStr);
      expect(store.profiles.length, 1);
      final loaded = store.profiles.first;
      expect(loaded.name, 'Teen Phone');
      expect(loaded.schedule?.blockHour, 23);
      expect(loaded.contentFilter, ContentFilterDns.openDnsFamilyShield);
      expect(loaded.isEnabled, isTrue);
    });

    test('Bypass state toggling and isMacPaused behavior', () {
      final profile = ParentalProfile(
        id: 'test_bypass',
        name: 'Bypass Test',
        icon: '📱',
        color: '#EF4444',
        macAddresses: const ['AA:BB:CC:DD:EE:99'],
        isPaused: true,
        isEnabled: true,
      );
      store.addProfile(profile);

      expect(store.isMacPaused('AA:BB:CC:DD:EE:99'), isTrue);

      // Toggle profile to bypass (disabled guardrails)
      store.toggleProfileEnabled('test_bypass');
      final bypassed = store.getProfile('test_bypass')!;
      expect(bypassed.isEnabled, isFalse);
      expect(bypassed.isBypassed, isTrue);

      // MAC should NOT report as paused when profile rules are bypassed!
      expect(store.isMacPaused('AA:BB:CC:DD:EE:99'), isFalse);
    });

    test('TimeSchedule isTimeInBlockWindow calculation', () {
      // Overnight schedule: 22:00 to 07:00 on Monday
      const schedule = TimeSchedule(
        activeDays: {ScheduleDay.monday},
        blockHour: 22,
        blockMinute: 0,
        resumeHour: 7,
        resumeMinute: 0,
      );

      // Monday 23:30 -> in block window
      final monNight = DateTime(2026, 8, 24, 23, 30); // 2026-08-24 is a Monday
      expect(schedule.isTimeInBlockWindow(monNight), isTrue);

      // Monday 05:15 -> in block window
      final monMorning = DateTime(2026, 8, 24, 5, 15);
      expect(schedule.isTimeInBlockWindow(monMorning), isTrue);

      // Monday 12:00 -> outside block window
      final monNoon = DateTime(2026, 8, 24, 12, 0);
      expect(schedule.isTimeInBlockWindow(monNoon), isFalse);

      // Tuesday 23:30 -> outside active days (only Monday active)
      final tueNight = DateTime(2026, 8, 25, 23, 30); // 2026-08-25 is a Tuesday
      expect(schedule.isTimeInBlockWindow(tueNight), isFalse);
    });
  });

  group('ParentalControls Widget & Overflow Tests', () {
    testWidgets('ParentalProfileCard renders correctly without bounds issues', (tester) async {
      final profile = ParentalProfile(
        id: 'card_test',
        name: 'Extremely Long Device Profile Name That Could Cause Right Overflow',
        icon: '💻',
        color: '#10B981',
        macAddresses: const ['AA:BB:CC:DD:EE:FF', '11:22:33:44:55:66'],
        isPaused: true,
        pauseExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 45)),
        schedule: const TimeSchedule(
          activeDays: {ScheduleDay.monday, ScheduleDay.tuesday},
          blockHour: 21,
          blockMinute: 0,
          resumeHour: 7,
          resumeMinute: 0,
        ),
        dailyTimeLimitMinutes: 90,
        contentFilter: ContentFilterDns.cloudflareFamilySafe,
      );

      // Force narrow viewport size to test responsiveness against bleeding/overflow
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ParentalProfileCard(
                profile: profile,
                hasFirewall: true,
                hasFileExec: true,
                onPause: (_) {},
                onResume: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Extremely Long Device Profile Name'), findsOneWidget);
      expect(find.text('2 devices'), findsOneWidget);
      expect(find.text('Resume Internet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddEditProfileDialog renders and scrolls without overflow on small screens', (tester) async {
      tester.view.physicalSize = const Size(360, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEditProfileDialog(
                allProfiles: const [],
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('New Profile'), findsOneWidget);
      expect(find.text('Profile Name *'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddEditProfileDialog context awareness disables save until modified when editing', (tester) async {
      final existing = ParentalProfile(
        id: 'p1',
        name: 'Kids Tablet',
        icon: '👦',
        color: '#F97316',
        macAddresses: const ['AA:BB:CC:DD:EE:FF'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEditProfileDialog(
                existing: existing,
                allProfiles: [existing],
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Initially, Save Changes button should be disabled (onPressed is null)
      final saveBtnFinder = find.widgetWithText(FilledButton, 'Save Changes');
      expect(saveBtnFinder, findsOneWidget);
      final initialButton = tester.widget<FilledButton>(saveBtnFinder);
      expect(initialButton.onPressed, isNull);

      // Type a new character in profile name
      await tester.enterText(find.byType(TextFormField).first, 'Kids Tablet 2');
      await tester.pump();

      // Now Save Changes button should be enabled
      final updatedButton = tester.widget<FilledButton>(saveBtnFinder);
      expect(updatedButton.onPressed, isNotNull);
    });
  });
}
