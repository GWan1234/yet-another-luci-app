// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/services/router_service.dart';
import 'package:luci_mobile/utils/logger.dart';

/// Encapsulates all network actions:
/// - VPN and secure tunnel toggles (OpenVPN, Tailscale, NextDNS, Cloudflared, WireGuard)
/// - Interface & service control (Wired/Wireless status, Firewall rules, init actions)
/// - Wi-Fi access control with safety revert timer management
/// - Client actions (disconnect, pause internet, static DHCP lease management, ban/unban)
///
/// Extracted from [AppState] to enforce single-responsibility.
class NetworkActionsController {
  NetworkActionsController({
    required IApiService? Function() apiServiceRef,
    required IAuthService? Function() authServiceRef,
    required RouterService? Function() routerServiceRef,
    required bool Function() reviewerModeRef,
    required Map<String, dynamic>? Function() dashboardDataRef,
    required Future<void> Function() refreshDashboard,
    required Future<void> Function() redetectCapabilities,
    required VoidCallback notifyListeners,
  })  : _apiServiceRef = apiServiceRef,
        _authServiceRef = authServiceRef,
        _routerServiceRef = routerServiceRef,
        _reviewerModeRef = reviewerModeRef,
        _dashboardDataRef = dashboardDataRef,
        _refreshDashboard = refreshDashboard,
        _redetectCapabilities = redetectCapabilities,
        _notifyListeners = notifyListeners;

  final IApiService? Function() _apiServiceRef;
  final IAuthService? Function() _authServiceRef;
  final RouterService? Function() _routerServiceRef;
  final bool Function() _reviewerModeRef;
  final Map<String, dynamic>? Function() _dashboardDataRef;
  final Future<void> Function() _refreshDashboard;
  final Future<void> Function() _redetectCapabilities;
  final VoidCallback _notifyListeners;

  // ── Access Control & Timer State ─────────────────────────────────
  Map<String, List<String>> _priorMaclistSnapshot = {};
  Map<String, String> _priorMacfilterSnapshot = {};
  bool _isAccessControlPendingConfirmation = false;
  int _accessControlCountdownSeconds = 25;

  Timer? _accessControlRevertTimer;
  Timer? _accessControlCountdownTimer;
  Timer? _accessControlRevertRetryTimer;

  bool get isAccessControlPendingConfirmation => _isAccessControlPendingConfirmation;
  int get accessControlCountdownSeconds => _accessControlCountdownSeconds;
  Map<String, List<String>> get priorMaclistSnapshot => _priorMaclistSnapshot;
  Map<String, String> get priorMacfilterSnapshot => _priorMacfilterSnapshot;

  // ── Paused Internet State ─────────────────────────────────────────
  final Set<String> _pausedInternetMacs = {};
  Set<String> get pausedInternetMacs => _pausedInternetMacs;
  bool isInternetPaused(String mac) =>
      _pausedInternetMacs.contains(mac.toUpperCase().replaceAll('-', ':'));

  void updatePausedInternetMacs(Set<String> macs) {
    _pausedInternetMacs.clear();
    _pausedInternetMacs.addAll(macs);
    _notifyListeners();
  }

  // ── Private Accessors ────────────────────────────────────────────
  String? get _ip => _routerServiceRef()?.selectedRouter?.ipAddress;
  String? get _sysauth => _authServiceRef()?.sysauth;
  bool get _useHttps => _routerServiceRef()?.selectedRouter?.useHttps ?? false;
  bool get _isReviewerMode => _reviewerModeRef();
  IApiService? get _apiService => _apiServiceRef();

  /// Dispose timers on controller teardown
  void dispose() {
    _accessControlRevertTimer?.cancel();
    _accessControlCountdownTimer?.cancel();
    _accessControlRevertRetryTimer?.cancel();
  }

  // ── VPN & Secure Toggles ─────────────────────────────────────────

