// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:yet_another_luci_app/models/interface.dart' as model;

/// Aggregates network monitoring details: Interfaces list, RX/TX tabular metrics, IPv4/IPv6, and Gateway status.
class NetworkMonitoringInfo {
  final List<model.NetworkInterface> interfaces;
  final Map<String, Map<String, num>> deviceStats;

  const NetworkMonitoringInfo({
    required this.interfaces,
    required this.deviceStats,
  });

  factory NetworkMonitoringInfo.fromDashboardData(Map<String, dynamic>? data) {
    final list = <model.NetworkInterface>[];
    final statsMap = <String, Map<String, num>>{};

    if (data != null) {
      // Parse interface dump
      final interfaceDump = data['interfaceDump'] as Map<String, dynamic>?;
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        for (final item in interfaceDump['interface']) {
          if (item is Map<String, dynamic>) {
            list.add(model.NetworkInterface.fromJson(item));
          }
        }
      }

      // Parse device statistics (networkDevices or network.device)
      final devices = data['networkDevices'] as Map<String, dynamic>?;
      if (devices != null) {
        devices.forEach((devName, devData) {
          if (devData is Map<String, dynamic> && devData['stats'] is Map) {
            final rawStats = devData['stats'] as Map;
            statsMap[devName] = {
              'rx_bytes': (rawStats['rx_bytes'] as num?) ?? 0,
              'tx_bytes': (rawStats['tx_bytes'] as num?) ?? 0,
              'rx_packets': (rawStats['rx_packets'] as num?) ?? 0,
              'tx_packets': (rawStats['tx_packets'] as num?) ?? 0,
              'rx_errors': (rawStats['rx_errors'] as num?) ?? 0,
              'tx_errors': (rawStats['tx_errors'] as num?) ?? 0,
            };
          }
        });
      }
    }

    return NetworkMonitoringInfo(
      interfaces: list,
      deviceStats: statsMap,
    );
  }

  int get upCount => interfaces.where((i) => i.isUp).length;
  int get downCount => interfaces.where((i) => !i.isUp).length;

  model.NetworkInterface? get defaultGatewayInterface {
    try {
      return interfaces.firstWhere((i) => i.gateway != null && i.gateway!.isNotEmpty);
    } catch (_) {
      return null;
    }
  }

  String? get publicIpv4 {
    final gw = defaultGatewayInterface;
    if (gw?.ipAddress != null && gw!.ipAddress!.trim().isNotEmpty) {
      return gw.ipAddress;
    }
    for (final iface in interfaces) {
      if (iface.name.toLowerCase().startsWith('wan') && iface.ipAddress != null && iface.ipAddress!.trim().isNotEmpty) {
        return iface.ipAddress;
      }
    }
    return null;
  }

  String? get publicIpv6 {
    // 1. Check default gateway interface first for global IPv6
    final gw = defaultGatewayInterface;
    if (gw?.ipv6Addresses != null) {
      final globalV6 = gw!.ipv6Addresses!.firstWhere(
        (addr) => _isGlobalIpv6(addr),
        orElse: () => '',
      );
      if (globalV6.isNotEmpty) return globalV6;
    }

    // 2. Check wan6 / WAN-related interfaces
    for (final iface in interfaces) {
      if (iface.name.toLowerCase().contains('wan') && iface.ipv6Addresses != null) {
        final globalV6 = iface.ipv6Addresses!.firstWhere(
          (addr) => _isGlobalIpv6(addr),
          orElse: () => '',
        );
        if (globalV6.isNotEmpty) return globalV6;
      }
    }

    // 3. Fallback: Check any interface for a global IPv6 address
    for (final iface in interfaces) {
      if (iface.ipv6Addresses != null) {
        final globalV6 = iface.ipv6Addresses!.firstWhere(
          (addr) => _isGlobalIpv6(addr),
          orElse: () => '',
        );
        if (globalV6.isNotEmpty) return globalV6;
      }
    }

    return null;
  }

  static bool _isGlobalIpv6(String addr) {
    final clean = addr.toLowerCase().trim();
    return !clean.startsWith('fe80') && !clean.startsWith('fd') && !clean.startsWith('fc') && clean.contains(':');
  }

  num get totalRxBytes {
    return deviceStats.values.fold(0, (sum, s) => sum + (s['rx_bytes'] ?? 0));
  }

  num get totalTxBytes {
    return deviceStats.values.fold(0, (sum, s) => sum + (s['tx_bytes'] ?? 0));
  }
}
