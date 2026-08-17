// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/models/dashboard_preferences.dart';
import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/services/router_service.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/services/service_factory.dart';
import 'package:luci_mobile/state/controllers/dashboard_controller.dart';
import 'package:luci_mobile/utils/http_client_manager.dart';
import 'package:luci_mobile/utils/logger.dart';

/// Encapsulates authentication session lifecycle, router profile selection,
/// preference storage, theme persistence, and reviewer mode configuration.
///
/// Extracted from [AppState] to enforce single-responsibility.
class SessionController {
  SessionController({
    required IApiService? Function() apiServiceRef,
    required IAuthService? Function() authServiceRef,
    required RouterService? Function() routerServiceRef,
    required SecureStorageService Function() secureStorageServiceRef,
    required HttpClientManager Function() httpClientManagerRef,
    required DashboardController? Function() dashboardControllerRef,
    required void Function() cancelThroughputTimer,
    required void Function() startThroughputTimer,
    required Future<void> Function() fetchDashboardData,
    required void Function() initializeServices,
    required void Function(bool isLoading) setLoadingState,
    required void Function(String? error) setErrorState,
    required VoidCallback notifyListeners,
  })  : _apiServiceRef = apiServiceRef,
        _authServiceRef = authServiceRef,
        _routerServiceRef = routerServiceRef,
        _secureStorageServiceRef = secureStorageServiceRef,
        _httpClientManagerRef = httpClientManagerRef,
        _dashboardControllerRef = dashboardControllerRef,
        _cancelThroughputTimer = cancelThroughputTimer,
        _startThroughputTimer = startThroughputTimer,
        _fetchDashboardData = fetchDashboardData,
        _initializeServices = initializeServices,
        _setLoadingState = setLoadingState,
        _setErrorState = setErrorState,
        _notifyListeners = notifyListeners;

  final IApiService? Function() _apiServiceRef;
  final IAuthService? Function() _authServiceRef;
  final RouterService? Function() _routerServiceRef;
  final SecureStorageService Function() _secureStorageServiceRef;
  final HttpClientManager Function() _httpClientManagerRef;
  final DashboardController? Function() _dashboardControllerRef;
  final void Function() _cancelThroughputTimer;
  final void Function() _startThroughputTimer;
  final Future<void> Function() _fetchDashboardData;
  final void Function() _initializeServices;
  final void Function(bool isLoading) _setLoadingState;
  final void Function(String? error) _setErrorState;
  final VoidCallback _notifyListeners;

  IApiService? get _apiService => _apiServiceRef();
  IAuthService? get _authService => _authServiceRef();
  RouterService? get _routerService => _routerServiceRef();
  SecureStorageService get _secureStorageService => _secureStorageServiceRef();
  HttpClientManager get _httpClientManager => _httpClientManagerRef();
  DashboardController? get _dashboardController => _dashboardControllerRef();

  // Reviewer mode state
  bool _reviewerModeEnabled = false;
  bool get reviewerModeEnabled => _reviewerModeEnabled;

  // Theme mode state
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  static const String _themeModeKey = 'themeMode';

  // Clients view mode (aggregate across routers)
  bool _clientsAggregateAllRouters = true;
  static const String _clientsAggregateKey = 'clients_aggregate_all';
  bool get clientsAggregateAllRouters => _clientsAggregateAllRouters;

  // Dashboard preferences state
  DashboardPreferences _dashboardPreferences = DashboardPreferences();
  DashboardPreferences get dashboardPreferences => _dashboardPreferences;

  // Public IP state
  String? _publicIpv4;
  String? _publicIpv6;
  bool _isFetchingPublicIps = false;

  String? get publicIpv4 => _publicIpv4;
  String? get publicIpv6 => _publicIpv6;
  bool get isFetchingPublicIps => _isFetchingPublicIps;

  String? get sysauth => _authService?.sysauth;

  List<model.Router> get routers => _routerService?.routers ?? [];
  model.Router? get selectedRouter => _routerService?.selectedRouter;
  String? get currentRouterIp => selectedRouter?.ipAddress;

  /// Explicit setter for public IPs (e.g. from DashboardController reviewer mode)
  void setPublicIps(String v4, String v6) {
    _publicIpv4 = v4;
    _publicIpv6 = v6;
  }

  Future<void> loadReviewerMode(SecureStorageService defaultStorage) async {
    // Initialize secure storage service with default factory first
    ServiceContainer.configure(reviewerMode: false);
    final stored = await defaultStorage.readValue(AppConfig.reviewerModeKey);
    _reviewerModeEnabled = stored == 'true';
  }

  Future<void> setReviewerMode(bool enabled) async {
    _reviewerModeEnabled = enabled;
    await _secureStorageService.writeValue(
      AppConfig.reviewerModeKey,
      enabled.toString(),
    );
    _initializeServices();
    _notifyListeners();
  }

  Future<void> loadThemeMode() async {
    final stored = await _secureStorageService.readValue(_themeModeKey);
    if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (stored == 'light') {
      _themeMode = ThemeMode.light;
    } else if (stored == 'system') {
      _themeMode = ThemeMode.system;
    }
    _notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _secureStorageService.writeValue(_themeModeKey, mode.name);
    _notifyListeners();
  }

  Future<void> loadClientsViewMode() async {
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
    _notifyListeners();
  }

