import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/interface.dart' as model;
import '../models/network_monitoring_info.dart';

class NetworkMonitoringScreen extends ConsumerWidget {
  const NetworkMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final netInfo = NetworkMonitoringInfo.fromDashboardData(appState.dashboardData);
    final gw = netInfo.defaultGatewayInterface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Monitoring'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'Gateway Status', Icons.router_outlined),
            const SizedBox(height: 8),
            _buildGatewayCard(context, appState, netInfo, gw),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'RX/TX Throughput Metrics (Tabular)', Icons.table_chart_outlined),
            const SizedBox(height: 8),
            _buildThroughputTableCard(context, netInfo),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'IPv4 / IPv6 Addresses & Subnets', Icons.dns_outlined),
            const SizedBox(height: 8),
            ...netInfo.interfaces.map((iface) => _buildIpAddressCard(context, appState, netInfo, iface)),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Network Interfaces Status', Icons.lan_outlined),
            const SizedBox(height: 8),
            ...netInfo.interfaces.map((iface) => _buildInterfaceStatusCard(context, iface)),
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

  Widget _buildGatewayCard(BuildContext context, dynamic appState, NetworkMonitoringInfo netInfo, model.NetworkInterface? gw) {
    final publicV4 = appState.publicIpv4 ?? netInfo.publicIpv4 ?? gw?.ipAddress ?? 'N/A';
    final publicV6 = appState.publicIpv6 ?? netInfo.publicIpv6 ?? 'N/A';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  gw != null && gw.isUp ? Icons.check_circle_outline : Icons.error_outline,
                  color: gw != null && gw.isUp ? Colors.green : Colors.red,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  gw != null ? 'Default Gateway (${gw.name.toUpperCase()})' : 'No Gateway Connected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Gateway IP Address', gw?.gateway ?? 'N/A'),
            _buildDetailRow('WAN IP Address', gw?.ipAddress ?? 'N/A'),
            _buildDetailRow('Public IPv4', publicV4),
            _buildDetailRow('Public IPv6', publicV6),
            _buildDetailRow('Subnet Mask', gw?.netmask ?? 'N/A'),
            _buildDetailRow('Interface Device', gw?.device ?? 'N/A'),
            _buildDetailRow('Protocol', gw?.protocol.toUpperCase() ?? 'N/A'),
            _buildDetailRow('DNS Servers', gw?.dnsServers.isNotEmpty == true ? gw!.dnsServers.join(', ') : 'None'),
          ],
        ),
      ),
    );
  }

  Widget _buildThroughputTableCard(BuildContext context, NetworkMonitoringInfo netInfo) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('Device', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RX Bytes', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('TX Bytes', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RX Packets', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('TX Packets', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Errors', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: netInfo.deviceStats.entries.map((entry) {
            final stats = entry.value;
            final rxBytes = _formatBytes(stats['rx_bytes'] ?? 0);
            final txBytes = _formatBytes(stats['tx_bytes'] ?? 0);
            final rxPackets = stats['rx_packets']?.toString() ?? '0';
            final txPackets = stats['tx_packets']?.toString() ?? '0';
            final errors = (stats['rx_errors'] ?? 0) + (stats['tx_errors'] ?? 0);

            return DataRow(
              cells: [
                DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(rxBytes)),
                DataCell(Text(txBytes)),
                DataCell(Text(rxPackets)),
                DataCell(Text(txPackets)),
                DataCell(Text('$errors', style: TextStyle(color: errors > 0 ? Colors.red : Colors.grey))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIpAddressCard(BuildContext context, dynamic appState, NetworkMonitoringInfo netInfo, model.NetworkInterface iface) {
    final isWan = iface.name.toLowerCase().contains('wan');
    final publicV4 = appState.publicIpv4 ?? netInfo.publicIpv4 ?? iface.ipAddress ?? 'N/A';
    final publicV6 = appState.publicIpv6 ?? netInfo.publicIpv6 ?? 'N/A';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(iface.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: iface.isUp ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    iface.isUp ? 'UP' : 'DOWN',
                    style: TextStyle(
                      color: iface.isUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildDetailRow('IPv4 Address', iface.ipAddress != null ? '${iface.ipAddress} / ${iface.netmask ?? "24"}' : 'None'),
            if (isWan) ...[
              _buildDetailRow('Public IPv4', publicV4),
              _buildDetailRow('Public IPv6', publicV6),
            ],
            if (iface.ipv6Addresses != null && iface.ipv6Addresses!.isNotEmpty)
              ...iface.ipv6Addresses!.map((v6) => _buildDetailRow('IPv6 Address', v6)),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfaceStatusCard(BuildContext context, model.NetworkInterface iface) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iface.isUp ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            iface.isUp ? Icons.lan : Icons.lan_outlined,
            color: iface.isUp ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(iface.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Device: ${iface.device} • Proto: ${iface.protocol}'),
        trailing: Text('Uptime: ${iface.formattedUptime}', style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    final double b = bytes.toDouble();
    if (b >= 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) {
      return '${(b / 1024).toStringAsFixed(0)} KB';
    }
    return '${b.toStringAsFixed(0)} B';
  }
}
