// ignore_for_file: use_build_context_synchronously
// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0


import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:yet_another_luci_app/modules/services_system/models/ddns_info.dart';
import 'package:yet_another_luci_app/services/interfaces/api_service_interface.dart';
import '../utils/http_client_manager.dart';
import '../utils/logger.dart';
import '../widgets/luci_toast.dart';

class LoginResult {
  final String? token;
  final bool actualUseHttps;

  LoginResult({required this.token, required this.actualUseHttps});
}

Uri _buildUrl(String ipAddress, bool useHttps, String path) {
  final scheme = useHttps ? 'https' : 'http';
  // Handle cases where ipAddress might already include a port
  String host = ipAddress;
  // Don't add scheme if the address already has one (shouldn't happen with our parser)
  if (host.startsWith('http://') || host.startsWith('https://')) {
    return Uri.parse('$host$path');
  }
  return Uri.parse('$scheme://$host$path');
}

class RealApiService implements IApiService {
  final HttpClientManager _httpClientManager = HttpClientManager();

  /// OpenWrt rpcd `file.exec` accepts `params` on newer builds and `args` on older ones.
  ///
  /// Some router images only support one form, so callers should try both when
  /// running package manager helper commands to remain compatible.
  static Map<String, dynamic> fileExecParams(String command, List<String> arguments) => {
        'command': command,
        'params': arguments,
      };

  static Map<String, dynamic> fileExecArgs(String command, List<String> arguments) => {
        'command': command,
        'args': arguments,
      };

  Dio _createHttpClient(
    bool useHttps,
    String hostWithPort, {
    BuildContext? context,
  }) {
    return _httpClientManager.getClient(
      hostWithPort,
      useHttps,
      context: context,
    );
  }

