import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/router_capabilities.dart';
import '../models/firewall_info.dart';

class FirewallSecurityScreen extends ConsumerWidget {
  const FirewallSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final capabilities = appState.capabilities;
    final backend = capabilities?.firewallBackend ?? FirewallBackend.fw4;
    final uciFirewall = appState.dashboardData?['uciFirewallConfig'];

    final overview = FirewallOverview.fromUciData(
      uciFirewall,
      backend: backend,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Firewall & Security (${backend == FirewallBackend.fw4 ? "fw4 / nftables" : "fw3 / iptables"})'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: !overview.isAvailable
            ? _buildUnavailableView(context, ref, overview)
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionHeader(context, 'Global Default Policies', Icons.shield_outlined),
                  const SizedBox(height: 8),
                  _buildDefaultPoliciesCard(context, overview.defaultPolicy),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Firewall Zones Overview', Icons.layers_outlined),
                  const SizedBox(height: 8),
                  ...overview.zones.map((zone) => _buildZoneCard(context, zone)),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Inter-Zone Forwarding Rules', Icons.alt_route_outlined),
                  const SizedBox(height: 8),
                  _buildForwardingsCard(context, overview.forwardings),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Port Forwarding (Redirects)', Icons.import_export_outlined),
                  const SizedBox(height: 8),
                  _buildPortForwardingsList(context, overview.portForwards),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Custom Security Rules', Icons.rule_outlined),
                  const SizedBox(height: 8),
                  _buildCustomRulesList(context, overview.customRules),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildUnavailableView(BuildContext context, WidgetRef ref, FirewallOverview overview) {
    final theme = Theme.of(context);
    final appState = ref.watch(appStateProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Firewall Configuration Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              overview.errorMessage ?? 'The firewall configuration could not be loaded or parsed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => appState.redetectCapabilities(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Re-probe Capabilities'),
            ),
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

  Widget _buildDefaultPoliciesCard(BuildContext context, FirewallDefaultPolicy def) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPolicyRow('Default Input', def.input),
            const Divider(),
            _buildPolicyRow('Default Output', def.output),
            const Divider(),
            _buildPolicyRow('Default Forward', def.forward),
            const Divider(),
            _buildPolicyRow('SYN Flood Protection', def.synFlood ? 'ENABLED' : 'DISABLED'),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, FirewallZone zone) {
    final theme = Theme.of(context);
    final isWan = zone.name.toLowerCase().contains('wan');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Icon(
                      isWan ? Icons.public : Icons.router,
                      color: isWan ? Colors.red : theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Zone: ${zone.name.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (zone.masquerade)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('MASQUERADE (NAT)', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Covered Networks: ${zone.networks.join(", ")}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactRuleTile('Input', zone.input),
                _buildCompactRuleTile('Output', zone.output),
                _buildCompactRuleTile('Forward', zone.forward),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForwardingsCard(BuildContext context, List<FirewallForwarding> forwardings) {
    if (forwardings.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No zone forwarding rules configured.')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: forwardings.map((fwd) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(label: Text(fwd.srcZone.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                  ),
                  Chip(label: Text(fwd.destZone.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPortForwardingsList(BuildContext context, List<FirewallPortForwarding> pfs) {
    if (pfs.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No port forwarding rules active.')),
      );
    }

    return Column(
      children: pfs.map((pf) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.compare_arrows),
            ),
            title: Text(pf.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${pf.srcZone.toUpperCase()}:${pf.srcPort} ➔ ${pf.destIp}:${pf.destPort} (${pf.proto.toUpperCase()})'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomRulesList(BuildContext context, List<FirewallCustomRule> rules) {
    if (rules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No custom security rules defined (default zone policies active).'),
        ),
      );
    }

    return Column(
      children: rules.map((r) {
        final policyColor = _getPolicyColor(r.target);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(
              r.enabled ? Icons.check_circle : Icons.pause_circle_filled,
              color: r.enabled ? Colors.green : Colors.grey,
            ),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${r.srcZone.toUpperCase()} ➔ ${r.destZone.toUpperCase()}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: policyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: r.isUnrecognizedTarget
                    ? Border.all(color: Colors.amber.shade700, width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.isUnrecognizedTarget) ...[
                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    r.target,
                    style: TextStyle(
                      color: r.isUnrecognizedTarget ? Colors.amber.shade800 : policyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPolicyRow(String title, String policy) {
    final color = _getPolicyColor(policy);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              policy,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRuleTile(String label, String policy) {
    final color = _getPolicyColor(policy);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(policy, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
      ],
    );
  }

  Color _getPolicyColor(String policy) {
    switch (policy.toUpperCase()) {
      case 'ACCEPT':
      case 'ENABLED':
        return Colors.green;
      case 'REJECT':
        return Colors.orange;
      case 'DROP':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
