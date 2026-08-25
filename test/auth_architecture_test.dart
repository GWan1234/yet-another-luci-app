// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yet_another_luci_app/services/interfaces/api_service_interface.dart';
import 'package:yet_another_luci_app/services/mock_api_service.dart';
import 'package:yet_another_luci_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Unified Auth Architecture Tests', () {
    test('AuthResult factory constructors set correct properties', () {
      final successResult = AuthResult.success(
        'test_token_123',
        actualUseHttps: true,
      );
      expect(successResult.status, AuthStatus.success);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.token, 'test_token_123');
      expect(successResult.actualUseHttps, isTrue);

      final invalidResult = AuthResult.invalidCredentials();
      expect(invalidResult.status, AuthStatus.invalidCredentials);
      expect(invalidResult.isSuccess, isFalse);
      expect(
        invalidResult.errorMessage,
        contains('Invalid username or password'),
      );

      final unreachableResult = AuthResult.unreachable();
      expect(unreachableResult.status, AuthStatus.unreachable);
      expect(unreachableResult.isSuccess, isFalse);

      final unknownResult = AuthResult.unknownError('Network error');
      expect(unknownResult.status, AuthStatus.unknownError);
      expect(unknownResult.isSuccess, isFalse);
      expect(unknownResult.errorMessage, 'Network error');
    });

    test(
      'RealAuthService delegates to IApiService.authenticate cleanly',
      () async {
        final mockApi = MockApiService();
        final authService = RealAuthService(mockApi);

        expect(authService.isAuthenticated, isFalse);

        await authService.login('192.168.1.1', 'root', 'password', false);

        expect(authService.isAuthenticated, isTrue);
        expect(authService.sysauth, 'mock_sysauth_token_12345');
        expect(authService.ipAddress, '192.168.1.1');
        expect(authService.useHttps, isFalse);
      },
    );

    test('RealAuthService tryAutoLogin delegates to login flow', () async {
      final mockApi = MockApiService();
      final authService = RealAuthService(mockApi);

      final success = await authService.tryAutoLogin(
        '192.168.1.1',
        'root',
        'password',
        false,
      );

      expect(success, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.sysauth, 'mock_sysauth_token_12345');
    });
  });
}
