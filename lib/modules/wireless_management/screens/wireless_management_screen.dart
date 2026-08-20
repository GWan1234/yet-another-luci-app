// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:yet_another_luci_app/state/app_state.dart';
import 'package:yet_another_luci_app/utils/os_platform_integration.dart';
import 'package:yet_another_luci_app/modules/dhcp_dns/models/dhcp_dns_info.dart';
import 'package:yet_another_luci_app/widgets/luci_app_bar.dart';
import 'package:yet_another_luci_app/widgets/luci_collapsible_card.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:yet_another_luci_app/design/luci_design_system.dart';
import '../models/wireless_info.dart';
import 'wifi_access_control_screen.dart';

class WirelessManagementScreen extends ConsumerStatefulWidget {
  final bool showBack;

  const WirelessManagementScreen({super.key, this.showBack = false});

  @override
  ConsumerState<WirelessManagementScreen> createState() => _WirelessManagementScreenState();
}

class _WirelessManagementScreenState extends ConsumerState<WirelessManagementScreen>
    with AutomaticKeepAliveClientMixin {
  Timer? _refreshTimer;
  bool _isStationsExpanded = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startRefreshTimerIfNeeded();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimerIfNeeded() {
    _refreshTimer?.cancel();
    if (_isStationsExpanded) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          ref.read(appStateProvider).fetchDashboardData();
        }
      });
    }
  }

  void _toggleStationsExpansion(bool expanded) {
    if (_isStationsExpanded != expanded) {
      setState(() {
        _isStationsExpanded = expanded;
      });
      _startRefreshTimerIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = ref.watch(appStateProvider);
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    int totalStationCount = 0;
    for (final radio in overview.radios) {
      for (final iface in radio.interfaces) {
        totalStationCount += iface.stations.length;
      }
    }

    return Scaffold(
      appBar: LuciAppBar(
        title: 'Wireless',
        showBack: widget.showBack,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader(context, 'Wireless Radios', Icons.cell_tower_outlined),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WifiAccessControlScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.security_rounded, size: 16),
                  label: const Text('Access Control', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (overview.radios.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: LuciEmptyState(
                  title: 'No Wireless Radios Found',
                  message: 'No active wireless devices or radios were detected on this router. Pull down to refresh data.',
                  icon: Icons.wifi_off_rounded,
                  actionLabel: 'Refresh',
                  onAction: () async {
                    await appState.fetchDashboardData();
                  },
                ),
              )
            else
              ...overview.radios.map((radio) => _buildRadioCard(context, radio, appState)),
            const SizedBox(height: 16),
            LuciCollapsibleCard(
              title: 'Connected Wireless Stations',
              icon: Icons.devices_other_outlined,
              count: totalStationCount,
              initiallyExpanded: _isStationsExpanded,
              onExpansionChanged: _toggleStationsExpansion,
              child: _buildStationsList(context, overview, appState),
            ),
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
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioCard(BuildContext context, WirelessRadio radio, AppState appState) {
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
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.wifi, color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              radio.name.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${radio.bandLabel} • Channel ${radio.channel}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: radio.isUp ? LuciStatusColors.connected.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    radio.isUp ? 'ACTIVE' : 'DISABLED',
                    style: TextStyle(
                      color: radio.isUp ? LuciStatusColors.connected : Colors.red,
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
                          Row(
                            children: [
                              Text('${iface.ssid} (${iface.mode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                iface.isEnabled ? '(Enabled)' : '(Disabled)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: iface.isEnabled ? LuciStatusColors.connected : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
                    Row(
                      children: [
                        Text('${iface.stations.length} clients', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Switch(
                          value: iface.isEnabled,
                          onChanged: (val) => _handleToggleSsid(context, radio, iface, val, appState),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggleSsid(
    BuildContext context,
    WirelessRadio radio,
    WirelessInterface iface,
    bool enable,
    AppState appState,
  ) async {
    bool isConnectedToThisSsid = false;
    // Check if any connected client station matches active app session or router connection
    for (final st in iface.stations) {
      if (st.macAddress.toUpperCase() == (appState.dashboardData?['activeSessionMac']?.toString().toUpperCase())) {
        isConnectedToThisSsid = true;
        break;
      }
    }

    if (!enable && isConnectedToThisSsid) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          title: const Text('Self-Disconnect Warning'),
          content: Text(
            'You\'re currently connected via network "${iface.ssid}". Disabling it will disconnect your session; the app will attempt to reconnect automatically once you rejoin a working network.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed & Disconnect'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${enable ? "Enable" : "Disable"} SSID?'),
          content: Text(
            'Are you sure you want to ${enable ? "enable" : "disable"} SSID "${iface.ssid}" on ${radio.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(enable ? 'Enable' : 'Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final actionKey = 'toggle_ssid_${iface.sectionName}';
    if (!context.mounted) return;
    context.showToastLoading(
      '${enable ? "Enabling" : "Disabling"} SSID "${iface.ssid}"...',
      actionKey: actionKey,
    );

    final success = await appState.setSsidEnabled(
      iface.sectionName,
      enable,
      context: context,
    );

    if (!context.mounted) return;
    if (success) {
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.medium));
      context.showToastSuccess(
        'SSID "${iface.ssid}" ${enable ? "enabled" : "disabled"} successfully.',
        actionKey: actionKey,
      );
    } else {
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.heavy));
      context.showToastError(
        'Failed to update SSID "${iface.ssid}".',
        actionKey: actionKey,
      );
    }
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

    allStations.sort((a, b) {
      final stA = a['station'] as WirelessStation;
      final stB = b['station'] as WirelessStation;
      final aSig = stA.signalDbm ?? -999;
      final bSig = stB.signalDbm ?? -999;
      return aSig.compareTo(bSig); // Higher dBm station at bottom of list
    });

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getSignalColor(st.signalDbm).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.wifi,
                    color: _getSignalColor(st.signalDbm),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
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
                PopupMenuButton<String>(
                  tooltip: '',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    final isPaused = appState.isInternetPaused(st.macAddress);
                    if (val == 'pause') {
                      _toggleInternetPause(context, st.macAddress, titleText, !isPaused, appState);
                    }
                  },
                  itemBuilder: (ctx) {
                    final isPaused = appState.isInternetPaused(st.macAddress);
                    return [
                      PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(
                              isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                              color: isPaused ? LuciStatusColors.connected : Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(isPaused ? 'Resume Internet' : 'Pause Internet'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _toggleInternetPause(
    BuildContext context,
    String mac,
    String name,
    bool pause,
    AppState appState,
  ) async {
    final actionKey = 'pause_internet_$mac';
    context.showToastLoading(
      '${pause ? "Pausing" : "Resuming"} internet for $name...',
      actionKey: actionKey,
    );
    final success = await appState.pauseClientInternet(
      mac,
      pause: pause,
      context: context,
    );
    if (!context.mounted) return;
    if (success) {
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.medium));
      context.showToastSuccess(
        'Internet ${pause ? "paused" : "restored"} for $name.',
        actionKey: actionKey,
      );
    } else {
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.heavy));
      context.showToastError(
        'Failed to ${pause ? "pause" : "resume"} internet for $name.',
        actionKey: actionKey,
      );
    }
  }

  String _formatBandwidthRate(num? rawRate) {
    if (rawRate == null) return 'N/A';
    double rate = rawRate.toDouble();
    if (rate <= 0) return '0 Mbps';

    double rateMbps;
    if (rate >= 10000000) {
      rateMbps = rate / 1000000;
    } else if (rate >= 1000 || (rate >= 1000 && rate % 1 == 0)) {
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
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
