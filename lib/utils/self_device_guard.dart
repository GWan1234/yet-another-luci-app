// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';

class SelfDeviceGuard {
  static Set<String>? _cachedLocalIpsAndMacs;
  static DateTime? _lastCacheTime;

  /// Fetches all active local network IP addresses and MAC addresses of this device.
  static Future<Set<String>> getLocalDeviceAddresses() async {
    final now = DateTime.now();
    if (_cachedLocalIpsAndMacs != null &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!) < const Duration(seconds: 10)) {
      return _cachedLocalIpsAndMacs!;
    }

    final addresses = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final clean = addr.address.toLowerCase().trim();
          if (clean.isNotEmpty) {
            addresses.add(clean);
          }
        }
      }
    } catch (_) {}

    _cachedLocalIpsAndMacs = addresses;
    _lastCacheTime = now;
    return addresses;
  }

  /// Normalizes MAC address string for comparison (e.g., 'AA:BB:CC:DD:EE:FF')
  static String normalizeMac(String mac) {
    return mac.toUpperCase().replaceAll('-', ':').trim();
  }

  /// Checks if target MAC or target IP belongs to the current device running this app.
  static Future<bool> isSelfDevice(String? targetMac, [String? targetIp]) async {
    final addresses = await getLocalDeviceAddresses();

    if (targetIp != null && targetIp.isNotEmpty && targetIp != 'N/A') {
      final cleanIp = targetIp.toLowerCase().trim();
      if (addresses.contains(cleanIp)) return true;
    }

    if (targetMac != null && targetMac.isNotEmpty && targetMac != 'N/A') {
      final normTargetMac = normalizeMac(targetMac);
      for (final addr in addresses) {
        if (normalizeMac(addr) == normTargetMac) return true;
      }
    }

    return false;
  }

  /// Prompts a guardrail confirmation dialog if the target MAC or IP belongs to this device.
  /// Returns `true` if it's safe to proceed (either not self-device, or user explicitly confirmed).
  static Future<bool> checkSelfActionGuardrail(
    BuildContext context, {
    required String actionName,
    String? targetMac,
    String? targetIp,
    String? targetHostname,
  }) async {
    final isSelf = await isSelfDevice(targetMac, targetIp);
    if (!isSelf || !context.mounted) return true;

    final theme = Theme.of(context);
    final displayName = targetHostname ?? targetIp ?? targetMac ?? 'Current Device';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 36),
        ),
        title: const Text(
          'Managing Device Warning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.phonelink_setup_rounded, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target ($displayName) is the phone/device currently running this app!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Performing "$actionName" on your own managing device will sever your router connection and disconnect this app session.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to proceed?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel (Recommended)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade900),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );

    if (context.mounted) {
      if (confirmed != true) {
        LuciToastManager.showGuardrail(
          context,
          'Action Aborted by Guardrail',
          subtitle: 'Modification on active managing device cancelled for safety.',
        );
      } else {
        LuciToastManager.showWarning(
          context,
          'Self-Device Guardrail Bypassed',
          subtitle: 'Proceeding with "$actionName" on managing device.',
        );
      }
    }

    return confirmed == true;
  }
}