  /// Toggle an OpenVPN instance enabled state and manage service action
  Future<bool> toggleOpenVpnInstance(String name, bool enable) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'openvpn',
        section: name,
        values: {'enabled': enable ? '1' : '0'},
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;
      final commitRes =
          await _apiService!.uciCommit(ip, sysauth, _useHttps, config: 'openvpn');
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'openvpn',
        action: enable ? 'start' : 'stop',
      );
      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to toggle OpenVPN instance $name', e, stack);
      return false;
    }
  }

  /// Toggle Tailscale mesh daemon enabled state
  Future<bool> toggleTailscale(bool enable) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'tailscale',
        section: 'settings',
        values: {'enabled': enable ? '1' : '0'},
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;
      final commitRes =
          await _apiService!.uciCommit(ip, sysauth, _useHttps, config: 'tailscale');
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'tailscale',
        action: enable ? 'start' : 'stop',
      );
      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to toggle Tailscale', e, stack);
      return false;
    }
  }

  /// Toggle NextDNS encrypted DNS daemon state
  Future<bool> toggleNextDns(bool enable) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'nextdns',
        section: 'main',
        values: {'enabled': enable ? '1' : '0'},
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;
      final commitRes =
          await _apiService!.uciCommit(ip, sysauth, _useHttps, config: 'nextdns');
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'nextdns',
        action: enable ? 'start' : 'stop',
      );

      try {
        final actionCmd = enable
            ? 'nextdns activate || /etc/init.d/nextdns activate'
            : 'nextdns deactivate || /etc/init.d/nextdns deactivate';
        await _apiService!.call(
          ip, sysauth, _useHttps,
          object: 'file',
          method: 'exec',
          params: {
            'command': '/bin/sh',
            'params': ['-c', actionCmd],
          },
        );
      } catch (_) {}

      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to toggle NextDNS', e, stack);
      return false;
    }
  }

  /// Toggle Cloudflared tunnel daemon enabled state
  Future<bool> toggleCloudflared(bool enable) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'cloudflared',
        section: 'main',
        values: {'enabled': enable ? '1' : '0'},
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;
      final commitRes =
          await _apiService!.uciCommit(ip, sysauth, _useHttps, config: 'cloudflared');
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'cloudflared',
        action: enable ? 'start' : 'stop',
      );
      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to toggle Cloudflared', e, stack);
      return false;
    }
  }

  /// Bring WireGuard interface up or down
  Future<bool> toggleWireguardInterface(String ifaceName, bool bringUp) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final cmd = bringUp ? '/sbin/ifup' : '/sbin/ifdown';
      await _apiService!.systemExec(ip, sysauth, _useHttps, command: '$cmd $ifaceName');
      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to toggle WireGuard interface $ifaceName', e, stack);
      return false;
    }
  }

  /// Restart a VPN service daemon by service name
  Future<bool> restartVpnService(String serviceName) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: serviceName,
        action: 'restart',
      );
      await _refreshDashboard();
      return true;
    } catch (e, stack) {
      Logger.exception('Failed to restart VPN service $serviceName', e, stack);
      return false;
    }
  }

  // ── Services & Interface Controls ─────────────────────────────────

  Future<bool> manageServiceAction(
    String serviceName,
    String action, {
    BuildContext? context,
  }) async {
    if (_isReviewerMode) return true;
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final success = await _apiService!.manageServiceAction(
      ip, sysauth, _useHttps,
      serviceName: serviceName,
      action: action,
      context: context,
    );
    if (success) {
      await _refreshDashboard();
    }
    return success;
  }

  Future<bool> updateFirewallCustomRuleStatus(
    String sectionKey,
    bool enabled, {
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'firewall',
        section: sectionKey,
        values: {'enabled': enabled ? '1' : '0'},
        context: context,
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;

      final commitRes = await _apiService!.uciCommit(
        ip, sysauth, _useHttps,
        config: 'firewall',
        context: (context != null && context.mounted) ? context : null,
      );
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'firewall',
        action: 'reload',
        context: (context != null && context.mounted) ? context : null,
      );
      return true;
    } catch (e, stack) {
      Logger.exception('updateFirewallCustomRuleStatus failed for $sectionKey', e, stack);
      return false;
    }
  }

  Future<bool> updateWiredInterfaceStatus(
    String interfaceName,
    bool enabled, {
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'network',
        section: interfaceName,
        values: {'disabled': enabled ? '0' : '1'},
        context: context,
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;

      final commitRes = await _apiService!.uciCommit(
        ip, sysauth, _useHttps,
        config: 'network',
        context: (context != null && context.mounted) ? context : null,
      );
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.manageServiceAction(
        ip, sysauth, _useHttps,
        serviceName: 'network',
        action: 'reload',
        context: (context != null && context.mounted) ? context : null,
      );
      return true;
    } catch (e, stack) {
      Logger.exception('updateWiredInterfaceStatus failed for $interfaceName', e, stack);
      return false;
    }
  }

  Future<bool> updateWirelessInterfaceStatus(
    String sectionKey,
    bool enabled, {
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    try {
      final setRes = await _apiService!.uciSet(
        ip, sysauth, _useHttps,
        config: 'wireless',
        section: sectionKey,
        values: {'disabled': enabled ? '0' : '1'},
        context: context,
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) return false;

      final commitRes = await _apiService!.uciCommit(
        ip, sysauth, _useHttps,
        config: 'wireless',
        context: (context != null && context.mounted) ? context : null,
      );
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) return false;

      await _apiService!.systemExec(
        ip, sysauth, _useHttps,
        command: 'wifi reload',
        context: (context != null && context.mounted) ? context : null,
      );
      return true;
    } catch (e, stack) {
      Logger.exception('updateWirelessInterfaceStatus failed for $sectionKey', e, stack);
      return false;
    }
  }

  // ── Wi-Fi Access Control & Auto-Revert Safety ───────────────────────

  Future<bool> applyWifiAccessControl({
    required Map<String, List<String>> newMaclistByIface,
    required Map<String, String> newMacfilterByIface,
    required Map<String, List<String>> priorMaclistSnapshot,
    required Map<String, String> priorMacfilterSnapshot,
    BuildContext? context,
  }) async {
    _priorMaclistSnapshot = priorMaclistSnapshot;
    _priorMacfilterSnapshot = priorMacfilterSnapshot;

    bool success = true;
    if (!_isReviewerMode) {
      final ip = _ip;
      final sysauth = _sysauth;
      if (ip == null || sysauth == null || _apiService == null) return false;

      success = await _apiService!.setWifiAccessControl(
        ip, sysauth, _useHttps,
        maclistByIface: newMaclistByIface,
        macfilterByIface: newMacfilterByIface,
        context: (context != null && context.mounted) ? context : null,
      );
    }

    if (success) {
      startAccessControlAutoRevertTimer(initialSeconds: 25);
      await _refreshDashboard();
    }
    return success;
  }

  void startAccessControlAutoRevertTimer({
    int initialSeconds = 25,
    Map<String, List<String>>? priorMaclist,
    Map<String, String>? priorMacfilter,
  }) {
    if (priorMaclist != null) _priorMaclistSnapshot = priorMaclist;
    if (priorMacfilter != null) _priorMacfilterSnapshot = priorMacfilter;

    _accessControlRevertTimer?.cancel();
    _accessControlCountdownTimer?.cancel();

    _isAccessControlPendingConfirmation = true;
    _accessControlCountdownSeconds = initialSeconds;
    _notifyListeners();

    _accessControlCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_accessControlCountdownSeconds > 1) {
        _accessControlCountdownSeconds--;
        _notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _accessControlRevertTimer = Timer(Duration(seconds: initialSeconds), () {
      if (_isAccessControlPendingConfirmation) {
        Logger.warning('Wi-Fi Access Control auto-revert timer expired. Reverting changes.');
        revertWifiAccessControlChanges();
      }
    });
  }

  Future<bool> confirmWifiAccessControlChanges() async {
    _accessControlRevertTimer?.cancel();
    _accessControlCountdownTimer?.cancel();
    _isAccessControlPendingConfirmation = false;

    bool success = true;
    if (!_isReviewerMode) {
      final ip = _ip;
      final sysauth = _sysauth;
      if (ip != null && sysauth != null && _apiService != null) {
        success = await _apiService!.confirmWifiAccessControl(
          ip, sysauth, _useHttps,
        );
      }
    }

    _priorMaclistSnapshot = {};
    _priorMacfilterSnapshot = {};
    _notifyListeners();
    return success;
  }

  Future<bool> revertWifiAccessControlChanges({BuildContext? context}) async {
    _accessControlRevertTimer?.cancel();
    _accessControlCountdownTimer?.cancel();
    _isAccessControlPendingConfirmation = false;
    _notifyListeners();

    if (_priorMaclistSnapshot.isEmpty && _priorMacfilterSnapshot.isEmpty) {
      return true;
    }

    bool success = true;
    if (!_isReviewerMode) {
      final ip = _ip;
      final sysauth = _sysauth;
      if (ip != null && sysauth != null && _apiService != null) {
        success = await _apiService!.revertWifiAccessControl(
          ip, sysauth, _useHttps,
          maclistByIface: _priorMaclistSnapshot,
          macfilterByIface: _priorMacfilterSnapshot,
          context: (context != null && context.mounted) ? context : null,
        );

        if (!success) {
          int retries = 0;
          _accessControlRevertRetryTimer?.cancel();
          _accessControlRevertRetryTimer =
              Timer.periodic(const Duration(seconds: 3), (retryTimer) async {
            retries++;
            if (retries > 10) {
              retryTimer.cancel();
              _accessControlRevertRetryTimer = null;
              return;
            }
            final retried = await _apiService!.revertWifiAccessControl(
              ip, sysauth, _useHttps,
              maclistByIface: _priorMaclistSnapshot,
              macfilterByIface: _priorMacfilterSnapshot,
            );
            if (retried) {
              retryTimer.cancel();
              _accessControlRevertRetryTimer = null;
              await _refreshDashboard();
            }
          });
        }
      }
    }

    _priorMaclistSnapshot = {};
    _priorMacfilterSnapshot = {};
    await _refreshDashboard();
    _notifyListeners();
    return success;
  }

  Future<bool> autoFixPermissions({BuildContext? context}) async {
    if (_isReviewerMode) {
      await _redetectCapabilities();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.autoFixPermissions(
      ip, sysauth, _useHttps,
      context: context,
    );
    if (res) {
      await _redetectCapabilities();
    }
    return res;
  }

  // ── Client Actions ────────────────────────────────────────────────

  Future<bool> disconnectWirelessClient(
    String macAddress, {
    String? iface,
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _refreshDashboard();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.disconnectWirelessClient(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      iface: iface,
      context: context,
    );
    if (res) {
      await _refreshDashboard();
    }
    return res;
  }

  Future<bool> pauseClientInternet(
    String macAddress, {
    required bool pause,
    BuildContext? context,
  }) async {
    final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
    if (_isReviewerMode) {
      if (pause) {
        _pausedInternetMacs.add(macUpper);
      } else {
        _pausedInternetMacs.remove(macUpper);
      }
      _notifyListeners();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.pauseClientInternet(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      pause: pause,
      context: context,
    );
    if (res) {
      if (pause) {
        _pausedInternetMacs.add(macUpper);
      } else {
        _pausedInternetMacs.remove(macUpper);
      }
      _notifyListeners();
    }
    return res;
  }

  Future<bool> addStaticLease({
    required String macAddress,
    required String targetIp,
    required String hostname,
    String? leaseTime,
    BuildContext? context,
  }) async {
    final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
    if (_isReviewerMode) {
      final dashboardData = _dashboardDataRef();
      if (dashboardData != null) {
        final hints = dashboardData['hostHints'] as Map<String, dynamic>? ?? {};
        hints[macUpper] = {
          'name': hostname,
          'staticLeaseName': hostname,
          'ipaddrs': [targetIp],
          'staticLeaseIp': targetIp,
          'isStaticLease': true,
        };
      }
      _notifyListeners();
      await _refreshDashboard();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.addStaticLease(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      targetIp: targetIp,
      hostname: hostname,
      leaseTime: leaseTime,
      context: context,
    );
    if (res) {
      await _refreshDashboard();
      _notifyListeners();
    }
    return res;
  }

  Future<bool> deleteStaticLease({
    required String macAddress,
    BuildContext? context,
  }) async {
    final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
    if (_isReviewerMode) {
      final dashboardData = _dashboardDataRef();
      if (dashboardData != null) {
        final hints = dashboardData['hostHints'] as Map<String, dynamic>? ?? {};
        hints.removeWhere((key, val) => key.toUpperCase().replaceAll('-', ':') == macUpper);
      }
      _notifyListeners();
      await _refreshDashboard();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.deleteStaticLease(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      context: context,
    );
    if (res) {
      await _refreshDashboard();
      _notifyListeners();
    }
    return res;
  }

  Future<bool> banWirelessClient(
    String macAddress, {
    String? iface,
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _refreshDashboard();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.banWirelessClient(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      iface: iface,
      context: context,
    );
    if (res) {
      await _refreshDashboard();
    }
    return res;
  }

  Future<bool> unbanWirelessClient(
    String macAddress, {
    BuildContext? context,
  }) async {
    if (_isReviewerMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _refreshDashboard();
      return true;
    }
    final ip = _ip;
    final sysauth = _sysauth;
    if (ip == null || sysauth == null || _apiService == null) return false;

    final res = await _apiService!.unbanWirelessClient(
      ip, sysauth, _useHttps,
      macAddress: macAddress,
      context: context,
    );
    if (res) {
      await _refreshDashboard();
    }
    return res;
  }
}
