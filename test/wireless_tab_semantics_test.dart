// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/screens/interfaces_screen.dart';

void main() {
  testWidgets('InterfacesScreen wireless tab renders and updates semantics without assertion failure', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InterfacesScreen(scrollToInterface: 'phy0-ap0'),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify semantics handles rendering without throwing parentDataDirty assertion error
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
