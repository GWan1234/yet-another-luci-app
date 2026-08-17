// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

/// Represents an active DHCP lease.
class DhcpLease {
  final String hostname;
  final String ipAddress;
  final String macAddress;
  final int expirySeconds;

  const DhcpLease({
    required this.hostname,
    required this.ipAddress,
    required this.macAddress,
    required this.expirySeconds,
  });

  factory DhcpLease.fromJson(Map<String, dynamic> json) {
    int parseSec(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final expRaw = json['expires'];
    final ltRaw = json['leasetime'];
    final expiry = expRaw != null && expRaw is! bool
        ? parseSec(expRaw)
        : (ltRaw != null && ltRaw is! bool ? parseSec(ltRaw) : 0);

    return DhcpLease(
      hostname: json['hostname']?.toString() ?? json['name']?.toString() ?? 'Anonymous Device',
      ipAddress: json['ipaddr']?.toString() ?? json['ip']?.toString() ?? 'N/A',
      macAddress: (json['macaddr']?.toString() ?? json['mac']?.toString() ?? 'N/A').toUpperCase(),
      expirySeconds: expiry,
    );
  }

  String get formattedExpiry {
    if (expirySeconds <= 0) return 'Unlimited';
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = expirySeconds > nowSeconds ? expirySeconds - nowSeconds : expirySeconds;
    if (remaining <= 0) return 'Unlimited';
    final duration = Duration(seconds: remaining);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m remaining';
    return '${minutes}m remaining';
  }
}

/// Represents a static IP DHCP reservation mapping.
class DhcpStaticMapping {
  final String hostname;
  final String ipAddress;
  final String macAddress;

  const DhcpStaticMapping({
    required this.hostname,
    required this.ipAddress,
    required this.macAddress,
  });

  factory DhcpStaticMapping.fromJson(Map<String, dynamic> json) {
    String macStr = 'N/A';
    final macVal = json['mac'] ?? json['macaddr'];
    if (macVal is List) {
      macStr = macVal.join(', ');
    } else if (macVal != null && macVal.toString().isNotEmpty) {
      macStr = macVal.toString();
    }

    return DhcpStaticMapping(
      hostname: json['name']?.toString() ?? json['hostname']?.toString() ?? 'Unnamed Host',
      ipAddress: json['ip']?.toString() ?? json['ipaddr']?.toString() ?? 'N/A',
      macAddress: macStr.toUpperCase(),
    );
  }
}

/// Dnsmasq and upstream DNS forwarders configuration.
class DnsmasqConfig {
  final String localDomain;
  final List<String> upstreamDnsServers;
  final bool rebindProtection;
  final bool domainNeeded;
  final bool authoritative;

  const DnsmasqConfig({
    required this.localDomain,
    required this.upstreamDnsServers,
    required this.rebindProtection,
    required this.domainNeeded,
    required this.authoritative,
  });

  factory DnsmasqConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DnsmasqConfig(
        localDomain: 'lan',
        upstreamDnsServers: ['ISP Default (Dynamic DNS)'],
        rebindProtection: true,
        domainNeeded: true,
        authoritative: true,
      );
    }

    final servers = <String>[];
    final serverVal = json['server'];
    if (serverVal is List) {
      servers.addAll(serverVal.map((e) => e.toString()));
    } else if (serverVal is String) {
      servers.add(serverVal);
    }
    return DnsmasqConfig(
      localDomain: json['domain']?.toString() ?? 'lan',
      upstreamDnsServers: servers.isNotEmpty ? servers : const ['ISP Default (Dynamic DNS)'],
      rebindProtection: json['rebind_protection'] == '1' || json['rebind_protection'] == true,
      domainNeeded: json['domainneeded'] == '1' || json['domainneeded'] == true,
      authoritative: json['authoritative'] == '1' || json['authoritative'] == true,
    );
  }
}

/// Complete overview container for DHCP & DNS monitoring.
class DhcpDnsOverview {
  final DnsmasqConfig dnsConfig;
  final List<DhcpLease> activeLeases;
  final List<DhcpStaticMapping> staticMappings;

  const DhcpDnsOverview({
    required this.dnsConfig,
    required this.activeLeases,
    required this.staticMappings,
  });

  factory DhcpDnsOverview.fromDashboardData(Map<String, dynamic>? data, {bool isReviewerMode = false}) {
    final leaseList = <DhcpLease>[];
    final staticList = <DhcpStaticMapping>[];
    Map<String, dynamic>? dnsmasqRaw;

    if (data != null) {
      // Parse DHCP leases from RPC dashboard data
      final rawLeases = data['dhcpLeases'];

      void addLeasesFromList(List<dynamic> list) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            leaseList.add(DhcpLease.fromJson(item));
          }
        }
      }

      if (rawLeases is List) {
        addLeasesFromList(rawLeases);
      } else if (rawLeases is Map) {
        rawLeases.forEach((key, val) {
          if (val is List) {
            addLeasesFromList(val);
          } else if (val is Map<String, dynamic>) {
            leaseList.add(DhcpLease.fromJson(val));
          }
        });
      }

      // Parse UCI DHCP config for dnsmasq and static host mappings
      final rawUciDhcp = data['uciDhcpConfig'];
      Map<String, dynamic>? uciDhcp;
      if (rawUciDhcp is Map<String, dynamic>) {
        uciDhcp = rawUciDhcp;
      } else if (rawUciDhcp is Map) {
        uciDhcp = rawUciDhcp.cast<String, dynamic>();
      }

      if (uciDhcp != null) {
        final rawValues = uciDhcp['values'] ?? uciDhcp;
        if (rawValues is Map) {
          rawValues.forEach((key, val) {
            if (val is Map) {
              final valMap = Map<String, dynamic>.from(val);
              final type = valMap['.type']?.toString();
              if (type == 'dnsmasq') {
                dnsmasqRaw = valMap;
              } else if (type == 'host') {
                staticList.add(DhcpStaticMapping.fromJson(valMap));
              }
            }
          });
        } else if (rawValues is List) {
          for (final val in rawValues) {
            if (val is Map) {
              final valMap = Map<String, dynamic>.from(val);
              final type = valMap['.type']?.toString();
              if (type == 'dnsmasq') {
                dnsmasqRaw = valMap;
              } else if (type == 'host') {
                staticList.add(DhcpStaticMapping.fromJson(valMap));
              }
            }
          }
        }
      }
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode) {
      if (leaseList.isEmpty) {
        leaseList.addAll([
          const DhcpLease(hostname: 'Android-Phone', ipAddress: '192.168.1.105', macAddress: 'DC:F5:05:12:34:56', expirySeconds: 38400),
          const DhcpLease(hostname: 'Linux-Workstation', ipAddress: '192.168.1.110', macAddress: '48:21:0B:78:90:AB', expirySeconds: 41200),
          const DhcpLease(hostname: 'Smart-TV', ipAddress: '192.168.1.115', macAddress: '70:B3:D5:CD:EF:01', expirySeconds: 21600),
        ]);
      }
      if (staticList.isEmpty) {
        staticList.addAll([
          const DhcpStaticMapping(hostname: 'Home-NAS', ipAddress: '192.168.1.200', macAddress: '00:11:22:33:44:55'),
          const DhcpStaticMapping(hostname: 'Printer-Office', ipAddress: '192.168.1.201', macAddress: '66:77:88:99:AA:BB'),
        ]);
      }
    }

    return DhcpDnsOverview(
      dnsConfig: DnsmasqConfig.fromJson(dnsmasqRaw),
      activeLeases: leaseList,
      staticMappings: staticList,
    );
  }
}
