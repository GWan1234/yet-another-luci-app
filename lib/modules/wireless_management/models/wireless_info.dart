// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// PMF (Protected Management Frames / IEEE 802.11w) state.
enum PmfState {
  disabled, // 0
  optional, // 1
  required; // 2

  String get displayName {
    switch (this) {
      case PmfState.disabled:
        return 'PMF Disabled';
      case PmfState.optional:
        return 'PMF Optional';
      case PmfState.required:
        return 'PMF Required';
    }
  }

  static PmfState parse(dynamic rawVal) {
    if (rawVal == null) return PmfState.disabled;
    final str = rawVal.toString().trim();
    if (str == '2' || str.toLowerCase() == 'required') return PmfState.required;
    if (str == '1' || str.toLowerCase() == 'optional') return PmfState.optional;
    return PmfState.disabled;
  }
}

/// Structured Wi-Fi Security Mode classification.
enum WifiSecurityMode {
  saeOnly,   // WPA3-SAE Only (PMF mandatory)
  saeMixed,  // WPA2/WPA3 Transitional Mode
  wpa2Psk,   // WPA2-PSK
  wpaPsk,    // WPA-PSK (Legacy)
  wep,       // WEP (Legacy)
  open,      // Open (No encryption)
  enterprise,// WPA-Enterprise / EAP
  unknown;   // Fallback for unclassified encryption

  String get displayName {
    switch (this) {
      case WifiSecurityMode.saeOnly:
        return 'WPA3-SAE (SAE-Only)';
      case WifiSecurityMode.saeMixed:
        return 'WPA2/WPA3 Mixed';
      case WifiSecurityMode.wpa2Psk:
        return 'WPA2-PSK';
      case WifiSecurityMode.wpaPsk:
        return 'WPA-PSK';
      case WifiSecurityMode.wep:
        return 'WEP';
      case WifiSecurityMode.open:
        return 'Open (None)';
      case WifiSecurityMode.enterprise:
        return 'WPA-Enterprise';
      case WifiSecurityMode.unknown:
        return 'Custom/Unknown';
    }
  }

  String get shortBadgeLabel {
    switch (this) {
      case WifiSecurityMode.saeOnly:
        return 'WPA3-SAE';
      case WifiSecurityMode.saeMixed:
        return 'WPA2/WPA3';
      case WifiSecurityMode.wpa2Psk:
        return 'WPA2-PSK';
      case WifiSecurityMode.wpaPsk:
        return 'WPA-PSK';
      case WifiSecurityMode.wep:
        return 'WEP';
      case WifiSecurityMode.open:
        return 'OPEN';
      case WifiSecurityMode.enterprise:
        return 'WPA-EAP';
      case WifiSecurityMode.unknown:
        return 'UNKNOWN';
    }
  }

  Color get badgeColor {
    switch (this) {
      case WifiSecurityMode.saeOnly:
        return Colors.deepPurple;
      case WifiSecurityMode.saeMixed:
        return Colors.indigo;
      case WifiSecurityMode.wpa2Psk:
        return Colors.green;
      case WifiSecurityMode.wpaPsk:
        return Colors.orange;
      case WifiSecurityMode.wep:
        return Colors.red;
      case WifiSecurityMode.open:
        return Colors.amber.shade800;
      case WifiSecurityMode.enterprise:
        return Colors.teal;
      case WifiSecurityMode.unknown:
        return Colors.grey;
    }
  }

