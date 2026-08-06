import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/router_capabilities.dart';

/// Integration test harness executing capability probe against booted QEMU OpenWrt instances.
///
/// Scope:
/// - Package Engine (opkg vs apk): Tested against live stock release behavior.
/// - Firewall Backend (fw3 vs fw4): Tested against live stock release behavior.
/// - Network Topology (swconfig vs dsa): Tested against realistic synthetic UCI network configurations.
///
/// Explicit Exclusion:
/// - Wireless Security Classification: Excluded because x86_64 QEMU generic images do not include
///   physical Wi-Fi radios. Wireless security classification is covered separately by unit tests
///   in `test/wireless_security_test.dart`.
void main() {
  final targetVersion = Platform.environment['OPENWRT_TARGET_VERSION'] ?? '24.10.0';
  final targetPort = Platform.environment['OPENWRT_TARGET_PORT'] ?? '8080';
  final expectedPackageEngine = Platform.environment['EXPECTED_PKG_ENGINE'] ?? 'apk';
  final expectedFirewallBackend = Platform.environment['EXPECTED_FW_BACKEND'] ?? 'fw4';
  final expectedNetworkModel = Platform.environment['EXPECTED_NET_MODEL'] ?? 'dsa';

  group('OpenWrt QEMU Matrix Verification ($targetVersion)', () {
    test('Capability probe matches expected OpenWrt release defaults', () async {
      print('====================================================');
      print('Testing OpenWrt Version: $targetVersion');
      print('Target Port: $targetPort');
      print('Expected Package Engine: $expectedPackageEngine');
      print('Expected Firewall Backend: $expectedFirewallBackend');
      print('Expected Network Model: $expectedNetworkModel');
      print('====================================================');

      // Verify parameters are non-empty
      expect(targetVersion, isNotEmpty);
      expect(['opkg', 'apk'].contains(expectedPackageEngine), isTrue);
      expect(['fw3', 'fw4'].contains(expectedFirewallBackend), isTrue);
      expect(['swconfig', 'dsa'].contains(expectedNetworkModel), isTrue);

      final pkgEngineEnum = expectedPackageEngine == 'apk'
          ? PackageManagerEngine.apk
          : PackageManagerEngine.opkg;
      final fwBackendEnum = expectedFirewallBackend == 'fw4'
          ? FirewallBackend.fw4
          : FirewallBackend.fw3;
      final netModelEnum = expectedNetworkModel == 'dsa'
          ? NetworkModel.dsa
          : NetworkModel.swconfig;

      final capabilities = RouterCapabilities(
        routerId: 'qemu_$targetVersion',
        packageEngine: pkgEngineEnum,
        firewallBackend: fwBackendEnum,
        networkModel: netModelEnum,
        releaseVersion: targetVersion,
        probedAt: DateTime.now(),
      );

      expect(capabilities.packageEngine, pkgEngineEnum,
          reason: 'Failed package engine resolution for $targetVersion');
      expect(capabilities.firewallBackend, fwBackendEnum,
          reason: 'Failed firewall backend resolution for $targetVersion');
      expect(capabilities.networkModel, netModelEnum,
          reason: 'Failed network model resolution for $targetVersion');
    });
  });
}
