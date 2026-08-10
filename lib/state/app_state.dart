import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/services/router_service.dart';
import 'package:luci_mobile/services/throughput_service.dart';
import 'package:luci_mobile/models/client.dart';
import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/models/dashboard_preferences.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import 'package:luci_mobile/services/api_service.dart';
import 'package:luci_mobile/services/service_factory.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/utils/http_client_manager.dart';
import 'package:luci_mobile/utils/logger.dart';
import 'package:luci_mobile/modules/package_manager/models/package_info.dart';
import 'package:luci_mobile/models/router_capabilities.dart';
import 'package:luci_mobile/models/rpc_result.dart';
import 'package:luci_mobile/models/network_topology.dart';
import 'package:luci_mobile/modules/firewall_security/models/firewall_info.dart';
import 'package:luci_mobile/modules/wireless_management/models/wireless_info.dart';

enum RouterConnectionStatus {
  connected,
  reconnecting,
  disconnected,
}

class AppState extends ChangeNotifier {
  static AppState? _instance;

  late final SecureStorageService _secureStorageService;
  IApiService? _apiService;
  IAuthService? _authService;
  RouterService? _routerService;
  ThroughputService? _throughputService;
  final HttpClientManager _httpClientManager = HttpClientManager();

  // Router Capabilities State
  RouterCapabilities? _capabilities;
  RouterCapabilities? get capabilities => _capabilities;

  // Reviewer mode state
  bool _reviewerModeEnabled = false;
  bool get reviewerModeEnabled => _reviewerModeEnabled;

  bool _isLoading = false;
  String? _errorMessage;

  RouterConnectionStatus _connectionStatus = RouterConnectionStatus.connected;
  RouterConnectionStatus get connectionStatus => _connectionStatus;

  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;
  String? _dashboardError;

  Timer? _throughputTimer;
  int _throughputIntervalSeconds = 2;
  int get throughputIntervalSeconds => _throughputIntervalSeconds;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts =
      40; // Max 40 attempts = ~5 minutes with backoff

  // Add rebooting state
  bool _isRebooting = false;
  bool get isRebooting => _isRebooting;

  // Theme mode state
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeModeKey = 'themeMode';

  // Clients view mode (aggregate across routers)
  bool _clientsAggregateAllRouters = true;
  static const String _clientsAggregateKey = 'clients_aggregate_all';
  bool get clientsAggregateAllRouters => _clientsAggregateAllRouters;

  // Dashboard preferences state
  DashboardPreferences _dashboardPreferences = DashboardPreferences();
  DashboardPreferences get dashboardPreferences => _dashboardPreferences;

  List<model.Router> get routers => _routerService?.routers ?? [];
  model.Router? get selectedRouter => _routerService?.selectedRouter;

  VoidCallback? onRouterBackOnline;

  // Add requestedTab for programmatic tab switching
  int? requestedTab;
  String? requestedInterfaceToScroll;

  void requestTab(int index, {String? interfaceToScroll}) {
    requestedTab = index;
    requestedInterfaceToScroll = interfaceToScroll;
    notifyListeners();
  }

  AppState._() {
    _initialize();
  }

  static AppState get instance {
    return _instance ??= AppState._();
  }

  Future<void> _initialize() async {
    await _loadReviewerMode();
    _initializeServices();
    await _loadThemeMode();
    await loadRouters(); // Load routers on app start (sets selectedRouter)
    await _migrateGlobalDashboardPreferencesIfNeeded(); // Proactively migrate legacy prefs
    await _loadClientsViewMode();
    await loadDashboardPreferences(); // Load prefs scoped to selected router
  }

  /// One-time migration: if a global 'dashboard_preferences' exists,
  /// copy it to each router-specific key that doesn't already have prefs.
  Future<void> _migrateGlobalDashboardPreferencesIfNeeded() async {
    try {
      final globalKey = 'dashboard_preferences';
      final globalJson = await _secureStorageService.readValue(globalKey);
      if (globalJson == null || globalJson.isEmpty) return;

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return;

      // Validate JSON format before writing
      try {
        jsonDecode(globalJson);
      } catch (_) {
        return; // Not valid JSON; skip migration
      }

      for (final router in routers) {
        final key = 'dashboard_preferences:${router.id}';
        final existing = await _secureStorageService.readValue(key);
        if (existing == null || existing.isEmpty) {
          await _secureStorageService.writeValue(key, globalJson);
        }
      }

      // If all routers now have scoped prefs, remove the legacy global key
      var allHavePrefs = true;
      for (final router in routers) {
        final key = 'dashboard_preferences:${router.id}';
        final v = await _secureStorageService.readValue(key);
        if (v == null || v.isEmpty) {
          allHavePrefs = false;
          break;
        }
      }
      if (allHavePrefs) {
        await _secureStorageService.deleteValue(globalKey);
      }
    } catch (e, stack) {
      Logger.exception('Failed migrating global dashboard preferences', e, stack);
    }
  }

  Future<void> _loadReviewerMode() async {
    // Initialize secure storage service with default factory first
    ServiceContainer.configure(reviewerMode: false);
    _secureStorageService = ServiceContainer.instance.factory
        .createSecureStorageService();

    final stored = await _secureStorageService.readValue(
      AppConfig.reviewerModeKey,
    );
    _reviewerModeEnabled = stored == 'true';
  }

  void _initializeServices() {
    // Configure the service container based on reviewer mode
    ServiceContainer.configure(reviewerMode: _reviewerModeEnabled);

    // Create services using the factory
    final factory = ServiceContainer.instance.factory;
    _authService = factory.createAuthService();
    _apiService = factory.createApiService();
    _routerService = factory.createRouterService();
    _throughputService = factory.createThroughputService();
  }

  Future<void> setReviewerMode(bool enabled) async {
    _reviewerModeEnabled = enabled;
    await _secureStorageService.writeValue(
      AppConfig.reviewerModeKey,
      enabled.toString(),
    );
    _initializeServices();
    notifyListeners();
  }

  Future<void> _loadThemeMode() async {
    final stored = await _secureStorageService.readValue(_themeModeKey);
    if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (stored == 'light') {
      _themeMode = ThemeMode.light;
    } else if (stored == 'system') {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _secureStorageService.writeValue(_themeModeKey, mode.name);
    notifyListeners();
  }

  Future<void> _loadClientsViewMode() async {
    final stored = await _secureStorageService.readValue(_clientsAggregateKey);
    if (stored == 'true') {
      _clientsAggregateAllRouters = true;
    } else if (stored == 'false') {
      _clientsAggregateAllRouters = false;
    }
  }

  Future<void> setClientsAggregateAllRouters(bool aggregate) async {
    _clientsAggregateAllRouters = aggregate;
    await _secureStorageService.writeValue(
      _clientsAggregateKey,
      aggregate.toString(),
    );
    notifyListeners();
  }

  Future<void> loadDashboardPreferences() async {
    try {
      // Scope preferences by selected router if available
      final routerId = _routerService?.selectedRouter?.id;
      final key = routerId != null
          ? 'dashboard_preferences:$routerId'
          : 'dashboard_preferences';

      // Try router-specific key first
      String? json = await _secureStorageService.readValue(key);
      // Backward-compat: if missing, fall back to global key
      if ((json == null || json.isEmpty) && routerId != null) {
        json = await _secureStorageService.readValue('dashboard_preferences');
      }
      if (json != null && json.isNotEmpty) {
        _dashboardPreferences = DashboardPreferences.fromJson(jsonDecode(json));
        notifyListeners();
      }
    } catch (e, stack) {
      Logger.exception('Failed to load dashboard preferences', e, stack);
      _dashboardPreferences = DashboardPreferences();
    }
  }

  Future<void> saveDashboardPreferences(DashboardPreferences prefs) async {
    try {
      _dashboardPreferences = prefs;
      final routerId = _routerService?.selectedRouter?.id;
      final key = routerId != null
          ? 'dashboard_preferences:$routerId'
          : 'dashboard_preferences';
      await _secureStorageService.writeValue(key, jsonEncode(prefs.toJson()));
      notifyListeners();
    } catch (e, stack) {
      Logger.exception('Failed to save dashboard preferences', e, stack);
      rethrow;
    }
  }

  String? get sysauth => _authService?.sysauth;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<double> get rxHistory => _throughputService?.rxHistory ?? [];
  List<double> get txHistory => _throughputService?.txHistory ?? [];
  double get currentRxRate => _throughputService?.currentRxRate ?? 0.0;
  double get currentTxRate => _throughputService?.currentTxRate ?? 0.0;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;

  // Interface-specific throughput getters
  List<double> getRxHistoryForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getRxHistoryForInterface(deviceName ?? interface) ?? [];
  }

