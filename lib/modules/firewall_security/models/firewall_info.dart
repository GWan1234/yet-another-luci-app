/// Default global firewall policy.
class FirewallDefaultPolicy {
  final String input;
  final String output;
  final String forward;
  final bool synFlood;

  const FirewallDefaultPolicy({
    required this.input,
    required this.output,
    required this.forward,
    required this.synFlood,
  });

  factory FirewallDefaultPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FirewallDefaultPolicy(
        input: 'ACCEPT',
        output: 'ACCEPT',
        forward: 'REJECT',
        synFlood: true,
      );
    }

    return FirewallDefaultPolicy(
      input: (json['input']?.toString() ?? 'ACCEPT').toUpperCase(),
      output: (json['output']?.toString() ?? 'ACCEPT').toUpperCase(),
      forward: (json['forward']?.toString() ?? 'REJECT').toUpperCase(),
      synFlood: json['syn_flood'] == '1' || json['syn_flood'] == true,
    );
  }
}

/// Firewall zone definition (e.g., LAN, WAN).
class FirewallZone {
  final String name;
  final String input;
  final String output;
  final String forward;
  final bool masquerade;
  final List<String> networks;

  const FirewallZone({
    required this.name,
    required this.input,
    required this.output,
    required this.forward,
    required this.masquerade,
    required this.networks,
  });

  factory FirewallZone.fromJson(String name, Map<String, dynamic> json) {
    final nets = <String>[];
    final netVal = json['network'];
    if (netVal is List) {
      nets.addAll(netVal.map((e) => e.toString()));
    } else if (netVal is String) {
      nets.add(netVal);
    }

    return FirewallZone(
      name: json['name']?.toString() ?? name,
      input: (json['input']?.toString() ?? 'ACCEPT').toUpperCase(),
      output: (json['output']?.toString() ?? 'ACCEPT').toUpperCase(),
      forward: (json['forward']?.toString() ?? 'REJECT').toUpperCase(),
      masquerade: json['masq'] == '1' || json['masq'] == true,
      networks: nets,
    );
  }
}

/// Firewall inter-zone forwarding rule (e.g. lan -> wan).
class FirewallForwarding {
  final String srcZone;
  final String destZone;

  const FirewallForwarding({
    required this.srcZone,
    required this.destZone,
  });

  factory FirewallForwarding.fromJson(Map<String, dynamic> json) {
    return FirewallForwarding(
      srcZone: json['src']?.toString() ?? 'lan',
      destZone: json['dest']?.toString() ?? 'wan',
    );
  }
}

/// Port forwarding rule (redirect).
class FirewallPortForwarding {
  final String name;
  final String srcZone;
  final String srcPort;
  final String destZone;
  final String destIp;
  final String destPort;
  final String proto;

  const FirewallPortForwarding({
    required this.name,
    required this.srcZone,
    required this.srcPort,
    required this.destZone,
    required this.destIp,
    required this.destPort,
    required this.proto,
  });

  factory FirewallPortForwarding.fromJson(Map<String, dynamic> json) {
    return FirewallPortForwarding(
      name: json['name']?.toString() ?? json['.name']?.toString() ?? 'Redirect',
      srcZone: json['src']?.toString() ?? 'wan',
      srcPort: json['src_dport']?.toString() ?? json['src_port']?.toString() ?? 'Any',
      destZone: json['dest']?.toString() ?? 'lan',
      destIp: json['dest_ip']?.toString() ?? 'Any',
      destPort: json['dest_port']?.toString() ?? json['src_dport']?.toString() ?? 'Any',
      proto: json['proto']?.toString() ?? 'tcp',
    );
  }
}

/// Custom security rule.
class FirewallCustomRule {
  final String name;
  final String srcZone;
  final String destZone;
  final String target;
  final bool enabled;

  const FirewallCustomRule({
    required this.name,
    required this.srcZone,
    required this.destZone,
    required this.target,
    required this.enabled,
  });

  factory FirewallCustomRule.fromJson(Map<String, dynamic> json) {
    return FirewallCustomRule(
      name: json['name']?.toString() ?? 'Custom Rule',
      srcZone: json['src']?.toString() ?? 'wan',
      destZone: json['dest']?.toString() ?? 'lan',
      target: (json['target']?.toString() ?? 'ACCEPT').toUpperCase(),
      enabled: json['enabled'] != '0' && json['enabled'] != false,
    );
  }
}

/// Complete firewall & security overview container.
class FirewallOverview {
  final FirewallDefaultPolicy defaultPolicy;
  final List<FirewallZone> zones;
  final List<FirewallForwarding> forwardings;
  final List<FirewallPortForwarding> portForwards;
  final List<FirewallCustomRule> customRules;

  const FirewallOverview({
    required this.defaultPolicy,
    required this.zones,
    required this.forwardings,
    required this.portForwards,
    required this.customRules,
  });

  factory FirewallOverview.fromUciData(Map<String, dynamic>? uciData, {bool isReviewerMode = false}) {
    Map<String, dynamic>? defaultsMap;
    final zoneList = <FirewallZone>[];
    final fwdList = <FirewallForwarding>[];
    final pfList = <FirewallPortForwarding>[];
    final ruleList = <FirewallCustomRule>[];

    if (uciData != null) {
      final values = uciData['values'] as Map<String, dynamic>? ?? uciData;
      values.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          final type = val['.type']?.toString();
          if (type == 'defaults') {
            defaultsMap = val;
          } else if (type == 'zone') {
            zoneList.add(FirewallZone.fromJson(key, val));
          } else if (type == 'forwarding') {
            fwdList.add(FirewallForwarding.fromJson(val));
          } else if (type == 'redirect') {
            pfList.add(FirewallPortForwarding.fromJson(val));
          } else if (type == 'rule') {
            ruleList.add(FirewallCustomRule.fromJson(val));
          }
        }
      });
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode && zoneList.isEmpty) {
      zoneList.addAll([
        const FirewallZone(
          name: 'lan',
          input: 'ACCEPT',
          output: 'ACCEPT',
          forward: 'ACCEPT',
          masquerade: false,
          networks: ['lan'],
        ),
        const FirewallZone(
          name: 'wan',
          input: 'REJECT',
          output: 'ACCEPT',
          forward: 'REJECT',
          masquerade: true,
          networks: ['wan', 'wan6'],
        ),
      ]);
      fwdList.add(const FirewallForwarding(srcZone: 'lan', destZone: 'wan'));
      pfList.add(const FirewallPortForwarding(
        name: 'SSH Forward',
        srcZone: 'wan',
        srcPort: '2222',
        destZone: 'lan',
        destIp: '192.168.1.1',
        destPort: '22',
        proto: 'tcp',
      ));
      ruleList.addAll([
        const FirewallCustomRule(
          name: 'Allow-DHCP-Renew',
          srcZone: 'wan',
          destZone: 'lan',
          target: 'ACCEPT',
          enabled: true,
        ),
        const FirewallCustomRule(
          name: 'Allow-ICMPv6-Input',
          srcZone: 'wan',
          destZone: 'lan',
          target: 'ACCEPT',
          enabled: true,
        ),
      ]);
    }

    return FirewallOverview(
      defaultPolicy: FirewallDefaultPolicy.fromJson(defaultsMap),
      zones: zoneList,
      forwardings: fwdList,
      portForwards: pfList,
      customRules: ruleList,
    );
  }
}
