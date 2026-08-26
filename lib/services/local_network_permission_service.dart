// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for checking and requesting Android 15+ (API 35+ / Target API 37) Local Network Permission.
class LocalNetworkPermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.nightcode.luci/local_network_permission');

  /// Checks whether local network permission (`ACCESS_LOCAL_NETWORK`) is granted.
  /// Returns `true` on non-Android platforms or Android < 15.
  static Future<bool> isGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('checkLocalNetworkPermission');
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('Error checking local network permission: $e');
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Requests local network permission (`ACCESS_LOCAL_NETWORK`) from the user at runtime.
  /// Returns `true` if granted, or `true` on non-Android platforms / Android < 15.
  static Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestLocalNetworkPermission');
      return granted ?? true;
    } on PlatformException catch (e) {
      debugPrint('Error requesting local network permission: $e');
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Helper to check and request permission if not already granted.
  static Future<bool> ensurePermissionGranted() async {
    final granted = await isGranted();
    if (!granted) {
      return await requestPermission();
    }
    return true;
  }
}
