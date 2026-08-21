// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../models/client.dart';
import '../state/app_state.dart';

/// Global helper for resolving client display names consistently across the application.
/// Enforces strict OpenWrt naming hierarchy:
/// 1. Custom static lease name (configured on router / staticLeaseName) - FIRST PRIORITY
/// 2. Router-assigned Hostname / DNS name - SECOND PRIORITY
/// 3. MAC address fallback
class ClientNamingHelper {
  /// Resolves display name for a MAC address or Client object.
  static String getDisplayName(
    String macAddress, {
    AppState? appState,
    Client? client,
    String? fallbackHostname,
  }) {
    final normMac = normalizeMac(macAddress);

    // 1. Check direct Client object or lookup from AppState
    final targetClient = client ?? appState?.findClientByMac(normMac);
    if (targetClient != null) {
      final name = targetClient.displayName;
      if (name.isNotEmpty && name != 'Unknown' && normalizeMac(name) != normMac) {
        return name;
      }
    }

    // 2. Direct host hint / static lease lookup from AppState dashboard data
    if (appState != null) {
      final hostHints = appState.dashboardData?['hostHints'] as Map<String, dynamic>? ?? {};
      final hint = hostHints[normMac] ?? hostHints[macAddress] ?? hostHints[macAddress.toLowerCase()];
      if (hint is Map) {
        final staticName = hint['staticLeaseName']?.toString() ?? hint['name']?.toString();
        if (staticName != null &&
            staticName.trim().isNotEmpty &&
            staticName != 'Unknown' &&
            staticName != '*' &&
            normalizeMac(staticName) != normMac) {
          return staticName.trim();
        }
        final hostName = hint['hostname']?.toString();
        if (hostName != null &&
            hostName.trim().isNotEmpty &&
            hostName != 'Unknown' &&
            hostName != '*' &&
            normalizeMac(hostName) != normMac) {
          return hostName.trim();
        }
      }
    }

    // 3. Fallback Hostname parameter
    if (fallbackHostname != null &&
        fallbackHostname.trim().isNotEmpty &&
        fallbackHostname != 'Unknown' &&
        fallbackHostname != '*' &&
        normalizeMac(fallbackHostname) != normMac) {
      return fallbackHostname.trim();
    }

    // 4. Fallback to MAC Address
    return normMac.isNotEmpty ? normMac : macAddress;
  }

