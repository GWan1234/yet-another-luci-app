/// WireGuard Peer details.
class WireguardPeer {
  final String publicKey;
  final String? endpoint;
  final List<String> allowedIps;
  final num rxBytes;
  final num txBytes;
  final int? latestHandshakeTimestamp;

  const WireguardPeer({
    required this.publicKey,
    this.endpoint,
    required this.allowedIps,
    required this.rxBytes,
    required this.txBytes,
    this.latestHandshakeTimestamp,
  });

  factory WireguardPeer.fromJson(Map<String, dynamic> json) {
    final ips = <String>[];
    final allowed = json['allowed_ips'];
    if (allowed is List) {
      ips.addAll(allowed.map((e) => e.toString()));
    } else if (allowed is String) {
      ips.add(allowed);
    }

    return WireguardPeer(
      publicKey: json['public_key']?.toString() ?? 'Unknown Key',
      endpoint: json['endpoint']?.toString(),
      allowedIps: ips,
      rxBytes: (json['rx_bytes'] as num?) ?? 0,
      txBytes: (json['tx_bytes'] as num?) ?? 0,
      latestHandshakeTimestamp: (json['latest_handshake'] as num?)?.toInt(),
    );
  }

  String get formattedHandshake {
    if (latestHandshakeTimestamp == null || latestHandshakeTimestamp == 0) {
      return 'No handshake yet';
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - latestHandshakeTimestamp!;
    if (diff < 60) return '$diff seconds ago';
    if (diff < 3600) return '${diff ~/ 60}m ${diff % 60}s ago';
    return '${diff ~/ 3600}h ago';
  }
}

/// WireGuard Interface definition.
class WireguardInterface {
  final String name;
  final String publicKey;
  final int listenPort;
  final bool isUp;
  final List<WireguardPeer> peers;

  const WireguardInterface({
    required this.name,
    required this.publicKey,
    required this.listenPort,
    required this.isUp,
    required this.peers,
  });

  factory WireguardInterface.fromJson(String name, Map<String, dynamic> json) {
    final peerList = <WireguardPeer>[];
    final rawPeers = json['peers'];
    if (rawPeers is List) {
      for (final p in rawPeers) {
        if (p is Map<String, dynamic>) {
          peerList.add(WireguardPeer.fromJson(p));
        }
      }
    } else if (rawPeers is Map) {
      rawPeers.forEach((_, p) {
        if (p is Map<String, dynamic>) {
          peerList.add(WireguardPeer.fromJson(p));
        }
      });
    }

    return WireguardInterface(
      name: name,
      publicKey: json['public_key']?.toString() ?? 'WgPubKeyString...',
      listenPort: (json['listen_port'] as num?)?.toInt() ?? 51820,
      isUp: json['up'] == true || json['up'] == 1,
      peers: peerList,
    );
  }
}

/// OpenVPN Instance definition.
class OpenVpnInstance {
  final String name;
  final bool isEnabled;
  final bool isRunning;
  final String port;
  final String proto;
  final String dev;

  const OpenVpnInstance({
    required this.name,
    required this.isEnabled,
    required this.isRunning,
    required this.port,
    required this.proto,
    required this.dev,
  });

  factory OpenVpnInstance.fromJson(String name, Map<String, dynamic> json) {
    return OpenVpnInstance(
      name: name,
      isEnabled: json['enabled'] == '1' || json['enabled'] == true,
      isRunning: json['running'] == true || json['running'] == 1,
      port: json['port']?.toString() ?? '1194',
      proto: json['proto']?.toString() ?? 'udp',
      dev: json['dev']?.toString() ?? 'tun',
    );
  }
}

/// Tailscale node status.
class TailscaleStatus {
  final bool isConfigured;
  final bool isRunning;
  final String nodeName;
  final String tailscaleIp;
  final String backendState;

  const TailscaleStatus({
    required this.isConfigured,
    required this.isRunning,
    required this.nodeName,
    required this.tailscaleIp,
    required this.backendState,
  });

  factory TailscaleStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TailscaleStatus(
        isConfigured: false,
        isRunning: false,
        nodeName: '',
        tailscaleIp: '',
        backendState: 'Disabled',
      );
    }
    final nodeName = json['node_name']?.toString() ?? json['hostname']?.toString() ?? '';
    final ip = json['ip']?.toString() ?? json['tailscale_ip']?.toString() ?? '';
    final state = json['state']?.toString() ?? 'Disabled';
    final isConfig = json['configured'] == true || nodeName.isNotEmpty || ip.isNotEmpty;
    return TailscaleStatus(
      isConfigured: isConfig,
      isRunning: json['running'] == true || state == 'Running',
      nodeName: nodeName.isNotEmpty ? nodeName : 'OpenWrt-Node',
      tailscaleIp: ip,
      backendState: state,
    );
  }
}

