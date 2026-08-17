// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:luci_mobile/modules/vpn_connectivity/models/vpn_info.dart';
import 'package:luci_mobile/models/dashboard_preferences.dart';
import 'package:luci_mobile/models/router_capabilities.dart';
import 'package:luci_mobile/modules/storage_monitoring/models/storage_info.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/services/router_service.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/state/controllers/throughput_controller.dart';
import 'package:luci_mobile/utils/logger.dart';

/// Enum matching AppState connection status for reporting connection failures.
enum DashboardConnectionStatus {
  connected,
  reconnecting,
  disconnected,
}

/// Encapsulates central dashboard data aggregation, capability probing/caching,
/// router hardware capabilities detection, and multi-RPC parallel fetching.
///
/// Extracted from [AppState] to enforce single-responsibility.
class DashboardController {
  DashboardController({
    required IApiService? Function() apiServiceRef,
    required IAuthService? Function() authServiceRef,
    required RouterService? Function() routerServiceRef,
    required SecureStorageService Function() secureStorageServiceRef,
    required ThroughputController? Function() throughputControllerRef,
    required DashboardPreferences Function() dashboardPreferencesRef,
    required bool Function() reviewerModeRef,
    required Future<bool> Function() tryAutoLogin,
    required Future<void> Function() fetchPublicIps,
    required void Function(String v4, String v6) setPublicIps,
    required void Function(DashboardConnectionStatus status)
        setConnectionStatus,
    required void Function() startThroughputTimer,
    required void Function() updateThroughputOnly,
    required Map<String, dynamic> Function(Map<String, dynamic> rawDhcpData)
        processDhcpLeases,
    required VoidCallback notifyListeners,
  })  : _apiServiceRef = apiServiceRef,
        _authServiceRef = authServiceRef,
        _routerServiceRef = routerServiceRef,
        _secureStorageServiceRef = secureStorageServiceRef,
        _throughputControllerRef = throughputControllerRef,
        _dashboardPreferencesRef = dashboardPreferencesRef,
        _reviewerModeRef = reviewerModeRef,
        _tryAutoLogin = tryAutoLogin,
        _fetchPublicIps = fetchPublicIps,
        _setPublicIps = setPublicIps,
        _setConnectionStatus = setConnectionStatus,
        _startThroughputTimer = startThroughputTimer,
        _updateThroughputOnly = updateThroughputOnly,
        _processDhcpLeases = processDhcpLeases,
        _notifyListeners = notifyListeners;

  final IApiService? Function() _apiServiceRef;
  final IAuthService? Function() _authServiceRef;
  final RouterService? Function() _routerServiceRef;
  final SecureStorageService Function() _secureStorageServiceRef;
  final ThroughputController? Function() _throughputControllerRef;
  final DashboardPreferences Function() _dashboardPreferencesRef;
  final bool Function() _reviewerModeRef;
  final Future<bool> Function() _tryAutoLogin;
  final Future<void> Function() _fetchPublicIps;
  final void Function(String v4, String v6) _setPublicIps;
  final void Function(DashboardConnectionStatus status) _setConnectionStatus;
  final void Function() _startThroughputTimer;
  final void Function() _updateThroughputOnly;
  final Map<String, dynamic> Function(Map<String, dynamic> rawDhcpData)
      _processDhcpLeases;
  final VoidCallback _notifyListeners;

  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;
  String? _dashboardError;
  RouterCapabilities? _capabilities;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;
  RouterCapabilities? get capabilities => _capabilities;

  IApiService? get _apiService => _apiServiceRef();
  IAuthService? get _authService => _authServiceRef();
  RouterService? get _routerService => _routerServiceRef();
  SecureStorageService get _secureStorageService =>
      _secureStorageServiceRef();
  ThroughputController? get _throughputController =>
      _throughputControllerRef();
  DashboardPreferences get _dashboardPreferences =>
      _dashboardPreferencesRef();
  bool get _isReviewerMode => _reviewerModeRef();

  /// Resets cached dashboard state and capabilities (e.g. on logout/router change).
  void resetState() {
    _dashboardData = null;
    _capabilities = null;
    _dashboardError = null;
    _isDashboardLoading = false;
  }

  /// Updates system information in cached dashboard data (e.g. from throughput ticks).
  void updateSysInfo(Map<String, dynamic> sysInfoData) {
    _dashboardData ??= <String, dynamic>{};
    _dashboardData!['sysInfo'] = sysInfoData;
  }

  /// Action to re-detect capabilities for the active router
  Future<void> redetectCapabilities() async {
    await probeRouterCapabilities(forceRefresh: true);
  }