  /// Resolves an accurate Material Icon based on client metadata (hostname, vendor, device type).
  static IconData getDeviceIcon(Client? client, {String? fallbackName}) {
    if (client == null) {
      final text = (fallbackName ?? '').toLowerCase();
      if (text.contains('tv')) return Icons.tv_rounded;
      if (text.contains('laptop') || text.contains('macbook')) return Icons.laptop_mac_rounded;
      return Icons.phone_android_rounded;
    }
    final nameLower = client.displayName.toLowerCase();
    final vendorLower = (client.vendor ?? '').toLowerCase();
    final dnsLower = (client.dnsName ?? '').toLowerCase();
    final fullSearchText = '$nameLower $vendorLower $dnsLower ${fallbackName ?? ''}';

    // 1. Router / Gateway / AP
    if (fullSearchText.contains('openwrt') ||
        fullSearchText.contains('router') ||
        fullSearchText.contains('repeater') ||
        fullSearchText.contains('gateway') ||
        fullSearchText.contains('mikrotik') ||
        fullSearchText.contains('unifi')) {
      return Icons.router_rounded;
    }

    // 2. Smart Doorbell / Door Lock / Security Camera & CCTV / Sensors
    if (fullSearchText.contains('doorbell') ||
        fullSearchText.contains('videodoorbell') ||
        fullSearchText.contains('chime')) {
      return Icons.doorbell_rounded;
    }

    if (fullSearchText.contains('lock') ||
        fullSearchText.contains('doorlock') ||
        fullSearchText.contains('smartlock') ||
        fullSearchText.contains('yale') ||
        fullSearchText.contains('august') ||
        fullSearchText.contains('schlage') ||
        fullSearchText.contains('nuki')) {
      return Icons.lock_rounded;
    }

    if (fullSearchText.contains('sensor') ||
        fullSearchText.contains('motion') ||
        fullSearchText.contains('contact') ||
        fullSearchText.contains('leak') ||
        fullSearchText.contains('smoke') ||
        fullSearchText.contains('humidity') ||
        fullSearchText.contains('pir') ||
        fullSearchText.contains('presence')) {
      return Icons.sensors_rounded;
    }

    if (fullSearchText.contains('camera') ||
        fullSearchText.contains('cam') ||
        fullSearchText.contains('cctv') ||
        fullSearchText.contains('ring') ||
        fullSearchText.contains('nest') ||
        fullSearchText.contains('reolink') ||
        fullSearchText.contains('wyze') ||
        fullSearchText.contains('imou') ||
        fullSearchText.contains('ezviz') ||
        fullSearchText.contains('hikvision') ||
        fullSearchText.contains('dahua') ||
        fullSearchText.contains('tapo') ||
        fullSearchText.contains('arlo')) {
      return Icons.videocam_rounded;
    }

    // 3. TV / Smart TV / Streaming Box / Set Top Box
    if (fullSearchText.contains('tv') ||
        fullSearchText.contains('settopbox') ||
        fullSearchText.contains('firetv') ||
        fullSearchText.contains('apple tv') ||
        fullSearchText.contains('appletv') ||
        fullSearchText.contains('roku') ||
        fullSearchText.contains('chromecast') ||
        fullSearchText.contains('bravia') ||
        fullSearchText.contains('webos') ||
        fullSearchText.contains('shield') ||
        fullSearchText.contains('tcl') ||
        fullSearchText.contains('hisense') ||
        fullSearchText.contains('vizio') ||
        fullSearchText.contains('actv')) {
      return Icons.tv_rounded;
    }

    // 3. Smart Watches & Wearables
    if (fullSearchText.contains('watch') ||
        fullSearchText.contains('applewatch') ||
        fullSearchText.contains('galaxywatch') ||
        fullSearchText.contains('fitbit') ||
        fullSearchText.contains('garmin') ||
        fullSearchText.contains('amazfit') ||
        fullSearchText.contains('miband') ||
        fullSearchText.contains('wearos') ||
        fullSearchText.contains('wearable') ||
        fullSearchText.contains('band')) {
      return Icons.watch_rounded;
    }

    // 4. Smart Glasses, AR & VR Headsets
    if (fullSearchText.contains('glasses') ||
        fullSearchText.contains('smartglasses') ||
        fullSearchText.contains('rayban') ||
        fullSearchText.contains('oculus') ||
        fullSearchText.contains('metaquest') ||
        fullSearchText.contains('quest') ||
        fullSearchText.contains('visionpro') ||
        fullSearchText.contains('pico') ||
        fullSearchText.contains('htcvive') ||
        fullSearchText.contains('headset') ||
        fullSearchText.contains('hololens') ||
        fullSearchText.contains(' vr') ||
        fullSearchText.contains('-vr') ||
        fullSearchText.contains('vr-') ||
        fullSearchText.contains('vr_')) {
      return Icons.view_in_ar_rounded;
    }

    // 5. Development Boards & Microcontrollers
    if (fullSearchText.contains('esp32') ||
        fullSearchText.contains('esp8266') ||
        fullSearchText.contains('espressif') ||
        fullSearchText.contains('arduino') ||
        fullSearchText.contains('raspberry') ||
        fullSearchText.contains('raspbian') ||
        fullSearchText.contains('pihole') ||
        fullSearchText.contains('orangepi') ||
        fullSearchText.contains('bananapi') ||
        fullSearchText.contains('jetson') ||
        fullSearchText.contains('stm32') ||
        fullSearchText.contains('pico_w') ||
        fullSearchText.contains('devboard') ||
        fullSearchText.contains('nodemcu') ||
        fullSearchText.contains('microcontroller') ||
        fullSearchText.contains('riscv')) {
      return Icons.developer_board_rounded;
    }

    // 6. NAS & Network Servers
    if (fullSearchText.contains('nas') ||
        fullSearchText.contains('synology') ||
        fullSearchText.contains('qnap') ||
        fullSearchText.contains('truenas') ||
        fullSearchText.contains('unraid') ||
        fullSearchText.contains('freenas') ||
        fullSearchText.contains('proxmox') ||
        fullSearchText.contains('server')) {
      return Icons.dns_rounded;
    }

    // 7. Smart Appliances & Home Automation
    if (fullSearchText.contains('vacuum') || fullSearchText.contains('roborock')) {
      return Icons.cleaning_services_rounded;
    }
    if (fullSearchText.contains('thermostat') || fullSearchText.contains('ecobee')) {
      return Icons.thermostat_rounded;
    }
    if (fullSearchText.contains('fridge') || fullSearchText.contains('refrigerator')) {
      return Icons.kitchen_rounded;
    }
    if (fullSearchText.contains('aircon') || fullSearchText.contains('purifier')) {
      return Icons.air_rounded;
    }

    // 8. Laptop / Mac / Notebook
    if (fullSearchText.contains('laptop') ||
        fullSearchText.contains('macbook') ||
        fullSearchText.contains('thinkpad') ||
        fullSearchText.contains('notebook') ||
        fullSearchText.contains('surface')) {
      return Icons.laptop_mac_rounded;
    }

    // 9. Desktop / PC / Workstation
    if (fullSearchText.contains('desktop') ||
        fullSearchText.contains('pc') ||
        fullSearchText.contains('imac') ||
        fullSearchText.contains('macmini') ||
        fullSearchText.contains('macstudio') ||
        fullSearchText.contains('workstation') ||
        fullSearchText.contains('tower')) {
      return Icons.desktop_windows_rounded;
    }

    // 10. Tablet / iPad
    if (fullSearchText.contains('ipad') ||
        fullSearchText.contains('tablet') ||
        fullSearchText.contains('kindle') ||
        fullSearchText.contains('tab')) {
      return Icons.tablet_mac_rounded;
    }

    // 11. Gaming Console
    if (fullSearchText.contains('playstation') ||
        fullSearchText.contains('ps4') ||
        fullSearchText.contains('ps5') ||
        fullSearchText.contains('xbox') ||
        fullSearchText.contains('nintendo') ||
        fullSearchText.contains('switch') ||
        fullSearchText.contains('steamdeck')) {
      return Icons.sports_esports_rounded;
    }

    // 12. Smart Home / Socket / Light / Speaker
    if (fullSearchText.contains('socket') ||
        fullSearchText.contains('plug') ||
        fullSearchText.contains('outlet') ||
        fullSearchText.contains('tuya') ||
        fullSearchText.contains('qubo') ||
        fullSearchText.contains('shelly') ||
        fullSearchText.contains('sonoff')) {
      return Icons.power_rounded;
    }
    if (fullSearchText.contains('bulb') ||
        fullSearchText.contains('light') ||
        fullSearchText.contains('lamp')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (fullSearchText.contains('speaker') ||
        fullSearchText.contains('echo') ||
        fullSearchText.contains('alexa') ||
        fullSearchText.contains('sonos') ||
        fullSearchText.contains('homepod')) {
      return Icons.speaker_rounded;
    }

    // 13. Printer
    if (fullSearchText.contains('printer') ||
        fullSearchText.contains('epson') ||
        fullSearchText.contains('canon') ||
        fullSearchText.contains('brother')) {
      return Icons.print_rounded;
    }

    // 14. Mobile Phone
    if (fullSearchText.contains('mobile') ||
        fullSearchText.contains('phone') ||
        fullSearchText.contains('iphone') ||
        fullSearchText.contains('galaxy') ||
        fullSearchText.contains('pixel') ||
        fullSearchText.contains('redmi') ||
        fullSearchText.contains('realme') ||
        fullSearchText.contains('oneplus') ||
        fullSearchText.contains('oppo') ||
        fullSearchText.contains('vivo')) {
      return Icons.phone_android_rounded;
    }

    // Fallback
    if (client.connectionType == ConnectionType.wireless) {
      return Icons.phone_android_rounded;
    } else {
      return Icons.devices_rounded;
    }
  }

  /// Normalizes MAC address string (e.g. AA:BB:CC:DD:EE:FF).
  static String normalizeMac(String mac) {
    if (mac.isEmpty) return mac;
    return mac
        .toUpperCase()
        .replaceAll('-', ':')
        .split(':')
        .map((b) => b.length == 1 ? '0$b' : b)
        .join(':');
  }
}