  Future<void> loadDashboardPreferences() async {
    try {
      final routerId = _routerService?.selectedRouter?.id;
      final key = routerId != null
          ? 'dashboard_preferences:$routerId'
          : 'dashboard_preferences';

      String? jsonStr = await _secureStorageService.readValue(key);
      if ((jsonStr == null || jsonStr.isEmpty) && routerId != null) {
        jsonStr = await _secureStorageService.readValue('dashboard_preferences');
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _dashboardPreferences =
            DashboardPreferences.fromJson(jsonDecode(jsonStr));
        _notifyListeners();
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
      _notifyListeners();
    } catch (e, stack) {
      Logger.exception('Failed to save dashboard preferences', e, stack);
      rethrow;
    }
  }

  /// One-time migration: if a global 'dashboard_preferences' exists,
  /// copy it to each router-specific key that doesn't already have prefs.
  Future<void> migrateGlobalDashboardPreferencesIfNeeded() async {
    try {
      const globalKey = 'dashboard_preferences';
      final globalJson = await _secureStorageService.readValue(globalKey);
      if (globalJson == null || globalJson.isEmpty) return;

      final currentRouters = _routerService?.routers ?? const <model.Router>[];
      if (currentRouters.isEmpty) return;

      try {
        jsonDecode(globalJson);
      } catch (_) {
        return; // Not valid JSON; skip migration
      }

      for (final router in currentRouters) {
        final key = 'dashboard_preferences:${router.id}';
        final existing = await _secureStorageService.readValue(key);
        if (existing == null || existing.isEmpty) {
          await _secureStorageService.writeValue(key, globalJson);
        }
      }

      var allHavePrefs = true;
      for (final router in currentRouters) {
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
      Logger.exception(
        'Failed migrating global dashboard preferences',
        e,
        stack,
      );
    }
  }

  Future<void> fetchPublicIps({BuildContext? context}) async {
    if (_reviewerModeEnabled) {
      _publicIpv4 = '203.0.113.195';
      _publicIpv6 = '2001:db8:85a3::8a2e:0370:7334';
      _notifyListeners();
      return;
    }

    final selected = selectedRouter;
    final sys = sysauth;
    if (selected == null || sys == null || _apiService == null) return;

    _isFetchingPublicIps = true;
    try {
      final res = await _apiService!.fetchPublicIps(
        selected.ipAddress,
        sys,
        selected.useHttps,
        context: context,
      );
      _publicIpv4 = res['ipv4'];
      _publicIpv6 = res['ipv6'];
    } catch (e) {
      Logger.warning('fetchPublicIps failed in SessionController: $e');
    } finally {
      _isFetchingPublicIps = false;
      _notifyListeners();
    }
  }

  Future<void> loadRouters() async {
    await _routerService?.loadRouters();
    _notifyListeners();
  }

  Future<void> addRouter(model.Router router) async {
    await _routerService?.addRouter(router);
    _notifyListeners();
  }

  Future<void> removeRouter(String id) async {
    if (_routerService == null) return;

    final router = _routerService!.routers.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Router not found'),
    );

    await _httpClientManager.clearCertificatesForHost(router.ipAddress);

    final needsSwitch = await _routerService!.removeRouter(id);
    if (needsSwitch && _routerService!.routers.isNotEmpty) {
      await selectRouter(_routerService!.routers.first.id);
    } else if (_routerService!.selectedRouter == null) {
      _dashboardController?.resetState();
      _notifyListeners();
    } else {
      _notifyListeners();
    }
  }

  Future<void> selectRouter(String id, {BuildContext? context}) async {
    if (_routerService == null || _routerService!.routers.isEmpty) return;

    final found = _routerService!.selectRouter(id);
    if (found == null) return;

    _setLoadingState(true);
    _dashboardController?.resetState();

    _cancelThroughputTimer();

    final safeContext = context?.mounted == true ? context : null;

    await loadDashboardPreferences();

    _notifyListeners();
    final loginSuccess = await login(
      found.ipAddress,
      found.username,
      found.password,
      found.useHttps,
      fromRouter: true,
      context: safeContext,
    );
    if (loginSuccess) {
      await _fetchDashboardData();
    }
    _setLoadingState(false);
    _notifyListeners();
  }

  Future<void> updateRouter(model.Router router) async {
    await _routerService?.updateRouter(router);
    _notifyListeners();
  }

  Future<bool> login(
    String ip,
    String user,
    String pass,
    bool useHttps, {
    bool fromRouter = false,
    BuildContext? context,
  }) async {
    _setLoadingState(true);
    _setErrorState(null);

    _cancelThroughputTimer();
    _notifyListeners();

    try {
      await _authService!.login(ip, user, pass, useHttps, context: context);

      if (_authService!.isAuthenticated) {
        final actualUseHttps = _authService!.useHttps;

        if (!fromRouter) {
          if (_routerService != null) {
            final router = _routerService!.createRouter(
              ip,
              user,
              pass,
              actualUseHttps,
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
          final router = _routerService!.selectedRouter;
          if (router != null) {
            final updatedRouter = router.copyWith(useHttps: actualUseHttps);
            await updateRouter(updatedRouter);
            Logger.info(
              'Updated router protocol from ${useHttps ? "HTTPS" : "HTTP"} to ${actualUseHttps ? "HTTPS" : "HTTP"}',
            );
          }
        }
        await _fetchDashboardData();
        _startThroughputTimer();
        _setLoadingState(false);
        _notifyListeners();
        return true;
      } else {
        _setErrorState('Login Failed: Invalid credentials or host unreachable.');
        _setLoadingState(false);
        _notifyListeners();
        return false;
      }
    } catch (e) {
      _setErrorState('An error occurred: $e');
      _setLoadingState(false);
      _notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService?.logout();
    await _routerService?.clearAllRouters();
    _dashboardController?.resetState();
    _cancelThroughputTimer();
    _notifyListeners();
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
}
