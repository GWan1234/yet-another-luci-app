import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import '../utils/http_client_manager.dart';
import '../utils/logger.dart';

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
        context: safeContext, // ignore: use_build_context_synchronously
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
            context: retryContext, // ignore: use_build_context_synchronously
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
          params: {'command': 'iw', 'args': ['dev']},
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
        result[label] = (result[label] ?? {})..addAll(stations);
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
          params: {'command': 'iwinfo', 'args': [interface, 'assoclist']},
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
            params: {'command': 'iw', 'args': ['dev', interface, 'station', 'dump']},
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
              final validName = (name != null && name.isNotEmpty && name != '*') ? name : null;
              final newIps = info['ipaddrs'] as List?;
              final newV6Ips = info['ip6addrs'] as List?;
              if (existing == null) {
                hints[normMac] = {
                  'name': name ?? '',
                  'staticLeaseName': validName,
                  'ipaddrs': newIps ?? [],
                  'ip6addrs': newV6Ips ?? [],
                };
              } else {
                // Keep static lease name if set, otherwise update missing fields
                if (existing['name'] == null || existing['name'].toString().isEmpty) {
                  existing['name'] = name ?? '';
                }
                if (existing['staticLeaseName'] == null && validName != null) {
                  existing['staticLeaseName'] = validName;
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
      object: 'system',
      method: 'exec',
      params: {'command': command},
      context: context,
    );
  }
}
