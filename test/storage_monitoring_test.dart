import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/modules/storage_monitoring/models/storage_info.dart';

void main() {
  group('Storage Monitoring Tests', () {
    test('Parses standard df -k output correctly', () {
      const dfOutput = '''
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/root                15360     15360         0 100% /rom
tmpfs                   124808       988    123820   1% /tmp
/dev/ubi0_1              28468      5124     21876  19% /overlay
overlayfs:/overlay       28468      5124     21876  19% /
tmpfs                      512         0       512   0% /dev
''';

      final overview = StorageOverview.fromRpcData(dfOutput);
      expect(overview.mountPoints.length, equals(5));

      final root = overview.rootFs;
      expect(root, isNotNull);
      expect(root!.mountPath, equals('/'));

      final overlay = overview.overlayFs;
      expect(overlay, isNotNull);
      expect(overlay!.mountPath, equals('/overlay'));
      expect(overlay.sizeBytes, equals(28468 * 1024));
      expect(overlay.usedBytes, equals(5124 * 1024));
    });

    test('Parses df output with split device names and spaces in mount target', () {
      const dfOutput = '''
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/mapper/vg-root
                      10485760   5242880   5242880  50% /
/dev/sda1
                       1000000    100000    900000  10% /mnt/USB Drive
''';

      final overview = StorageOverview.fromRpcData(dfOutput);
      expect(overview.mountPoints.length, equals(2));
      expect(overview.mountPoints[0].mountPath, equals('/'));
      expect(overview.mountPoints[1].mountPath, equals('/mnt/USB Drive'));
      expect(overview.mountPoints[1].sizeBytes, equals(1000000 * 1024));
    });

    test('Parses /proc/mounts text fallback correctly', () {
      const procMounts = '''
/dev/root /rom squashfs ro,relatime 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev,noatime,size=124808k 0 0
/dev/ubi0_1 /overlay ubifs rw,noatime,ubi=0,vol=1 0 0
overlayfs:/overlay / overlay rw,noatime 0 0
''';

      final overview = StorageOverview.fromRpcData(procMounts);
      expect(overview.mountPoints.length, equals(4));
      expect(overview.rootFs, isNotNull);
      expect(overview.overlayFs, isNotNull);
      expect(overview.overlayFs!.filesystemType, equals('ubifs'));
    });

    test('Parses JSON RPC mount points correctly', () {
      final jsonRpcData = [
        {
          'mount': '/',
          'device': '/dev/root',
          'fs': 'squashfs',
          'size': 131072, // 1K-blocks (128MB)
          'used': 46080,
          'avail': 84992,
        },
        {
          'mount': '/overlay',
          'device': '/dev/mtdblock6',
          'fs': 'ext4',
          'size': 65536, // 1K-blocks (64MB)
          'used': 16384,
          'avail': 49152,
        },
      ];

      final overview = StorageOverview.fromRpcData(jsonRpcData);
      expect(overview.mountPoints.length, equals(2));
      expect(overview.rootFs!.sizeBytes, equals(131072 * 1024));
      expect(overview.overlayFs!.sizeBytes, equals(65536 * 1024));
      expect(StorageOverview.formatBytes(overview.rootFs!.sizeBytes), equals('128.0 MB'));
      expect(StorageOverview.formatBytes(overview.overlayFs!.sizeBytes), equals('64.0 MB'));
    });

    test('Parses dynamic map representations without strict String generics', () {
      final dynamicMap = {
        'mountPoints': <dynamic, dynamic>{
          '0': <dynamic, dynamic>{
            'mount': '/',
            'device': '/dev/root',
            'sizeBytes': 134217728, // Explicit bytes
            'usedBytes': 47185920,
            'availableBytes': 87031808,
          }
        }
      };

      final overview = StorageOverview.fromRpcData(dynamicMap);
      expect(overview.mountPoints.length, equals(1));
      expect(overview.mountPoints[0].sizeBytes, equals(134217728));
      expect(StorageOverview.formatBytes(overview.mountPoints[0].sizeBytes), equals('128.0 MB'));
    });

    test('Format bytes function returns human readable strings', () {
      expect(StorageOverview.formatBytes(512), equals('512 B'));
      expect(StorageOverview.formatBytes(512000), equals('500.0 KB'));
      expect(StorageOverview.formatBytes(134217728), equals('128.0 MB'));
      expect(StorageOverview.formatBytes(2684354560), equals('2.50 GB'));
    });

    test('Reviewer mode fallback provides complete mock storage structure', () {
      final overview = StorageOverview.fromRpcData(null, isReviewerMode: true);
      expect(overview.mountPoints.length, equals(3));
      expect(overview.rootFs, isNotNull);
      expect(overview.overlayFs, isNotNull);
      expect(overview.totalSizeBytes, greaterThan(0));
    });
  });
}
