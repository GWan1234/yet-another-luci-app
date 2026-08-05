import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/vpn_info.dart';

class VpnConnectivityCard extends ConsumerWidget {
  const VpnConnectivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final overview = VpnConnectivityOverview.fromDashboardData(appState.dashboardData);

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
                      Icons.vpn_lock_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VPN & Secure Tunneling',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${overview.totalWgPeers} WG Peers',
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
                  child: _buildMetricTile(
                    context,
                    label: 'WireGuard',
                    value: '${overview.wireguardInterfaces.length} Tunnels',
                    icon: Icons.shield_outlined,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'OpenVPN',
                    value: overview.openvpnInstances.any((o) => o.isRunning) ? 'ACTIVE' : 'STOPPED',
                    icon: Icons.lock_outline,
                    color: overview.openvpnInstances.any((o) => o.isRunning) ? Colors.green : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Tailscale',
                    value: overview.tailscale.backendState.toUpperCase(),
                    icon: Icons.hub_outlined,
                    color: overview.tailscale.isRunning ? Colors.teal : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'NextDNS',
                    value: overview.nextdns.isEnabled ? 'ENCRYPTED' : 'DISABLED',
                    icon: Icons.security_outlined,
                    color: overview.nextdns.isEnabled ? Colors.indigo : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
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
          textAlign: TextAlign.center,
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
}
