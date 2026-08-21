// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';

void main() {
  testWidgets('_LuciToastWidget renders inside Overlay without ParentData exception', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LuciToastManager.show(
                    context,
                    title: 'Test Notification',
                    subtitle: 'Test Subtitle',
                    type: LuciToastType.info,
                    duration: const Duration(seconds: 2),
                    useNativeOs: false,
                  );
                },
                child: const Text('Show Toast'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show toast
    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify toast title and subtitle are present
    expect(find.text('Test Notification'), findsOneWidget);
    expect(find.text('Test Subtitle'), findsOneWidget);

    // Verify no exception was thrown
    expect(tester.takeException(), isNull);
  });
}
