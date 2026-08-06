import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/router_capabilities.dart';
import 'package:luci_mobile/models/rpc_result.dart';
import 'package:luci_mobile/modules/package_manager/models/package_info.dart';

void main() {
  group('Package Manager Engine Wiring Tests', () {
    test('PackageManagerType is unified with PackageManagerEngine', () {
      expect(PackageManagerType.opkg, equals(PackageManagerEngine.opkg));
      expect(PackageManagerType.apk, equals(PackageManagerEngine.apk));
      expect(PackageManagerType.none, equals(PackageManagerEngine.none));
    });

    test('classifyExecResult maps exit code 127 to methodNotFound', () {
      final execPayload = [
        0,
        {
          'code': 127,
          'stdout': '',
          'stderr': 'opkg: command not found',
        }
      ];

      final result = RpcResult.classifyExecResult<String>(execPayload, (data) => data['stdout']);
      expect(result.status, equals(RpcCallStatus.methodNotFound));
      expect(result.isMethodNotFound, isTrue);
    });

    test('classifyExecResult maps exit code 126 and permission denied stderr to permissionDenied', () {
      final execPayload = [
        0,
        {
          'code': 126,
          'stdout': '',
          'stderr': 'Permission denied executing command',
        }
      ];

      final result = RpcResult.classifyExecResult<String>(execPayload, (data) => data['stdout']);
      expect(result.status, equals(RpcCallStatus.permissionDenied));
      expect(result.isPermissionDenied, isTrue);
    });

    test('classifyExecResult maps non-zero exit code to failed with raw stderr detail', () {
      final execPayload = [
        0,
        {
          'code': 1,
          'stdout': '',
          'stderr': 'opkg_install_cmd: Cannot install package luci-app-test: No space left on device',
        }
      ];

      final result = RpcResult.classifyExecResult<String>(execPayload, (data) => data['stdout']);
      expect(result.status, equals(RpcCallStatus.failed));
      expect(result.errorMessage, contains('No space left on device'));
    });

    test('classifyExecResult maps exit code 0 to success', () {
      final execPayload = [
        0,
        {
          'code': 0,
          'stdout': 'base-files - 1570-r23805\n',
          'stderr': '',
        }
      ];

      final result = RpcResult.classifyExecResult<String>(execPayload, (data) => data['stdout']);
      expect(result.status, equals(RpcCallStatus.success));
      expect(result.isSuccess, isTrue);
      expect(result.data, equals('base-files - 1570-r23805\n'));
    });

    test('OpenWrtPackageRepository correctly parses OPKG feeds', () {
      const line = 'src/gz openwrt_core https://downloads.openwrt.org/snapshots/packages/x86_64/base';
      final repo = OpenWrtPackageRepository.parseOpkgLine(line);

      expect(repo, isNotNull);
      expect(repo!.name, equals('openwrt_core'));
      expect(repo.url, equals('https://downloads.openwrt.org/snapshots/packages/x86_64/base'));
      expect(repo.engine, equals(PackageManagerEngine.opkg));
    });

    test('OpenWrtPackageRepository correctly parses APK repositories', () {
      const line = 'https://downloads.openwrt.org/snapshots/packages/x86_64/base';
      final repo = OpenWrtPackageRepository.parseApkLine(line);

      expect(repo, isNotNull);
      expect(repo!.url, equals('https://downloads.openwrt.org/snapshots/packages/x86_64/base'));
      expect(repo.engine, equals(PackageManagerEngine.apk));
    });
  });
}
