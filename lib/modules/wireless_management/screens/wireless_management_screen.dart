import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/modules/dhcp_dns/models/dhcp_dns_info.dart';
import '../models/wireless_info.dart';

class WirelessManagementScreen extends ConsumerWidget {
  const WirelessManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wireless Management'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'Wireless Radios', Icons.cell_tower_outlined),
            const SizedBox(height: 8),
            ...overview.radios.map((radio) => _buildRadioCard(context, radio)),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Connected Wireless Stations', Icons.devices_other_outlined),
            const SizedBox(height: 8),
            _buildStationsList(context, overview, appState),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioCard(BuildContext context, WirelessRadio radio) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.wifi, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(radio.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${radio.bandLabel} • Channel ${radio.channel}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: radio.isUp ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    radio.isUp ? 'ACTIVE' : 'DISABLED',
                    style: TextStyle(
                      color: radio.isUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('TX Power', '${radio.txPowerDbm ?? 20} dBm'),
            _buildDetailRow('Frequency', radio.formattedFrequency),
            _buildDetailRow('Country Code', radio.country),
            const SizedBox(height: 12),
            if (radio.interfaces.isNotEmpty) ...[
              const Text('Interfaces / SSIDs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ...radio.interfaces.map((iface) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${iface.ssid} (${iface.mode})', style: const TextStyle(fontSize: 13)),
                    Text('${iface.stations.length} clients', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationsList(BuildContext context, WirelessOverview overview, AppState appState) {
    final dhcpOverview = DhcpDnsOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    final allStations = <Map<String, dynamic>>[];
    for (final radio in overview.radios) {
      for (final iface in radio.interfaces) {
        for (final st in iface.stations) {
          allStations.add({
            'station': st,
            'ssid': iface.ssid,
            'band': radio.bandLabel,
          });
        }
      }
    }

    if (allStations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No wireless stations connected.'),
          ),
        ),
      );
    }

    String normMac(String m) => m.toUpperCase().replaceAll('-', ':').split(':').map((b) => b.length == 1 ? '0$b' : b).join(':');

    String? resolveHostname(String macStr) {
      final macNorm = normMac(macStr);
      for (final st in dhcpOverview.staticMappings) {
        if (normMac(st.macAddress) == macNorm && st.hostname.isNotEmpty && st.hostname != 'Unnamed Host') {
          return st.hostname;
        }
      }
      for (final l in dhcpOverview.activeLeases) {
        if (normMac(l.macAddress) == macNorm && l.hostname.isNotEmpty && l.hostname != 'Anonymous Device') {
          return l.hostname;
        }
      }
      return null;
    }

    return Column(
      children: allStations.map((item) {
        final st = item['station'] as WirelessStation;
        final ssid = item['ssid'] as String;
        final band = item['band'] as String;

        final hostname = resolveHostname(st.macAddress);
        final hasName = hostname != null && hostname.isNotEmpty && normMac(hostname) != normMac(st.macAddress);
        final titleText = hasName ? hostname : st.macAddress;
        final subtitleText = hasName ? 'MAC: ${st.macAddress} • SSID: $ssid ($band)' : 'SSID: $ssid ($band)';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(
              Icons.wifi_tethering,
              color: _getSignalColor(st.signalDbm),
            ),
            title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitleText),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(st.formattedSignal, style: TextStyle(fontWeight: FontWeight.bold, color: _getSignalColor(st.signalDbm))),
                Text(
                  st.rxRate != null && st.txRate != null ? 'Rx: ${st.rxRate} / Tx: ${st.txRate} M' : st.signalQualityLabel,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getSignalColor(int? signal) {
    if (signal == null) return Colors.grey;
    if (signal >= -50) return Colors.green;
    if (signal >= -65) return Colors.teal;
    if (signal >= -75) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