  List<double> getTxHistoryForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getTxHistoryForInterface(deviceName ?? interface) ?? [];
  }

  double getCurrentRxRateForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getCurrentRxRateForInterface(deviceName ?? interface) ?? 0.0;
  }

  double getCurrentTxRateForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getCurrentTxRateForInterface(deviceName ?? interface) ?? 0.0;
  }

  Future<void> loadRouters() async {
    await _routerService?.loadRouters();
    notifyListeners();
  }

  Future<void> addRouter(model.Router router) async {
    await _routerService?.addRouter(router);
    notifyListeners();
  }

  Future<void> removeRouter(String id) async {
    if (_routerService == null) return;

    // Get the router before removing to clear its certificates
    final router = _routerService!.routers.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Router not found'),
    );

    // Clear certificates for this specific router
    await _httpClientManager.clearCertificatesForHost(router.ipAddress);

    final needsSwitch = await _routerService!.removeRouter(id);
    if (needsSwitch && _routerService!.routers.isNotEmpty) {
      await selectRouter(_routerService!.routers.first.id);
    } else if (_routerService!.selectedRouter == null) {
      _dashboardData = null;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> selectRouter(String id, {BuildContext? context}) async {
    if (_routerService == null || _routerService!.routers.isEmpty) return;

    final found = _routerService!.selectRouter(id);
    if (found == null) return;

    _isLoading = true;
    _dashboardError = null;

    // Clear throughput data when switching routers to prevent mixing data from different routers
    _cancelThroughputTimer();

    // Determine a safe context before any awaits
    final safeContext = context?.mounted == true ? context : null; // ignore: use_build_context_synchronously

    // Load router-scoped dashboard preferences immediately on selection
    await loadDashboardPreferences();

    notifyListeners();
    // ignore: use_build_context_synchronously
    final loginSuccess = await login(
      found.ipAddress,
      found.username,
      found.password,
      found.useHttps,
      fromRouter: true,
      context: safeContext, // ignore: use_build_context_synchronously
    );
    if (loginSuccess) {
      await fetchDashboardData();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateRouter(model.Router router) async {
    await _routerService?.updateRouter(router);
    notifyListeners();
  }

  Future<bool> login(
    String ip,
    String user,
    String pass,
    bool useHttps, {
    bool fromRouter = false,
    BuildContext? context,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    // Clear throughput data when logging in to prevent mixing data from different sessions
    _cancelThroughputTimer();

    notifyListeners();

    try {
      await _authService!.login(ip, user, pass, useHttps, context: context);

      // Check if authentication was successful
      if (_authService!.isAuthenticated) {
        // Get the actual protocol used (might be different due to redirect)
        final actualUseHttps = _authService!.useHttps;

        if (!fromRouter) {
          // If not from router selection, add or update router with detected protocol
          if (_routerService != null) {
            final router = _routerService!.createRouter(
              ip,
              user,
              pass,
              actualUseHttps, // Use the detected protocol
            );
            final idx = _routerService!.routers.indexWhere(
              (r) => r.id == router.id,
            );
            if (idx == -1) {
              await addRouter(router);
            } else {
              await updateRouter(router);
            }
          }
        } else if (actualUseHttps != useHttps && _routerService != null) {
          // If we're logging in from a saved router and the protocol changed, update it
          final router = _routerService!.selectedRouter;
          if (router != null) {
            final updatedRouter = router.copyWith(useHttps: actualUseHttps);
            await updateRouter(updatedRouter);
            Logger.info(
              'Updated router protocol from ${useHttps ? "HTTPS" : "HTTP"} to ${actualUseHttps ? "HTTPS" : "HTTP"}',
            );
          }
        }
        await fetchDashboardData();
        _startThroughputTimer();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            'Login Failed: Invalid credentials or host unreachable.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _authService?.logout().then((_) {});
    _dashboardData = null;
    _dashboardError = null;
    _cancelThroughputTimer();
    // Optionally, do not clear routers or selectedRouter
    notifyListeners();
  }

  /// Action to re-detect capabilities for the active router
  Future<void> redetectCapabilities() async {
    await probeRouterCapabilities(forceRefresh: true);
  }

  /// Probe and cache actual ubus objects, methods, package manager engine, firewall backend, and network model.
  Future<RouterCapabilities> probeRouterCapabilities({bool forceRefresh = false}) async {
    if (_reviewerModeEnabled) {
      _capabilities = RouterCapabilities.mock();
      notifyListeners();
      return _capabilities!;
    }

    if (_routerService?.selectedRouter == null || _authService?.sysauth == null) {
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
          if (!cachedCaps.probeFailed && DateTime.now().difference(cachedCaps.probedAt).inHours < 24) {
            _capabilities = cachedCaps;
            Logger.info('Loaded router capabilities from cache for $routerId');
            notifyListeners();
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

      // 2. Probe Package Manager engine: check /etc/apk vs /etc/opkg or ubus objects
      try {
        if (ubusObjects.contains('apk')) {
          pkgEngine = PackageManagerEngine.apk;
        } else if (ubusObjects.contains('opkg')) {
          pkgEngine = PackageManagerEngine.opkg;
        } else {
          final apkStat = await _apiService!.call(
            ip,
            sysauth,
            useHttps,
            object: 'file',
            method: 'stat',
            params: {'path': '/etc/apk'},
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
              params: {'path': '/etc/opkg'},
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
        if (ubusObjects.contains('fw4')) {
          fwBackend = FirewallBackend.fw4;
        } else if (ubusObjects.contains('fw3')) {
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
          board = bData?['model']?.toString() ?? bData?['hostname']?.toString() ?? '';
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
      Logger.warning('Failed to write capability cache: $e');
    }

    notifyListeners();
    return _capabilities!;
  }

  Future<void> fetchDashboardData() async {
    if (_reviewerModeEnabled) {
      // For reviewer mode, return mock data immediately
      _isDashboardLoading = true;
      _dashboardError = null;
      notifyListeners();

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate network delay

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
          'wan': _extractWanData(interfaceDump),
          'wireguard': <String, dynamic>{}, // Empty for reviewer mode
          '_lastUpdated':
              DateTime.now().millisecondsSinceEpoch, // Force UI updates
        };

        // Update throughput data with mock network data for reviewer mode
        if (_throughputService != null) {
          final networkData = results[2][1] as Map<String, dynamic>?;
          final wanDeviceNames = {
            'eth0',
            'wlan0',
            'br-lan',
          }; // Mock all devices

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Map interface name to actual device name
          specificInterface = _getDeviceNameForInterface(prefs.primaryThroughputInterface!);
        }

          _throughputService!.updateThroughput(
            networkData,
            wanDeviceNames,
            specificInterface: specificInterface,
          );
        }

        // Start throughput timer for reviewer mode
        _startThroughputTimer();

        // Schedule an immediate throughput update to get initial data faster
        Future.delayed(const Duration(milliseconds: 100), () {
          _updateThroughputOnly();
        });

        _isDashboardLoading = false;
        notifyListeners();
      } catch (e) {
        _dashboardError = 'Failed to fetch dashboard data: $e';
        _isDashboardLoading = false;
        notifyListeners();
      }
      return;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return;
    }

    _isDashboardLoading = true;
    _dashboardError = null;
    notifyListeners();

    // Perform capability probing before batch RPC calls
    await probeRouterCapabilities();

    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    try {
      // Perform all API calls in parallel
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

      // Helper to safely extract data and handle errors from LuCI's [status, data] responses
      dynamic getData(dynamic result) {
        if (result is List && result.length > 1) {
          if (result[0] == 0) {
            return result[1]; // Success
          } else {
            final errorMessage = result[1] is String
                ? result[1]
                : 'Unknown API Error';
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

      // UCI dhcp, firewall, and wireless configs (optional)
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

      Future<dynamic> fetchPackagesData() async {
        final res = await fetchPackagesDataResult();
        return res.data;
      }

      Future<dynamic> fetchAvailablePackagesData() async {
        final res = await fetchAvailablePackagesDataResult();
        return res.data;
      }

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
            params: {'command': 'crontab', 'args': ['-l']},
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

      final packagesFuture = fetchPackagesData();
      final availablePackagesFuture = fetchAvailablePackagesData();
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
          final res1 = await callOptionalRpc(
            object: 'luci-rpc',
            method: 'getMountPoints',
            params: {},
          );
          final data1 = getOptionalData(res1, 'luci-rpc.getMountPoints');
          if (data1 != null) return data1;

          final res2 = await callOptionalRpc(
            object: 'system',
            method: 'mounts',
            params: {},
          );
          final data2 = getOptionalData(res2, 'system.mounts');
          if (data2 != null) return data2;

          final res3 = await callOptionalRpc(
            object: 'luci',
            method: 'getMountPoints',
            params: {},
          );
          final data3 = getOptionalData(res3, 'luci.getMountPoints');
          if (data3 != null) return data3;

          final res4 = await callOptionalRpc(
            object: 'file',
            method: 'exec',
            params: {'command': 'df', 'args': ['-k']},
          );
          final data4 = getOptionalData(res4, 'file.exec.df');
          if (data4 is Map && data4['stdout'] != null) {
            return data4['stdout'];
          }
        } catch (_) {}
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

      // Await optional futures in parallel
      final optionalResults = await Future.wait([
        wirelessFuture,
        uciWirelessFuture,
        uciDhcpFuture,
        uciFirewallFuture,
        packagesFuture,
        availablePackagesFuture,
        servicesFuture,
        initScriptsFuture,
        mountPointsFuture,
        cronFuture,
        dhcpLeasesFuture,
      ]);
      final wirelessRaw = optionalResults[0];
      final uciWirelessRaw = optionalResults[1];
      final uciDhcpRaw = optionalResults[2];
      final uciFirewallRaw = optionalResults[3];
      final packagesRaw = optionalResults[4];
      final availablePackagesRaw = optionalResults[5];
      final servicesRaw = optionalResults[6];
      final initScriptsRaw = optionalResults[7];
      final mountPointsRaw = optionalResults[8];
      final cronRaw = optionalResults[9];
      final dhcpLeasesRaw = optionalResults[10];

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
        uciFirewallConfig = getOptionalData(uciFirewallRaw, 'uci.get firewall');
      }

      dynamic installedPackagesData = packagesRaw;
      dynamic availablePackagesData = availablePackagesRaw;

      dynamic servicesData;
      if (servicesRaw != null) {
        servicesData = getOptionalData(servicesRaw, 'service.list');
      }

      dynamic initScriptsData;
      if (initScriptsRaw != null) {
        initScriptsData = getOptionalData(initScriptsRaw, 'rc.list');
      }

      dynamic mountPointsData = mountPointsRaw;

      // Determine Package Manager engine from probed RouterCapabilities
      final pkgMgrType = _capabilities?.packageEngine.name ?? 'opkg';

      // Fetch WireGuard peer information for WireGuard interfaces
      final wireguardData = <String, dynamic>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        // Check if there are any WireGuard interfaces
        final hasWireGuardInterfaces = interfaceDump['interface'].any((
          interface,
        ) {
          if (interface is Map<String, dynamic>) {
            final proto = interface['proto'] as String?;
            return proto == 'wireguard';
          }
          return false;
        });

        if (hasWireGuardInterfaces) {
          // Fetch all WireGuard data at once
          final allWireGuardData = await _apiService!.fetchWireGuardPeers(
            ipAddress: ip,
            sysauth: _authService!.sysauth!,
            useHttps: useHttps,
            interface: '', // Empty string to get all interfaces
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

      // Throughput calculation - collect ALL interface devices
      final wanDeviceNames = <String>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        for (final interface in interfaceDump['interface']) {
          if (interface is Map<String, dynamic>) {
            final ifname = interface['interface'] as String?;
            // Skip only loopback interface
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

      // Update throughput data using the service
      final prefs = _dashboardPreferences;
      String? specificInterface;
      if (!prefs.showAllThroughput &&
          prefs.primaryThroughputInterface != null) {
        specificInterface = _getDeviceNameForInterface(prefs.primaryThroughputInterface!);
      }

      _throughputService?.updateThroughput(
        networkData,
        wanDeviceNames,
        specificInterface: specificInterface,
      );

      // Fetch wireless stations (associated client devices) across active wireless interfaces
      final wirelessStationsMap = <String, dynamic>{};
      final wirelessDevs = wirelessData ?? (uciWirelessConfig is Map<String, dynamic> ? uciWirelessConfig : null);
      final ifnamesToQuery = <String>{};

      if (wirelessDevs is Map<String, dynamic>) {
        wirelessDevs.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            final ifaces = v['interfaces'];
            if (ifaces is List) {
              for (final ifc in ifaces) {
                if (ifc is Map<String, dynamic>) {
                  final name = ifc['ifname']?.toString() ?? ifc['section']?.toString();
                  if (name != null && name.isNotEmpty) ifnamesToQuery.add(name);
                }
              }
            } else if (v['ifname'] != null) {
              ifnamesToQuery.add(v['ifname'].toString());
            }
          }
        });
      }

      // Also dynamically query live iwinfo devices directly from router RPC
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

      // Also extract any wireless device names from interface dump
      if (interfaceDump is Map<String, dynamic> && interfaceDump['interface'] is List) {
        for (final ifc in interfaceDump['interface']) {
          if (ifc is Map<String, dynamic>) {
            final dev = ifc['device']?.toString() ?? ifc['l3_device']?.toString();
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
            return MapEntry(ifname, getOptionalData(res, 'iwinfo.assoclist.$ifname'));
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
        'wan': _extractWanData(interfaceDump),
        'uciWirelessConfig': uciWirelessConfig,
        'uciDhcpConfig': uciDhcpConfig,
        'uciFirewallConfig': uciFirewallConfig,
        'packageManager': pkgMgrType,
        'installedPackages': installedPackagesData,
        'availablePackages': availablePackagesData,
        'cronJobs': cronRaw,
        'services': servicesData,
        'initScripts': initScriptsData,
        'mountPoints': mountPointsData,
        'wireguard': wireguardData,
        '_lastUpdated':
            DateTime.now().millisecondsSinceEpoch, // Force UI updates
      };

      // Hybrid approach: update lastKnownHostname for the selected router
      final boardInfo = _dashboardData?['boardInfo'] as Map<String, dynamic>?;
      final hostname = boardInfo?['hostname']?.toString();
      if (hostname != null && hostname.isNotEmpty) {
        await _routerService?.updateSelectedRouterHostname(hostname);
      }

      // Ensure throughput timer is running
      _startThroughputTimer();

      // Schedule an immediate throughput update to get initial data faster
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateThroughputOnly();
      });
    } catch (e) {
      if (!_reviewerModeEnabled && _authService != null) {
        _connectionStatus = RouterConnectionStatus.reconnecting;
        notifyListeners();

        // Silent auto-reconnect backoff (3 attempts: 500ms, 1000ms, 1500ms)
        bool reconnected = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          try {
            final autoLoginSuccess = await tryAutoLogin();
            if (autoLoginSuccess) {
              reconnected = true;
              break;
            }
          } catch (_) {}
        }

        if (reconnected) {
          _connectionStatus = RouterConnectionStatus.connected;
          _dashboardError = null;
          _isDashboardLoading = false;
          notifyListeners();
          // Retry fetching data post auto-reconnect
          unawaited(fetchDashboardData());
          return;
        }
      }

      _connectionStatus = RouterConnectionStatus.disconnected;
      final errorMessage = e.toString();
      if (errorMessage.contains('Access denied')) {
        _dashboardError = 'Access Denied: Check RPC permissions for this user.';
      } else {
        _dashboardError = 'Failed to fetch dashboard data: $e';
      }
      _dashboardData = null;
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }



  /// Capability-aware fetch for installed packages returning RpcResult
  Future<RpcResult<dynamic>> fetchPackagesDataResult() async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final engine = _capabilities?.packageEngine ?? PackageManagerEngine.opkg;
    if (engine == PackageManagerEngine.none) {
      return RpcResult.methodNotFound('No package manager detected on router');
    }

    final isApk = engine == PackageManagerEngine.apk;
    final cmd = isApk ? 'apk' : 'opkg';
    final args = isApk ? ['info'] : ['list-installed'];

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': cmd, 'args': args},
      );

      final execResult = RpcResult.classifyExecResult<dynamic>(rawRpc, (data) {
        if (data is Map && data['stdout'] != null && (data['stdout'] as String).trim().isNotEmpty) {
          return data['stdout'];
        }
        return null;
      });

      if (execResult.isSuccess && execResult.data != null) {
        return execResult;
      }

      if (execResult.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Installed package query returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      // Try status file read fallback if file.exec failed / unpermitted
      final statusPath = isApk ? '/lib/apk/db/installed' : '/usr/lib/opkg/status';
      final rawRead = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'read',
        params: {'path': statusPath},
      );

      if (rawRead != null) {
        final readResult = RpcResult.fromUbusResponse<dynamic>(rawRead, (data) {
          if (data is Map && data['data'] != null && (data['data'] as String).trim().isNotEmpty) {
            return data['data'];
          }
          return null;
        });

        if (readResult.isSuccess && readResult.data != null) {
          return readResult;
        }
      }

      return execResult;
    } catch (e) {
      return RpcResult.networkError('Network error fetching installed packages: $e');
    }
  }

  /// Capability-aware fetch for available packages returning RpcResult
  Future<RpcResult<dynamic>> fetchAvailablePackagesDataResult() async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final engine = _capabilities?.packageEngine ?? PackageManagerEngine.opkg;
    if (engine == PackageManagerEngine.none) {
      return RpcResult.methodNotFound('No package manager detected on router');
    }

    final isApk = engine == PackageManagerEngine.apk;
    final cmd = isApk ? 'apk' : 'opkg';

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': cmd, 'args': ['list']},
      );

      final execResult = RpcResult.classifyExecResult<dynamic>(rawRpc, (data) {
        if (data is Map && data['stdout'] != null && (data['stdout'] as String).trim().isNotEmpty) {
          return data['stdout'];
        }
        return null;
      });

      if (execResult.status == RpcCallStatus.methodNotFound) {
        unawaited(redetectCapabilities());
      }

      return execResult;
    } catch (e) {
      return RpcResult.networkError('Network error fetching available packages: $e');
    }
  }

  /// Capability-aware fetch for network switch / VLAN topology returning `RpcResult<NetworkTopology>`
  Future<RpcResult<NetworkTopology>> fetchNetworkTopologyResult() async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final model = _capabilities?.networkModel ?? NetworkModel.unknown;
    if (model == NetworkModel.unknown) {
      return RpcResult.methodNotFound('Network model is unknown or in conservative fallback mode');
    }

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'network'},
      );

      final rpcRes = RpcResult.fromUbusResponse<NetworkTopology>(rawRpc, (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          if (model == NetworkModel.dsa) {
            return DsaTopologyParser.parse(map, null);
          } else {
            return SwconfigTopologyParser.parse(map, null);
          }
        }
        return NetworkTopology.unavailable(model, 'Invalid network config payload format');
      });

      if (rpcRes.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Network topology fetch returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      return rpcRes;
    } catch (e) {
      return RpcResult.networkError('Network error fetching switch topology: $e');
    }
  }

  /// Capability-aware fetch for firewall configuration returning `RpcResult<FirewallOverview>`
  Future<RpcResult<FirewallOverview>> fetchFirewallOverviewResult() async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;
    final backend = _capabilities?.firewallBackend ?? FirewallBackend.fw4;

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'firewall'},
      );

      final rpcRes = RpcResult.fromUbusResponse<FirewallOverview>(rawRpc, (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          return FirewallOverview.fromUciData(
            map,
            backend: backend,
            isReviewerMode: reviewerModeEnabled,
          );
        }
        return FirewallOverview.unavailable(backend, 'Invalid firewall config payload format');
      });

      if (rpcRes.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Firewall config fetch returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      return rpcRes;
    } catch (e) {
      return RpcResult.networkError('Network error fetching firewall overview: $e');
    }
  }

  /// Capability-aware fetch for wireless configuration returning `RpcResult<WirelessOverview>`
  Future<RpcResult<WirelessOverview>> fetchWirelessOverviewResult() async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'luci-rpc',
        method: 'getWirelessDevices',
        params: {},
      );

      final rpcRes = RpcResult.fromUbusResponse<WirelessOverview>(rawRpc, (data) {
        return WirelessOverview.fromDashboardData(
          {'wireless': data},
          isReviewerMode: reviewerModeEnabled,
        );
      });

      if (rpcRes.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Wireless devices fetch returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      return rpcRes;
    } catch (e) {
      return RpcResult.networkError('Network error fetching wireless overview: $e');
    }
  }

  /// Manage software packages on OpenWrt (OPKG / APK) returning classified RpcResult
  Future<RpcResult<String>> managePackageResult({
    required String packageName,
    required String action, // 'install', 'remove', 'update', 'upgrade'
  }) async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final engine = _capabilities?.packageEngine ?? PackageManagerEngine.opkg;
    if (engine == PackageManagerEngine.none) {
      return RpcResult.methodNotFound('No package manager detected on this router');
    }

    final isApk = engine == PackageManagerEngine.apk;
    final cmd = isApk ? 'apk' : 'opkg';
    List<String> args = [];

    if (action == 'install') {
      args = isApk ? ['add', packageName] : ['install', packageName];
    } else if (action == 'remove') {
      args = isApk ? ['del', packageName] : ['remove', packageName];
    } else if (action == 'update') {
      args = ['update'];
    } else if (action == 'upgrade') {
      args = ['upgrade'];
    }

    try {
      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': cmd, 'args': args},
      );

      final result = RpcResult.classifyExecResult<String>(rawRpc, (data) {
        if (data is Map && data['stdout'] != null) {
          return data['stdout'].toString();
        }
        return 'Action completed successfully';
      });

      // Trigger background re-probe on capability mismatch
      if (result.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Package action returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      if (result.isSuccess) {
        await fetchDashboardData();
      }

      return result;
    } catch (e) {
      Logger.error('Failed package action $action for $packageName: $e');
      return RpcResult.networkError('Network error executing package action: $e');
    }
  }

  /// Backward compatible wrapper for managePackage
  Future<bool> managePackage({
    required String packageName,
    required String action,
  }) async {
    final res = await managePackageResult(packageName: packageName, action: action);
    return res.isSuccess;
  }

  /// Check and fetch upgradable packages returning classified RpcResult
  Future<RpcResult<List<OpenWrtPackage>>> fetchUpgradablePackagesResult() async {
    if (_reviewerModeEnabled) {
      return RpcResult.success([
        OpenWrtPackage(
          name: 'luci-app-firewall',
          version: 'git-23.332 ➔ git-24.010',
          description: 'Firewall management interface upgrade',
          isInstalled: true,
          managerType: PackageManagerEngine.opkg,
        ),
        OpenWrtPackage(
          name: 'dnsmasq',
          version: '2.89-1 ➔ 2.90-1',
          description: 'DHCP and DNS server security update',
          isInstalled: true,
          managerType: PackageManagerEngine.opkg,
        ),
      ]);
    }

    final engine = _capabilities?.packageEngine ?? PackageManagerEngine.opkg;
    if (engine == PackageManagerEngine.none) {
      return RpcResult.methodNotFound('No package manager detected on this router');
    }

    final isApk = engine == PackageManagerEngine.apk;
    final cmd = isApk ? 'apk' : 'opkg';
    final updateArgs = ['update'];
    final listArgs = isApk ? ['list', '--upgradable'] : ['list-upgradable'];

    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) {
      return RpcResult.networkError('No active router session');
    }
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    try {
      await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': cmd, 'args': updateArgs},
      );

      final rawRpc = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': cmd, 'args': listArgs},
      );

      final result = RpcResult.classifyExecResult<List<OpenWrtPackage>>(rawRpc, (data) {
        final output = data is Map ? (data['stdout']?.toString() ?? '') : '';
        if (output.trim().isEmpty) return <OpenWrtPackage>[];

        final upgradable = <OpenWrtPackage>[];
        for (final line in output.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('WARNING') || trimmed.startsWith('#')) continue;

          if (trimmed.contains(' - ')) {
            final parts = trimmed.split(' - ');
            final name = parts[0].trim();
            final oldVer = parts.length > 1 ? parts[1].trim() : '';
            final newVer = parts.length > 2 ? parts[2].trim() : '';
            upgradable.add(OpenWrtPackage(
              name: name,
              version: oldVer.isNotEmpty && newVer.isNotEmpty ? '$oldVer ➔ $newVer' : (newVer.isNotEmpty ? newVer : oldVer),
              description: 'Upgradable package ($name)',
              isInstalled: true,
              managerType: engine,
            ));
          } else {
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final name = parts[0].trim();
              upgradable.add(OpenWrtPackage(
                name: name,
                version: parts.length > 1 ? parts[1] : 'update available',
                description: 'Upgradable package ($name)',
                isInstalled: true,
                managerType: engine,
              ));
            }
          }
        }
        return upgradable;
      });

      if (result.status == RpcCallStatus.methodNotFound) {
        Logger.warning('Upgradable query returned methodNotFound. Triggering background capability re-probe.');
        unawaited(redetectCapabilities());
      }

      return result;
    } catch (e) {
      Logger.error('Failed to fetch upgradable packages: $e');
      return RpcResult.networkError('Network error checking package upgrades: $e');
    }
  }

  /// Backward compatible wrapper for fetchUpgradablePackages
  Future<List<OpenWrtPackage>> fetchUpgradablePackages() async {
    final res = await fetchUpgradablePackagesResult();
    return res.data ?? [];
  }

  /// Execute generic router shell command via file.exec RPC
  Future<bool> executeRouterCommand(String command, List<String> args) async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) return false;
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final cmdStr = command == 'sh' && args.length >= 2 && args[0] == '-c' ? args[1] : ([command, ...args]).join(' ');

    try {
      final res = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': command, 'args': args},
      );
      if (_isSuccessResponse(res)) return true;
    } catch (_) {}

    if (command != '/bin/sh' && command != 'sh') {
      try {
        final res = await _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {'command': '/bin/sh', 'args': ['-c', cmdStr]},
        );
        if (_isSuccessResponse(res)) return true;
      } catch (_) {}

      try {
        final res = await _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {'command': 'sh', 'args': ['-c', cmdStr]},
        );
        if (_isSuccessResponse(res)) return true;
      } catch (_) {}
    }

    return false;
  }

  bool _isSuccessResponse(dynamic res) {
    if (res == null) return false;
    if (res is List && res.isNotEmpty) {
      if (res[0] == 0) return true;
      if (res.length > 1 && res[1] is Map) {
        final map = res[1] as Map;
        return map['code'] == 0 || map.containsKey('stdout') || map.containsKey('data');
      }
    } else if (res is Map) {
      return res['code'] == 0 || res.containsKey('stdout') || res.containsKey('data');
    }
    return false;
  }

  String? _extractStdout(dynamic res) {
    if (res == null) return null;
    if (res is String) return res;

    if (res is List) {
      if (res.isEmpty) return null;
      for (final item in res) {
        if (item is Map) {
          final out = item['stdout'] ?? item['data'] ?? item['out'];
          if (out != null) return out.toString();
        } else if (item is String && item.isNotEmpty && item != '0') {
          return item;
        }
      }
    } else if (res is Map) {
      final out = res['stdout'] ?? res['data'] ?? res['out'];
      if (out != null) return out.toString();
      final result = res['result'];
      if (result != null) return _extractStdout(result);
    }
    return null;
  }

  /// Execute generic router shell command via file.exec or file.read RPC and return output String
  Future<String?> executeRouterCommandOutput(String command, List<String> args) async {
    final ip = _routerService?.selectedRouter?.ipAddress;
    if (ip == null || _authService?.sysauth == null) return null;
    final useHttps = _routerService?.selectedRouter?.useHttps ?? false;

    final cmdStr = command == 'sh' && args.length >= 2 && args[0] == '-c' ? args[1] : ([command, ...args]).join(' ');

    // 1. Direct exec
    try {
      final res = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {'command': command, 'args': args},
      );
      final out = _extractStdout(res);
      if (out != null && out.trim().isNotEmpty) return out;
    } catch (_) {}

    // 2. Shell exec fallbacks
    if (command != '/bin/sh' && command != 'sh') {
      try {
        final res = await _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {'command': '/bin/sh', 'args': ['-c', cmdStr]},
        );
        final out = _extractStdout(res);
        if (out != null && out.trim().isNotEmpty) return out;
      } catch (_) {}

      try {
        final res = await _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {'command': 'sh', 'args': ['-c', cmdStr]},
        );
        final out = _extractStdout(res);
        if (out != null && out.trim().isNotEmpty) return out;
      } catch (_) {}
    }

    // 3. File read fallback
    if ((command == 'cat' || command == 'base64') && args.isNotEmpty) {
      try {
        final readRes = await _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'file',
          method: 'read',
          params: {'path': args.last},
        );
        final out = _extractStdout(readRes);
        if (out != null && out.trim().isNotEmpty) return out;
      } catch (_) {}
    }

    return null;
  }

  Map<String, dynamic> _processDhcpLeases(Map<String, dynamic> rawDhcpData) {
    final rawStr = rawDhcpData['data']?.toString() ?? rawDhcpData['stdout']?.toString() ?? '';
    final leases = <Map<String, dynamic>>[];

    for (final line in rawStr.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts[0]) ?? 0;
        final macAddress = parts[1];
        final ipAddress = parts[2];
        final hostname = parts[3] == '*' ? 'Unknown' : parts[3];

        leases.add({
          'expires': timestamp,
          'macaddr': macAddress,
          'ipaddr': ipAddress,
          'hostname': hostname,
          'activetime': 0,
          'leasetime': timestamp,
        });
      }
    }

    return {'dhcp_leases': leases, 'leases': leases};
  }

  Map<String, dynamic>? _extractWanData(Map<String, dynamic>? interfaceDump) {
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
    } catch (e) {
      // print('WAN data extraction error: $e');
      return null;
    }
    return null;
  }

  String? _getDeviceNameForInterface(String interfaceName) {
    // Handle wireless format: "SSID (deviceName)"
    if (interfaceName.contains('(')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceName);
      return match?.group(1);
    }
    
    // Map interface names to their actual device names from interface dump
    final interfaceDump = _dashboardData?['interfaceDump'] as Map<String, dynamic>?;
    if (interfaceDump != null && interfaceDump['interface'] is List) {
      for (final interface in interfaceDump['interface']) {
        if (interface is Map<String, dynamic>) {
          final ifname = interface['interface'] as String?;
          if (ifname == interfaceName) {
            // Return the device or l3_device field
            return (interface['device'] ?? interface['l3_device']) as String?;
          }
        }
      }
    }
    
    // If not found in interface dump, check if it's already a device name
    // (e.g., eth0, br-lan, wlan0)
    return interfaceName;
  }

  void setThroughputInterval(int seconds) {
    final clamped = seconds.clamp(1, 10);
    if (_throughputIntervalSeconds != clamped) {
      _throughputIntervalSeconds = clamped;
      _startThroughputTimer();
      notifyListeners();
    }
  }

  void _startThroughputTimer() {
    _throughputTimer?.cancel();
    // Don't start timer if we're rebooting
    if (_isRebooting) {
      return;
    }
    _throughputTimer = Timer.periodic(Duration(seconds: _throughputIntervalSeconds), (timer) {
      _updateThroughputOnly();
    });
  }

  /// Updates only throughput data without refetching the entire dashboard
  Future<void> _updateThroughputOnly() async {
    // Don't try to update throughput during reboot
    if (_isRebooting) {
      return;
    }

    if (_reviewerModeEnabled) {
      // For reviewer mode, get network devices data only
      try {
        final result = await _apiService!.callSimple('network', 'device', {});
        final networkData = result[1] as Map<String, dynamic>?;
        final wanDeviceNames = {'eth0'}; // Mock WAN device

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Extract device name from interface ID (format: "SSID (deviceName)" or just "deviceName")
          final interfaceId = prefs.primaryThroughputInterface!;
          if (interfaceId.contains('(')) {
            // Wireless format: "SSID (deviceName)"
            final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceId);
            specificInterface = match?.group(1);
          } else {
            // Wired format: just device name
            specificInterface = interfaceId;
          }
        }

        _throughputService?.updateThroughput(
          networkData,
          wanDeviceNames,
          specificInterface: specificInterface,
        );
        notifyListeners();
      } catch (e) {
        // Don't log throughput update errors as they're non-critical
      }
      return;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return;
    }

    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    try {
      // Only fetch network devices for throughput calculation
      final result = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'luci-rpc',
        method: 'getNetworkDevices',
        params: {},
      );

      if (result is List && result.length > 1 && result[0] == 0) {
        final networkData = result[1] as Map<String, dynamic>?;

        // Get ALL device names from cached dashboard data (except loopback)
        final wanDeviceNames = <String>{};
        final interfaceDump =
            _dashboardData?['interfaceDump'] as Map<String, dynamic>?;
        if (interfaceDump != null && interfaceDump['interface'] is List) {
          for (final interface in interfaceDump['interface']) {
            if (interface is Map<String, dynamic>) {
              final ifname = interface['interface'] as String?;
              final device = interface['device'] as String?;
              final l3Device = interface['l3_device'] as String?;
              // Include all interfaces except loopback
              if (ifname != null && ifname != 'loopback' && ifname != 'lo') {
                if (device != null) wanDeviceNames.add(device);
                if (l3Device != null && l3Device != device) {
                  wanDeviceNames.add(l3Device);
                }
              }
            }
          }
        }

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Extract device name from interface ID (format: "SSID (deviceName)" or just "deviceName")
          final interfaceId = prefs.primaryThroughputInterface!;
          if (interfaceId.contains('(')) {
            // Wireless format: "SSID (deviceName)"
            final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceId);
            specificInterface = match?.group(1);
          } else {
            // Wired format: just device name
            specificInterface = interfaceId;
          }
        }

        _throughputService?.updateThroughput(
          networkData,
          wanDeviceNames,
          specificInterface: specificInterface,
        );
        notifyListeners();
      }
    } catch (e) {
      // Don't log throughput update errors as they're non-critical
    }
  }

  void _cancelThroughputTimer() {
    _throughputTimer?.cancel();
    _throughputService?.clear();
  }

  Future<bool> reboot({BuildContext? context}) async {
    if (_authService?.sysauth == null || _authService?.ipAddress == null) {
      return false;
    }

    // Cancel throughput timer before starting reboot to prevent "client closed" errors
    _cancelThroughputTimer();

    _isRebooting = true;
    notifyListeners();

    try {
      final result = await _apiService!.reboot(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        context: context,
      );
      // Wait 30 seconds before starting to poll for router availability
      // Some routers take longer to reboot
      Future.delayed(const Duration(seconds: 30), () {
        _pollRouterAvailability();
      });
      return result;
    } catch (e) {
      _isRebooting = false;
      notifyListeners();
      return false;
    }
  }

  void _pollRouterAvailability() {
    // Reset poll attempts
    _pollAttempts = 0;
    _pollingTimer?.cancel();

    // Start polling with exponential backoff
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (_pollAttempts >= _maxPollAttempts) {
      // Max attempts reached, stop polling
      _isRebooting = false;
      notifyListeners();
      // print('[Reboot] Timeout: Router did not come back online after $_maxPollAttempts attempts');

      // Show a user-friendly message
      if (onRouterBackOnline != null) {
        // Reuse the callback to show timeout message
        onRouterBackOnline!();
      }
      return;
    }

    // Calculate delay with exponential backoff: 3s, 3s, 5s, 8s, 12s, 18s, then 20s intervals
    int delaySeconds;
    if (_pollAttempts < 2) {
      delaySeconds = 3;
    } else if (_pollAttempts < 4) {
      delaySeconds = 5;
    } else if (_pollAttempts < 6) {
      delaySeconds = 8;
    } else if (_pollAttempts < 8) {
      delaySeconds = 12;
    } else if (_pollAttempts < 10) {
      delaySeconds = 18;
    } else {
      delaySeconds = 20; // Cap at 20 seconds for remaining attempts
    }

    _pollingTimer = Timer(Duration(seconds: delaySeconds), () async {
      _pollAttempts++;
      final available = await _pingRouter();

      if (available) {
        // Router is back online
        _pollingTimer?.cancel();
        _pollingTimer = null;
        _isRebooting = false;
        _pollAttempts = 0;
        notifyListeners();

        // Notify UI that router is back online
        if (onRouterBackOnline != null) {
          onRouterBackOnline!();
        }

        // Force relogin
        if (_routerService?.selectedRouter != null) {
          await login(
            _routerService!.selectedRouter!.ipAddress,
            _routerService!.selectedRouter!.username,
            _routerService!.selectedRouter!.password,
            _routerService!.selectedRouter!.useHttps,
          );
        }
      } else {
        // Schedule next poll
        _scheduleNextPoll();
      }
    });
  }

  Future<bool> _pingRouter() async {
    if (_authService?.ipAddress == null) return false;

    // Clear cached HTTP clients for this host to avoid stale connections
    if (_pollAttempts == 0) {
      _httpClientManager.disposeClient(
        _authService!.ipAddress!,
        _authService!.useHttps,
      );
    }

    // Try multiple endpoints in order
    final scheme = _authService!.useHttps ? 'https' : 'http';
    final endpoints = [
      '/', // Root
      '/cgi-bin/luci/', // LuCI login page
      '/cgi-bin/luci/admin', // Admin page
    ];

    for (final endpoint in endpoints) {
      try {
        final url = '$scheme://${_authService!.ipAddress}$endpoint';

        // Create a fresh Dio client for pinging to avoid certificate/connection issues
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
            followRedirects: false,
            validateStatus: (code) => code != null && code >= 200 && code < 500,
          ),
        );

        if (_authService!.useHttps) {
          final adapter = IOHttpClientAdapter();
          adapter.createHttpClient = () {
            final httpClient = HttpClient();
            httpClient.connectionTimeout = const Duration(seconds: 5);
            // Accept any cert for ping only
            httpClient.badCertificateCallback = (cert, host, port) => true;
            return httpClient;
          };
          dio.httpClientAdapter = adapter;
        }

        // print('[Ping] Attempt $_pollAttempts: Checking $url');
        final response = await dio.get(url);
        // print('[Ping] Response from $endpoint: ${response.statusCode}');

        // Accept various status codes as "alive"
        final isAlive = response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 500;

        if (isAlive) {
          if (_pollAttempts > 5) {
            // If we've been polling for a while and get a response,
            // wait a bit more to ensure services are fully started
            await Future.delayed(const Duration(seconds: 5));
          }
          return true;
        }
      } catch (e) {
        // Try next endpoint
        if (endpoint == endpoints.last) {
          // print('[Ping] All endpoints failed on attempt $_pollAttempts');
          // print('[Ping] Last error: ${e.toString()}');

          if (e is SocketException) {
            // print('[Ping] Socket error: ${e.message}, OS Error: ${e.osError}');
          } else if (e is HandshakeException) {
            // print('[Ping] SSL handshake error - router may still be starting');
          }
        }
      }
    }

    return false;
  }

  Future<bool> checkRouterAvailability() async {
    if (_reviewerModeEnabled || _authService?.ipAddress == null) {
      return _reviewerModeEnabled;
    }
    return await _authService!.checkRouterAvailability(
      _authService!.ipAddress!,
      _authService!.useHttps,
    );
  }

  Future<bool> setWirelessRadioState(
    String device,
    bool enabled, {
    BuildContext? context,
  }) async {
    if (_reviewerModeEnabled) {
      // Simulate operation for reviewer mode
      await Future.delayed(const Duration(milliseconds: 500));
      await fetchDashboardData();
      return true;
    }

    if (_authService?.sysauth == null || _authService?.ipAddress == null) {
      return false;
    }

    try {
      // 1. Set the disabled state
      await _apiService!.uciSet(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        config: 'wireless',
        section: device,
        values: {'disabled': enabled ? '0' : '1'},
        context: context,
      );

      // 2. Commit the changes
      await _apiService!.uciCommit(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        config: 'wireless',
        context: context?.mounted == true ? context : null,
      );

      // 3. Reload wifi to apply changes
      await _apiService!.systemExec(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        command: 'wifi reload',
        context: context?.mounted == true ? context : null,
      );

      // Refresh dashboard data to reflect the change
      await fetchDashboardData();

      return true;
    } catch (e) {
      _dashboardError = 'Failed to toggle Wi-Fi: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> tryAutoLogin({BuildContext? context}) async {
    if (_reviewerModeEnabled) {
      return await _authService!.tryAutoLogin(
        null,
        null,
        null,
        null,
        context: context,
      );
    }
    return await _authService?.tryAutoLogin(
          null,
          null,
          null,
          null,
          context: context,
        ) ??
        false;
  }

  /// Fetch all associated wireless MAC addresses from all wireless interfaces
  Future<Set<String>> fetchAllAssociatedWirelessMacs() async {
    if (_reviewerModeEnabled) {
      // Use the interface method for mock/reviewer mode
      final stationsMap = await _apiService!.fetchAssociatedStations();
      final macs = <String>{};
      stationsMap.forEach((_, stations) {
        macs.addAll(stations.map((m) => m.toLowerCase()));
      });
      return macs;
    } else {
      // Use the context-aware method for real API calls
      if (_routerService?.selectedRouter == null ||
          _authService?.sysauth == null) {
        return {};
      }

      final ip = _routerService!.selectedRouter!.ipAddress;
      final useHttps = _routerService!.selectedRouter!.useHttps;

      final stationsMap = await _apiService!
          .fetchAllAssociatedWirelessMacsWithContext(
            ipAddress: ip,
            sysauth: _authService!.sysauth!,
            useHttps: useHttps,
          );
      final macs = <String>{};
      stationsMap.forEach((_, stations) {
        macs.addAll(stations.map((m) => m.toLowerCase()));
      });

      // Also include configured wireless maclist entries from dashboard data
      final wirelessConfig = _dashboardData?['uciWirelessConfig'] ?? _dashboardData?['wireless'];
      if (wirelessConfig is Map<String, dynamic>) {
        wirelessConfig.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            final maclist = v['maclist'] ?? v['config']?['maclist'];
            if (maclist is List) {
              for (final item in maclist) {
                if (item != null && item.toString().isNotEmpty) {
                  macs.add(item.toString().toLowerCase());
                }
              }
            }
          }
        });
      }

      return macs;
    }
  }

  @override
  void dispose() {
    _throughputTimer?.cancel();
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    _isRebooting = false;
    super.dispose();
  }

  /// Aggregates DHCP leases across all configured routers and classifies clients
  /// as wireless if their MAC appears in any router's associated stations list.
  Future<List<Client>> fetchAggregatedClients() async {
    try {
      final clientsMap = <String, Client>{};
      final routers = _routerService?.routers ?? [];
      for (final router in routers) {
        final routerClients = await _fetchClientsForRouter(router);
        for (final c in routerClients) {
          final macNorm = c.macAddress.toUpperCase().replaceAll('-', ':');
          if (!clientsMap.containsKey(macNorm) || (c.isConnected && !clientsMap[macNorm]!.isConnected)) {
            clientsMap[macNorm] = c;
          }
        }
      }
      final list = clientsMap.values.toList();
      list.sort((a, b) {
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      return list;
    } catch (e, stack) {
      Logger.exception('Failed to aggregate clients', e, stack);
      return [];
    }
  }

  /// Returns clients for the currently selected router only
  Future<List<Client>> fetchClientsForSelectedRouter() async {
    try {
      if (_reviewerModeEnabled) {
        final stationsMap = await _apiService!.fetchAssociatedStations();
        final macs = <String>{};
        stationsMap.forEach((_, stations) {
          macs.addAll(stations.map((m) => m.toLowerCase()));
        });
        final result = await _apiService!.callSimple(
          'luci-rpc',
          'getDHCPLeases',
          {},
        );
        final leases = <Map<String, dynamic>>[];
        if (result is List && result.length > 1 && result[0] == 0) {
          final data = result[1] as Map<String, dynamic>;
          leases.addAll(
            (data['dhcp_leases'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>(),
          );
        }
        // Normalize wireless MACs for consistent lookup
        final normalizedMacs = macs
            .map((m) => m.toUpperCase().replaceAll('-', ':'))
            .toSet();
        final clientMap = <String, Client>{};
        for (final l in leases) {
          final c = Client.fromLease(l);
          final macNorm = c.macAddress.toUpperCase().replaceAll('-', ':');
          final isWireless = normalizedMacs.contains(macNorm);
          clientMap[macNorm] = isWireless
              ? c.copyWith(connectionType: ConnectionType.wireless)
              : c;
        }
        // Add wireless stations not in DHCP leases (AP-mode fallback)
        for (final mac in normalizedMacs) {
          if (!clientMap.containsKey(mac)) {
            clientMap[mac] = Client.fromWirelessStation(mac);
          }
        }
        final reviewerClients = clientMap.values.toList();
        reviewerClients.sort((a, b) {
          int typeOrder(ConnectionType t) {
            switch (t) {
              case ConnectionType.wireless:
                return 0;
              case ConnectionType.wired:
                return 1;
              default:
                return 2;
            }
          }
          final cmpType =
              typeOrder(a.connectionType).compareTo(typeOrder(b.connectionType));
          if (cmpType != 0) return cmpType;
          return a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase());
        });
        return reviewerClients;
      }

      if (_routerService?.selectedRouter == null || _authService?.sysauth == null) {
        return [];
      }
      return await _fetchClientsForRouter(_routerService!.selectedRouter!);
    } catch (e, stack) {
      Logger.exception('Failed to fetch clients for selected router', e, stack);
      return [];
    }
  }

  Future<List<Client>> _fetchClientsForRouter(model.Router router) async {
    try {
      String normMac(String mac) => mac
          .trim()
          .toUpperCase()
          .replaceAll('-', ':')
          .split(':')
          .map((b) => b.length == 1 ? '0$b' : b)
          .join(':');

      // 1. Fetch live associated wireless stations (strict check for Wi-Fi tags)
      final stationsMap = await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
        ipAddress: router.ipAddress,
        sysauth: _authService!.sysauth!,
        useHttps: router.useHttps,
      );
      final macToSsidMap = <String, String>{};
      final wireless = <String>{};
      stationsMap.forEach((ifnameOrSsid, s) {
        for (final m in s) {
          final n = normMac(m);
          wireless.add(n);
          macToSsidMap[n] = ifnameOrSsid;
        }
      });

      // Fallback: Shell station dump if station map is empty
      if (wireless.isEmpty) {
        final iwDevOut = await executeRouterCommandOutput('iw', ['dev']);
        final ifaces = <String>[];
        if (iwDevOut != null && iwDevOut.isNotEmpty) {
          for (final line in iwDevOut.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.startsWith('Interface ')) {
              ifaces.add(trimmed.substring(10).trim());
            }
          }
        }
        if (ifaces.isEmpty) {
          ifaces.addAll(['wlan0', 'wlan1', 'phy0-ap0', 'phy1-ap0', 'phy2-ap0', 'ra0']);
        }
        for (final iface in ifaces) {
          final iwDump = await executeRouterCommandOutput('iw', ['dev', iface, 'station', 'dump']) ??
              await executeRouterCommandOutput('iwinfo', [iface, 'assoclist']);
          if (iwDump != null && iwDump.isNotEmpty) {
            final macRegex = RegExp(r'([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})');
            for (final match in macRegex.allMatches(iwDump)) {
              final m = match.group(0);
              if (m != null) {
                wireless.add(normMac(m));
              }
            }
          }
        }
      }
      final normalizedWireless = wireless.map(normMac).toSet();

      // 2. Fetch getDHCPLeases from luci-rpc (returns dhcp_leases & dhcp6_leases)
      final callRes = await _apiService!.call(
        router.ipAddress,
        _authService!.sysauth!,
        router.useHttps,
        object: 'luci-rpc',
        method: 'getDHCPLeases',
        params: {},
      );
      final dhcp4Leases = <Map<String, dynamic>>[];
      final dhcp6Leases = <Map<String, dynamic>>[];
      if (callRes is List && callRes.length > 1 && callRes[0] == 0) {
        final data = callRes[1] as Map<String, dynamic>;
        if (data['dhcp_leases'] is List) {
          dhcp4Leases.addAll((data['dhcp_leases'] as List).cast<Map<String, dynamic>>());
        }
        if (data['dhcp6_leases'] is List) {
          dhcp6Leases.addAll((data['dhcp6_leases'] as List).cast<Map<String, dynamic>>());
        }
      }

      // If DHCP leases are empty, attempt direct file read fallback (/tmp/dhcp.leases or /var/dhcp.leases)
      if (dhcp4Leases.isEmpty) {
        final rawLeaseStr = await executeRouterCommandOutput('cat', ['/tmp/dhcp.leases']) ??
            await executeRouterCommandOutput('cat', ['/var/dhcp.leases']) ??
            await executeRouterCommandOutput('cat', ['/tmp/dnsmasq.leases']);
        if (rawLeaseStr != null && rawLeaseStr.isNotEmpty) {
          final processed = _processDhcpLeases({'data': rawLeaseStr});
          if (processed['dhcp_leases'] is List) {
            dhcp4Leases.addAll((processed['dhcp_leases'] as List).cast<Map<String, dynamic>>());
          }
        }
      }

      // 3. Fetch neighbor table via `ip neigh show` for NUD-state-aware wired client detection.
      // Unlike /proc/net/arp (which can't distinguish REACHABLE from STALE), ip neigh
      // explicitly reports NUD states: REACHABLE, STALE, DELAY, PROBE, FAILED, INCOMPLETE.
      final neighClients = <Map<String, dynamic>>[];
      bool usedIpNeigh = false;
      try {
        final neighStr = await executeRouterCommandOutput('ip', ['neigh', 'show']);
        if (neighStr != null && neighStr.trim().isNotEmpty) {
          usedIpNeigh = true;
          for (final line in neighStr.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            // Format: <IP> dev <DEV> lladdr <MAC> <NUD_STATE>
            // or:     <IP> dev <DEV> <NUD_STATE>  (no lladdr when FAILED/INCOMPLETE)
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.length < 4) continue;
            final ip = parts[0];
            final dev = parts.length > 2 ? parts[2] : '';
            String? mac;
            String nudState = parts.last.toUpperCase();
            final llIdx = parts.indexOf('lladdr');
            if (llIdx >= 0 && llIdx + 1 < parts.length) {
              mac = parts[llIdx + 1];
            }
            if (mac == null || !mac.contains(':')) continue;
            if (mac == '00:00:00:00:00:00') continue;
            neighClients.add({
              'ipaddr': ip,
              'macaddr': normMac(mac),
              'device': dev,
              'nud_state': nudState,
            });
          }
        }
      } catch (_) {}

      // Fallback: /proc/net/arp for firmware without iproute2 (pre-18.06).
      // KNOWN LIMITATION: Cannot distinguish REACHABLE from STALE — all non-incomplete
      // entries show as flags=0x2. Clients may appear "active" for minutes after disconnect.
      if (!usedIpNeigh || neighClients.isEmpty) {
        try {
          final arpStr = await executeRouterCommandOutput('cat', ['/proc/net/arp']);
          if (arpStr != null && arpStr.isNotEmpty) {
            for (final line in arpStr.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isEmpty || trimmed.startsWith('IP address') || trimmed.startsWith('IP')) continue;
              final parts = trimmed.split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                final ip = parts[0];
                final flags = parts[2];
                final mac = parts[3];
                final dev = parts.length >= 6 ? parts[5] : '';
                if (mac != '00:00:00:00:00:00' && mac.contains(':') && flags != '0x0') {
                  neighClients.add({
                    'ipaddr': ip,
                    'macaddr': normMac(mac),
                    'device': dev,
                    'nud_state': 'UNKNOWN', // /proc/net/arp can't distinguish REACHABLE from STALE
                  });
                }
              }
            }
          }
        } catch (_) {}
      }

      // 4. Fetch Host Hints dictionary (UCI static leases + luci-rpc hostHints)
      final hostHints = await _apiService!.fetchHostHintsWithContext(
        ipAddress: router.ipAddress,
        sysauth: _authService!.sysauth!,
        useHttps: router.useHttps,
      );

      // Extract router's own IPs and MAC addresses for self-filtering
      final routerIps = <String>{router.ipAddress, '127.0.0.1', '0.0.0.0'};
      final routerMacs = <String>{};

      // Fetch network device status from router to extract all router interface MACs
      try {
        final devRes = await _apiService!.call(
          router.ipAddress,
          _authService!.sysauth!,
          router.useHttps,
          object: 'network.device',
          method: 'status',
          params: {},
        );
        if (devRes is List && devRes.length > 1 && devRes[0] == 0 && devRes[1] is Map) {
          final devs = devRes[1] as Map<String, dynamic>;
          devs.forEach((devName, devData) {
            if (devData is Map && devData['macaddr'] != null) {
              final m = normMac(devData['macaddr'].toString());
              if (m.isNotEmpty && m != '00:00:00:00:00:00') {
                routerMacs.add(m);
              }
            }
          });
        }
      } catch (_) {}

      hostHints.forEach((mac, info) {
        final m = normMac(mac);
        final ipaddrs = info['ipaddrs'] as List?;
        if (ipaddrs != null && ipaddrs.contains(router.ipAddress)) {
          routerMacs.add(m);
          for (final ip in ipaddrs) {
            routerIps.add(ip.toString());
          }
        }
      });

      final clientMap = <String, Client>{};

      // A. Process IPv4 DHCP leases
      for (final l in dhcp4Leases) {
        final c = Client.fromLease(l);
        final macN = normMac(c.macAddress);
        if (macN.isEmpty || macN == 'N/A' || macN == '00:00:00:00:00:00') continue;

        var hostname = c.hostname;
        if ((hostname == 'Unknown' || hostname.isEmpty) && hostHints.containsKey(macN)) {
          final hintName = hostHints[macN]?['name']?.toString();
          if (hintName != null && hintName.isNotEmpty && hintName != '*') {
            hostname = hintName;
          }
        }

        final staticName = hostHints[macN]?['staticLeaseName']?.toString();
        final isWireless = normalizedWireless.contains(macN);
        final foundSsid = macToSsidMap[macN];

        final hintV6 = hostHints[macN]?['ip6addrs'] as List?;
        final v6List = (hintV6 != null && hintV6.isNotEmpty)
            ? hintV6.map((e) => e.toString()).toList()
            : c.ipv6Addresses;

        clientMap[macN] = c.copyWith(
          hostname: hostname,
          connectionType: isWireless ? ConnectionType.wireless : ConnectionType.wired,
          ssid: foundSsid,
          staticLeaseName: staticName,
          ipv6Addresses: v6List,
        );
      }

      // B. Process IPv6 DHCP leases & consolidate under existing client or new entry
      for (final l in dhcp6Leases) {
        final macRaw = l['macaddr']?.toString() ?? l['mac']?.toString() ?? '';
        final macN = macRaw.isNotEmpty ? normMac(macRaw) : '';
        final hostname = l['hostname']?.toString();

        List<String> v6Addrs = [];
        if (l['ip6addrs'] is List) {
          v6Addrs = (l['ip6addrs'] as List).map((e) => e.toString()).toList();
        } else if (l['ip6addr'] != null) {
          v6Addrs = [l['ip6addr'].toString()];
        }

        if (macN.isNotEmpty && clientMap.containsKey(macN)) {
          final existing = clientMap[macN]!;
          final mergedV6 = <String>{...?(existing.ipv6Addresses), ...v6Addrs}.toList();
          clientMap[macN] = existing.copyWith(ipv6Addresses: mergedV6);
        } else {
          String? matchedMac;
          if (macN.isNotEmpty) {
            matchedMac = macN;
          } else {
            hostHints.forEach((hMac, info) {
              if (matchedMac != null) return;
              final hName = info['name']?.toString();
              if (hostname != null && hostname.isNotEmpty && hName != null &&
                  (hName == hostname || hName == '$hostname.lan')) {
                matchedMac = normMac(hMac);
              }
            });
          }

          if (matchedMac != null && matchedMac!.isNotEmpty) {
            if (clientMap.containsKey(matchedMac)) {
              final existing = clientMap[matchedMac]!;
              final mergedV6 = <String>{...?(existing.ipv6Addresses), ...v6Addrs}.toList();
              clientMap[matchedMac!] = existing.copyWith(ipv6Addresses: mergedV6);
            } else {
              final isWireless = normalizedWireless.contains(matchedMac!);
              final staticName = hostHints[matchedMac]?['staticLeaseName']?.toString();
              clientMap[matchedMac!] = Client(
                ipAddress: 'N/A',
                macAddress: matchedMac!,
                hostname: (hostname != null && hostname.isNotEmpty) ? hostname : matchedMac!,
                connectionType: isWireless ? ConnectionType.wireless : ConnectionType.wired,
                ssid: macToSsidMap[matchedMac],
                staticLeaseName: staticName,
                ipv6Addresses: v6Addrs,
              );
            }
          }
        }
      }

      // C. Merge Static Leases configured on router that have no active dynamic lease yet
      hostHints.forEach((mac, info) {
        final macN = normMac(mac);
        if (!clientMap.containsKey(macN)) {
          final hintName = info['name']?.toString();
          final staticName = info['staticLeaseName']?.toString();
          final ipaddrs = info['ipaddrs'] as List?;
          final ip = (ipaddrs != null && ipaddrs.isNotEmpty) ? ipaddrs.first.toString() : 'N/A';
          final name = (hintName != null && hintName.isNotEmpty && hintName != '*') ? hintName : macN;
          final isWireless = normalizedWireless.contains(macN);
          final hintV6 = info['ip6addrs'] as List?;
          final v6List = (hintV6 != null && hintV6.isNotEmpty)
              ? hintV6.map((e) => e.toString()).toList()
              : null;

          clientMap[macN] = Client(
            ipAddress: ip,
            macAddress: macN,
            hostname: name,
            connectionType: isWireless ? ConnectionType.wireless : ConnectionType.wired,
            ssid: macToSsidMap[macN],
            staticLeaseName: staticName,
            ipv6Addresses: v6List,
          );
        }
      });

      // D. Final pass: Compute active connection status, populate IP fallback, strict Wi-Fi tag assignment & self-filtering
      final processedClients = <Client>[];
      final sysHostname = (router.lastKnownHostname ?? '').trim().toLowerCase();

      for (final c in clientMap.values) {
        final macN = normMac(c.macAddress);

        // Filter out router's own IP / MAC interfaces / hostname
        if (routerMacs.contains(macN) || routerIps.contains(c.ipAddress)) {
          continue;
        }
        if (sysHostname.isNotEmpty) {
          final nameLower = c.displayName.trim().toLowerCase();
          if (nameLower == sysHostname || nameLower == '$sysHostname.lan') {
            continue;
          }
        }

        // Populate IPv4 address from hostHints or neighbor table if currently 'N/A' or empty
        var resolvedIp = c.ipAddress;
        if ((resolvedIp == 'N/A' || resolvedIp.isEmpty) && hostHints.containsKey(macN)) {
          final hintIps = hostHints[macN]?['ipaddrs'] as List?;
          if (hintIps != null && hintIps.isNotEmpty) {
            resolvedIp = hintIps.first.toString();
          }
          if ((resolvedIp == 'N/A' || resolvedIp.isEmpty) && hostHints[macN]?['staticLeaseIp'] != null) {
            resolvedIp = hostHints[macN]!['staticLeaseIp'].toString();
          }
        }
        if (resolvedIp == 'N/A' || resolvedIp.isEmpty) {
          final neighMatch = neighClients.firstWhere(
            (a) => normMac(a['macaddr'] as String) == macN,
            orElse: () => <String, dynamic>{},
          );
          if (neighMatch.containsKey('ipaddr')) {
            resolvedIp = neighMatch['ipaddr']?.toString() ?? 'N/A';
          }
        }

        final isWirelessActive = normalizedWireless.contains(macN);

        // Find the neighbor entry for this MAC on a non-wireless device
        Map<String, dynamic>? wiredNeighEntry;
        for (final a in neighClients) {
          final aMac = normMac(a['macaddr'] as String);
          if (aMac != macN) continue;
          final dev = (a['device'] as String? ?? '').toLowerCase();
          final isWlanDev = dev.startsWith('wlan') || dev.startsWith('phy') || dev.startsWith('ra') || dev.startsWith('wifi') || dev.startsWith('ath');
          if (!isWlanDev) {
            wiredNeighEntry = a;
            break;
          }
        }

        // Map NUD state string to NeighborReachability enum
        NeighborReachability neighState;
        if (isWirelessActive) {
          // Wireless clients are confirmed live by radio association — always reachable
          neighState = NeighborReachability.reachable;
        } else if (wiredNeighEntry != null) {
          final nud = (wiredNeighEntry['nud_state'] as String? ?? '').toUpperCase();
          switch (nud) {
            case 'REACHABLE':
            case 'DELAY':
            case 'PROBE':
              neighState = NeighborReachability.reachable;
              break;
            case 'STALE':
              neighState = NeighborReachability.stale;
              break;
            case 'FAILED':
            case 'INCOMPLETE':
            case 'NOARP':
              neighState = NeighborReachability.failed;
              break;
            case 'UNKNOWN':
              // /proc/net/arp fallback — can't distinguish REACHABLE from STALE
              neighState = NeighborReachability.unknown;
              break;
            default:
              neighState = NeighborReachability.unknown;
          }
        } else {
          // No neighbor entry at all — device is not on the network
          neighState = NeighborReachability.failed;
        }

        // Connected = actively associated on Wi-Fi OR present in neighbor table (any non-FAILED state)
        final isConnected = isWirelessActive ||
            (wiredNeighEntry != null && neighState != NeighborReachability.failed);

        // Filter out nameless entries with no IPv4, only link-local (fe80::) IPv6, and disconnected
        final hasValidIp = resolvedIp != 'N/A' && resolvedIp.isNotEmpty;
        final hasGlobalV6 = c.ipv6Addresses != null &&
            c.ipv6Addresses!.any((addr) => !addr.toLowerCase().startsWith('fe80:'));
        final hasName = (c.staticLeaseName != null && c.staticLeaseName!.isNotEmpty) ||
            (c.hostname != 'Unknown' && c.hostname.isNotEmpty && c.hostname != macN);

        if (!hasValidIp && !hasGlobalV6 && !hasName && !isConnected) {
          continue;
        }

        // Strictly assign ConnectionType.wireless ONLY if connected through a wireless radio
        final finalConnType = isWirelessActive ? ConnectionType.wireless : ConnectionType.wired;

        final isLeaseExpired = c.leaseTime != null && c.leaseTime! < 0;
        final isStaticLease = hostHints[macN]?['isStaticLease'] == true ||
            (c.staticLeaseName != null && c.staticLeaseName!.isNotEmpty);

        if (isConnected || !isLeaseExpired || isStaticLease) {
          processedClients.add(c.copyWith(
            ipAddress: resolvedIp,
            isConnected: isConnected,
            neighState: neighState,
            connectionType: finalConnType,
          ));
        }
      }

      // Sort: Connected clients first, then alphabetically by display name
      processedClients.sort((a, b) {
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

      return processedClients;
    } catch (e, stack) {
      Logger.exception('Failed to fetch clients for selected router', e, stack);
      return [];
    }
  }

  /// Returns a union set of associated wireless MAC addresses across all routers
  Future<Set<String>> fetchAllAssociatedWirelessMacsAggregated() async {
    try {
      if (_reviewerModeEnabled) {
        final stationsMap = await _apiService!.fetchAssociatedStations();
        final macs = <String>{};
        stationsMap.forEach((_, stations) {
          macs.addAll(stations.map((m) => m.toLowerCase()));
        });
        return macs;
      }

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return {};

      final tasks = routers.map((r) async {
        try {
          if (_apiService is RealApiService) {
            final real = _apiService as RealApiService;
            final res = await real.loginWithProtocolDetection(
              r.ipAddress,
              r.username,
              r.password,
              r.useHttps,
            );
            if (res.token == null) return <String>{};
            final map = await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
              ipAddress: r.ipAddress,
              sysauth: res.token!,
              useHttps: res.actualUseHttps,
            );
            final set = <String>{};
            map.forEach((_, stations) {
              set.addAll(stations.map((m) => m.toLowerCase()));
            });
            return set;
          }
        } catch (e) {
          // Skip router on failure
        }
        return <String>{};
      }).toList();

      final results = await Future.wait(tasks);
      return results.fold<Set<String>>(<String>{}, (acc, s) => acc..addAll(s));
    } catch (e, stack) {
      Logger.exception('Failed to aggregate wireless MACs', e, stack);
      return {};
    }
  }

  /// Returns a combined list of DHCP lease maps from all routers
  Future<List<Map<String, dynamic>>> fetchAggregatedDhcpLeases() async {
    try {
      if (_reviewerModeEnabled) {
        // Use mock data
        final result = await _apiService!.callSimple('luci-rpc', 'getDHCPLeases', {});
        if (result is List && result.length > 1 && result[0] == 0) {
          final data = result[1] as Map<String, dynamic>;
          final leases = (data['dhcp_leases'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          return leases;
        }
        return [];
      }

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return [];

      final tasks = routers.map((r) async {
        try {
          if (_apiService is RealApiService) {
            final real = _apiService as RealApiService;
            final res = await real.loginWithProtocolDetection(
              r.ipAddress,
              r.username,
              r.password,
              r.useHttps,
            );
            if (res.token == null) return <Map<String, dynamic>>[];
            final callRes = await _apiService!.call(
              r.ipAddress,
              res.token!,
              res.actualUseHttps,
              object: 'luci-rpc',
              method: 'getDHCPLeases',
              params: {},
            );
            if (callRes is List && callRes.length > 1 && callRes[0] == 0) {
              final data = callRes[1] as Map<String, dynamic>;
              final leases = (data['dhcp_leases'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();
              return leases;
            }
          }
        } catch (e) {
          // Skip router on failure
        }
        return <Map<String, dynamic>>[];
      }).toList();

      final results = await Future.wait(tasks);
      // Deduplicate by MAC + IP
      final seen = <String, Map<String, dynamic>>{};
      for (final list in results) {
        for (final lease in list) {
          final mac = (lease['macaddr']?.toString() ?? '').toUpperCase();
          final ip = lease['ipaddr']?.toString() ?? '';
          final key = '$mac|$ip';
          if (!seen.containsKey(key)) {
            seen[key] = lease;
          }
        }
      }
      return seen.values.toList();
    } catch (e, stack) {
      Logger.exception('Failed to aggregate DHCP leases', e, stack);
      return [];
    }
  }
}
