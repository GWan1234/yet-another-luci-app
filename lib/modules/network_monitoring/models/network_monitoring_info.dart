import 'package:luci_mobile/models/interface.dart' as model;

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

  num get totalRxBytes {
    return deviceStats.values.fold(0, (sum, s) => sum + (s['rx_bytes'] ?? 0));
  }

  num get totalTxBytes {
    return deviceStats.values.fold(0, (sum, s) => sum + (s['tx_bytes'] ?? 0));
  }
}
