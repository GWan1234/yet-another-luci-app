import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/network_monitoring_info.dart';

class NetworkMonitoringCard extends ConsumerWidget {
  const NetworkMonitoringCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final netInfo = NetworkMonitoringInfo.fromDashboardData(appState.dashboardData);
    final gw = netInfo.defaultGatewayInterface;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Network Monitoring',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${netInfo.upCount} Active / ${netInfo.interfaces.length} Total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricBlock(
                    context,
                    label: 'Gateway IP',
                    value: gw?.gateway ?? 'None',
                    icon: Icons.router_outlined,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricBlock(
                    context,
                    label: 'WAN IPv4',
                    value: gw?.ipAddress ?? 'Disconnected',
                    icon: Icons.public_outlined,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricBlock(
                    context,
                    label: 'Total RX',
                    value: _formatBytes(netInfo.totalRxBytes),
                    icon: Icons.arrow_downward_outlined,
                    color: Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildMetricBlock(
                    context,
                    label: 'Total TX',
                    value: _formatBytes(netInfo.totalTxBytes),
                    icon: Icons.arrow_upward_outlined,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBlock(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    final double b = bytes.toDouble();
    if (b >= 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
