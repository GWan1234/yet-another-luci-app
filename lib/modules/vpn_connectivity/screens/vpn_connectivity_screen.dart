import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/vpn_info.dart';

class VpnConnectivityScreen extends ConsumerWidget {
  const VpnConnectivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final overview = VpnConnectivityOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN & Secure Tunnels'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'WireGuard VPN Interfaces & Peers', Icons.shield_outlined),
            const SizedBox(height: 8),
            ...overview.wireguardInterfaces.map((wg) => _buildWireguardCard(context, wg)),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'OpenVPN Tunnels', Icons.lock_outline),
            const SizedBox(height: 8),
            _buildOpenVpnCard(context, overview.openvpnInstances),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Tailscale Mesh VPN', Icons.hub_outlined),
            const SizedBox(height: 8),
            _buildTailscaleCard(context, overview.tailscale),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'NextDNS / Encrypted DNS', Icons.security_outlined),
            const SizedBox(height: 8),
            _buildNextDnsCard(context, overview.nextdns),
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

  Widget _buildWireguardCard(BuildContext context, WireguardInterface wg) {
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
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.vpn_key, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Interface: ${wg.name.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: wg.isUp ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    wg.isUp ? 'UP' : 'DOWN',
                    style: TextStyle(color: wg.isUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Public Key', wg.publicKey),
            _buildDetailRow('Listen Port', '${wg.listenPort}'),
            const Divider(height: 20),
            Text('Connected WireGuard Peers (${wg.peers.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...wg.peers.map((p) => _buildPeerTile(context, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerTile(BuildContext context, WireguardPeer peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Peer: ${peer.publicKey}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(peer.formattedHandshake, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          _buildDetailRow('Endpoint', peer.endpoint ?? 'N/A'),
          _buildDetailRow('Allowed IPs', peer.allowedIps.join(', ')),
          _buildDetailRow('Traffic Transferred', 'RX: ${_formatBytes(peer.rxBytes)} / TX: ${_formatBytes(peer.txBytes)}'),
        ],
      ),
    );
  }

  Widget _buildOpenVpnCard(BuildContext context, List<OpenVpnInstance> instances) {
    if (instances.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No OpenVPN instances configured.')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: instances.map((ovpn) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: ovpn.isRunning ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
              child: Icon(Icons.lock, color: ovpn.isRunning ? Colors.green : Colors.grey),
            ),
            title: Text(ovpn.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Device: ${ovpn.dev} • Proto: ${ovpn.proto.toUpperCase()}:${ovpn.port}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ovpn.isRunning ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ovpn.isRunning ? 'RUNNING' : 'STOPPED',
                style: TextStyle(color: ovpn.isRunning ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTailscaleCard(BuildContext context, TailscaleStatus ts) {
    return Card(
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
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.hub, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(ts.nodeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ts.isRunning ? Colors.teal.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ts.backendState.toUpperCase(),
                    style: TextStyle(color: ts.isRunning ? Colors.teal : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Tailscale IP', ts.tailscaleIp),
            _buildDetailRow('Backend Daemon State', ts.backendState),
          ],
        ),
      ),
    );
  }

  Widget _buildNextDnsCard(BuildContext context, NextDnsStatus ndns) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailRow('Encrypted DNS Profile ID', ndns.profileId),
            const Divider(height: 16),
            _buildDetailRow('NextDNS Daemon Status', ndns.isEnabled ? 'ACTIVE & ENCRYPTED' : 'DISABLED'),
            const Divider(height: 16),
            _buildDetailRow('Report Client Info', ndns.reportClientInfo ? 'ENABLED' : 'DISABLED'),
          ],
        ),
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
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    final double b = bytes.toDouble();
    if (b >= 1024 * 1024 * 1024) return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${b.toStringAsFixed(0)} B';
  }
}