  /// Probe and cache actual ubus objects, methods, package manager engine, firewall backend, and network model.
  Future<RouterCapabilities> probeRouterCapabilities(
      {bool forceRefresh = false}) async {
    if (_isReviewerMode) {
      _capabilities = RouterCapabilities.mock();
      _notifyListeners();
      return _capabilities!;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      _capabilities = RouterCapabilities.conservative('unknown');
      return _capabilities!;
    }

    final routerId = _routerService!.selectedRouter!.id;
    final cacheKey = 'router_capabilities_$routerId';

    if (!forceRefresh) {
      try {
        final cachedJsonStr = await _secureStorageService.readValue(cacheKey);
        if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
          final Map<String, dynamic> cachedMap = jsonDecode(cachedJsonStr);
          final cachedCaps = RouterCapabilities.fromJson(cachedMap);
          if (!cachedCaps.probeFailed &&
              DateTime.now().difference(cachedCaps.probedAt).inHours < 24) {
            _capabilities = cachedCaps;
            Logger.info('Loaded router capabilities from cache for $routerId');
            _notifyListeners();
            return _capabilities!;
          }
        }
      } catch (e) {
        Logger.warning('Failed to load cached router capabilities: $e');
      }
    }

    final ip = _routerService!.selectedRouter!.ipAddress;
    final sysauth = _authService!.sysauth!;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    final ubusObjects = <String>{};
    final ubusMethods = <String, List<String>>{};
    PackageManagerEngine pkgEngine = PackageManagerEngine.opkg;
    FirewallBackend fwBackend = FirewallBackend.fw4;
    NetworkModel netModel = NetworkModel.dsa;
    String releaseVer = '';
    String board = '';
    bool probeFailed = false;
    String? probeError;
    Map<String, dynamic> featuresData = {};

    try {
      // 1. Probe available ubus objects and methods
      try {
        final listRes = await _apiService!.call(
          ip,
          sysauth,
          useHttps,
          object: 'rpc',
          method: 'list',
        );
        if (listRes is Map<String, dynamic>) {
          listRes.forEach((obj, methods) {
            ubusObjects.add(obj);
            if (methods is List) {
              ubusMethods[obj] = methods.cast<String>();
            } else if (methods is Map) {
              ubusMethods[obj] = methods.keys.cast<String>().toList();
            }
          });
        }
      } catch (e) {
        Logger.warning('ubus list probe failed: $e');
      }

      try {
        final featuresRes = await _apiService!.call(
          ip,
          sysauth,
          useHttps,
          object: 'luci',
          method: 'getFeatures',
        );
        if (featuresRes is List &&
            featuresRes.length > 1 &&
            featuresRes[0] == 0) {
          final data = featuresRes[1];
          if (data is Map) {
            featuresData = Map<String, dynamic>.from(data);
          }
        }
      } catch (e) {
        Logger.warning('LuCI feature probe failed: $e');
      }

      // 2. Probe Package Manager engine: check /etc/apk vs /etc/opkg or ubus objects
      try {
        if (featuresData['apk'] == true || ubusObjects.contains('apk')) {
          pkgEngine = PackageManagerEngine.apk;
        } else if (featuresData['opkg'] == true ||
            ubusObjects.contains('opkg')) {
          pkgEngine = PackageManagerEngine.opkg;
        } else {
          final apkStat = await _apiService!.call(
            ip,
            sysauth,
            useHttps,
            object: 'file',
            method: 'stat',
            params: {'path': '/lib/apk/db/installed'},
          );
          if (apkStat is List && apkStat.length > 1 && apkStat[0] == 0) {
            pkgEngine = PackageManagerEngine.apk;
          } else {
            final opkgStat = await _apiService!.call(
              ip,
              sysauth,
              useHttps,
              object: 'file',
              method: 'stat',
              params: {'path': '/usr/lib/opkg/status'},
            );
            if (opkgStat is List && opkgStat.length > 1 && opkgStat[0] == 0) {
              pkgEngine = PackageManagerEngine.opkg;
            }
          }
        }
      } catch (e) {
        Logger.warning('Package engine probe failed: $e');
      }

      // 3. Probe Firewall backend (fw3 vs fw4)
      try {
        if (featuresData['firewall4'] == true || ubusObjects.contains('fw4')) {
          fwBackend = FirewallBackend.fw4;
        } else if (featuresData['firewall'] == true ||
            ubusObjects.contains('fw3')) {
          fwBackend = FirewallBackend.fw3;
        } else {
          final uciFw = await _apiService!.call(
            ip,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'get',
            params: {'config': 'firewall'},
          );
          if (uciFw is List && uciFw.length > 1 && uciFw[0] == 0) {
            final values = uciFw[1] as Map<String, dynamic>?;
            if (values != null && values.toString().contains('nftables')) {
              fwBackend = FirewallBackend.fw4;
            } else {
              fwBackend = FirewallBackend.fw3;
            }
          }
        }
      } catch (e) {
        Logger.warning('Firewall backend probe failed: $e');
      }

      // 4. Probe Network model (DSA vs swconfig)
      try {
        final uciNet = await _apiService!.call(
          ip,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'get',
          params: {'config': 'network'},
        );
        if (uciNet is List && uciNet.length > 1 && uciNet[0] == 0) {
          final values = uciNet[1] as Map<String, dynamic>?;
          if (values != null) {
            final strVal = values.toString();
            if (strVal.contains('switch_vlan') || strVal.contains('swconfig')) {
              netModel = NetworkModel.swconfig;
            } else {
              netModel = NetworkModel.dsa;
            }
          }
        }
      } catch (e) {
        Logger.warning('Network model probe failed: $e');
      }

      // 5. System board / release info
      try {
        final boardRes = await _apiService!.call(
          ip,
          sysauth,
          useHttps,
          object: 'system',
          method: 'board',
        );
        if (boardRes is List && boardRes.length > 1 && boardRes[0] == 0) {
          final bData = boardRes[1] as Map<String, dynamic>?;
          board = bData?['model']?.toString() ??
              bData?['hostname']?.toString() ??
              '';
          final release = bData?['release'] as Map<String, dynamic>?;
          releaseVer = release?['version']?.toString() ?? '';
        }
      } catch (e) {
        Logger.warning('Board probe failed: $e');
      }
    } catch (e) {
      probeFailed = true;
      probeError = e.toString();
      Logger.error('Router capability probe error: $e');
    }

