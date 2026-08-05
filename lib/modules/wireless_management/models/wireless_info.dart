/// Represents a connected wireless station (client device).
class WirelessStation {
  final String macAddress;
  final int? signalDbm;
  final int? noiseDbm;
  final num? rxRate;
  final num? txRate;
  final int? inactiveSeconds;

  const WirelessStation({
    required this.macAddress,
    this.signalDbm,
    this.noiseDbm,
    this.rxRate,
    this.txRate,
    this.inactiveSeconds,
  });

  factory WirelessStation.fromJson(String mac, Map<String, dynamic> json) {
    final rx = json['rx_rate'] as num? ?? (json['rx'] is Map ? (json['rx']['rate'] as num?) : null);
    final tx = json['tx_rate'] as num? ?? (json['tx'] is Map ? (json['tx']['rate'] as num?) : null);
    return WirelessStation(
      macAddress: mac,
      signalDbm: (json['signal'] as num?)?.toInt() ?? (json['signal_dbm'] as num?)?.toInt(),
      noiseDbm: (json['noise'] as num?)?.toInt() ?? (json['noise_dbm'] as num?)?.toInt(),
      rxRate: rx,
      txRate: tx,
      inactiveSeconds: (json['inactive'] as num?)?.toInt(),
    );
  }

  String get formattedSignal => signalDbm != null ? '$signalDbm dBm' : 'N/A';

  String get signalQualityLabel {
    if (signalDbm == null) return 'Unknown';
    if (signalDbm! >= -50) return 'Excellent';
    if (signalDbm! >= -65) return 'Good';
    if (signalDbm! >= -75) return 'Fair';
    return 'Weak';
  }
}

/// Represents a single Wi-Fi SSID / virtual interface on a radio.
class WirelessInterface {
  final String ifName;
  final String ssid;
  final String mode; // AP, Client, Mesh, Ad-Hoc
  final String encryption;
  final String channel;
  final bool isEnabled;
  final List<WirelessStation> stations;

  const WirelessInterface({
    required this.ifName,
    required this.ssid,
    required this.mode,
    required this.encryption,
    required this.channel,
    required this.isEnabled,
    required this.stations,
  });

  factory WirelessInterface.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? assocData,
  ) {
    final config = json['config'] as Map<String, dynamic>? ?? {};
    final iwinfo = json['iwinfo'] as Map<String, dynamic>? ?? {};

    final name = json['ifname']?.toString() ?? config['ifname']?.toString() ?? 'wlan';
    final ssidStr = iwinfo['ssid']?.toString() ?? config['ssid']?.toString() ?? 'Unnamed';
    final modeStr = (iwinfo['mode']?.toString() ?? config['mode']?.toString() ?? 'ap').toUpperCase();
    final encStr = iwinfo['encryption']?['description']?.toString() ??
        config['encryption']?.toString() ??
        'WPA2-PSK';
    final chStr = (iwinfo['channel'] ?? config['channel'] ?? 'Auto').toString();
    final enabled = !(config['disabled'] as bool? ?? false);

    final stationList = <WirelessStation>[];
    if (assocData != null) {
      final candidates = [
        name,
        json['ifname']?.toString(),
        config['ifname']?.toString(),
        json['section']?.toString(),
        config['.name']?.toString(),
        ssidStr,
      ].whereType<String>().toSet();

      dynamic rawStations;
      for (final cand in candidates) {
        if (assocData.containsKey(cand) && assocData[cand] != null) {
          rawStations = assocData[cand];
          break;
        }
      }

      if (rawStations is Map<String, dynamic>) {
        final stationMapOrList = rawStations['results'] ?? rawStations['assoclist'] ?? rawStations;
        if (stationMapOrList is List) {
          for (final item in stationMapOrList) {
            if (item is Map<String, dynamic>) {
              final mac = item['mac']?.toString() ?? item['macaddr']?.toString() ?? 'Unknown';
              stationList.add(WirelessStation.fromJson(mac, item));
            }
          }
        } else if (stationMapOrList is Map<String, dynamic>) {
          stationMapOrList.forEach((mac, val) {
            if (val is Map<String, dynamic>) {
              stationList.add(WirelessStation.fromJson(mac, val));
            }
          });
        }
      } else if (rawStations is List) {
        for (final item in rawStations) {
          if (item is Map<String, dynamic>) {
            final mac = item['mac']?.toString() ?? item['macaddr']?.toString() ?? 'Unknown';
            stationList.add(WirelessStation.fromJson(mac, item));
          }
        }
      }
    }

    return WirelessInterface(
      ifName: name,
      ssid: ssidStr,
      mode: modeStr,
      encryption: encStr,
      channel: chStr,
      isEnabled: enabled,
      stations: stationList,
    );
  }
}

/// Represents a physical wireless radio (radio0, radio1).
class WirelessRadio {
  final String name;
  final bool isUp;
  final String channel;
  final int? frequency;
  final int? txPowerDbm;
  final String country;
  final List<WirelessInterface> interfaces;

