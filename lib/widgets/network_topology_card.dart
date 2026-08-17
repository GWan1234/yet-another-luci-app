// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../models/network_topology.dart';
import '../models/router_capabilities.dart';
import '../design/luci_design_system.dart';

class NetworkTopologyCard extends StatelessWidget {
  final NetworkTopology? topology;
  final VoidCallback? onRetry;

  const NetworkTopologyCard({
    super.key,
    required this.topology,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (topology == null || !topology!.isAvailable) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: LuciCardStyles.standardRadius,
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(LuciSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.router_outlined, color: colorScheme.onSurfaceVariant, size: 36),
              const SizedBox(height: LuciSpacing.xs),
              Text(
                'Switch Topology Unavailable',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                topology?.errorMessage ?? 'The router capabilities profile does not support active switch/VLAN topology probing.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: LuciSpacing.xs),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-probe Capabilities'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (topology!.isZeroVlans) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: LuciCardStyles.standardRadius,
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(LuciSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.lan_outlined, color: colorScheme.primary, size: 36),
              const SizedBox(height: LuciSpacing.xs),
              Text(
                'Flat Network (0 Configured VLANs)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'This router uses a single unsegmented ${topology!.modelType == NetworkModel.dsa ? "DSA bridge" : "switch"} interface.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isDsa = topology!.modelType == NetworkModel.dsa;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LuciSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDsa ? Icons.hub_outlined : Icons.settings_input_component,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDsa ? 'DSA Switch Topology' : 'Legacy swconfig Topology',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDsa ? 'DSA Engine' : 'swconfig Engine',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LuciSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: LuciSpacing.sm),
            Text(
              'Configured VLANs & Port Memberships',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...topology!.vlans.map((vlan) => _buildVlanRow(context, vlan)),
          ],
        ),
      ),
    );
  }

  Widget _buildVlanRow(BuildContext context, VlanConfig vlan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VID ${vlan.vid}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                vlan.name,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: vlan.ports.map((port) => _buildPortBadge(context, port)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPortBadge(BuildContext context, TopologyPort port) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isWan = port.isWan;
    final isTagged = port.isTagged;

    final badgeColor = isWan
        ? Colors.amber.shade700
        : (isTagged ? colorScheme.primary : colorScheme.secondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWan ? Icons.public : Icons.settings_ethernet,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            port.name,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
          if (isTagged) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'T',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