    _capabilities = RouterCapabilities(
      routerId: routerId,
      ubusObjects: ubusObjects,
      ubusMethods: ubusMethods,
      packageEngine: pkgEngine,
      firewallBackend: fwBackend,
      networkModel: netModel,
      releaseVersion: releaseVer,
      boardName: board,
      probedAt: DateTime.now(),
      probeFailed: probeFailed,
      lastProbeError: probeError,
    );

    try {
      await _secureStorageService.writeValue(
        cacheKey,
        jsonEncode(_capabilities!.toJson()),
      );
    } catch (e) {
      Logger.warning('Failed to cache router capabilities: $e');
    }

    _notifyListeners();
    return _capabilities!;
  }

  /// Central method to fetch all dashboard data concurrently
  Future<void> fetchDashboardData() async {
    if (_isReviewerMode) {
      _isDashboardLoading = true;
      _dashboardError = null;
      _notifyListeners();

      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final results = await Future.wait([
          _apiService!.callSimple('system', 'board', {}),
          _apiService!.callSimple('system', 'info', {}),
          _apiService!.callSimple('network', 'device', {}),
          _apiService!.callSimple('network.interface', 'dump', {}),
          _apiService!.callSimple('wireless', 'devices', {}),
          _apiService!.callSimple('luci-rpc', 'getDHCPLeases', {}),
          _apiService!.callSimple('uci', 'get', {'config': 'wireless'}),
          _apiService!.callSimple('uci', 'get', {'config': 'network'}),
        ]);

        final interfaceDump = results[3][1] as Map<String, dynamic>;
        final rawDhcpData = results[5][1] as Map<String, dynamic>;
        final processedDhcpData = _processDhcpLeases(rawDhcpData);

        _dashboardData = {
          'boardInfo': results[0][1],
          'sysInfo': results[1][1],
          'networkDevices': results[2][1],
          'interfaceDump': interfaceDump,
          'wireless': results[4][1],
          'dhcpLeases': processedDhcpData,
          'uciWirelessConfig': results[6][1],
          'uciNetworkConfig': results[7][1],
          'wan': extractWanData(interfaceDump),
          'mountPoints': [
            {
              'mount': '/',
              'device': '/dev/root',
              'fs': 'squashfs',
              'size': 131072,
              'used': 46080,
              'avail': 84992,
            },
            {
              'mount': '/overlay',
              'device': '/dev/mtdblock6',
              'fs': 'ext4',
              'size': 65536,
              'used': 16384,
              'avail': 49152,
            },
            {
              'mount': '/tmp',
              'device': 'tmpfs',
              'fs': 'tmpfs',
              'size': 262144,
              'used': 2048,
              'avail': 260096,
            },
          ],
          'wireguard': <String, dynamic>{},
          '_lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };

        _setPublicIps('203.0.113.195', '2001:db8:85a3::8a2e:0370:7334');

        if (_throughputController != null) {
          final networkData = results[2][1] as Map<String, dynamic>?;
          final wanDeviceNames = {'eth0', 'wlan0', 'br-lan'};

          final prefs = _dashboardPreferences;
          String? specificInterface;
          if (!prefs.showAllThroughput &&
              prefs.primaryThroughputInterface != null) {
            specificInterface =
                getDeviceNameForInterface(prefs.primaryThroughputInterface!);
          }

          _throughputController!.updateThroughput(
            networkData,
            wanDeviceNames,
            specificInterface: specificInterface,
          );
        }

        _startThroughputTimer();

        Future.delayed(const Duration(milliseconds: 100), () {
          _updateThroughputOnly();
        });

        _isDashboardLoading = false;
        _notifyListeners();
      } catch (e) {
        _dashboardError = 'Failed to fetch dashboard data: $e';
        _isDashboardLoading = false;
        _notifyListeners();
      }
      return;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return;
    }

    _isDashboardLoading = true;
    _dashboardError = null;
    _notifyListeners();

    await probeRouterCapabilities();

    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    try {
      Future<dynamic> callOptionalRpc({
        required String object,
        required String method,
        Map<String, dynamic>? params,
      }) async {
        try {
          return await _apiService!.call(
            ip,
            _authService!.sysauth!,
            useHttps,
            object: object,
            method: method,
            params: params,
          );
        } catch (e, stack) {
          Logger.warning('Optional RPC $object.$method failed: $e');
          Logger.debug('Optional RPC $object.$method stack: $stack');
          return null;
        }
      }

      dynamic getData(dynamic result) {
        if (result is List && result.length > 1) {
          if (result[0] == 0) {
            return result[1];
          } else {
            final errorMessage =
                result[1] is String ? result[1] : 'Unknown API Error';
            throw Exception(errorMessage);
          }
        }
        return result;
      }

      dynamic getOptionalData(dynamic result, String label) {
        try {
          return getData(result);
        } catch (e) {
          Logger.warning('Optional RPC $label returned error: $e');
          return null;
        }
      }

      final wirelessFuture = callOptionalRpc(
        object: 'luci-rpc',
        method: 'getWirelessDevices',
        params: {},
      );

      final uciWirelessFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'wireless'},
      );

      final uciDhcpFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'dhcp'},
      );

      final uciFirewallFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'firewall'},
      );

      final uciOpenvpnFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'openvpn'},
      );

      final uciTailscaleFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'tailscale'},
      );

      final uciNextdnsFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'nextdns'},
      );

      final uciCloudflaredFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'cloudflared'},
      );

      Future<dynamic> fetchCronData() async {
        try {
          final res1 = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/etc/crontabs/root'},
          );
          final data1 = getOptionalData(res1, 'file.read.cron');
          if (data1 is Map && data1['data'] != null) {
            return (data1['data'] as String).split('\n');
          }

          final res2 = await callOptionalRpc(
            object: 'file',
            method: 'exec',
            params: {'command': 'crontab', 'params': ['-l'], 'args': ['-l']},
          );
          final data2 = getOptionalData(res2, 'file.exec.cron');
          if (data2 is Map && data2['stdout'] != null) {
            return (data2['stdout'] as String).split('\n');
          }
        } catch (_) {}
        return null;
      }

      Future<dynamic> fetchDhcpLeasesData() async {
        try {
          final res1 = await callOptionalRpc(
            object: 'luci-rpc',
            method: 'getDHCPLeases',
            params: {},
          );
          final data1 = getOptionalData(res1, 'luci-rpc.getDHCPLeases');
          if (data1 != null) return data1;

          final res2 = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/tmp/dhcp.leases'},
          );
          final data2 = getOptionalData(res2, 'file.read.dhcp');
          if (data2 is Map && data2['data'] != null) {
            return _processDhcpLeases(Map<String, dynamic>.from(data2));
          }

          final res3 = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/var/dhcp.leases'},
          );
          final data3 = getOptionalData(res3, 'file.read.dhcp2');
          if (data3 is Map && data3['data'] != null) {
            return _processDhcpLeases(Map<String, dynamic>.from(data3));
          }
        } catch (_) {}
        return null;
      }

      final cronFuture = fetchCronData();
      final dhcpLeasesFuture = fetchDhcpLeasesData();

      final servicesFuture = callOptionalRpc(
        object: 'service',
        method: 'list',
        params: {},
      );

      final initScriptsFuture = callOptionalRpc(
        object: 'rc',
        method: 'list',
        params: {},
      );

      Future<dynamic> fetchStorageData() async {
        try {
          bool hasValidMounts(dynamic rawData) {
            if (rawData == null) return false;
            final overview = StorageOverview.fromRpcData(rawData);
            return overview.mountPoints.isNotEmpty;
          }

          final res1 = await callOptionalRpc(
            object: 'luci-rpc',
            method: 'getMountPoints',
            params: {},
          );
          final data1 = getOptionalData(res1, 'luci-rpc.getMountPoints');
          if (hasValidMounts(data1)) return data1;

          final res2 = await callOptionalRpc(
            object: 'system',
            method: 'mounts',
            params: {},
          );
          final data2 = getOptionalData(res2, 'system.mounts');
          if (hasValidMounts(data2)) return data2;

          final res3 = await callOptionalRpc(
            object: 'luci',
            method: 'getMountPoints',
            params: {},
          );
          final data3 = getOptionalData(res3, 'luci.getMountPoints');
          if (hasValidMounts(data3)) return data3;

          final procMountPaths = [
            '/proc/mounts',
            '/proc/self/mounts',
            '/etc/mtab'
          ];
          for (final mountPath in procMountPaths) {
            final resProc = await callOptionalRpc(
              object: 'file',
              method: 'read',
              params: {'path': mountPath},
            );
            final dataProc = getOptionalData(resProc, 'file.read.$mountPath');
            if (dataProc is Map) {
              final fileData = dataProc['data']?.toString();
              if (hasValidMounts(fileData)) return fileData;
            }
          }

          final res4 = await callOptionalRpc(
            object: 'uci',
            method: 'get',
            params: {'config': 'fstab'},
          );
          final data4 = getOptionalData(res4, 'uci.get.fstab');
          if (hasValidMounts(data4)) return data4;

          final dfVariations = [
            {'command': 'df', 'params': ['-k'], 'args': ['-k']},
            {'command': '/bin/df', 'params': ['-k'], 'args': ['-k']},
            {'command': '/usr/bin/df', 'params': ['-k'], 'args': ['-k']},
            {'command': 'df', 'params': ['-h'], 'args': ['-h']},
            {'command': 'df', 'params': ['-P'], 'args': ['-P']},
            {'command': 'df', 'params': <String>[], 'args': <String>[]},
            {'command': 'sh', 'params': ['-c', 'df -k'], 'args': ['-c', 'df -k']},
            {
              'command': '/bin/sh',
              'params': ['-c', 'df -k'],
              'args': ['-c', 'df -k']
            },
            {
              'command': 'cat',
              'params': ['/proc/mounts'],
              'args': ['/proc/mounts']
            },
          ];

          for (final dfParams in dfVariations) {
            final resDf = await callOptionalRpc(
              object: 'file',
              method: 'exec',
              params: dfParams,
            );
            final dataDf = getOptionalData(resDf, 'file.exec.df');
            if (dataDf is Map) {
              final stdout = dataDf['stdout']?.toString();
              if (hasValidMounts(stdout)) return stdout;
            }
          }

          final resProc = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/proc/mounts'},
          );
          final dataProc = getOptionalData(resProc, 'file.read.mounts');
          if (dataProc is Map) {
            final fileData = dataProc['data']?.toString();
            if (hasValidMounts(fileData)) return fileData;
          }

          final resSelfProc = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/proc/self/mounts'},
          );
          final dataSelfProc =
              getOptionalData(resSelfProc, 'file.read.selfmounts');
          if (dataSelfProc is Map) {
            final fileData = dataSelfProc['data']?.toString();
            if (hasValidMounts(fileData)) return fileData;
          }

          final resMtab = await callOptionalRpc(
            object: 'file',
            method: 'read',
            params: {'path': '/etc/mtab'},
          );
          final dataMtab = getOptionalData(resMtab, 'file.read.mtab');
          if (dataMtab is Map) {
            final fileData = dataMtab['data']?.toString();
            if (hasValidMounts(fileData)) return fileData;
          }
        } catch (e) {
          Logger.warning('Storage data RPC error: $e');
        }
        return null;
      }

      final mountPointsFuture = fetchStorageData();

      final results = await Future.wait([
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'system',
          method: 'board',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'system',
          method: 'info',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'luci-rpc',
          method: 'getNetworkDevices',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'network.interface',
          method: 'dump',
          params: {},
        ),
      ]);

      final boardInfoData = getData(results[0]);
      final sysInfoData = getData(results[1]);
      final networkData = getData(results[2]) as Map<String, dynamic>?;
      final interfaceDump = getData(results[3]) as Map<String, dynamic>?;

      final optionalResults = await Future.wait([
        wirelessFuture,
        uciWirelessFuture,
        uciDhcpFuture,
        uciFirewallFuture,
        servicesFuture,
        initScriptsFuture,
        mountPointsFuture,
        cronFuture,
        dhcpLeasesFuture,
        uciOpenvpnFuture,
        uciTailscaleFuture,
        uciNextdnsFuture,
        uciCloudflaredFuture,
      ]);
      final wirelessRaw = optionalResults[0];
      final uciWirelessRaw = optionalResults[1];
      final uciDhcpRaw = optionalResults[2];
      final uciFirewallRaw = optionalResults[3];
      final servicesRaw = optionalResults[4];
      final initScriptsRaw = optionalResults[5];
      final mountPointsRaw = optionalResults[6];
      final cronRaw = optionalResults[7];
      final dhcpLeasesRaw = optionalResults[8];
      final uciOpenvpnRaw = optionalResults[9];
      final uciTailscaleRaw = optionalResults[10];
      final uciNextdnsRaw = optionalResults[11];
      final uciCloudflaredRaw = optionalResults[12];

      Map<String, dynamic>? wirelessData;
      if (wirelessRaw != null) {
        final parsedWireless =
            getOptionalData(wirelessRaw, 'luci-rpc.getWirelessDevices');
        if (parsedWireless is Map<String, dynamic>) {
          wirelessData = parsedWireless;
        }
      }

      dynamic uciWirelessConfig;
      if (uciWirelessRaw != null) {
        uciWirelessConfig =
            getOptionalData(uciWirelessRaw, 'uci.get wireless');
      }

      dynamic uciDhcpConfig;
      if (uciDhcpRaw != null) {
        uciDhcpConfig = getOptionalData(uciDhcpRaw, 'uci.get dhcp');
      }

      dynamic uciFirewallConfig;
      if (uciFirewallRaw != null) {
        uciFirewallConfig =
            getOptionalData(uciFirewallRaw, 'uci.get firewall');
      }

      Map<String, dynamic>? openvpnData;
      if (uciOpenvpnRaw != null) {
        final parsedOpenvpn =
            getOptionalData(uciOpenvpnRaw, 'uci.get openvpn');
        if (parsedOpenvpn is Map<String, dynamic>) {
          final values = parsedOpenvpn['values'] is Map<String, dynamic>
              ? parsedOpenvpn['values'] as Map<String, dynamic>
              : parsedOpenvpn;
          final map = <String, dynamic>{};
          values.forEach((name, sec) {
            if (sec is Map<String, dynamic>) {
              final type = sec['.type']?.toString();
              if (type == 'openvpn' || type == 'instance' || type == null) {
                map[name] = sec;
              }
            }
          });
          if (map.isNotEmpty) openvpnData = map;
        }
      }

      Map<String, dynamic>? tailscaleData;
      if (uciTailscaleRaw != null) {
        final parsedTailscale =
            getOptionalData(uciTailscaleRaw, 'uci.get tailscale');
        if (parsedTailscale is Map<String, dynamic>) {
          final values = parsedTailscale['values'] is Map<String, dynamic>
              ? parsedTailscale['values'] as Map<String, dynamic>
              : parsedTailscale;
          Map<String, dynamic>? sec;
          if (values.containsKey('settings')) {
            sec = values['settings'] as Map<String, dynamic>?;
          } else if (values.isNotEmpty) {
            sec = values.values.firstWhere((v) => v is Map<String, dynamic>,
                orElse: () => null) as Map<String, dynamic>?;
          }
          if (sec != null) {
            tailscaleData = {
              'configured': true,
              'enabled': sec['enabled'] == '1' || sec['enabled'] == true,
              'running': sec['enabled'] == '1' || sec['enabled'] == true,
              'node_name': sec['hostname']?.toString() ??
                  sec['node_name']?.toString() ??
                  'OpenWrt-Router',
              'tailscale_ip': sec['ip']?.toString() ?? '',
              'state': (sec['enabled'] == '1' || sec['enabled'] == true)
                  ? 'Running'
                  : 'Stopped',
            };
          }
        }
      }

      Map<String, dynamic>? nextdnsData;
      if (uciNextdnsRaw != null) {
        final parsedNextdns =
            getOptionalData(uciNextdnsRaw, 'uci.get nextdns');
        if (parsedNextdns is Map<String, dynamic>) {
          final values = parsedNextdns['values'] is Map<String, dynamic>
              ? parsedNextdns['values'] as Map<String, dynamic>
              : parsedNextdns;
          Map<String, dynamic>? sec;
          if (values.containsKey('main')) {
            sec = values['main'] as Map<String, dynamic>?;
          } else if (values.isNotEmpty) {
            sec = values.values.firstWhere((v) => v is Map<String, dynamic>,
                orElse: () => null) as Map<String, dynamic>?;
          }
          if (sec != null) {
            final isEnabled = sec['enabled'] == '1' || sec['enabled'] == true;
            bool isRunning = isEnabled;

            final parsedServices = servicesRaw != null
                ? getOptionalData(servicesRaw, 'service.list')
                : null;
            final parsedInit = initScriptsRaw != null
                ? getOptionalData(initScriptsRaw, 'rc.list')
                : null;

            if (parsedServices is Map<String, dynamic> &&
                parsedServices.containsKey('nextdns')) {
              final sObj = parsedServices['nextdns'];
              if (sObj is Map && sObj['instances'] is Map) {
                final instances = sObj['instances'] as Map;
                if (instances.isNotEmpty) {
                  isRunning = instances.values.any((i) =>
                      i is Map && (i['running'] == true || i['running'] == 1));
                } else {
                  isRunning = false;
                }
              } else if (sObj is Map && sObj.containsKey('running')) {
                isRunning = sObj['running'] == true || sObj['running'] == 1;
              }
            } else if (parsedInit is Map<String, dynamic> &&
                parsedInit.containsKey('nextdns')) {
              final iObj = parsedInit['nextdns'];
              if (iObj is Map && iObj.containsKey('running')) {
                isRunning = iObj['running'] == true || iObj['running'] == 1;
              }
            }

            nextdnsData = {
              'configured': true,
              'enabled': isEnabled,
              'running': isRunning,
              'profile': sec['profile']?.toString() ??
                  sec['profile_id']?.toString() ??
                  '',
              'report_client_info': sec['report_client_info'] == '1' ||
                  sec['report_client_info'] == true,
            };
          }
        }
      }

      Map<String, dynamic>? cloudflaredData;
      if (uciCloudflaredRaw != null) {
        final parsedCf =
            getOptionalData(uciCloudflaredRaw, 'uci.get cloudflared');
        if (parsedCf is Map<String, dynamic>) {
          final values = parsedCf['values'] is Map<String, dynamic>
              ? parsedCf['values'] as Map<String, dynamic>
              : parsedCf;

          String foundTunnelId = '';
          String foundTunnelName = '';
          String foundToken = '';
          bool isEnabled = false;

          for (final entry in values.entries) {
            if (entry.value is! Map) continue;
            final secMap = Map<String, dynamic>.from(entry.value as Map);
            secMap['.name'] = entry.key;

            final secEnabled = secMap['enabled'] == '1' ||
                secMap['enabled'] == true ||
                secMap['enable'] == '1' ||
                secMap['enable'] == true;
            if (secEnabled) isEnabled = true;

            final secTunnelId = CloudflaredStatus.extractTunnelId(secMap);
            if (secTunnelId.isNotEmpty && secTunnelId != 'N/A') {
              foundTunnelId = secTunnelId;
            }

            final secName = secMap['tunnel_name']?.toString() ??
                secMap['name']?.toString() ??
                secMap['tunnel']?.toString() ??
                '';
            if (secName.isNotEmpty &&
                secName != foundTunnelId &&
                secName != 'config' &&
                secName != 'main' &&
                secName != 'global') {
              foundTunnelName = secName;
            }

            final secToken = secMap['token']?.toString() ??
                secMap['tunnel_token']?.toString() ??
                '';
            if (secToken.isNotEmpty) {
              foundToken = secToken;
            }
          }

          if (values.isNotEmpty) {
            bool isRunning = isEnabled;
            final parsedServices = servicesRaw != null
                ? getOptionalData(servicesRaw, 'service.list')
                : null;
            final parsedInit = initScriptsRaw != null
                ? getOptionalData(initScriptsRaw, 'rc.list')
                : null;

            if (parsedServices is Map<String, dynamic> &&
                parsedServices.containsKey('cloudflared')) {
              final sObj = parsedServices['cloudflared'];
              if (sObj is Map && sObj['instances'] is Map) {
                final instances = sObj['instances'] as Map;
                if (instances.isNotEmpty) {
                  isRunning = instances.values.any((i) =>
                      i is Map && (i['running'] == true || i['running'] == 1));
                } else {
                  isRunning = false;
                }
              } else if (sObj is Map && sObj.containsKey('running')) {
                isRunning = sObj['running'] == true || sObj['running'] == 1;
              }
            } else if (parsedInit is Map<String, dynamic> &&
                parsedInit.containsKey('cloudflared')) {
              final iObj = parsedInit['cloudflared'];
              if (iObj is Map && iObj.containsKey('running')) {
                isRunning = iObj['running'] == true || iObj['running'] == 1;
              }
            }

            cloudflaredData = {
              'configured': true,
              'enabled': isEnabled,
              'running': isRunning,
              'tunnel_id': foundTunnelId,
              'tunnel_name': foundTunnelName.isNotEmpty
                  ? foundTunnelName
                  : ((foundTunnelId.isNotEmpty && foundTunnelId != 'N/A')
                      ? 'Cloudflare Tunnel'
                      : ''),
              'token': foundToken,
              'connections': isRunning ? 4 : 0,
            };
          }
        }
      }

      dynamic servicesData;
      if (servicesRaw != null) {
        servicesData = getOptionalData(servicesRaw, 'service.list');
      }

      dynamic initScriptsData;
      if (initScriptsRaw != null) {
        initScriptsData = getOptionalData(initScriptsRaw, 'rc.list');
      }

      dynamic mountPointsData = mountPointsRaw;

      final pkgMgrType = _capabilities?.packageEngine.name ?? 'opkg';

      final wireguardData = <String, dynamic>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        final hasWireGuardInterfaces =
            interfaceDump['interface'].any((interface) {
          if (interface is Map<String, dynamic>) {
            final proto = interface['proto'] as String?;
            return proto == 'wireguard';
          }
          return false;
        });

        if (hasWireGuardInterfaces) {
          final allWireGuardData = await _apiService!.fetchWireGuardPeers(
            ipAddress: ip,
            sysauth: _authService!.sysauth!,
            useHttps: useHttps,
            interface: '',
          );

          if (allWireGuardData != null) {
            for (final interface in interfaceDump['interface']) {
              if (interface is Map<String, dynamic>) {
                final ifname = interface['interface'] as String?;
                final proto = interface['proto'] as String?;
                if (proto == 'wireguard' && ifname != null) {
                  final interfaceData = allWireGuardData[ifname];
                  if (interfaceData != null) {
                    wireguardData[ifname] = interfaceData;
                  }
                }
              }
            }
          }
        }
      }

      final wanDeviceNames = <String>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        for (final interface in interfaceDump['interface']) {
          if (interface is Map<String, dynamic>) {
            final ifname = interface['interface'] as String?;
            if (ifname != null && ifname != 'loopback' && ifname != 'lo') {
              final device = interface['device'] as String?;
              final l3Device = interface['l3_device'] as String?;
              if (device != null) {
                wanDeviceNames.add(device);
              }
              if (l3Device != null && l3Device != device) {
                wanDeviceNames.add(l3Device);
              }
            }
          }
        }
      }

      final prefs = _dashboardPreferences;
      String? specificInterface;
      if (!prefs.showAllThroughput &&
          prefs.primaryThroughputInterface != null) {
        specificInterface =
            getDeviceNameForInterface(prefs.primaryThroughputInterface!);
      }

      _throughputController?.updateThroughput(
        networkData,
        wanDeviceNames,
        specificInterface: specificInterface,
      );

      final wirelessStationsMap = <String, dynamic>{};
      final wirelessDevs = wirelessData ??
          (uciWirelessConfig is Map<String, dynamic>
              ? uciWirelessConfig
              : null);
      final ifnamesToQuery = <String>{};

      if (wirelessDevs is Map<String, dynamic>) {
        wirelessDevs.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            final ifaces = v['interfaces'];
            if (ifaces is List) {
              for (final ifc in ifaces) {
                if (ifc is Map<String, dynamic>) {
                  final name =
                      ifc['ifname']?.toString() ?? ifc['section']?.toString();
                  if (name != null && name.isNotEmpty) {
                    ifnamesToQuery.add(name);
                  }
                }
              }
            } else if (v['ifname'] != null) {
              ifnamesToQuery.add(v['ifname'].toString());
            }
          }
        });
      }

      try {
        final devRes = await callOptionalRpc(
          object: 'iwinfo',
          method: 'devices',
        );
        final devData = getOptionalData(devRes, 'iwinfo.devices');
        if (devData is List) {
          for (final item in devData) {
            if (item != null && item.toString().isNotEmpty) {
              ifnamesToQuery.add(item.toString());
            }
          }
        }
      } catch (_) {}

      if (interfaceDump is Map<String, dynamic> &&
          interfaceDump['interface'] is List) {
        for (final ifc in interfaceDump['interface']) {
          if (ifc is Map<String, dynamic>) {
            final dev =
                ifc['device']?.toString() ?? ifc['l3_device']?.toString();
            if (dev != null &&
                (dev.contains('wlan') ||
                    dev.contains('phy') ||
                    dev.contains('wifi') ||
                    dev.contains('ath') ||
                    dev.contains('ra'))) {
              ifnamesToQuery.add(dev);
            }
          }
        }
      }

      final assocResults = await Future.wait(
        ifnamesToQuery.map((ifname) async {
          try {
            final res = await callOptionalRpc(
              object: 'iwinfo',
              method: 'assoclist',
              params: {'device': ifname},
            );
            return MapEntry(
                ifname, getOptionalData(res, 'iwinfo.assoclist.$ifname'));
          } catch (_) {
            return MapEntry(ifname, null);
          }
        }),
      );

      for (final entry in assocResults) {
        if (entry.value != null) {
          wirelessStationsMap[entry.key] = entry.value;
        }
      }

      _dashboardData = {
        'boardInfo': boardInfoData,
        'sysInfo': sysInfoData,
        'networkDevices': networkData,
        'interfaceDump': interfaceDump,
        'wireless': wirelessData ?? <String, dynamic>{},
        'wirelessStations': wirelessStationsMap,
        'dhcpLeases': dhcpLeasesRaw,
        'wan': extractWanData(interfaceDump),
        'uciWirelessConfig': uciWirelessConfig,
        'uciDhcpConfig': uciDhcpConfig,
        'uciFirewallConfig': uciFirewallConfig,
        'packageManager': pkgMgrType,
        'installedPackages': null,
        'availablePackages': null,
        'cronJobs': cronRaw,
        'services': servicesData,
        'initScripts': initScriptsData,
        'mountPoints': mountPointsData,
        'wireguard': wireguardData,
        'openvpn': openvpnData,
        'tailscale': tailscaleData,
        'nextdns': nextdnsData,
        'cloudflared': cloudflaredData,
        '_lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      final boardInfo = _dashboardData?['boardInfo'] as Map<String, dynamic>?;
      final hostname = boardInfo?['hostname']?.toString();
      if (hostname != null && hostname.isNotEmpty) {
        await _routerService?.updateSelectedRouterHostname(hostname);
      }

      _startThroughputTimer();
      unawaited(_fetchPublicIps());

      Future.delayed(const Duration(milliseconds: 100), () {
        _updateThroughputOnly();
      });
    } catch (e) {
      if (!_isReviewerMode && _authService != null) {
        _setConnectionStatus(DashboardConnectionStatus.reconnecting);
        _notifyListeners();

        bool reconnected = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          try {
            final autoLoginSuccess = await _tryAutoLogin();
            if (autoLoginSuccess) {
              reconnected = true;
              break;
            }
          } catch (_) {}
        }

        if (reconnected) {
          _setConnectionStatus(DashboardConnectionStatus.connected);
          _dashboardError = null;
          _isDashboardLoading = false;
          _notifyListeners();
          unawaited(fetchDashboardData());
          return;
        }
      }

      _setConnectionStatus(DashboardConnectionStatus.disconnected);
      final errorMessage = e.toString();
      if (errorMessage.contains('Access denied')) {
        _dashboardError =
            'Access Denied: Check RPC permissions for this user.';
      } else {
        _dashboardError = 'Failed to fetch dashboard data: $e';
      }
      _dashboardData = null;
    } finally {
      _isDashboardLoading = false;
      _notifyListeners();
    }
  }

  /// Maps an interface name to its actual Linux device name (e.g. eth0, br-lan)
  String? getDeviceNameForInterface(String interfaceName) {
    if (interfaceName.contains('(')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceName);
      return match?.group(1);
    }

    final interfaceDump =
        _dashboardData?['interfaceDump'] as Map<String, dynamic>?;
    if (interfaceDump != null && interfaceDump['interface'] is List) {
      for (final interface in interfaceDump['interface']) {
        if (interface is Map<String, dynamic>) {
          final ifname = interface['interface'] as String?;
          if (ifname == interfaceName) {
            return (interface['device'] ?? interface['l3_device']) as String?;
          }
        }
      }
    }

    return interfaceName;
  }

  static Map<String, dynamic>? extractWanData(Map<String, dynamic>? interfaceDump) {
    if (interfaceDump == null || interfaceDump['interface'] == null) {
      return null;
    }
    try {
      for (var interface in interfaceDump['interface']) {
        if (interface['route'] is List) {
          for (var route in interface['route']) {
            if (route is Map &&
                route['target'] == '0.0.0.0' &&
                route['mask'] == 0) {
              return interface;
            }
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
