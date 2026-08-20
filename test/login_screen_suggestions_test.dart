import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen initializes and handles floating autofill hint without assertion failures', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/': (context) => const Scaffold(body: Text('Main Screen')),
          },
        ),
      ),
    );

    // Pump frames to resolve _tryAutoLogin async task
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Ensure no assertion failure occurred
    expect(tester.takeException(), isNull);
  });
}
