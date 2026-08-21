// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import '../models/wireless_info.dart';
import 'edit_ssid_dialog.dart';
import 'wifi_qr_dialog.dart';

/// Context-aware responsive card component for managing a individual virtual Wi-Fi SSID interface.
/// Features non-truncating title header, responsive badge toolbar, full security overview,
/// and quick-action menu options tailored for standard phone & tablet screen sizes.
class WirelessInterfaceCard extends ConsumerStatefulWidget {
  final WirelessRadio radio;
  final WirelessInterface interface;
  final ValueChanged<bool>? onToggleEnabled;

  const WirelessInterfaceCard({
    super.key,
    required this.radio,
    required this.interface,
    this.onToggleEnabled,
  });

  @override
  ConsumerState<WirelessInterfaceCard> createState() => _WirelessInterfaceCardState();
}

class _WirelessInterfaceCardState extends ConsumerState<WirelessInterfaceCard> {
  bool _isExpanded = false;

  void _showEditSsidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditSsidDialog(
        radio: widget.radio,
        interface: widget.interface,
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => WifiQrDialog(
        interface: widget.interface,
      ),
    );
  }

  void _confirmDeleteInterface() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Virtual Interface'),
        content: Text(
          'Are you sure you want to remove interface "${widget.interface.ssid}" (${widget.interface.sectionName}) from ${widget.radio.name.toUpperCase()}?\n\nThis will remove the wireless configuration section from UCI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Interface'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final appState = ref.read(appStateProvider);
    final success = await appState.deleteWirelessInterface(
      sectionName: widget.interface.sectionName,
    );
    if (!mounted) return;
    if (success) {
      context.showToastSuccess('Deleted interface "${widget.interface.ssid}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = ref.watch(appStateProvider);
    final iface = widget.interface;
    final isGuest = iface.isGuestInterface(appState.customGuestSections, appState.excludedGuestSections);
    final isCustomTagged = appState.isCustomGuestSection(iface.sectionName);
    final isExcluded = appState.isExcludedGuestSection(iface.sectionName);
    final hasWriteAccess = (appState.capabilities?.hasUciWriteAccess ?? true) && appState.isAdministrativeUser;

    return Card(
      elevation: isGuest ? 1 : 0,
      color: isGuest ? theme.colorScheme.surfaceTint.withValues(alpha: 0.03) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isGuest
              ? Colors.amber.withValues(alpha: 0.7)
              : (iface.isEnabled
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          width: isGuest ? 1.5 : 1.0,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        children: [
          // Primary Card Header & Controls
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Full Unobstructed SSID Title + Master Toggle Switch
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isGuest
                            ? Colors.amber.shade800.withValues(alpha: 0.12)
                            : (iface.isEnabled
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isGuest
                            ? Icons.shield_moon_rounded
                            : (iface.isEnabled ? Icons.wifi : Icons.wifi_off_rounded),
                        size: 20,
                        color: isGuest
                            ? Colors.amber.shade800
                            : (iface.isEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        iface.ssid,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: iface.isEnabled,
                      onChanged: hasWriteAccess
                          ? widget.onToggleEnabled
                          : (val) {
                              context.showToastError('Read-only session: Wireless interface toggle is disabled.');
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Subtitle Info Line
                Text(
                  'Section: ${iface.sectionName} (${iface.ifName}) • ${iface.stations.length} ${iface.stations.length == 1 ? 'client' : 'clients'} connected',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),

                // Responsive Badges & Actions Bar (Guaranteed No Overflow)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Left Badges Group
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!iface.isEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'DISABLED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        if (isGuest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade800.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade800.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_moon_rounded, size: 11, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  'Guest Network',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: iface.securityMode.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: iface.securityMode.badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            iface.securityMode.shortBadgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: iface.securityMode.badgeColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            iface.mode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (iface.isHidden)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HIDDEN',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),

                    // Right Action Buttons Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Security Button
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: hasWriteAccess ? null : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          tooltip: hasWriteAccess ? 'Edit Security & Parameters' : 'Edit Restricted (Read-Only)',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (!hasWriteAccess) {
                              context.showToastError('Read-only session: UCI write permission required.');
                              return;
                            }
                            _showEditSsidDialog(context);
                          },
                        ),
                        const SizedBox(width: 4),
                        // Quick QR Code Button
                        IconButton(
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          tooltip: 'Show Wi-Fi QR Code',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () => _showQrCodeDialog(context),
                        ),
                        const SizedBox(width: 4),
                        // Delete Interface Button
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: hasWriteAccess ? Colors.redAccent : Colors.grey,
                          ),
                          tooltip: hasWriteAccess ? 'Delete Virtual Interface' : 'Delete Restricted (Read-Only)',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (!hasWriteAccess) {
                              context.showToastError('Read-only session: UCI write permission required to delete interface.');
                              return;
                            }
                            _confirmDeleteInterface();
                          },
                        ),
                        const SizedBox(width: 4),
                        // Tagging & Override Popup Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            (isCustomTagged || isExcluded) ? Icons.bookmark_rounded : Icons.more_vert_rounded,
                            size: 18,
                            color: isCustomTagged
                                ? Colors.amber.shade800
                                : (isExcluded ? theme.colorScheme.primary : null),
                          ),
                          tooltip: 'More Options',
                          onSelected: (val) {
                            if (val == 'mark_guest') {
                              appState.markAsGuestSection(iface.sectionName);
                              context.showToastSuccess('Marked "${iface.ssid}" as Guest Network');
                            } else if (val == 'mark_standard') {
                              appState.markAsStandardSection(iface.sectionName);
                              context.showToastSuccess('Moved "${iface.ssid}" to Primary Networks');
                            } else if (val == 'reset_override') {
                              appState.resetGuestSectionOverride(iface.sectionName);
                              context.showToastSuccess('Reset detection override for "${iface.ssid}"');
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (isGuest)
                              PopupMenuItem<String>(
                                value: 'mark_standard',
                                child: Row(
                                  children: const [
                                    Icon(Icons.wifi_rounded, size: 16, color: Colors.blueAccent),
                                    SizedBox(width: 8),
                                    Text('Move to Primary Networks', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              )
                            else
                              PopupMenuItem<String>(
                                value: 'mark_guest',
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_moon_rounded, size: 16, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    const Text('Move to Guest Networks', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            if (isCustomTagged || isExcluded)
                              PopupMenuItem<String>(
                                value: 'reset_override',
                                child: Row(
                                  children: const [
                                    Icon(Icons.restart_alt_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Reset to Auto-Detection', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // Expand Details Toggle Button
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                          tooltip: _isExpanded ? 'Collapse Details' : 'Expand Details',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsible Detailed Properties Section
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12.0),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wireless Interface Technical Parameters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailGrid(context, iface, isGuest),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailGrid(BuildContext context, WirelessInterface iface, bool isGuest) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDetailChip(context, 'Mode', iface.mode, Icons.router_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _buildDetailChip(context, 'PMF 802.11w', iface.pmfState.displayName, Icons.security_rounded)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildDetailChip(context, 'Encryption', iface.securityMode.displayName, Icons.lock_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _buildDetailChip(context, 'Client Isolation', iface.isolateClients ? 'Enabled' : 'Disabled', Icons.do_not_disturb_on_rounded)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildDetailChip(context, 'Network Bridge', iface.networkBridge ?? (isGuest ? 'br-guest' : 'lan'), Icons.alt_route_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _buildDetailChip(context, 'Broadcast SSID', iface.isHidden ? 'Hidden' : 'Visible', Icons.cell_tower_rounded)),
          ],
        ),
        if (iface.fastTransitionEnabled) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildDetailChip(context, '802.11r Fast Roaming', 'Enabled (FT)', Icons.bolt_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildDetailChip(context, 'Mobility Domain', iface.mobilityDomain ?? '4f4b', Icons.domain_rounded)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDetailChip(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
