import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/modules/dhcp_dns/models/dhcp_dns_info.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import '../models/wireless_info.dart';

class WirelessManagementScreen extends ConsumerWidget {
  final bool showBack;

  const WirelessManagementScreen({super.key, this.showBack = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: LuciAppBar(
        title: 'Wireless',
        showBack: showBack,
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
    final freqStr = radio.formattedFrequency ?? 'Channel ${radio.channel} (Freq Unreported)';

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
                        Text('${radio.bandLabel} • Channel ${radio.channel}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
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
            _buildDetailRow(context, 'TX Power', '${radio.txPowerDbm ?? 20} dBm'),
            _buildDetailRow(context, 'Frequency', freqStr),
            _buildDetailRow(context, 'Country Code', radio.country),
            const SizedBox(height: 12),
            if (radio.interfaces.isNotEmpty) ...[
              const Text('Interfaces / SSIDs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ...radio.interfaces.map((iface) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${iface.ssid} (${iface.mode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: iface.securityMode.badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  iface.securityMode.shortBadgeLabel,
                                  style: TextStyle(
                                    color: iface.securityMode.badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (iface.pmfState != PmfState.disabled) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (iface.pmfState == PmfState.required ? theme.colorScheme.tertiary : theme.colorScheme.secondary).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    iface.pmfState.displayName,
                                    style: TextStyle(
                                      color: iface.pmfState == PmfState.required ? theme.colorScheme.tertiary : theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('${iface.stations.length} clients', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _getSignalColor(st.signalDbm).withValues(alpha: 0.12),
              child: Icon(
                Icons.wifi,
                color: _getSignalColor(st.signalDbm),
                size: 20,
              ),
            ),
            title: Text(
              titleText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              subtitleText,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  st.formattedSignal,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getSignalColor(st.signalDbm),
                    fontSize: 12,
                  ),
                ),
                if (st.rxRate != null)
                  Text(
                    'Rx: ${_formatBandwidthRate(st.rxRate)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (st.txRate != null)
                  Text(
                    'Tx: ${_formatBandwidthRate(st.txRate)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (st.rxRate == null && st.txRate == null)
                  Text(
                    st.signalQualityLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatBandwidthRate(num? rawRate) {
    if (rawRate == null) return 'N/A';
    double rate = rawRate.toDouble();
    if (rate <= 0) return '0 Mbps';

    // Normalize raw rate to Mbps based on standard OpenWrt payload scales:
    // 1. bps (>= 10,000,000)
    // 2. Kbps (>= 10,000 or integer >= 1,000)
    // 3. Mbps (< 10,000 with decimals or direct Mbps)
    double rateMbps;
    if (rate >= 10000000) {
      rateMbps = rate / 1000000;
    } else if (rate >= 10000 || (rate >= 1000 && rate % 1 == 0)) {
      rateMbps = rate / 1000;
    } else {
      rateMbps = rate;
    }

    if (rateMbps >= 1000) {
      final gbps = rateMbps / 1000;
      return '${gbps % 1 == 0 ? gbps.toInt() : gbps.toStringAsFixed(1)} Gbps';
    } else if (rateMbps >= 1) {
      return '${rateMbps % 1 == 0 ? rateMbps.toInt() : rateMbps.toStringAsFixed(1)} Mbps';
    } else if (rateMbps > 0) {
      final kbps = (rateMbps * 1000).round();
      if (kbps >= 1) {
        return '$kbps Kbps';
      } else {
        final bytes = (rateMbps * 1000000 / 8).round();
        return '$bytes Bytes';
      }
    }
    return '0 Mbps';
  }

  Color _getSignalColor(int? signal) {
    if (signal == null) return Colors.grey;
    if (signal >= -50) return Colors.green;
    if (signal >= -65) return Colors.teal;
    if (signal >= -75) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
