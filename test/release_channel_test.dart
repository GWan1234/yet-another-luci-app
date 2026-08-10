import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/utils/release_utils.dart';

void main() {
  group('Release channel detection', () {
    test('detects SNAPSHOT version', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': 'SNAPSHOT',
        'revision': 'r28597-d3e1c1fba8',
        'description': 'OpenWrt SNAPSHOT r28597-d3e1c1fba8',
      };
      expect(deriveReleaseChannel(release), 'snapshot');
    });

    test('detects 24.10-SNAPSHOT version', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': '24.10-SNAPSHOT',
        'revision': 'r28500-abc123',
        'description': 'OpenWrt 24.10-SNAPSHOT r28500-abc123',
      };
      expect(deriveReleaseChannel(release), 'snapshot');
    });

    test('detects snapshot in description only', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': '24.10.0',
        'description': 'OpenWrt 24.10.0-SNAPSHOT r28500',
      };
      expect(deriveReleaseChannel(release), 'snapshot');
    });

    test('stable release returns stable', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': '23.05.0',
        'revision': 'r23497-6637af95aa',
        'description': 'OpenWrt 23.05.0 r23497-6637af95aa',
      };
      expect(deriveReleaseChannel(release), 'stable');
    });

    test('detects beta channel', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': '24.10.0-beta1',
        'description': 'OpenWrt 24.10.0-beta1',
      };
      expect(deriveReleaseChannel(release), 'beta');
    });

    test('detects rc channel', () {
      final release = {
        'distribution': 'OpenWrt',
        'version': '24.10.0-rc1',
        'description': 'OpenWrt 24.10.0-rc1',
      };
      expect(deriveReleaseChannel(release), 'rc');
    });

    test('rc check does not false-positive on common words', () {
      // "source" contains 'rc' — should NOT match
      final release = {
        'distribution': 'OpenWrt',
        'version': '23.05.0',
        'description': 'OpenWrt from source build',
      };
      expect(deriveReleaseChannel(release), 'stable');
    });

    test('null release returns stable', () {
      expect(deriveReleaseChannel(null), 'stable');
    });

    test('empty release returns stable', () {
      expect(deriveReleaseChannel({}), 'stable');
    });

    test('checks all fields including non-standard ones', () {
      // Some custom builds might put snapshot info in non-standard fields
      final release = {
        'distribution': 'OpenWrt',
        'version': '24.10.0',
        'custom_field': 'snapshot-build',
      };
      expect(deriveReleaseChannel(release), 'snapshot');
    });
  });
}