/// NextDNS / Encrypted DNS status.
class NextDnsStatus {
  final bool isConfigured;
  final bool isEnabled;
  final String profileId;
  final bool reportClientInfo;

  const NextDnsStatus({
    required this.isConfigured,
    required this.isEnabled,
    required this.profileId,
    required this.reportClientInfo,
  });

  factory NextDnsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NextDnsStatus(
        isConfigured: false,
        isEnabled: false,
        profileId: '',
        reportClientInfo: false,
      );
    }
    final profile = json['profile']?.toString() ?? '';
    final isConfig = json['configured'] == true || profile.isNotEmpty;
    return NextDnsStatus(
      isConfigured: isConfig,
      isEnabled: json['enabled'] == '1' || json['enabled'] == true,
      profileId: profile,
      reportClientInfo: json['report_client_info'] == '1' || json['report_client_info'] == true,
    );
  }
}

/// Complete VPN & Connectivity overview container.
class VpnConnectivityOverview {
  final List<WireguardInterface> wireguardInterfaces;
  final List<OpenVpnInstance> openvpnInstances;
  final TailscaleStatus tailscale;
  final NextDnsStatus nextdns;

  const VpnConnectivityOverview({
    required this.wireguardInterfaces,
    required this.openvpnInstances,
    required this.tailscale,
    required this.nextdns,
  });

  factory VpnConnectivityOverview.fromDashboardData(Map<String, dynamic>? data, {bool isReviewerMode = false}) {
    final wgList = <WireguardInterface>[];
    final ovpnList = <OpenVpnInstance>[];
    Map<String, dynamic>? tsRaw;
    Map<String, dynamic>? ndnsRaw;

    if (data != null) {
      final wgMap = data['wireguard'] as Map<String, dynamic>?;
      if (wgMap != null) {
        wgMap.forEach((name, val) {
          if (val is Map<String, dynamic>) {
            wgList.add(WireguardInterface.fromJson(name, val));
          }
        });
      }

      final ovpnMap = data['openvpn'] as Map<String, dynamic>?;
      if (ovpnMap != null) {
        ovpnMap.forEach((name, val) {
          if (val is Map<String, dynamic>) {
            ovpnList.add(OpenVpnInstance.fromJson(name, val));
          }
        });
      }

      tsRaw = data['tailscale'] as Map<String, dynamic>?;
      ndnsRaw = data['nextdns'] as Map<String, dynamic>?;
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode) {
      if (wgList.isEmpty) {
        wgList.add(
          WireguardInterface(
            name: 'wg0',
            publicKey: 'eX4mP1ePuB11cK3yF0rW1r3Gu4rdN3tw0rk=',
            listenPort: 51820,
            isUp: true,
            peers: [
              WireguardPeer(
                publicKey: 'P33r1PuB11cK3yStr1ngM0b1l3Ph0n3=',
                endpoint: '198.51.100.42:51820',
                allowedIps: ['10.0.0.2/32', 'fd42:42:42::2/128'],
                rxBytes: 15420000,
                txBytes: 4210000,
                latestHandshakeTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 45,
              ),
              WireguardPeer(
                publicKey: 'P33r2PuB11cK3yStr1ngL4pt0pD3v1c3=',
                endpoint: '203.0.113.88:51820',
                allowedIps: ['10.0.0.3/32'],
                rxBytes: 850000,
                txBytes: 210000,
                latestHandshakeTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 120,
              ),
            ],
          ),
        );
      }

      if (ovpnList.isEmpty) {
        ovpnList.add(
          const OpenVpnInstance(
            name: 'custom_client',
            isEnabled: true,
            isRunning: true,
            port: '1194',
            proto: 'udp',
            dev: 'tun0',
          ),
        );
      }
    }

    return VpnConnectivityOverview(
      wireguardInterfaces: wgList,
      openvpnInstances: ovpnList,
      tailscale: isReviewerMode ? (tsRaw != null ? TailscaleStatus.fromJson(tsRaw) : const TailscaleStatus(isConfigured: true, isRunning: true, nodeName: 'OpenWrt-Router', tailscaleIp: '100.64.0.15', backendState: 'Running')) : TailscaleStatus.fromJson(tsRaw),
      nextdns: isReviewerMode ? (ndnsRaw != null ? NextDnsStatus.fromJson(ndnsRaw) : const NextDnsStatus(isConfigured: true, isEnabled: true, profileId: 'abcdef', reportClientInfo: true)) : NextDnsStatus.fromJson(ndnsRaw),
    );
  }

  int get totalWgPeers => wireguardInterfaces.fold(0, (sum, i) => sum + i.peers.length);
}
