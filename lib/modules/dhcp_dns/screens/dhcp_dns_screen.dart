// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/add_static_lease_dialog.dart';
import '../models/dhcp_dns_info.dart';

class DhcpDnsScreen extends ConsumerWidget {
  const DhcpDnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final dashboardData = Map<String, dynamic>.from(appState.dashboardData ?? {});
    dashboardData['clients'] = appState.clients.map((c) => {
      'macAddress': c.macAddress,
      'ipAddress': c.ipAddress,
      'name': c.displayName,
      'isStaticLease': c.isStaticLease,
    }).toList();
    final overview = DhcpDnsOverview.fromDashboardData(
      dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('DHCP & DNS Management'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
          await appState.fetchClientsForSelectedRouter();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'DNS Forwarders & Dnsmasq Config', Icons.dns_outlined),
            const SizedBox(height: 8),
            _buildDnsConfigCard(context, overview.dnsConfig),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Active DHCP Leases', Icons.badge_outlined),
            const SizedBox(height: 8),
            _buildLeasesList(context, ref, overview.activeLeases, overview.staticMappings),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(context, 'Static IP Reservations (Host Mappings)', Icons.pin_drop_outlined),
                TextButton.icon(
                  onPressed: () => _showAddStaticLeaseDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Static', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStaticMappingsList(context, ref, overview.staticMappings),
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

  Widget _buildDnsConfigCard(BuildContext context, DnsmasqConfig config) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Local Domain Name', '.${config.localDomain}'),
            const Divider(height: 16),
            _buildDetailRow('Upstream DNS Forwarders', config.upstreamDnsServers.join(', ')),
            const Divider(height: 16),
            _buildDetailRow('Rebind Protection', config.rebindProtection ? 'ENABLED' : 'DISABLED'),
            const Divider(height: 16),
            _buildDetailRow('Domain Needed (Strict Order)', config.domainNeeded ? 'ENABLED' : 'DISABLED'),
            const Divider(height: 16),
            _buildDetailRow('Authoritative Mode', config.authoritative ? 'ENABLED' : 'DISABLED'),
          ],
        ),
      ),
    );
  }

  Widget _buildLeasesList(
    BuildContext context,
    WidgetRef ref,
    List<DhcpLease> leases,
    List<DhcpStaticMapping> staticMappings,
  ) {
    if (leases.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No active DHCP leases currently assigned.')),
      );
    }

    return Column(
      children: leases.map((lease) {
        final normLeaseMac = lease.macAddress.toUpperCase().replaceAll('-', ':');
        final normLeaseIp = lease.ipAddress.trim();

        DhcpStaticMapping? matchingStatic;
        for (final m in staticMappings) {
          final mMacs = m.macAddress.toUpperCase().replaceAll('-', ':');
          final mIp = m.ipAddress.trim();
          if ((normLeaseMac.isNotEmpty && normLeaseMac != 'N/A' && mMacs.contains(normLeaseMac)) ||
              (normLeaseIp.isNotEmpty && normLeaseIp != 'N/A' && mIp == normLeaseIp)) {
            matchingStatic = m;
            break;
          }
        }
        final isStatic = matchingStatic != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isStatic ? Colors.teal.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
              child: Icon(
                isStatic ? Icons.push_pin : Icons.devices,
                color: isStatic ? Colors.teal : Colors.blue,
              ),
            ),
            title: Text(lease.hostname, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('IP: ${lease.ipAddress} • MAC: ${lease.macAddress}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lease.formattedExpiry,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                if (isStatic)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.teal),
                    tooltip: 'Edit Static Lease',
                    onPressed: () => _showAddStaticLeaseDialog(
                      context,
                      ref,
                      existingMapping: matchingStatic,
                      lease: lease,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20, color: Colors.blue),
                    tooltip: 'Reserve as Static IP',
                    onPressed: () => _showAddStaticLeaseDialog(
                      context,
                      ref,
                      lease: lease,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStaticMappingsList(BuildContext context, WidgetRef ref, List<DhcpStaticMapping> mappings) {
    if (mappings.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No static host reservations configured.')),
      );
    }

    return Column(
      children: mappings.map((mapping) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withValues(alpha: 0.15),
              child: const Icon(Icons.push_pin, color: Colors.teal),
            ),
            title: Text(mapping.hostname, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Reserved IP: ${mapping.ipAddress} • MAC: ${mapping.macAddress}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('STATIC', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.teal, size: 20),
                  tooltip: 'Edit Static Lease',
                  onPressed: () => _showAddStaticLeaseDialog(context, ref, existingMapping: mapping),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Remove Static Lease',
                  onPressed: () => _confirmDeleteStaticLease(context, ref, mapping),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmDeleteStaticLease(BuildContext context, WidgetRef ref, DhcpStaticMapping mapping) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove Static Lease',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the static IP reservation for "${mapping.hostname}" (${mapping.macAddress})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove Reservation'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removing static lease for ${mapping.hostname}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final appState = ref.read(appStateProvider);
      final success = await appState.deleteStaticLease(
        macAddress: mapping.macAddress,
        context: context,
      );

      if (success) {
        final appState = ref.read(appStateProvider);
        await appState.fetchDashboardData();
        await appState.fetchClientsForSelectedRouter();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Static lease removed for ${mapping.hostname}.'
                : 'Failed to remove static lease for ${mapping.hostname}.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showAddStaticLeaseDialog(
    BuildContext context,
    WidgetRef ref, {
    DhcpLease? lease,
    DhcpStaticMapping? existingMapping,
  }) {
    final appState = ref.read(appStateProvider);
    showDialog(
      context: context,
      builder: (dialogCtx) => AddStaticLeaseDialog(
        macAddress: lease?.macAddress ?? existingMapping?.macAddress,
        initialIp: lease?.ipAddress ?? existingMapping?.ipAddress,
        initialHostname: lease?.hostname ?? existingMapping?.hostname,
        existingMapping: existingMapping,
        allClients: appState.clients,
        onSaved: () async {
          await appState.fetchDashboardData();
          await appState.fetchClientsForSelectedRouter();
        },
      ),
    );
  }



  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