  const WirelessRadio({
    required this.name,
    required this.isUp,
    required this.channel,
    this.frequency,
    this.txPowerDbm,
    required this.country,
    required this.interfaces,
  });

  factory WirelessRadio.fromJson(
    String radioName,
    Map<String, dynamic> json,
    Map<String, dynamic>? assocData,
  ) {
    final up = json['up'] as bool? ?? true;
    final ch = (json['channel'] ?? 'Auto').toString();
    final freq = (json['frequency'] as num?)?.toInt();
    final txp = (json['txpower'] as num?)?.toInt();
    final ctry = json['country']?.toString() ?? 'Global';

    final ifaceList = <WirelessInterface>[];
    final ifacesRaw = json['interfaces'];

    if (ifacesRaw is List) {
      for (final item in ifacesRaw) {
        if (item is Map<String, dynamic>) {
          ifaceList.add(WirelessInterface.fromJson(item, assocData));
        }
      }
    } else if (ifacesRaw is Map) {
      ifacesRaw.forEach((_, item) {
        if (item is Map<String, dynamic>) {
          ifaceList.add(WirelessInterface.fromJson(item, assocData));
        }
      });
    }

    return WirelessRadio(
      name: radioName,
      isUp: up,
      channel: ch,
      frequency: freq,
      txPowerDbm: txp,
      country: ctry,
      interfaces: ifaceList,
    );
  }

  String get bandLabel {
    if (frequency != null) {
      if (frequency! >= 5925) return '6 GHz';
      if (frequency! >= 4900) return '5 GHz';
      if (frequency! >= 2400) return '2.4 GHz';
      if (frequency! >= 900) return '900 MHz';
    }
    final chNum = int.tryParse(channel) ?? 0;
    if (chNum > 14) return '5 GHz';
    if (chNum > 0 && chNum <= 14) return '2.4 GHz';
    for (final ifc in interfaces) {
      final ifcCh = int.tryParse(ifc.channel) ?? 0;
      if (ifcCh > 14) return '5 GHz';
      if (ifcCh > 0 && ifcCh <= 14) return '2.4 GHz';
    }
    return 'Wi-Fi';
  }
}

/// Overview container for all wireless radios and stations.
class WirelessOverview {
  final List<WirelessRadio> radios;

  const WirelessOverview({required this.radios});

  factory WirelessOverview.fromDashboardData(Map<String, dynamic>? data, {bool isReviewerMode = false}) {
    final radioList = <WirelessRadio>[];
    Map<String, dynamic>? assocData;

    if (data != null) {
      assocData = data['wirelessStations'] as Map<String, dynamic>?;

      final wirelessMap = (data['wireless'] ?? data['wirelessInterfaces'] ?? data['uciWirelessConfig']) as Map<String, dynamic>?;
      if (wirelessMap != null) {
        wirelessMap.forEach((radioName, radioData) {
          if (radioData is Map<String, dynamic>) {
            radioList.add(WirelessRadio.fromJson(radioName, radioData, assocData));
          }
        });
      }
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode && radioList.isEmpty) {
      radioList.addAll([
        WirelessRadio(
          name: 'radio0',
          isUp: true,
          channel: '6',
          frequency: 2437,
          txPowerDbm: 20,
          country: 'US',
          interfaces: [
            const WirelessInterface(
              ifName: 'wlan0',
              ssid: 'OpenWrt-2.4G',
              mode: 'AP',
              encryption: 'WPA2-PSK (CCMP)',
              channel: '6',
              isEnabled: true,
              stations: [
                WirelessStation(macAddress: 'AA:BB:CC:11:22:33', signalDbm: -48, noiseDbm: -95, rxRate: 144, txRate: 72),
                WirelessStation(macAddress: 'AA:BB:CC:44:55:66', signalDbm: -62, noiseDbm: -92, rxRate: 108, txRate: 54),
              ],
            ),
          ],
        ),
        WirelessRadio(
          name: 'radio1',
          isUp: true,
          channel: '36',
          frequency: 5180,
          txPowerDbm: 23,
          country: 'US',
          interfaces: [
            const WirelessInterface(
              ifName: 'wlan1',
              ssid: 'OpenWrt-5G',
              mode: 'AP',
              encryption: 'WPA3-SAE / WPA2-PSK',
              channel: '36',
              isEnabled: true,
              stations: [
                WirelessStation(macAddress: 'AA:BB:CC:77:88:99', signalDbm: -38, noiseDbm: -98, rxRate: 433, txRate: 433),
              ],
            ),
          ],
        ),
      ]);
    }

    return WirelessOverview(radios: radioList);
  }

  int get totalConnectedStations {
    int count = 0;
    for (final radio in radios) {
      for (final iface in radio.interfaces) {
        count += iface.stations.length;
      }
    }
    return count;
  }
}