  @override
  Future<String> login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final result = await loginWithProtocolDetection(
      ipAddress,
      username,
      password,
      useHttps,
      context: context,
    );
    if (result.token == null) {
      throw Exception('Login failed');
    }
    return result.token!;
  }

  /// Login with automatic HTTPS redirect detection
  /// Returns both the auth token and the actual protocol used
  Future<LoginResult> loginWithProtocolDetection(
    String ipAddress,
    String username,
    String password,
    bool initialUseHttps, {
    BuildContext? context,
  }) async {
    // First try with the initial protocol
    var result = await _login(
      ipAddress,
      username,
      password,
      initialUseHttps,
      context: context,
      checkRedirect: true,
    );

    // Check if we got a redirect marker
    if (result != null && result.startsWith('HTTPS_REDIRECT:')) {
      final token = result.substring('HTTPS_REDIRECT:'.length);
      Logger.info('Login successful via HTTP to HTTPS redirect');
      return LoginResult(token: token, actualUseHttps: true);
    }

    if (result != null) {
      return LoginResult(token: result, actualUseHttps: initialUseHttps);
    }

    // If login failed and we were using HTTP, try HTTPS in case of redirect
    if (!initialUseHttps) {
      Logger.info('HTTP login failed or redirected, attempting HTTPS');
      final safeContext = context?.mounted == true ? context : null;
      result = await _login(
        ipAddress,
        username,
        password,
        true, // Try with HTTPS
        context: safeContext,
        checkRedirect: false,
      );

      if (result != null) {
        Logger.info('Login successful with HTTPS after redirect detection');
        return LoginResult(token: result, actualUseHttps: true);
      }
    }

    return LoginResult(token: null, actualUseHttps: initialUseHttps);
  }

  Future<String?> _login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
    bool checkRedirect = false,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(ipAddress, useHttps, '/cgi-bin/luci/');
    final params =
        'luci_username=${Uri.encodeComponent(username)}&luci_password=${Uri.encodeComponent(password)}';

    try {
      // Normal POST request - Dio will follow redirects by default
      final response = await client.post(
        uri.toString(),
        data: params,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400 || code == 302,
        ),
      );

      // Check if we were redirected to HTTPS (only relevant for initial HTTP attempts)
      if (checkRedirect && !useHttps) {
        final finalUrl = response.realUri;
        if (finalUrl.scheme == 'https') {
          Logger.info('Detected HTTP to HTTPS redirect: $uri -> $finalUrl');
          // If we got a successful login after redirect, extract the token
          if (response.statusCode == 302 || response.statusCode == 200) {
            final setCookies = response.headers.map['set-cookie'];
            if (setCookies != null && setCookies.isNotEmpty) {
              final cookies = setCookies.join(',').split(',');
              for (final cookie in cookies) {
                if (cookie.contains('sysauth')) {
                  final cookieValue = cookie.split(';')[0].split('=')[1];
                  // Signal that HTTPS should be used by returning a special marker
                  // We'll handle this in loginWithProtocolDetection
                  return 'HTTPS_REDIRECT:$cookieValue';
                }
              }
            }
          }
          // No token found, trigger HTTPS retry
          return null;
        }
      }

      if (response.statusCode == 302 || response.statusCode == 200) {
        // Parse Set-Cookie headers to find sysauth cookie
        final setCookies = response.headers.map['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          final cookies = setCookies.join(',').split(',');
          for (final cookie in cookies) {
            if (cookie.contains('sysauth')) {
              final cookieValue = cookie.split(';')[0].split('=')[1];
              return cookieValue;
            }
          }
        }
      }

      // Fallback: Try ubus JSON-RPC session.login (for modern OpenWrt 24.10/25.12+)
      try {
        final ubusUrl = _buildUrl(ipAddress, useHttps, '/ubus');
        final rpcPayload = {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'call',
          'params': [
            '00000000000000000000000000000000',
            'session',
            'login',
            {'username': username, 'password': password}
          ],
        };
        final ubusResponse = await client.post(
          ubusUrl.toString(),
          data: jsonEncode(rpcPayload),
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (code) => code != null && code < 500,
          ),
        );
        if (ubusResponse.statusCode == 200) {
          final decoded = ubusResponse.data is String
              ? jsonDecode(ubusResponse.data as String)
              : ubusResponse.data;
          if (decoded is Map &&
              decoded['result'] is List &&
              (decoded['result'] as List).length > 1) {
            final resData = decoded['result'][1];
            if (resData is Map && resData['ubus_rpc_session'] != null) {
              final sessionToken = resData['ubus_rpc_session'].toString();
              Logger.info('Successfully authenticated via ubus JSON-RPC session.login');
              return sessionToken;
            }
          }
        }
      } catch (ubusErr) {
        Logger.info('ubus JSON-RPC login attempt fallback error: $ubusErr');
      }

      return null;
    } on DioException catch (e, stack) {
      Logger.exception('Login failed', e, stack);

      final isCertError =
          e.error is HandshakeException || e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true;

      if (!useHttps && checkRedirect && isCertError) {
        Logger.info('Detected HTTPS certificate issue during redirect; retrying with HTTPS');
        final retryContext = context != null && context.mounted ? context : null;
        try {
          return await _login(
            ipAddress,
            username,
            password,
            true,
            context: retryContext,
            checkRedirect: false,
          );
        } on DioException catch (httpsError, httpsStack) {
          Logger.exception('HTTPS retry after redirect failed', httpsError, httpsStack);
        }
      }

      if (useHttps && context != null && context.mounted && isCertError) {
        // Try to prompt for certificate acceptance
        final accepted = await _httpClientManager.promptForCertificateAcceptance(
          context: context,
          hostWithPort: ipAddress,
          useHttps: useHttps,
        );

        if (accepted && context.mounted) {
          // Create a new client and retry the login
          final retryClient = _createHttpClient(useHttps, ipAddress, context: context);
          try {
            final retryResponse = await retryClient.post(
              uri.toString(),
              data: params,
              options: Options(
                contentType: Headers.formUrlEncodedContentType,
                followRedirects: true,
                validateStatus: (code) => code != null && code >= 200 && code < 400 || code == 302,
              ),
            );

            if (retryResponse.statusCode == 302 || retryResponse.statusCode == 200) {
              final setCookies = retryResponse.headers.map['set-cookie'];
              if (setCookies != null && setCookies.isNotEmpty) {
                final cookies = setCookies.join(',').split(',');
                for (final cookie in cookies) {
                  if (cookie.contains('sysauth')) {
                    final cookieValue = cookie.split(';')[0].split('=')[1];
                    return cookieValue;
                  }
                }
              }
            }
          } on DioException catch (retryError, retryStack) {
            Logger.exception('Login retry failed', retryError, retryStack);
          }
        }
      }

      if (isCertError) {
        return null;
      }

      rethrow;
    }
  }

  @override
  Future<dynamic> call(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String object,
    required String method,
    Map<String, dynamic>? params,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: object,
      method: method,
      params: params,
      context: context,
    );
  }

  // Simplified call method for reviewer mode
  @override
  Future<dynamic> callSimple(
    String object,
    String method,
    Map<String, dynamic> params,
  ) async {
    // Use default values for ipAddress, sysauth, and useHttps
    // This is primarily for mock/testing scenarios
    return await call(
      'localhost', // Default IP address
      '', // Default sysauth (empty for mock scenarios)
      false, // Default to HTTP
      object: object,
      method: method,
      params: params,
    );
  }

  Future<dynamic> callWithContext(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String object,
    required String method,
    Map<String, dynamic>? params,
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final rpcPayload = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'call',
      'params': [sysauth, object, method, params ?? {}],
    };

    final endpoints = ['/ubus', '/cgi-bin/luci/admin/ubus'];

    for (int i = 0; i < endpoints.length; i++) {
      final endpointPath = endpoints[i];
      final url = _buildUrl(ipAddress, useHttps, endpointPath);

      try {
        final response = await client.post(
          url.toString(),
          data: jsonEncode(rpcPayload),
          options: Options(
            headers: {'Content-Type': 'application/json'},
            responseDecoder: (responseBytes, options, responseBody) {
              return utf8.decode(responseBytes, allowMalformed: true);
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200) {
          final decoded = response.data is String
              ? jsonDecode(response.data as String)
              : response.data;
          if (decoded['error'] != null) {
            throw Exception('RPC error: ${decoded['error']['message']}');
          }
          // Return in LuCI RPC format: [status, data]
          final result = decoded['result'];
          if (result is List && result.isNotEmpty) {
            return result;
          } else {
            return [0, result];
          }
        } else if (response.statusCode == 404 && i < endpoints.length - 1) {
          // Fallback to next endpoint
          continue;
        } else {
          throw Exception('Failed to call RPC: HTTP ${response.statusCode}');
        }
      } on DioException catch (e, stack) {
        if (i < endpoints.length - 1) {
          continue;
        }
        Logger.exception('API call failed', e, stack);
        rethrow;
      }
    }

    throw Exception('Failed to reach RPC endpoint');
  }

  @override
  Future<bool> reboot(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    return await rebootWithContext(
      ipAddress,
      sysauth,
      useHttps,
      context: context,
    );
  }

  Future<bool> rebootWithContext(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      final result = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'system',
        method: 'reboot',
        context: context,
      );
      // Handle LuCI RPC format: [status, data] - successful reboot returns [0, ...]
      if (result is List && result.isNotEmpty && result[0] == 0) {
        Logger.info('Router reboot initiated successfully');
        return true;
      }
      Logger.warning('Router reboot call returned unexpected result: $result');
      return false;
    } catch (e, stack) {
      Logger.exception('Router reboot failed', e, stack);
      return false;
    }
  }

  @override
  Future<Map<String, Set<String>>> fetchAssociatedStations() async {
    // This method is mainly used by the mock service
    // For real implementation, individual interface queries via fetchAssociatedStationsWithContext should be used
    // The app_state.dart should call fetchAllAssociatedWirelessMacsWithContext instead
    throw UnimplementedError(
      'Use fetchAllAssociatedWirelessMacsWithContext for real implementation',
    );
  }

  /// Fetches all associated wireless MAC addresses from all wireless interfaces for real API
  @override
  Future<Map<String, Set<String>>> fetchAllAssociatedWirelessMacsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    BuildContext? context,
  }) async {
    final result = <String, Set<String>>{};
    final discoveredIfaces = <String, String>{}; // ifname -> ssid/label

    try {
      // 1. Try getWirelessDevices via luci-rpc
      final wirelessResult = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'luci-rpc',
        method: 'getWirelessDevices',
        context: context,
      );

      if (wirelessResult is List && wirelessResult.length > 1 && wirelessResult[0] == 0) {
        final wirelessData = wirelessResult[1] as Map<String, dynamic>?;
        if (wirelessData != null) {
          for (final entry in wirelessData.entries) {
            final radioData = entry.value as Map<String, dynamic>?;
            if (radioData == null || radioData['interfaces'] == null) continue;

            final rawIfaces = radioData['interfaces'];
            final interfaces = rawIfaces is List ? rawIfaces : (rawIfaces is Map ? rawIfaces.values.toList() : null);
            if (interfaces == null) continue;

            for (final iface in interfaces) {
              if (iface is Map<String, dynamic>) {
                final ifname = iface['ifname']?.toString();
                final ssid = iface['config']?['ssid']?.toString() ??
                    iface['iwinfo']?['ssid']?.toString() ??
                    iface['ssid']?.toString() ??
                    ifname;
                if (ifname != null && ifname.isNotEmpty) {
                  discoveredIfaces[ifname] = ssid ?? ifname;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Query UCI wireless configuration directly for VAP interface names & maclists
    try {
      final uciRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'wireless'},
        context: context?.mounted == true ? context : null,
      );
      if (uciRes is List && uciRes.length > 1 && uciRes[0] == 0) {
        final values = (uciRes[1] as Map<String, dynamic>?)?['values'] as Map<String, dynamic>?;
        if (values != null) {
          for (final section in values.values) {
            if (section is Map<String, dynamic> && section['.type'] == 'wifi-iface') {
              final ifname = section['ifname']?.toString();
              final ssid = section['ssid']?.toString() ?? ifname;
              if (ifname != null && ifname.isNotEmpty && ssid != null) {
                discoveredIfaces[ifname] = ssid;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 3. Command/ubus fallback to find interface names if none found
    if (discoveredIfaces.isEmpty) {
      try {
        final resIwDev = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: fileExecParams('iw', ['dev']),
          context: context?.mounted == true ? context : null,
        );
        if (resIwDev is List && resIwDev.length > 1 && resIwDev[0] == 0) {
          final data = resIwDev[1] as Map<String, dynamic>?;
          final stdout = data?['stdout']?.toString() ?? '';
          String? currentIface;
          for (final line in stdout.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.startsWith('Interface ')) {
              currentIface = trimmed.substring(10).trim();
              discoveredIfaces[currentIface] = currentIface;
            } else if (trimmed.startsWith('ssid ') && currentIface != null) {
              final ssid = trimmed.substring(5).trim();
              discoveredIfaces[currentIface] = ssid;
            }
          }
        }
      } catch (_) {}
    }

    // 3. For every discovered interface, fetch associated stations
    for (final entry in discoveredIfaces.entries) {
      final ifname = entry.key;
      final label = entry.value;

      final stations = await fetchAssociatedStationsWithContext(
        ipAddress: ipAddress,
        sysauth: sysauth,
        useHttps: useHttps,
        interface: ifname,
        context: context?.mounted == true ? context : null,
      );

      if (stations.isNotEmpty) {
        final mapKey = '$ifname|$label';
        result[mapKey] = (result[mapKey] ?? {})..addAll(stations);
      }
    }

    return result;
  }

  /// Fetches associated stations (wireless clients) for a given wireless interface (e.g., wlan0)
  /// Fetches associated stations (wireless clients) for a given wireless interface (e.g., phy0-ap0, wlan0)
  @override
  Future<List<String>> fetchAssociatedStationsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    final stations = <String>{};

    try {
      // 1. Try iwinfo assoclist
      final resultIw = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'iwinfo',
        method: 'assoclist',
        params: {'device': interface},
        context: context?.mounted == true ? context : null,
      );
      if (resultIw is List && resultIw.length > 1 && resultIw[0] == 0) {
        final data = resultIw[1];
        if (data is Map && data['results'] is List) {
          for (final entry in (data['results'] as List)) {
            final mac = (entry as Map<String, dynamic>)['mac']?.toString();
            if (mac != null && mac.isNotEmpty) {
              stations.add(mac.toUpperCase().replaceAll('-', ':'));
            }
          }
        }
      }
    } catch (_) {}

    try {
      // 2. Try hostapd.<interface> get_clients
      final resultHostapd = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'hostapd.$interface',
        method: 'get_clients',
        params: {},
        context: context?.mounted == true ? context : null,
      );
      if (resultHostapd is List && resultHostapd.length > 1 && resultHostapd[0] == 0) {
        final data = resultHostapd[1];
        if (data is Map && data['clients'] is Map) {
          final clientsMap = data['clients'] as Map<String, dynamic>;
          for (final mac in clientsMap.keys) {
            stations.add(mac.toUpperCase().replaceAll('-', ':'));
          }
        }
      }
    } catch (_) {}

    if (stations.isEmpty) {
      try {
        // 3. Command execution fallback (iwinfo <iface> assoclist or iw dev <iface> station dump)
        final resExec1 = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: fileExecParams('iwinfo', [interface, 'assoclist']),
          context: context?.mounted == true ? context : null,
        );
        if (resExec1 is List && resExec1.length > 1 && resExec1[0] == 0) {
          final data = resExec1[1] as Map<String, dynamic>?;
          final stdout = data?['stdout']?.toString() ?? '';
          final macRegex = RegExp(r'([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})');
          for (final m in macRegex.allMatches(stdout)) {
            final macStr = m.group(0);
            if (macStr != null) stations.add(macStr.toUpperCase().replaceAll('-', ':'));
          }
        }

        if (stations.isEmpty) {
          final resExec2 = await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'file',
            method: 'exec',
            params: fileExecParams('iw', ['dev', interface, 'station', 'dump']),
            context: context?.mounted == true ? context : null,
          );
          if (resExec2 is List && resExec2.length > 1 && resExec2[0] == 0) {
            final data = resExec2[1] as Map<String, dynamic>?;
            final stdout = data?['stdout']?.toString() ?? '';
            final macRegex = RegExp(r'([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})');
            for (final m in macRegex.allMatches(stdout)) {
              final macStr = m.group(0);
              if (macStr != null) stations.add(macStr.toUpperCase().replaceAll('-', ':'));
            }
          }
        }
      } catch (_) {}
    }

    return stations.toList();
  }

  /// Fetches Host Hints dictionary from luci-rpc and UCI dhcp static host leases
  @override
  Future<Map<String, Map<String, dynamic>>> fetchHostHintsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    BuildContext? context,
  }) async {
    final hints = <String, Map<String, dynamic>>{};

    // 1. Fetch static DHCP host leases directly from UCI (dhcp)
    try {
      final uciRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'dhcp', 'type': 'host'},
        context: context?.mounted == true ? context : null,
      );
      if (uciRes is List && uciRes.length > 1 && uciRes[0] == 0) {
        final rawData = uciRes[1];
        Map<String, dynamic>? values;
        if (rawData is Map<String, dynamic>) {
          if (rawData['values'] is Map<String, dynamic>) {
            values = rawData['values'] as Map<String, dynamic>;
          } else {
            values = rawData;
          }
        }
        if (values != null) {
          values.forEach((_, sec) {
            if (sec is Map<String, dynamic>) {
              final rawName = sec['name']?.toString() ??
                  sec['hostname']?.toString() ??
                  sec['comment']?.toString() ??
                  sec['description']?.toString();
              final rawMac = sec['mac'];
              if (rawName != null && rawName.isNotEmpty && rawMac != null) {
                final macList = <String>[];
                if (rawMac is List) {
                  macList.addAll(rawMac.map((e) => e.toString()));
                } else if (rawMac is String) {
                  macList.addAll(rawMac.split(RegExp(r'\s+')));
                }
                for (final mac in macList) {
                  final normMac = mac
                      .toUpperCase()
                      .replaceAll('-', ':')
                      .split(':')
                      .map((b) => b.length == 1 ? '0$b' : b)
                      .join(':');
                  if (normMac.isNotEmpty) {
                    hints[normMac] = {
                      'name': rawName,
                      'staticLeaseName': rawName,
                      'ipaddrs': sec['ip'] != null ? [sec['ip'].toString()] : [],
                      'staticLeaseIp': sec['ip']?.toString(),
                      'isStaticLease': true,
                    };
                  }
                }
              }
            }
          });
        }
      }
    } catch (_) {}

    // 2. Fetch getHostHints from luci-rpc (merges /etc/hosts, ethers, and active leases)
    try {
      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'luci-rpc',
        method: 'getHostHints',
        params: {},
        context: context?.mounted == true ? context : null,
      );
      if (res is List && res.length > 1 && res[0] == 0) {
        final data = res[1];
        if (data is Map<String, dynamic>) {
          data.forEach((mac, info) {
            if (info is Map<String, dynamic>) {
              final normMac = mac
                  .trim()
                  .toUpperCase()
                  .replaceAll('-', ':')
                  .split(':')
                  .map((b) => b.length == 1 ? '0$b' : b)
                  .join(':');
              var name = info['name']?.toString();
              if (name != null && name.isNotEmpty && name != '*') {
                if (name.endsWith('.lan')) {
                  name = name.substring(0, name.length - 4);
                } else if (name.endsWith('.local')) {
                  name = name.substring(0, name.length - 6);
                }
              }
              final existing = hints[normMac];
              final newIps = info['ipaddrs'] as List?;
              final newV6Ips = info['ip6addrs'] as List?;
              if (existing == null) {
                hints[normMac] = {
                  'name': name ?? '',
                  'ipaddrs': newIps ?? [],
                  'ip6addrs': newV6Ips ?? [],
                  'isStaticLease': false,
                };
              } else {
                // Keep static lease info if set from UCI in step 1, otherwise update missing dynamic fields
                if (existing['name'] == null || existing['name'].toString().isEmpty) {
                  existing['name'] = name ?? '';
                }
                if (newIps != null && newIps.isNotEmpty) {
                  existing['ipaddrs'] = newIps;
                }
                if (newV6Ips != null && newV6Ips.isNotEmpty) {
                  existing['ip6addrs'] = newV6Ips;
                }
              }
            }
          });
        }
      }
    } catch (_) {}
    return hints;
  }

  @override
  Future<Map<String, dynamic>?> fetchWireGuardPeers({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    return await fetchWireGuardPeersWithContext(
      ipAddress: ipAddress,
      sysauth: sysauth,
      useHttps: useHttps,
      interface: interface,
      context: context,
    );
  }

  /// Fetches WireGuard peer information for a given interface
  /// If interface is empty, returns data for all WireGuard interfaces
  Future<Map<String, dynamic>?> fetchWireGuardPeersWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    try {
      // Use the correct luci.wireguard.getWgInstances method
      final result = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'luci.wireguard',
        method: 'getWgInstances',
        params: {},
        context: context,
      );

      // Handle LuCI RPC format: [status, data]
      if (result is List && result.length > 1 && result[0] == 0) {
        final data = result[1] as Map<String, dynamic>?;
        if (data != null) {
          return _parseWireGuardFromInstances(data, interface);
        }
      }

      return null;
    } catch (e, stack) {
      Logger.exception('Failed to fetch WireGuard peers', e, stack);
      return null;
    }
  }

  Map<String, dynamic>? _parseWireGuardFromInstances(
    Map<String, dynamic> data,
    String targetInterface,
  ) {
    final wireguardData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Look for peers in the interface data
        final peers = <String, dynamic>{};

        // The structure might have peers in different formats
        final rawPeers = value['peers'];
        if (rawPeers is List) {
          for (final peer in rawPeers) {
            if (peer is Map<String, dynamic>) {
              final publicKey = peer['public_key'] as String?;
              if (publicKey != null) {
                peers[publicKey] = {
                  'public_key': publicKey,
                  'endpoint': peer['endpoint'] ?? 'N/A',
                  'last_handshake':
                      int.tryParse(
                        peer['latest_handshake']?.toString() ?? '0',
                      ) ??
                      0,
                  'rx_bytes': peer['rx_bytes'] ?? 0,
                  'tx_bytes': peer['tx_bytes'] ?? 0,
                  'allowed_ips': peer['allowed_ips'] ?? [],
                };
              }
            }
          }
        } else if (rawPeers is Map) {
          rawPeers.forEach((k, peer) {
            if (peer is Map<String, dynamic>) {
              final publicKey = peer['public_key'] as String? ?? k.toString();
              peers[publicKey] = {
                'public_key': publicKey,
                'endpoint': peer['endpoint'] ?? 'N/A',
                'last_handshake':
                    int.tryParse(
                      peer['latest_handshake']?.toString() ?? '0',
                    ) ??
                    0,
              };
            }
          });
        }

        if (peers.isNotEmpty) {
          wireguardData[key] = {'interface': key, 'peers': peers};
        }
      }
    });

    if (targetInterface.isEmpty) {
      return wireguardData;
    } else {
      return wireguardData[targetInterface];
    }
  }

  @override
  Future<dynamic> uciSet(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    required String section,
    required Map<String, String> values,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'uci',
      method: 'set',
      params: {'config': config, 'section': section, 'values': values},
      context: context,
    );
  }

  @override
  Future<dynamic> uciCommit(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'uci',
      method: 'commit',
      params: {'config': config},
      context: context,
    );
  }

  @override
  Future<dynamic> systemExec(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String command,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'file',
      method: 'exec',
      params: fileExecParams('/bin/sh', ['-c', command]),
      context: context,
    );
  }

  /// Helper to safely obtain mounted BuildContext across async gaps.
  BuildContext? mountedContext(BuildContext? ctx) => (ctx != null && ctx.mounted) ? ctx : null;

  @override
  bool execSucceeded(dynamic res) {
    if (res == null) return false;
    if (res is List && res.isNotEmpty) {
      if (res.length > 1 && res[1] is Map) {
        final map = res[1] as Map;
        if (map['code'] is int) return map['code'] == 0;
        return res[0] == 0;
      }
      return res[0] == 0;
    }
    if (res is Map) {
      if (res['code'] is int) return res['code'] == 0;
      if (res['rc'] is int) return res['rc'] == 0;
      return false;
    }
    return res == 0;
  }

  bool _execSucceeded(dynamic res) => execSucceeded(res);



  @override
  Future<bool> setSsidEnabled(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String ifaceSection,
    required bool enabled,
    BuildContext? context,
  }) async {
    try {
      final setRes = await uciSet(
        ipAddress,
        sysauth,
        useHttps,
        config: 'wireless',
        section: ifaceSection,
        values: {'disabled': enabled ? '0' : '1'},
        context: context,
      );
      if (setRes is List && setRes.isNotEmpty && setRes[0] != 0) {
        return false;
      }

      final commitRes = await uciCommit(
        ipAddress,
        sysauth,
        useHttps,
        config: 'wireless',
        context: mountedContext(context),
      );
      if (commitRes is List && commitRes.isNotEmpty && commitRes[0] != 0) {
        return false;
      }

      // Reload wifi configuration
      final reloadRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/sbin/wifi',
          'params': ['reload'],
        },
        context: mountedContext(context),
      );
      return _execSucceeded(reloadRes);
    } catch (e, stack) {
      Logger.exception('setSsidEnabled failed for $ifaceSection', e, stack);
      return false;
    }
  }

  @override
  Future<bool> setWifiAccessControl(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required Map<String, List<String>> maclistByIface,
    required Map<String, String> macfilterByIface,
    BuildContext? context,
  }) async {
    try {
      final allSections = {...maclistByIface.keys, ...macfilterByIface.keys};
      for (final section in allSections) {
        final values = <String, dynamic>{};
        if (macfilterByIface.containsKey(section)) {
          values['macfilter'] = macfilterByIface[section]!;
        }
        if (maclistByIface.containsKey(section)) {
          values['maclist'] = maclistByIface[section]!;
        }

        final res = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'set',
          params: {'config': 'wireless', 'section': section, 'values': values},
          context: mountedContext(context),
        );
        if (res is List && res.isNotEmpty && res[0] != 0) {
          return false;
        }
      }

      final applyRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'apply',
        params: {'rollback': true, 'timeout': 25},
        context: mountedContext(context),
      );
      return applyRes is List && applyRes.isNotEmpty && applyRes[0] == 0;
    } catch (e, stack) {
      Logger.exception('setWifiAccessControl failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> confirmWifiAccessControl(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'confirm',
        params: {},
        context: mountedContext(context),
      );
      return res is List && res.isNotEmpty && res[0] == 0;
    } catch (e, stack) {
      Logger.exception('confirmWifiAccessControl failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> revertWifiAccessControl(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required Map<String, List<String>> maclistByIface,
    required Map<String, String> macfilterByIface,
    BuildContext? context,
  }) async {
    try {
      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'revert',
        params: {'config': 'wireless'},
        context: mountedContext(context),
      );

      // Fallback: If uci revert didn't clean everything, explicitly re-apply prior state
      final allSections = {...maclistByIface.keys, ...macfilterByIface.keys};
      for (final section in allSections) {
        final values = <String, dynamic>{};
        if (macfilterByIface.containsKey(section)) {
          values['macfilter'] = macfilterByIface[section]!;
        }
        if (maclistByIface.containsKey(section)) {
          values['maclist'] = maclistByIface[section]!;
        }
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'set',
          params: {'config': 'wireless', 'section': section, 'values': values},
          context: mountedContext(context),
        );
      }
      await uciCommit(ipAddress, sysauth, useHttps, config: 'wireless', context: mountedContext(context));
      final reloadRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/sbin/wifi',
          'params': ['reload'],
        },
        context: mountedContext(context),
      );

      return res is List && res.isNotEmpty && res[0] == 0 && _execSucceeded(reloadRes);
    } catch (e, stack) {
      Logger.exception('revertWifiAccessControl failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> autoFixPermissions(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/bin/sh',
          'params': [
            '-c',
            'mkdir -p /usr/share/rpcd/acl.d/ && '
            'printf \'{\\n  "luci-app-tailscale": {\\n    "description": "Tailscale VPN ACL Permissions",\\n    "read": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      }\\n    },\\n    "write": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      }\\n    }\\n  }\\n}\\n\' > /usr/share/rpcd/acl.d/luci-app-tailscale.json && '
            'if command -v apk >/dev/null 2>&1; then '
            'apk update && apk add luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status; '
            'else '
            'opkg update && opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status; '
            'fi && /etc/init.d/rpcd restart'
          ],
        },
        context: context,
      );
      if (_execSucceeded(res)) {
        return true;
      }

      final fallbackRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/bin/sh',
          'args': [
            '-c',
            'mkdir -p /usr/share/rpcd/acl.d/ && '
            'printf \'{\\n  "luci-app-tailscale": {\\n    "description": "Tailscale VPN ACL Permissions",\\n    "read": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      }\\n    },\\n    "write": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      }\\n    }\\n  }\\n}\\n\' > /usr/share/rpcd/acl.d/luci-app-tailscale.json && '
            'if command -v apk >/dev/null 2>&1; then '
            'apk update && apk add luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status; '
            'else '
            'opkg update && opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status; '
            'fi && /etc/init.d/rpcd restart'
          ],
        },
        context: context,
      );
      return _execSucceeded(fallbackRes);
    } catch (e, stack) {
      Logger.exception('autoFixPermissions failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> ensureSilentPermissions(
    String ipAddress,
    String sysauth,
    bool useHttps,
  ) async {
    try {
      const aclScript =
          'if [ ! -f /usr/share/rpcd/acl.d/yet-another-luci-app.json ]; then '
          'mkdir -p /usr/share/rpcd/acl.d/ && '
          'printf \'{\\n  "yet-another-luci-app": {\\n    "description": "Yet Another LuCI App Silent RPC Permissions",\\n    "read": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      },\\n      "ubus": {\\n        "iwinfo": [ "*" ],\\n        "rc": [ "*" ],\\n        "file": [ "*" ],\\n        "luci-rpc": [ "*" ]\\n      }\\n    },\\n    "write": {\\n      "file": {\\n        "/usr/sbin/tailscale": [ "exec" ],\\n        "/usr/bin/tailscale": [ "exec" ],\\n        "/usr/bin/nextdns": [ "exec" ],\\n        "/usr/bin/cloudflared": [ "exec" ]\\n      },\\n      "ubus": {\\n        "iwinfo": [ "*" ],\\n        "rc": [ "*" ],\\n        "file": [ "*" ],\\n        "luci-rpc": [ "*" ]\\n      }\\n    }\\n  }\\n}\\n\' > /usr/share/rpcd/acl.d/yet-another-luci-app.json && '
          '(/etc/init.d/rpcd reload 2>/dev/null || /etc/init.d/rpcd restart 2>/dev/null || true); '
          'fi';

      await call(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/bin/sh',
          'params': ['-c', aclScript],
        },
      );
      return true;
    } catch (e) {
      Logger.warning('Silent background permission setup skipped/failed: $e');
      return false;
    }
  }

  @override
  Future<bool> manageServiceAction(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String serviceName,
    required String action,
    BuildContext? context,
  }) async {
    try {
      try {
        final rcRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {
            'name': serviceName,
            'action': action,
          },
          context: context,
        );
        if (_execSucceeded(rcRes)) return true;
      } catch (_) {
        // Older LuCI/rpcd builds may not expose rc.init; fall back below.
      }

      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/etc/init.d/$serviceName',
          'params': [action],
        },
        context: context,
      );
      return _execSucceeded(res);
    } catch (e, stack) {
      Logger.exception('manageServiceAction failed for $serviceName', e, stack);
      return false;
    }
  }

  /// Enforces client restriction via firewall rules (UCI firewall + nftables/iptables)
  /// and notifies user if the firewall rule was created for the first time.
  Future<bool> _enforceFirewallBlock({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String macAddress,
    String rulePrefix = 'nointernet_wireless_clients',
    BuildContext? context,
  }) async {
    final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
    final macLower = macAddress.toLowerCase();
    final ruleName = "nointernet_wireless_clients";

    bool ruleExisted = false;

    // 1. Check existing uci firewall rules via native ubus call
    try {
      final getRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'firewall'},
        context: mountedContext(context),
      );

      if (getRes is List && getRes.length > 1 && getRes[0] == 0) {
        final values = (getRes[1] as Map<String, dynamic>?)?['values'] as Map<String, dynamic>? ?? {};
        String? targetSecKey;
        List<String> currentMacs = [];

        for (final entry in values.entries) {
          final sec = entry.value;
          if (sec is Map<String, dynamic>) {
            final name = sec['name']?.toString() ?? '';
            if (name == ruleName) {
              ruleExisted = true;
              targetSecKey = entry.key;
              final srcMac = sec['src_mac'];
              if (srcMac is List) {
                currentMacs = srcMac.map((e) => e.toString().toUpperCase()).toList();
              } else if (srcMac != null) {
                currentMacs = [srcMac.toString().toUpperCase()];
              }
              break;
            }
          }
        }

        if (!ruleExisted) {
          await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'add',
            params: {
              'config': 'firewall',
              'type': 'rule',
              'values': {
                'name': ruleName,
                'src': '*',
                'dest': 'wan',
                'src_mac': [macUpper],
                'target': 'DROP',
                'enabled': '1',
              },
            },
            context: mountedContext(context),
          );
        } else if (targetSecKey != null && !currentMacs.contains(macUpper)) {
          currentMacs.add(macUpper);
          await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'set',
            params: {
              'config': 'firewall',
              'section': targetSecKey,
              'values': {
                'src': '*',
                'src_mac': currentMacs,
              },
            },
            context: mountedContext(context),
          );
        }

        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'commit',
          params: {'config': 'firewall'},
          context: mountedContext(context),
        );
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'firewall', 'action': 'reload'},
          context: mountedContext(context),
        );
      }
    } catch (e) {
      Logger.warning('Native ubus firewall rule check/add encountered issue: $e');
    }

    // 2. Shell fallback check and execute for single universal rule (uci, nft, and iptables)
    final shellScript = '''
MAC_U="$macUpper"
MAC_L="$macLower"
RULE_NAME="$ruleName"

EXISTS=\$(uci show firewall 2>/dev/null | grep -i "name=['"]*\${RULE_NAME}['"]*" | head -n 1)
if [ -z "\$EXISTS" ]; then
  uci add firewall rule >/dev/null
  uci set firewall.@rule[-1].name="\$RULE_NAME"
  uci set firewall.@rule[-1].src='*'
  uci set firewall.@rule[-1].dest='wan'
  uci add_list firewall.@rule[-1].src_mac="\$MAC_U"
  uci set firewall.@rule[-1].target='DROP'
  uci set firewall.@rule[-1].enabled='1'
else
  SEC=\$(uci show firewall 2>/dev/null | grep -i "name=['"]*\${RULE_NAME}['"]*" | cut -d. -f2)
  if [ -n "\$SEC" ]; then
    uci set firewall.\${SEC}.src='*' 2>/dev/null || true
    MAC_EXISTS=\$(uci get firewall.\${SEC}.src_mac 2>/dev/null | grep -i "\$MAC_U")
    if [ -z "\$MAC_EXISTS" ]; then
      uci add_list firewall.\${SEC}.src_mac="\$MAC_U"
    fi
  fi
fi
uci commit firewall
/etc/init.d/firewall reload >/dev/null 2>&1

nft add rule inet fw4 forward ether saddr "\$MAC_U" drop >/dev/null 2>&1 || true
nft add rule inet fw4 forward ether saddr "\$MAC_L" drop >/dev/null 2>&1 || true
iptables -I FORWARD -m mac --mac-source "\$MAC_U" -j DROP >/dev/null 2>&1 || true
iptables -I FORWARD -m mac --mac-source "\$MAC_L" -j DROP >/dev/null 2>&1 || true
exit 0
''';

    await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'file',
      method: 'exec',
      params: fileExecParams('/bin/sh', ['-c', shellScript]),
      context: mountedContext(context),
    );

    // If used for the FIRST time (rule didn't exist before), notify the user as requested
    if (!ruleExisted && context != null && context.mounted) {
      context.showToastInfo(
        'Firewall Rule Created',
        subtitle: 'Created firewall rule "$ruleName" to restrict client $macUpper',
        duration: const Duration(seconds: 4),
      );
    }

    return true;
  }

  /// Removes firewall block rules for the specified client MAC.
  Future<bool> _removeFirewallBlock({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String macAddress,
    BuildContext? context,
  }) async {
    final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
    final macLower = macAddress.toLowerCase();
    final macClean = macUpper.replaceAll(':', '');
    final ruleName = "nointernet_wireless_clients";

    try {
      final getRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'get',
        params: {'config': 'firewall'},
        context: mountedContext(context),
      );

      if (getRes is List && getRes.length > 1 && getRes[0] == 0) {
        final values = (getRes[1] as Map<String, dynamic>?)?['values'] as Map<String, dynamic>? ?? {};
        for (final entry in values.entries) {
          final secKey = entry.key;
          final sec = entry.value;
          if (sec is Map<String, dynamic>) {
            final name = sec['name']?.toString() ?? '';
            final srcMac = sec['src_mac'];
            List<String> macs = srcMac is List ? srcMac.map((e) => e.toString().toUpperCase()).toList() : (srcMac != null ? [srcMac.toString().toUpperCase()] : []);
            
            if (name == ruleName) {
              macs.removeWhere((m) => m == macUpper || m.toLowerCase() == macLower);
              if (macs.isEmpty) {
                await callWithContext(
                  ipAddress,
                  sysauth,
                  useHttps,
                  object: 'uci',
                  method: 'delete',
                  params: {'config': 'firewall', 'section': secKey},
                  context: mountedContext(context),
                );
              } else {
                await callWithContext(
                  ipAddress,
                  sysauth,
                  useHttps,
                  object: 'uci',
                  method: 'set',
                  params: {
                    'config': 'firewall',
                    'section': secKey,
                    'values': {'src_mac': macs},
                  },
                  context: mountedContext(context),
                );
              }
            } else if (name.startsWith('Pause_Internet_$macClean') ||
                       name.startsWith('Ban_Client_$macClean') ||
                       name.startsWith('Kick_Client_$macClean')) {
              await callWithContext(
                ipAddress,
                sysauth,
                useHttps,
                object: 'uci',
                method: 'delete',
                params: {'config': 'firewall', 'section': secKey},
                context: mountedContext(context),
              );
            }
          }
        }
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'commit',
          params: {'config': 'firewall'},
          context: mountedContext(context),
        );
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'firewall', 'action': 'reload'},
          context: mountedContext(context),
        );
      }
    } catch (e) {
      Logger.warning('Native ubus firewall remove encountered issue: $e');
    }

    final script = '''
MAC_U="$macUpper"
MAC_L="$macLower"
CLEAN="$macClean"
RULE_NAME="$ruleName"

SEC=\$(uci show firewall 2>/dev/null | grep -i "name=['"]*\${RULE_NAME}['"]*" | cut -d. -f2)
if [ -n "\$SEC" ]; then
  uci del_list firewall.\${SEC}.src_mac="\$MAC_U" 2>/dev/null || true
  uci del_list firewall.\${SEC}.src_mac="\$MAC_L" 2>/dev/null || true
  REMAINING=\$(uci get firewall.\${SEC}.src_mac 2>/dev/null | tr ' ' '\\n' | grep -v "^\$" | wc -l)
  if [ "\$REMAINING" -eq 0 ]; then
    uci delete firewall.\${SEC} 2>/dev/null || true
  fi
fi

for legacy in \$(uci show firewall 2>/dev/null | grep -iE "Pause_Internet_\${CLEAN}|Ban_Client_\${CLEAN}" | cut -d. -f2); do
  uci delete firewall.\${legacy} 2>/dev/null || true
done

uci commit firewall
/etc/init.d/firewall reload >/dev/null 2>&1

nft delete rule inet fw4 forward ether saddr "\$MAC_U" >/dev/null 2>&1 || true
nft delete rule inet fw4 forward ether saddr "\$MAC_L" >/dev/null 2>&1 || true
iptables -D FORWARD -m mac --mac-source "\$MAC_U" -j DROP >/dev/null 2>&1 || true
iptables -D FORWARD -m mac --mac-source "\$MAC_L" -j DROP >/dev/null 2>&1 || true
exit 0
''';

    await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'file',
      method: 'exec',
      params: fileExecParams('/bin/sh', ['-c', script]),
      context: mountedContext(context),
    );

    return true;
  }

  @override
  Future<bool> disconnectWirelessClient(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    String? iface,
    BuildContext? context,
  }) async {
    try {
      final macUpper = macAddress.toUpperCase();
      final macLower = macAddress.toLowerCase();

      // 1. Enforce firewall block rule first (and notify if created for first time)
      await _enforceFirewallBlock(
        ipAddress: ipAddress,
        sysauth: sysauth,
        useHttps: useHttps,
        macAddress: macAddress,
        rulePrefix: 'Ban_Client_',
        context: context,
      );

      // 2. Perform immediate Wi-Fi deauth / client disconnection
      if (iface != null && iface.isNotEmpty) {
        for (final mac in [macUpper, macLower]) {
          try {
            await callWithContext(
              ipAddress,
              sysauth,
              useHttps,
              object: 'hostapd.$iface',
              method: 'del_client',
              params: {'addr': mac, 'reason': 1, 'deauth': true, 'ban_time': 0},
              context: mountedContext(context),
            );
          } catch (_) {}
        }
      }

      try {
        final listRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rpc',
          method: 'list',
          params: {},
          context: mountedContext(context),
        );
        if (listRes is List && listRes.length > 1 && listRes[0] == 0 && listRes[1] is Map) {
          final objects = (listRes[1] as Map).keys.where((k) => k.toString().startsWith('hostapd.')).toList();
          for (final obj in objects) {
            final objName = obj.toString();
            for (final mac in [macUpper, macLower]) {
              try {
                await callWithContext(
                  ipAddress,
                  sysauth,
                  useHttps,
                  object: objName,
                  method: 'del_client',
                  params: {'addr': mac, 'reason': 1, 'deauth': true, 'ban_time': 0},
                  context: mountedContext(context),
                );
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      final targetIface = (iface != null && iface.isNotEmpty) ? iface : '';
      final cmdScript = '''
MAC_U="$macUpper"
MAC_L="$macLower"
IFACE="$targetIface"

if [ -n "\$IFACE" ]; then
  /usr/sbin/hostapd_cli -i "\$IFACE" deauth "\$MAC_U" 2>/dev/null || true
  ubus call "hostapd.\$IFACE" del_client '{"addr":"'"\$MAC_U"'","reason":1,"deauth":true}' 2>/dev/null || true
fi
for s in /var/run/hostapd/* /var/run/hostapd-*/*; do
  if [ -S "\$s" ]; then
    s_dir="\${s%/*}"
    s_if="\${s##*/}"
    /usr/sbin/hostapd_cli -p "\$s_dir" -i "\$s_if" deauth "\$MAC_U" 2>/dev/null || true
  fi
done
for obj in \$(ubus list 'hostapd.*' 2>/dev/null); do
  ubus call "\$obj" del_client '{"addr":"'"\$MAC_U"'","reason":1,"deauth":true}' 2>/dev/null || true
  ubus call "\$obj" del_client '{"addr":"'"\$MAC_L"'","reason":1,"deauth":true}' 2>/dev/null || true
done
for dev in \$(iw dev 2>/dev/null | awk '\$1=="Interface"{print \$2}'); do
  iw dev "\$dev" station del "\$MAC_L" 2>/dev/null || true
  iw dev "\$dev" station del "\$MAC_U" 2>/dev/null || true
done
exit 0
''';

      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: fileExecParams('/bin/sh', ['-c', cmdScript]),
        context: mountedContext(context),
      );

      return true;
    } catch (e, stack) {
      Logger.exception('disconnectWirelessClient failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> pauseClientInternet(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    required bool pause,
    BuildContext? context,
  }) async {
    if (pause) {
      return _enforceFirewallBlock(
        ipAddress: ipAddress,
        sysauth: sysauth,
        useHttps: useHttps,
        macAddress: macAddress,
        rulePrefix: 'Pause_Internet_',
        context: context,
      );
    } else {
      return _removeFirewallBlock(
        ipAddress: ipAddress,
        sysauth: sysauth,
        useHttps: useHttps,
        macAddress: macAddress,
        context: context,
      );
    }
  }

  @override
  Future<bool> banWirelessClient(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    String? iface,
    BuildContext? context,
  }) async {
    return disconnectWirelessClient(
      ipAddress,
      sysauth,
      useHttps,
      macAddress: macAddress,
      iface: iface,
      context: context,
    );
  }

  @override
  Future<bool> unbanWirelessClient(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    BuildContext? context,
  }) async {
    return _removeFirewallBlock(
      ipAddress: ipAddress,
      sysauth: sysauth,
      useHttps: useHttps,
      macAddress: macAddress,
      context: context,
    );
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchRestrictedAndBannedClientsLive(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      final script = '''
RESTRICTED_MACS=\$(uci show firewall 2>/dev/null | grep -iE "target=['"]*(DROP|REJECT)['"]*|nointernet_wireless_clients|Pause_Internet_|Ban_Client_" -B 2 -A 25 | grep -i "src_mac" | grep -oE "([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}" || true)
NFT_MACS=\$(nft list chain inet fw4 forward 2>/dev/null | grep -iE "drop|reject" | grep -oE "([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}" || true)
IPT_MACS=\$(iptables -L FORWARD -v -n 2>/dev/null | grep -iE "DROP|REJECT" | grep -oE "([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}" || true)

ALL_RESTRICTED=\$(echo "\$RESTRICTED_MACS \$NFT_MACS \$IPT_MACS" | tr ' ' '\\n' | grep -vE "^00:00:00:00:00:00\$|^FF:FF:FF:FF:FF:FF\$" | sort -u | grep -v "^\$")

BANNED_MACS=\$(uci show wireless 2>/dev/null | grep -iE "macfilter=['"]*(deny|2)['"]*" -A 5 | grep -i "maclist" | grep -oE "([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}" || true)

ALL_BANNED=\$(echo "\$BANNED_MACS" | tr ' ' '\\n' | grep -vE "^00:00:00:00:00:00\$|^FF:FF:FF:FF:FF:FF\$" | sort -u | grep -v "^\$")

echo "RESTRICTED:"
echo "\$ALL_RESTRICTED"
echo "BANNED:"
echo "\$ALL_BANNED"
''';

      final res = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/bin/sh',
          'params': ['-c', script],
        },
        context: mountedContext(context),
      );

      final result = <String, List<Map<String, dynamic>>>{
        'restricted': [],
        'banned': [],
      };

      Map<String, dynamic>? cachedHostHints;
      Future<Map<String, dynamic>> getHostHints() async {
        cachedHostHints ??= await fetchHostHintsWithContext(
          ipAddress: ipAddress,
          sysauth: sysauth,
          useHttps: useHttps,
          context: mountedContext(context),
        );
        return cachedHostHints!;
      }

      if (res is List && res.length > 1 && res[0] == 0) {
        final resMap = res[1] as Map<String, dynamic>?;
        final stdout = resMap?['stdout']?.toString() ?? '';

        final hostHints = await getHostHints();

        String currentSection = '';
        for (final line in stdout.split('\n')) {
          final trimmed = line.trim();
          if (trimmed == 'RESTRICTED:') {
            currentSection = 'restricted';
            continue;
          } else if (trimmed == 'BANNED:') {
            currentSection = 'banned';
            continue;
          }

          if (trimmed.isNotEmpty && trimmed.contains(':')) {
            final macUpper = trimmed.toUpperCase().replaceAll('-', ':');
            if (macUpper == '00:00:00:00:00:00' || macUpper == 'FF:FF:FF:FF:FF:FF') {
              continue;
            }
            final macLower = macUpper.toLowerCase();
            final macHyphen = macUpper.replaceAll(':', '-');
            final rawHint = hostHints[macUpper] ?? hostHints[macLower] ?? hostHints[macHyphen];
            final hint = rawHint is Map<String, dynamic> ? rawHint : <String, dynamic>{};
            final name = hint['name']?.toString() ?? hint['staticLeaseName']?.toString() ?? macUpper;
            final ips = hint['ipaddrs'] as List?;
            final ip = (ips != null && ips.isNotEmpty) ? ips.first.toString() : 'N/A';

            final entry = {
              'mac': macUpper,
              'name': name,
              'ip': ip,
              'type': currentSection,
            };

            if (currentSection == 'restricted') {
              result['restricted']!.add(entry);
            } else if (currentSection == 'banned') {
              result['banned']!.add(entry);
            }
          }
        }
      }

      if (result['restricted']!.isEmpty && result['banned']!.isEmpty) {
        try {
          final wirelessRes = await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'get',
            params: {'config': 'wireless'},
            context: mountedContext(context),
          );
          if (wirelessRes is List && wirelessRes.length > 1 && wirelessRes[0] == 0) {
            final values = (wirelessRes[1] as Map<String, dynamic>?)?['values'] as Map<String, dynamic>?;
            if (values != null) {
              final hostHints = await getHostHints();
              for (final sec in values.values) {
                if (sec is Map<String, dynamic>) {
                  final macfilter = sec['macfilter']?.toString().toLowerCase();
                  if (macfilter == 'deny' || macfilter == '2') {
                    final maclist = sec['maclist'];
                    final macs = maclist is List ? maclist : (maclist != null ? [maclist] : []);
                    for (final m in macs) {
                      final mStr = m.toString();
                      if (mStr.isNotEmpty && (mStr.contains(':') || mStr.contains('-'))) {
                        final macUpper = mStr.toUpperCase().replaceAll('-', ':');
                        if (macUpper != '00:00:00:00:00:00' && macUpper != 'FF:FF:FF:FF:FF:FF' && !result['banned']!.any((e) => e['mac'] == macUpper)) {
                          final rawHint = hostHints[macUpper] ?? hostHints[macUpper.toLowerCase()];
                          final hint = rawHint is Map<String, dynamic> ? rawHint : <String, dynamic>{};
                          final name = hint['name']?.toString() ?? hint['staticLeaseName']?.toString() ?? macUpper;
                          result['banned']!.add({
                            'mac': macUpper,
                            'name': name,
                            'ip': 'N/A',
                            'type': 'banned',
                          });
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          final firewallRes = await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'get',
            params: {'config': 'firewall'},
            context: mountedContext(context),
          );
          if (firewallRes is List && firewallRes.length > 1 && firewallRes[0] == 0) {
            final values = (firewallRes[1] as Map<String, dynamic>?)?['values'] as Map<String, dynamic>?;
            if (values != null) {
              final hostHints = await getHostHints();
              for (final sec in values.values) {
                if (sec is Map<String, dynamic>) {
                  final target = sec['target']?.toString().toUpperCase();
                  final name = sec['name']?.toString();
                  if (target == 'DROP' || target == 'REJECT' || (name != null && (name.startsWith('Pause_Internet_') || name.startsWith('Ban_Client_') || name.startsWith('Kick_Client_')))) {
                    final srcMac = sec['src_mac'];
                    final macs = srcMac is List ? srcMac : (srcMac != null ? [srcMac] : []);
                    for (final m in macs) {
                      final mStr = m.toString();
                      if (mStr.isNotEmpty && (mStr.contains(':') || mStr.contains('-'))) {
                        final macUpper = mStr.toUpperCase().replaceAll('-', ':');
                        if (macUpper != '00:00:00:00:00:00' && macUpper != 'FF:FF:FF:FF:FF:FF' && !result['restricted']!.any((e) => e['mac'] == macUpper)) {
                          final rawHint = hostHints[macUpper] ?? hostHints[macUpper.toLowerCase()];
                          final hint = rawHint is Map<String, dynamic> ? rawHint : <String, dynamic>{};
                          final name = hint['name']?.toString() ?? hint['staticLeaseName']?.toString() ?? macUpper;
                          result['restricted']!.add({
                            'mac': macUpper,
                            'name': name,
                            'ip': 'N/A',
                            'type': 'restricted',
                          });
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          Logger.warning('UCI fallback in fetchRestrictedAndBannedClientsLive encountered issue: $e');
        }
      }

      return result;
    } catch (e, stack) {
      Logger.exception('fetchRestrictedAndBannedClientsLive failed', e, stack);
      return {'restricted': [], 'banned': []};
    }
  }

  static String? _sanitizeOpenWrtLeaseTime(String? lt) {
    if (lt == null) return null;
    final trimmed = lt.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (trimmed == 'infinite') return 'infinite';

    if (trimmed.endsWith('w')) {
      final weeks = int.tryParse(trimmed.substring(0, trimmed.length - 1));
      if (weeks != null && weeks > 0) return '${weeks * 7}d';
    }
    if (trimmed.endsWith('s')) {
      final secs = int.tryParse(trimmed.substring(0, trimmed.length - 1));
      if (secs != null && secs > 0) {
        final mins = (secs / 60).ceil();
        return '${mins < 2 ? 2 : mins}m';
      }
    }
    if (RegExp(r'^\d+[mhd]$').hasMatch(trimmed)) {
      return trimmed;
    }
    final plainNumber = int.tryParse(trimmed);
    if (plainNumber != null && plainNumber > 0) {
      final mins = (plainNumber / 60).ceil();
      return '${mins < 2 ? 2 : mins}m';
    }
    return '12h';
  }

  @override
  Future<bool> addStaticLease(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    required String targetIp,
    required String hostname,
    String? targetIp6,
    String? duid,
    String? leaseTime,
    BuildContext? context,
  }) async {
    try {
      final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
      final cleanTargetIp = targetIp.trim();
      final sanitizedLt = _sanitizeOpenWrtLeaseTime(leaseTime);

      final values = <String, String>{
        'name': hostname.trim(),
      };

      if (macUpper.isNotEmpty && macUpper != 'N/A' && !macUpper.startsWith('DUID:')) {
        values['mac'] = macUpper;
      }
      if (cleanTargetIp.isNotEmpty && cleanTargetIp != 'N/A') {
        values['ip'] = cleanTargetIp;
      }
      if (targetIp6 != null && targetIp6.trim().isNotEmpty && targetIp6.trim() != 'N/A') {
        values['ip6addr'] = targetIp6.trim();
      }
      if (duid != null && duid.trim().isNotEmpty && duid.trim() != 'N/A') {
        values['duid'] = duid.trim().toUpperCase();
      }
      if (sanitizedLt != null && sanitizedLt.isNotEmpty) {
        values['leasetime'] = sanitizedLt;
      }

      // 1. Find all existing host sections matching MAC or IP to prevent duplicate dhcp-host entries
      final matchingSections = <String>[];
      try {
        final getRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'get',
          params: {'config': 'dhcp'},
          context: mountedContext(context),
        );
        if (getRes is List && getRes.length > 1 && getRes[0] == 0) {
          final uciData = getRes[1];
          final valuesMap = (uciData is Map && uciData['values'] is Map)
              ? uciData['values'] as Map
              : (uciData is Map ? uciData : {});
          valuesMap.forEach((key, val) {
            if (val is Map && val['.type'] == 'host') {
              final macVal = val['mac'];
              final ipVal = val['ip']?.toString().trim();
              bool isMatch = false;

              if (ipVal == cleanTargetIp) {
                isMatch = true;
              } else if (macVal is String && macVal.toUpperCase().replaceAll('-', ':') == macUpper) {
                isMatch = true;
              } else if (macVal is List) {
                for (final item in macVal) {
                  if (item.toString().toUpperCase().replaceAll('-', ':') == macUpper) {
                    isMatch = true;
                    break;
                  }
                }
              }

              if (isMatch) {
                matchingSections.add(key.toString());
              }
            }
          });
        }
      } catch (e) {
        Logger.warning('uci dhcp lookup encountered issue during addStaticLease: $e');
      }

      bool addSuccess = false;

      // Delete any duplicate matching sections beyond the first one
      if (matchingSections.length > 1) {
        for (int i = 1; i < matchingSections.length; i++) {
          try {
            await callWithContext(
              ipAddress,
              sysauth,
              useHttps,
              object: 'uci',
              method: 'delete',
              params: {'config': 'dhcp', 'section': matchingSections[i]},
              context: mountedContext(context),
            );
          } catch (_) {}
        }
      }

      if (matchingSections.isNotEmpty) {
        // Update existing primary section in place
        final setRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'set',
          params: {
            'config': 'dhcp',
            'section': matchingSections.first,
            'values': values,
          },
          context: mountedContext(context),
        );
        addSuccess = setRes is List && setRes.isNotEmpty && setRes[0] == 0;
        if (addSuccess) {
          await uciCommit(ipAddress, sysauth, useHttps, config: 'dhcp', context: mountedContext(context));
        }
      } else {
        // Create new host section via uci.add
        final addRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'add',
          params: {
            'config': 'dhcp',
            'type': 'host',
            'values': values,
          },
          context: mountedContext(context),
        );
        addSuccess = addRes is List && addRes.isNotEmpty && addRes[0] == 0;
        if (addSuccess) {
          await uciCommit(ipAddress, sysauth, useHttps, config: 'dhcp', context: mountedContext(context));
        }
      }

      if (!addSuccess) {
        // Fallback: Shell execution via /bin/sh - ensures duplicates are deleted and dnsmasq restarted
        final cmdList = [
          'for sec in \$(uci show dhcp 2>/dev/null | grep -iE "$macUpper|$cleanTargetIp" | cut -d. -f2 | sort -u); do uci delete dhcp.\$sec 2>/dev/null || true; done',
          'SECNAME=\$(uci add dhcp host)',
          'uci set dhcp.\$SECNAME.name="${hostname.trim()}"',
          'uci set dhcp.\$SECNAME.mac="$macUpper"',
          'uci set dhcp.\$SECNAME.ip="$cleanTargetIp"',
        ];
        if (sanitizedLt != null && sanitizedLt.isNotEmpty) {
          cmdList.add('uci set dhcp.\$SECNAME.leasetime="$sanitizedLt"');
        }
        cmdList.add('uci commit dhcp');

        final shellRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {
            'command': '/bin/sh',
            'params': ['-c', cmdList.join(' && ')],
          },
          context: mountedContext(context),
        );
        addSuccess = _execSucceeded(shellRes);
      }

      // Restart dnsmasq service to ensure clean recovery & application of static lease
      await manageServiceAction(
        ipAddress,
        sysauth,
        useHttps,
        serviceName: 'dnsmasq',
        action: 'restart',
        context: mountedContext(context),
      );

      return addSuccess;
    } catch (e, stack) {
      Logger.exception('addStaticLease failed for $macAddress', e, stack);
      return false;
    }
  }

  @override
  Future<bool> deleteStaticLease(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    BuildContext? context,
  }) async {
    try {
      final cleanMac = macAddress.trim().toLowerCase();
      final sectionsToDelete = <String>[];

      // 1. Attempt to find all matching sections via UCI ubus call
      try {
        final getRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'get',
          params: {'config': 'dhcp'},
          context: mountedContext(context),
        );

        if (getRes is List && getRes.length > 1 && getRes[0] == 0) {
          final uciData = getRes[1];
          final valuesMap = (uciData is Map && uciData['values'] is Map)
              ? uciData['values'] as Map
              : (uciData is Map ? uciData : {});
          valuesMap.forEach((key, val) {
            if (val is Map && val['.type'] == 'host') {
              final macVal = val['mac'];
              if (macVal is String) {
                if (macVal.toLowerCase().contains(cleanMac)) {
                  sectionsToDelete.add(key.toString());
                }
              } else if (macVal is List) {
                for (final item in macVal) {
                  if (item.toString().toLowerCase().contains(cleanMac)) {
                    sectionsToDelete.add(key.toString());
                    break;
                  }
                }
              }
            }
          });
        }
      } catch (e) {
        Logger.warning('ubus dhcp config lookup failed during deleteStaticLease: $e');
      }

      bool deleteSuccess = false;

      if (sectionsToDelete.isNotEmpty) {
        for (final sec in sectionsToDelete) {
          final delRes = await callWithContext(
            ipAddress,
            sysauth,
            useHttps,
            object: 'uci',
            method: 'delete',
            params: {
              'config': 'dhcp',
              'section': sec,
            },
            context: mountedContext(context),
          );
          if (delRes is List && delRes.isNotEmpty && delRes[0] == 0) {
            deleteSuccess = true;
          }
        }
        if (deleteSuccess) {
          await uciCommit(ipAddress, sysauth, useHttps, config: 'dhcp', context: mountedContext(context));
        }
      }

      // 2. Fallback to shell execution if ubus delete failed or sections were not matched via ubus
      if (!deleteSuccess) {
        final shellRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: {
            'command': '/bin/sh',
            'params': ['-c', "for sec in \$(uci show dhcp 2>/dev/null | grep -i '$cleanMac' | cut -d. -f2 | sort -u); do uci delete dhcp.\$sec 2>/dev/null || true; done; uci commit dhcp && /etc/init.d/dnsmasq restart"],
          },
          context: mountedContext(context),
        );
        deleteSuccess = _execSucceeded(shellRes);
      } else {
        // Restart dnsmasq service to apply change
        await manageServiceAction(
          ipAddress,
          sysauth,
          useHttps,
          serviceName: 'dnsmasq',
          action: 'restart',
          context: mountedContext(context),
        );
      }

      return deleteSuccess;
    } catch (e, stack) {
      Logger.exception('deleteStaticLease failed for $macAddress', e, stack);
      return false;
    }
  }

  @override
  Future<bool> refreshClientConnection(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String macAddress,
    BuildContext? context,
  }) async {
    try {
      final macUpper = macAddress.toUpperCase().replaceAll('-', ':');
      final macLower = macAddress.toLowerCase().replaceAll('-', ':');

      final script = '''
MAC_U="$macUpper"
MAC_L="$macLower"

if [ -f /tmp/dhcp.leases ]; then
  sed -i "/\$MAC_U/d; /\$MAC_L/d" /tmp/dhcp.leases 2>/dev/null || true
fi

for obj in \$(ubus list 'hostapd.*' 2>/dev/null); do
  ubus call "\$obj" del_client '{"addr":"'"\$MAC_U"'","reason":1,"deauth":true}' 2>/dev/null || true
  ubus call "\$obj" del_client '{"addr":"'"\$MAC_L"'","reason":1,"deauth":true}' 2>/dev/null || true
done
for dev in \$(iw dev 2>/dev/null | awk '\$1=="Interface"{print \$2}'); do
  iw dev "\$dev" station del "\$MAC_L" 2>/dev/null || true
  iw dev "\$dev" station del "\$MAC_U" 2>/dev/null || true
done

/etc/init.d/dnsmasq reload 2>/dev/null || true
exit 0
''';

      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: fileExecParams('/bin/sh', ['-c', script]),
        context: mountedContext(context),
      );

      return true;
    } catch (e, stack) {
      Logger.exception('refreshClientConnection failed for $macAddress', e, stack);
      return false;
    }
  }

  @override
  Future<int> deleteUnusedDhcpLeases(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required List<String> macsToFlush,
    BuildContext? context,
  }) async {
    if (macsToFlush.isEmpty) return 0;
    try {
      // 1. Fetch running processes to find PIDs of dnsmasq and odhcpd
      try {
        final procRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'luci',
          method: 'getProcessList',
          params: {},
          context: mountedContext(context),
        );
        if (procRes is Map && procRes['result'] is List) {
          final pList = procRes['result'] as List;
          for (final proc in pList) {
            if (proc is Map) {
              final cmd = (proc['COMMAND'] ?? '').toString();
              final pid = (proc['PID'] ?? '').toString();
              if (pid.isNotEmpty && (cmd.contains('dnsmasq') || cmd.contains('odhcpd'))) {
                try {
                  // Send SIGHUP (-1) via /bin/kill which is allowed by ubus ACLs
                  await callWithContext(
                    ipAddress,
                    sysauth,
                    useHttps,
                    object: 'file',
                    method: 'exec',
                    params: fileExecParams('/bin/kill', ['-1', pid]),
                    context: mountedContext(context),
                  );
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}

      // 2. Commit uci dhcp configuration to sync OpenWrt DHCP subsystem
      try {
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'commit',
          params: {'config': 'dhcp'},
          context: mountedContext(context),
        );
      } catch (_) {}

      // 3. Fallback: attempt /bin/sh shell script if router allows full shell exec
      try {
        final macUpper = macsToFlush.map((m) => m.toUpperCase().replaceAll('-', ':')).join('|');
        final macLower = macsToFlush.map((m) => m.toLowerCase().replaceAll('-', ':')).join('|');
        final macPattern = '$macUpper|$macLower';
        final script = '''
for f in /tmp/dhcp.leases /var/dhcp.leases /tmp/dnsmasq.leases /var/run/odhcpd.leases /tmp/odhcpd.leases /tmp/hosts/odhcpd; do
  if [ -f "\$f" ]; then
    grep -vE "$macPattern" "\$f" > "\$f.tmp" 2>/dev/null && mv "\$f.tmp" "\$f" 2>/dev/null || true
  fi
done
exit 0
''';
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: fileExecParams('/bin/sh', ['-c', script]),
          context: mountedContext(context),
        );
      } catch (_) {}

      return macsToFlush.length;
    } catch (e, stack) {
      Logger.exception('deleteUnusedDhcpLeases failed', e, stack);
      return 0;
    }
  }

  @override
  Future<Map<String, String?>> fetchPublicIps(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    String? publicV4;
    String? publicV6;

    // 1. Attempt router-side URL fetch via /bin/sh exec (handles CGNAT from router WAN context)
    try {
      final cmd = 'V4=\$(wget -q -O - http://api.ipify.org 2>/dev/null || wget -q -O - http://checkip.amazonaws.com 2>/dev/null || curl -s -m 3 http://api.ipify.org 2>/dev/null || uclient-fetch -q -O - http://api.ipify.org 2>/dev/null); '
                  'V6=\$(wget -q -O - http://api6.ipify.org 2>/dev/null || wget -q -O - http://v6.ipv6-test.com/api/myip.php 2>/dev/null || curl -s -6 -m 3 http://api6.ipify.org 2>/dev/null || uclient-fetch -q -O - http://api6.ipify.org 2>/dev/null); '
                  'echo "V4:\$V4"; echo "V6:\$V6"';

      final shellRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': '/bin/sh',
          'params': ['-c', cmd],
        },
        context: mountedContext(context),
      );

      if (shellRes is List && shellRes.length > 1 && shellRes[0] == 0) {
        final stdout = shellRes[1]['stdout']?.toString() ?? '';
        for (final line in stdout.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('V4:')) {
            final candidate = trimmed.substring(3).trim();
            if (candidate.isNotEmpty && _isValidIpv4Candidate(candidate)) {
              publicV4 = candidate;
            }
          } else if (trimmed.startsWith('V6:')) {
            final candidate = trimmed.substring(3).trim();
            if (candidate.isNotEmpty && candidate.contains(':')) {
              publicV6 = candidate;
            }
          }
        }
      }
    } catch (e) {
      Logger.warning('Router-side public IP resolution failed: $e');
    }

    // 2. Client-side HTTP fallback if router execution returned null
    if (publicV4 == null) {
      try {
        final res = await http.get(Uri.parse('http://api.ipify.org')).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final body = res.body.trim();
          if (_isValidIpv4Candidate(body)) {
            publicV4 = body;
          }
        }
      } catch (e) {
        Logger.debug('Client-side IPv4 lookup failed: $e');
      }
    }

    if (publicV6 == null) {
      try {
        final res = await http.get(Uri.parse('http://api6.ipify.org')).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final body = res.body.trim();
          if (body.contains(':')) {
            publicV6 = body;
          }
        }
      } catch (e) {
        Logger.debug('Client-side IPv6 lookup failed: $e');
      }
    }

    return {'ipv4': publicV4, 'ipv6': publicV6};
  }

  static bool _isValidIpv4Candidate(String ip) {
    final reg = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.){3}(25[0-5]|(2[0-4]|1\d|[1-9]|)\d)$');
    return reg.hasMatch(ip);
  }

  @override
  Future<bool> forceRefreshDhcpLeases(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      // 1. Resolve lease file location from UCI dhcp config
      String leasePath = '/tmp/dhcp.leases';
      try {
        final uciRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'get',
          params: {'config': 'dhcp'},
          context: mountedContext(context),
        );
        if (execSucceeded(uciRes) && uciRes is List && uciRes.length > 1 && uciRes[1] is Map) {
          final values = uciRes[1]['values'] ?? uciRes[1];
          if (values is Map) {
            values.forEach((k, v) {
              if (v is Map && (v['.type'] == 'dnsmasq' || k.toString().contains('dnsmasq'))) {
                if (v['leasefile'] != null && v['leasefile'].toString().isNotEmpty) {
                  leasePath = v['leasefile'].toString();
                }
              }
            });
          }
        }
      } catch (_) {}

      bool executedAny = false;

      // 2. Stop dnsmasq and odhcpd via rc.init
      try {
        final stopDns = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'dnsmasq', 'action': 'stop'},
          context: mountedContext(context),
        );
        if (execSucceeded(stopDns)) executedAny = true;
      } catch (_) {}

      try {
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'odhcpd', 'action': 'stop'},
          context: mountedContext(context),
        );
      } catch (_) {}

      // 3. Send SIGHUP (-1) and SIGTERM (-15) via /bin/kill (allowed by rpcd ACLs) to dnsmasq and odhcpd
      try {
        final procRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'luci',
          method: 'getProcessList',
          params: {},
          context: mountedContext(context),
        );
        if (procRes is Map && procRes['result'] is List) {
          final pList = procRes['result'] as List;
          for (final proc in pList) {
            if (proc is Map) {
              final cmd = (proc['COMMAND'] ?? '').toString();
              final pid = (proc['PID'] ?? '').toString();
              if (pid.isNotEmpty && (cmd.contains('dnsmasq') || cmd.contains('odhcpd'))) {
                try {
                  await callWithContext(
                    ipAddress,
                    sysauth,
                    useHttps,
                    object: 'file',
                    method: 'exec',
                    params: fileExecParams('/bin/kill', ['-1', pid]),
                    context: mountedContext(context),
                  );
                  executedAny = true;
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}

      // 4. Shell purge fallback script if shell exec is permitted
      final purgeScript = '''
rm -f "$leasePath" /tmp/dhcp.leases /var/dhcp.leases /tmp/dnsmasq.leases /var/lib/misc/dnsmasq.leases /var/run/odhcpd.leases 2>/dev/null || > "$leasePath" 2>/dev/null || true
''';
      try {
        final shRes = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'file',
          method: 'exec',
          params: fileExecParams('/bin/sh', ['-c', purgeScript]),
          context: mountedContext(context),
        );
        if (execSucceeded(shRes)) executedAny = true;
      } catch (_) {}

      // 5. Commit UCI dhcp configuration
      try {
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'uci',
          method: 'commit',
          params: {'config': 'dhcp'},
          context: mountedContext(context),
        );
        executedAny = true;
      } catch (_) {}

      // 6. Restart/Start dnsmasq and odhcpd via rc.init & luci-rpc
      try {
        final startDns = await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'dnsmasq', 'action': 'restart'},
          context: mountedContext(context),
        );
        if (execSucceeded(startDns)) executedAny = true;
      } catch (_) {}

      try {
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'rc',
          method: 'init',
          params: {'name': 'odhcpd', 'action': 'restart'},
          context: mountedContext(context),
        );
      } catch (_) {}

      try {
        await callWithContext(
          ipAddress,
          sysauth,
          useHttps,
          object: 'luci-rpc',
          method: 'setInitAction',
          params: {'name': 'dnsmasq', 'action': 'restart'},
          context: mountedContext(context),
        );
      } catch (_) {}

      return executedAny;
    } catch (e, stack) {
      Logger.exception('forceRefreshDhcpLeases failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> saveCronJobs(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required List<String> cronLines,
    BuildContext? context,
  }) async {
    try {
      final sanitizedLines = cronLines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final content = sanitizedLines.isEmpty ? '' : '${sanitizedLines.join('\n')}\n';

      // 1. Write the crontab file to /etc/crontabs/root
      final writeRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'write',
        params: {
          'path': '/etc/crontabs/root',
          'data': content,
        },
        context: mountedContext(context),
      );

      final success = execSucceeded(writeRes);

      if (success) {
        // 2. Restart the cron daemon service so changes take effect immediately
        try {
          await manageServiceAction(
            ipAddress,
            sysauth,
            useHttps,
            serviceName: 'cron',
            action: 'restart',
            context: mountedContext(context),
          );
        } catch (_) {}
      }

      return success;
    } catch (e, stack) {
      Logger.exception('saveCronJobs failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> saveDdnsInstance(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required DdnsInstance instance,
    BuildContext? context,
  }) async {
    try {
      final setRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'set',
        params: {
          'config': 'ddns',
          'section': instance.name,
          'type': 'service',
          'values': instance.toUciParams(),
        },
        context: mountedContext(context),
      );

      if (!execSucceeded(setRes)) return false;

      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'commit',
        params: {'config': 'ddns'},
        context: mountedContext(context),
      );

      try {
        await manageServiceAction(
          ipAddress,
          sysauth,
          useHttps,
          serviceName: 'ddns',
          action: 'reload',
          context: mountedContext(context),
        );
      } catch (_) {}

      return true;
    } catch (e, stack) {
      Logger.exception('saveDdnsInstance failed', e, stack);
      return false;
    }
  }

  @override
  Future<bool> deleteDdnsInstance(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String instanceName,
    BuildContext? context,
  }) async {
    try {
      final delRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'delete',
        params: {
          'config': 'ddns',
          'section': instanceName,
        },
        context: mountedContext(context),
      );

      if (!execSucceeded(delRes)) return false;

      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'commit',
        params: {'config': 'ddns'},
        context: mountedContext(context),
      );

      try {
        await manageServiceAction(
          ipAddress,
          sysauth,
          useHttps,
          serviceName: 'ddns',
          action: 'reload',
          context: mountedContext(context),
        );
      } catch (_) {}

      return true;
    } catch (e, stack) {
      Logger.exception('deleteDdnsInstance failed', e, stack);
      return false;
    }
  }

  @override
  Future<DdnsValidationResult> testDdnsConfiguration(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required DdnsInstance instance,
    BuildContext? context,
  }) async {
    try {
      if (instance.lookupHost.isEmpty && instance.domain.isEmpty) {
        return DdnsValidationResult.failure('Lookup Hostname / Domain cannot be empty.');
      }

      final hostToTest = instance.lookupHost.isNotEmpty ? instance.lookupHost : instance.domain;

      final rpcRes = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'file',
        method: 'exec',
        params: {
          'command': 'nslookup',
          'params': [hostToTest],
        },
        context: mountedContext(context),
      );

      final stdout = rpcRes is Map ? rpcRes['stdout']?.toString() ?? '' : '';
      final stderr = rpcRes is Map ? rpcRes['stderr']?.toString() ?? '' : '';
      final combined = '$stdout\n$stderr'.trim();

      if (combined.contains('Address:') || combined.contains('Name:')) {
        return DdnsValidationResult.success(
          testOutput: 'DNS Lookup Successful:\n$combined',
        );
      } else if (combined.contains("can't find") || combined.contains('NXDOMAIN') || combined.contains('ServFail')) {
        return DdnsValidationResult.failure(
          'Hostname DNS lookup failed ($hostToTest). Ensure domain exists or is registered.',
          testOutput: combined,
        );
      }

      return DdnsValidationResult.success(
        testOutput: 'Configuration passed basic validation checks.\n$combined',
      );
    } catch (e) {
      return DdnsValidationResult.failure('Validation test execution error: $e');
    }
  }

  @override
  Future<bool> toggleGlobalDdns(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required bool enable,
    BuildContext? context,
  }) async {
    try {
      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'set',
        params: {
          'config': 'ddns',
          'section': 'global',
          'type': 'global',
          'values': {'is_enabled': enable ? '1' : '0'},
        },
        context: mountedContext(context),
      );

      await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'uci',
        method: 'commit',
        params: {'config': 'ddns'},
        context: mountedContext(context),
      );

      await manageServiceAction(
        ipAddress,
        sysauth,
        useHttps,
        serviceName: 'ddns',
        action: enable ? 'start' : 'stop',
        context: mountedContext(context),
      );

      return true;
    } catch (e, stack) {
      Logger.exception('toggleGlobalDdns failed', e, stack);
      return false;
    }
  }
}
