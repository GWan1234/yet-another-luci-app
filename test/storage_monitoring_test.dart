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

    test('Parses JSON RPC mount points (native byte units) correctly', () {
      final jsonRpcData = [
        {
          'mount': '/',
          'device': '/dev/root',
          'fs': 'squashfs',
          'size': 134217728, // Bytes (128MB)
          'used': 47185920,
          'avail': 87031808,
        },
        {
          'mount': '/overlay',
          'device': '/dev/mtdblock6',
          'fs': 'ext4',
          'size': 67108864, // Bytes (64MB)
          'used': 16777216,
          'avail': 50331648,
        },
      ];

      final overview = StorageOverview.fromRpcData(jsonRpcData);
      expect(overview.mountPoints.length, equals(2));
      expect(overview.rootFs!.sizeBytes, equals(134217728));
      expect(overview.overlayFs!.sizeBytes, equals(67108864));
      expect(StorageOverview.formatBytes(overview.rootFs!.sizeBytes), equals('128.0 MB'));
      expect(StorageOverview.formatBytes(overview.overlayFs!.sizeBytes), equals('64.0 MB'));
    });

    test('Parses df -h human-readable format correctly without double conversion', () {
      const dfHumanOutput = '''
Filesystem           Size  Used Avail Use% Mounted on
/dev/root            128M  128M     0 100% /rom
tmpfs                123M  2.0M  121M   2% /tmp
/dev/mtdblock6        53M  5.0M   48M  10% /overlay
''';

      final overview = StorageOverview.fromRpcData(dfHumanOutput);
      expect(overview.mountPoints.length, equals(3));
      expect(StorageOverview.formatBytes(overview.mountPoints[1].sizeBytes), equals('123.0 MB'));
      expect(StorageOverview.formatBytes(overview.overlayFs!.sizeBytes), equals('53.0 MB'));
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

    test('priorityDisplayMounts selects Root 1st, TempFS 2nd, and fallback partitions when missing', () {
      // 1. Standard case: Root and /tmp present
      const dfOutput = '''
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/root                15360     15360         0 100% /rom
tmpfs                   124808       988    123820   1% /tmp
/dev/ubi0_1              28468      5124     21876  19% /overlay
overlayfs:/overlay       28468      5124     21876  19% /
''';
      final overview = StorageOverview.fromRpcData(dfOutput);
      final priority = overview.priorityDisplayMounts;
      expect(priority.length, equals(2));
      expect(priority[0].mountPath, equals('/'));
      expect(priority[1].mountPath, equals('/tmp'));

      // 2. Missing /tmp case: Root present, /overlay present
      const dfOutputNoTmp = '''
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/ubi0_1              28468      5124     21876  19% /overlay
overlayfs:/overlay       28468      5124     21876  19% /
''';
      final overviewNoTmp = StorageOverview.fromRpcData(dfOutputNoTmp);
      final priorityNoTmp = overviewNoTmp.priorityDisplayMounts;
      expect(priorityNoTmp.length, equals(2));
      expect(priorityNoTmp[0].mountPath, equals('/'));
      expect(priorityNoTmp[1].mountPath, equals('/overlay'));

      // 3. Missing Root case: only /tmp and /mnt/usb
      const dfOutputNoRoot = '''
Filesystem           1K-blocks      Used Available Use% Mounted on
tmpfs                   124808       988    123820   1% /tmp
/dev/sda1              1000000    100000    900000  10% /mnt/usb
''';
      final overviewNoRoot = StorageOverview.fromRpcData(dfOutputNoRoot);
      final priorityNoRoot = overviewNoRoot.priorityDisplayMounts;
      expect(priorityNoRoot.length, equals(2));
      expect(priorityNoRoot[0].mountPath, equals('/tmp'));
      expect(priorityNoRoot[1].mountPath, equals('/mnt/usb'));
    });

    test('Scales 1K-blocks from OpenWrt RPC getMountPoints correctly for 384 MB router', () {
      final rpcData = [
        {
          'mount': '/',
          'device': 'overlayfs:/overlay',
          'fs': 'overlay',
          'size': 393216,  // 393216 KB = 384 MB
          'used': 196608,  // 196608 KB = 192 MB
          'avail': 196608,
        }
      ];

      final overview = StorageOverview.fromRpcData(rpcData);
      expect(overview.rootFs, isNotNull);
      expect(StorageOverview.formatBytes(overview.rootFs!.sizeBytes), equals('384.0 MB'));
      expect(StorageOverview.formatBytes(overview.rootFs!.usedBytes), equals('192.0 MB'));
    });
  });
}