  static WifiSecurityMode parse({
    Map<String, dynamic>? iwinfoEnc,
    String? rawConfigEnc,
  }) {
    final configEnc = (rawConfigEnc ?? '').toLowerCase().trim();
    final description = (iwinfoEnc?['description']?.toString() ?? '').toUpperCase();
    final enabled = iwinfoEnc?['enabled'] as bool? ?? true;

    final authSuitesRaw = iwinfoEnc?['auth_suites'];
    final authSuites = <String>[];
    if (authSuitesRaw is List) {
      authSuites.addAll(authSuitesRaw.map((e) => e.toString().toUpperCase()));
    }

    if (configEnc == 'none' || (!enabled && description.isEmpty && configEnc.isEmpty)) {
      return WifiSecurityMode.open;
    }

    final hasSaeSuite = authSuites.contains('SAE') || description.contains('SAE') || configEnc.contains('sae');
    final hasPsk2Suite = authSuites.contains('PSK') || description.contains('WPA2') || configEnc.contains('psk2');
    final hasPsk1Suite = configEnc == 'psk' || (description.contains('WPA') && !description.contains('WPA2'));

    // 1. SAE Only vs SAE Mixed
    if (hasSaeSuite) {
      if (configEnc == 'sae' || (!hasPsk2Suite && !description.contains('WPA2') && !description.contains('PSK'))) {
        return WifiSecurityMode.saeOnly;
      }
      return WifiSecurityMode.saeMixed;
    }

    // 2. WPA Enterprise
    if (description.contains('802.1X') || description.contains('EAP') || (configEnc.startsWith('wpa') && !configEnc.contains('psk'))) {
      return WifiSecurityMode.enterprise;
    }

    // 3. WPA2-PSK
    if (hasPsk2Suite) {
      return WifiSecurityMode.wpa2Psk;
    }

    // 4. WPA-PSK Legacy
    if (hasPsk1Suite || configEnc.contains('psk')) {
      return WifiSecurityMode.wpaPsk;
    }

    // 5. WEP
    if (configEnc.contains('wep') || description.contains('WEP') || (iwinfoEnc?['wep'] == true)) {
      return WifiSecurityMode.wep;
    }

    if (description.isNotEmpty) {
      return WifiSecurityMode.unknown;
    }

    return WifiSecurityMode.wpa2Psk;
  }
}

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
    final rx = json['rx_rate'] as num? ??
        json['rx_bitrate'] as num? ??
        (json['rx'] is Map ? (json['rx']['rate'] as num? ?? json['rx']['bitrate'] as num?) : null);
    final tx = json['tx_rate'] as num? ??
        json['tx_bitrate'] as num? ??
        (json['tx'] is Map ? (json['tx']['rate'] as num? ?? json['tx']['bitrate'] as num?) : null);
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
  final String sectionName;
  final String ssid;
  final String mode; // AP, Client, Mesh, Ad-Hoc
  final String encryption;
  final WifiSecurityMode securityMode;
  final PmfState pmfState;
  final String channel;
  final bool isEnabled;
  final List<WirelessStation> stations;

  const WirelessInterface({
    required this.ifName,
    required this.sectionName,
    required this.ssid,
    required this.mode,
    required this.encryption,
    required this.securityMode,
    required this.pmfState,
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

    final iwEncMap = iwinfo['encryption'] is Map<String, dynamic>
        ? iwinfo['encryption'] as Map<String, dynamic>
        : null;
    final rawConfigEnc = config['encryption']?.toString();

    final secMode = WifiSecurityMode.parse(
      iwinfoEnc: iwEncMap,
      rawConfigEnc: rawConfigEnc,
    );

    final rawPmf = config['ieee80211w'] ?? iwinfo['ieee80211w'];
    final pmf = PmfState.parse(rawPmf);

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

    final sectionStr = json['section']?.toString() ??
        json['.name']?.toString() ??
        config['.name']?.toString() ??
        json['ifname']?.toString() ??
        config['ifname']?.toString() ??
        name;

    return WirelessInterface(
      ifName: name,
      sectionName: sectionStr,
      ssid: ssidStr,
      mode: modeStr,
      encryption: encStr,
      securityMode: secMode,
      pmfState: pmf,
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
  final int? frequency; // frequency in MHz
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
    final ch = (json['channel'] ?? json['config']?['channel'] ?? 'Auto').toString();
    int? freq = (json['frequency'] as num?)?.toInt();
    if (freq == null && json['config'] != null) {
      freq = (json['config']['frequency'] as num?)?.toInt();
    }
    final txp = (json['txpower'] as num?)?.toInt();
    final ctry = json['country']?.toString() ?? json['config']?['country']?.toString() ?? 'Global';

    final ifaceList = <WirelessInterface>[];
    final ifacesRaw = json['interfaces'];

    if (ifacesRaw is List) {
      for (final item in ifacesRaw) {
        if (item is Map<String, dynamic>) {
          ifaceList.add(WirelessInterface.fromJson(item, assocData));
          if ((freq == null || freq == 0) && item['iwinfo'] != null) {
            final iwFreq = (item['iwinfo']['frequency'] as num?)?.toInt();
            if (iwFreq != null && iwFreq > 0) freq = iwFreq;
          }
        }
      }
    } else if (ifacesRaw is Map) {
      ifacesRaw.forEach((_, item) {
        if (item is Map<String, dynamic>) {
          ifaceList.add(WirelessInterface.fromJson(item, assocData));
          if ((freq == null || freq == 0) && item['iwinfo'] != null) {
            final iwFreq = (item['iwinfo']['frequency'] as num?)?.toInt();
            if (iwFreq != null && iwFreq > 0) freq = iwFreq;
          }
        }
      });
    }

    return WirelessRadio(
      name: radioName,
      isUp: up,
      channel: ch,
      frequency: (freq != null && freq! > 0) ? freq : null,
      txPowerDbm: txp,
      country: ctry,
      interfaces: ifaceList,
    );
  }

  /// Formatted frequency display string (e.g. "2.437 GHz").
  /// Returns null if frequency data is absent/unreported on older radios/firmware.
  String? get formattedFrequency {
    if (frequency != null && frequency! > 0) {
      final ghz = frequency! / 1000.0;
      return '${ghz.toStringAsFixed(3)} GHz';
    }
    return null;
  }

  String get bandLabel {
    if (frequency != null && frequency! > 0) {
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
              sectionName: 'wifinet0',
              ssid: 'OpenWrt-2.4G',
              mode: 'AP',
              encryption: 'WPA2-PSK (CCMP)',
              securityMode: WifiSecurityMode.wpa2Psk,
              pmfState: PmfState.disabled,
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
              sectionName: 'wifinet1',
              ssid: 'OpenWrt-5G',
              mode: 'AP',
              encryption: 'WPA3-SAE (Mandatory PMF)',
              securityMode: WifiSecurityMode.saeOnly,
              pmfState: PmfState.required,
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
