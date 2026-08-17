// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

/// Represents a Procd system service.
class ProcdService {
  final String name;
  final bool isRunning;
  final bool isEnabled;
  final String? pid;
  final String description;

  const ProcdService({
    required this.name,
    required this.isRunning,
    required this.isEnabled,
    this.pid,
    required this.description,
  });

  factory ProcdService.fromJson(String name, Map<String, dynamic> json) {
    bool running = false;
    String? pidStr = json['pid']?.toString();

    if (json['running'] == true || json['running'] == 1 || json['pid'] != null) {
      running = true;
    }

    if (json['instances'] is Map) {
      final instances = json['instances'] as Map;
      if (instances.isEmpty) {
        // One-shot or kernel-managed services with empty instances (e.g. firewall, system) are active
        running = true;
      } else {
        bool hasRunning = false;
        bool hasStopped = false;
        for (final inst in instances.values) {
          if (inst is Map) {
            if (inst['running'] == true || inst['running'] == 1 || inst['pid'] != null) {
              hasRunning = true;
              pidStr ??= inst['pid']?.toString();
            } else if (inst['running'] == false || inst['running'] == 0) {
              hasStopped = true;
            }
          }
        }
        if (hasRunning) {
          running = true;
        } else if (!hasStopped) {
          running = true;
        } else {
          running = false;
        }
      }
    } else if (json.isEmpty) {
      // Empty procd object registered in service list means active procd service
      running = true;
    }

    final enabled = json['enabled'] != false && json['enabled'] != 0;

    return ProcdService(
      name: name,
      isRunning: running,
      isEnabled: enabled,
      pid: pidStr,
      description: _getServiceDescription(name),
    );
  }

  static String _getServiceDescription(String name) {
    switch (name.toLowerCase()) {
      case 'dnsmasq':
        return 'DNS Forwarder & DHCP Server';
      case 'firewall':
        return 'OpenWrt Netfilter Firewall Utility';
      case 'dropbear':
        return 'Lightweight SSH Server';
      case 'uhttpd':
        return 'LuCI Web Interface Webserver';
      case 'network':
        return 'Core Network Interface Manager';
      case 'odhcpd':
        return 'Embedded DHCPv6 & RA Daemon';
      case 'sysntpd':
        return 'NTP Time Synchronization Client';
      default:
        return 'Background Procd Daemon Service';
    }
  }
}

/// Represents a startup init script (/etc/init.d/*).
class InitScript {
  final String name;
  final bool isEnabled;
  final bool isRunning;
  final int startPriority;

  const InitScript({
    required this.name,
    required this.isEnabled,
    required this.isRunning,
    required this.startPriority,
  });

  InitScript copyWith({
    String? name,
    bool? isEnabled,
    bool? isRunning,
    int? startPriority,
  }) {
    return InitScript(
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      isRunning: isRunning ?? this.isRunning,
      startPriority: startPriority ?? this.startPriority,
    );
  }

  factory InitScript.fromJson(String name, Map<String, dynamic> json) {
    final enabled = json['enabled'] == true || json['enabled'] == 1 || json['enabled'] == '1';
    bool running = json['running'] == true || json['running'] == 1 || json['running'] == '1';
    if (!running && json['running'] == null && enabled) {
      running = true;
    }
    return InitScript(
      name: name,
      isEnabled: enabled,
      isRunning: running,
      startPriority: (json['index'] as num?)?.toInt() ?? (json['start'] as num?)?.toInt() ?? 50,
    );
  }
}

/// Represents a system cron job entry.
class CronJob {
  final String expression;
  final String command;

  const CronJob({
    required this.expression,
    required this.command,
  });

  factory CronJob.fromCronLine(String line) {
    final trimmed = line.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 6) {
      final expr = parts.sublist(0, 5).join(' ');
      final cmd = parts.sublist(5).join(' ');
      return CronJob(expression: expr, command: cmd);
    }
    return CronJob(expression: '* * * * *', command: trimmed);
  }
}

/// Complete overview container for services, init scripts, and cron jobs.
class ServicesSystemOverview {
  final List<ProcdService> services;
  final List<InitScript> initScripts;
  final List<CronJob> cronJobs;

  const ServicesSystemOverview({
    required this.services,
    required this.initScripts,
    required this.cronJobs,
  });

  factory ServicesSystemOverview.fromDashboardData(Map<String, dynamic>? data, {bool isReviewerMode = false}) {
    final serviceList = <ProcdService>[];
    final initList = <InitScript>[];
    final cronList = <CronJob>[];

    if (data != null) {
      final servicesRaw = data['services'] as Map<String, dynamic>?;
      if (servicesRaw != null) {
        servicesRaw.forEach((name, val) {
          if (val is Map<String, dynamic>) {
            serviceList.add(ProcdService.fromJson(name, val));
          }
        });
      }

      final initRaw = data['initScripts'] as Map<String, dynamic>?;
      if (initRaw != null) {
        initRaw.forEach((name, val) {
          if (val is Map<String, dynamic>) {
            initList.add(InitScript.fromJson(name, val));
          }
        });
      }

      final cronRaw = data['cronJobs'];
      if (cronRaw is List) {
        for (final item in cronRaw) {
          if (item is String && item.trim().isNotEmpty && !item.trim().startsWith('#')) {
            cronList.add(CronJob.fromCronLine(item));
          }
        }
      }
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode) {
      if (serviceList.isEmpty) {
        serviceList.addAll([
          const ProcdService(name: 'dnsmasq', isRunning: true, isEnabled: true, pid: '1240', description: 'DNS Forwarder & DHCP Server'),
          const ProcdService(name: 'firewall', isRunning: true, isEnabled: true, pid: '890', description: 'OpenWrt Netfilter Firewall Utility'),
          const ProcdService(name: 'dropbear', isRunning: true, isEnabled: true, pid: '1532', description: 'Lightweight SSH Server'),
          const ProcdService(name: 'uhttpd', isRunning: true, isEnabled: true, pid: '1620', description: 'LuCI Web Interface Webserver'),
          const ProcdService(name: 'network', isRunning: true, isEnabled: true, pid: '912', description: 'Core Network Interface Manager'),
          const ProcdService(name: 'odhcpd', isRunning: true, isEnabled: true, pid: '1310', description: 'Embedded DHCPv6 & RA Daemon'),
        ]);
      }

      if (initList.isEmpty) {
        initList.addAll([
          const InitScript(name: 'boot', isEnabled: true, isRunning: false, startPriority: 10),
          const InitScript(name: 'network', isEnabled: true, isRunning: true, startPriority: 20),
          const InitScript(name: 'dnsmasq', isEnabled: true, isRunning: true, startPriority: 60),
          const InitScript(name: 'dropbear', isEnabled: true, isRunning: true, startPriority: 50),
          const InitScript(name: 'firewall', isEnabled: true, isRunning: true, startPriority: 19),
        ]);
      }

      if (cronList.isEmpty) {
        cronList.addAll([
          const CronJob(expression: '0 4 * * *', command: '/sbin/reboot'),
          const CronJob(expression: '*/15 * * * *', command: '/usr/bin/ping-check.sh'),
        ]);
      }
    }

    return ServicesSystemOverview(
      services: serviceList,
      initScripts: initList,
      cronJobs: cronList,
    );
  }

  int get runningServicesCount => services.where((s) => s.isRunning).length;
}
