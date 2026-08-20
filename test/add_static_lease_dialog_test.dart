// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/widgets/add_static_lease_dialog.dart';

void main() {
  testWidgets('AddStaticLeaseDialog initializes without error when parameters are null', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const AddStaticLeaseDialog(),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog title is rendered and no LateInitializationError occurred
    expect(find.text('Add Static Lease'), findsOneWidget);
    expect(find.text('MAC Address'), findsOneWidget);
    expect(find.text('Hostname / Client Name'), findsOneWidget);
    expect(find.text('Save Reservation'), findsOneWidget);

    // Verify initial clean state without premature error messages
    expect(find.text('MAC address cannot be empty'), findsNothing);
    expect(find.text('Hostname cannot be empty'), findsNothing);
    expect(find.text('IPv4 address cannot be empty'), findsNothing);
    expect(find.textContaining('Paste MAC'), findsNothing);
  });
}
