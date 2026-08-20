import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_luci_app/models/rpc_result.dart';
import 'package:yet_another_luci_app/modules/wireless_management/models/wireless_info.dart';

void main() {
  group('Wireless Security Mode & Frequency Display Unit Tests', () {
    test('WifiSecurityMode classifies SAE-Only (WPA3-Only) correctly', () {
      final mode1 = WifiSecurityMode.parse(
        iwinfoEnc: {
          'enabled': true,
          'description': 'WPA3 SAE (CCMP)',
          'auth_suites': ['SAE'],
        },
        rawConfigEnc: 'sae',
      );
      expect(mode1, equals(WifiSecurityMode.saeOnly));
      expect(mode1.shortBadgeLabel, equals('WPA3-SAE'));

      final pmfReq = PmfState.parse('2');
      expect(pmfReq, equals(PmfState.required));
      expect(pmfReq.displayName, equals('PMF Required'));
    });

    test('WifiSecurityMode classifies SAE-Mixed (WPA2/WPA3 Transitional) correctly', () {
      final mode = WifiSecurityMode.parse(
        iwinfoEnc: {
          'enabled': true,
          'description': 'WPA2/WPA3 PSK/SAE (CCMP)',
          'auth_suites': ['PSK', 'SAE'],
        },
        rawConfigEnc: 'sae-mixed',
      );
      expect(mode, equals(WifiSecurityMode.saeMixed));
      expect(mode.shortBadgeLabel, equals('WPA2/WPA3'));

      final pmfOpt = PmfState.parse('1');
      expect(pmfOpt, equals(PmfState.optional));
      expect(pmfOpt.displayName, equals('PMF Optional'));
    });

    test('WifiSecurityMode classifies WPA2-PSK, WPA-PSK, Open, and Enterprise', () {
      final wpa2 = WifiSecurityMode.parse(
        iwinfoEnc: {'description': 'WPA2 PSK (CCMP)', 'auth_suites': ['PSK']},
        rawConfigEnc: 'psk2',
      );
      expect(wpa2, equals(WifiSecurityMode.wpa2Psk));

      final wpa1 = WifiSecurityMode.parse(
        rawConfigEnc: 'psk',
      );
      expect(wpa1, equals(WifiSecurityMode.wpaPsk));

      final openMode = WifiSecurityMode.parse(
        iwinfoEnc: {'enabled': false, 'description': ''},
        rawConfigEnc: 'none',
      );
      expect(openMode, equals(WifiSecurityMode.open));

      final eapMode = WifiSecurityMode.parse(
        iwinfoEnc: {'description': 'WPA2 802.1X (CCMP)'},
        rawConfigEnc: 'wpa2',
      );
      expect(eapMode, equals(WifiSecurityMode.enterprise));
    });

    test('WirelessRadio handles valid frequency and 6GHz / 5GHz / 2.4GHz band labels', () {
      final radio2g = WirelessRadio.fromJson('radio0', {
        'channel': 6,
        'frequency': 2437,
      }, null);
      expect(radio2g.formattedFrequency, equals('2.437 GHz'));
      expect(radio2g.bandLabel, equals('2.4 GHz'));

      final radio5g = WirelessRadio.fromJson('radio1', {
        'channel': 36,
        'frequency': 5180,
      }, null);
      expect(radio5g.formattedFrequency, equals('5.180 GHz'));
      expect(radio5g.bandLabel, equals('5 GHz'));

      final radio6g = WirelessRadio.fromJson('radio6', {
        'channel': 1,
        'frequency': 5955,
      }, null);
      expect(radio6g.formattedFrequency, equals('5.955 GHz'));
      expect(radio6g.bandLabel, equals('6 GHz'));
    });

    test('WirelessRadio gracefully handles missing/null frequency on older radios without 0.000 GHz', () {
      final legacyRadio = WirelessRadio.fromJson('radioLegacy', {
        'channel': 6,
        'frequency': null, // frequency absent on older iwinfo
      }, null);

      expect(legacyRadio.formattedFrequency, isNull);
      expect(legacyRadio.bandLabel, equals('2.4 GHz'));
    });

    test('RpcResult classification handles ubus status branches for wireless devices fetch', () {
      final deniedRpc = [6, 'Access denied'];
      final missingRpc = [3, 'Object not found'];

      final deniedRes = RpcResult.fromUbusResponse<WirelessOverview>(
        deniedRpc,
        (data) => WirelessOverview.fromDashboardData({'wireless': data}),
      );
      expect(deniedRes.status, equals(RpcCallStatus.permissionDenied));

      final missingRes = RpcResult.fromUbusResponse<WirelessOverview>(
        missingRpc,
        (data) => WirelessOverview.fromDashboardData({'wireless': data}),
      );
      expect(missingRes.status, equals(RpcCallStatus.methodNotFound));
    });
  });
}
