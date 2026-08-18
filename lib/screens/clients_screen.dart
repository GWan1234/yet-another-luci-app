// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/models/client.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';

import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/widgets/luci_loading_states.dart';
import 'package:luci_mobile/widgets/luci_refresh_components.dart';

import 'package:luci_mobile/utils/self_device_guard.dart';
import 'package:luci_mobile/widgets/add_static_lease_dialog.dart';
import 'restricted_clients_screen.dart';
import 'package:luci_mobile/modules/dhcp_dns/models/dhcp_dns_info.dart';

enum ClientCategoryFilter { all, wired, wireless }

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final Set<String> _expandedClientMacs = {};
  late AnimationController _controller;
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  Timer? _autoRefreshTimer;
  bool _aggregateAllRouters = true;
  Future<List<Client>>? _clientsFuture;
  String? _lastSelectedRouterId;
  dynamic _lastDashboardUpdated;
  bool _showOnlyActiveConnected = false;
  ClientCategoryFilter _categoryFilter = ClientCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    // Initialize toggle from persisted state
    final initState = ref.read(appStateProvider);
    _aggregateAllRouters = initState.clientsAggregateAllRouters;
    _lastSelectedRouterId = initState.selectedRouter?.id;
    _lastDashboardUpdated = initState.dashboardData?['_lastUpdated'];
    _computeClientsFuture();
    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _computeClientsFuture();
        });
      }
    });
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  void _computeClientsFuture() {
    final appState = ref.read(appStateProvider);
    _clientsFuture = _aggregateAllRouters
        ? appState.fetchAggregatedClients()
        : appState.fetchClientsForSelectedRouter();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final watchedAppState = ref.watch(appStateProvider);
    // Recompute future when selected router or dashboard data timestamp changes
    final currentId = watchedAppState.selectedRouter?.id;
    final lastUpdated = watchedAppState.dashboardData?['_lastUpdated'];
    if (currentId != _lastSelectedRouterId || lastUpdated != _lastDashboardUpdated) {
      _lastSelectedRouterId = currentId;
      _lastDashboardUpdated = lastUpdated;
      _computeClientsFuture();
    }
    Future<List<Client>>? future = _clientsFuture;
    return FutureBuilder<List<Client>>(
      future: future,
      builder: (context, snapshot) {
        final aggregatedClients = snapshot.data ?? [];
        return Scaffold(
          appBar: LuciAppBar(
            title: 'Clients',
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined),
                tooltip: 'Restricted & Banned Clients',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RestrictedClientsScreen(),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _computeClientsFuture();
                    });
                  }
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              LuciPullToRefresh(
                onRefresh: () async {
                  // Trigger a refresh by re-fetching dashboard data for selected router
                  await ref.read(appStateProvider).fetchDashboardData();
                  setState(() { _computeClientsFuture(); });
                },
                child: Builder(
                  builder: (context) {
                    final appState = ref.watch(appStateProvider);
                    final isLoading = snapshot.connectionState == ConnectionState.waiting && (aggregatedClients.isEmpty);
                    final dashboardError = appState.dashboardError;

                    if (isLoading) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: LuciSpacing.md,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: LuciSpacing.md),
                            // Search bar skeleton
                            LuciSkeleton(
                              width: double.infinity,
                              height: 56,
                              borderRadius: BorderRadius.circular(
                                LuciSpacing.sm,
                              ),
                            ),
                            SizedBox(height: LuciSpacing.md),
                            // Client list skeletons
                            Expanded(
                              child: ListView.separated(
                                itemCount: 6,
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: LuciSpacing.sm),
                                itemBuilder: (context, index) =>
                                    LuciListItemSkeleton(
                                      showLeading: true,
                                      showTrailing: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (dashboardError != null && aggregatedClients.isEmpty) {
                      return LuciErrorDisplay(
                        title: 'Failed to Load Clients',
                        message:
                            'Could not connect to the router. Please check your network connection and the router\'s IP address.',
                        actionLabel: 'Retry',
                        onAction: () =>
                            ref.read(appStateProvider).fetchDashboardData(),
                        icon: Icons.wifi_off_rounded,
                      );
                    }

                    final clients = aggregatedClients;
                    final filteredClients = clients.where((client) {
                      if (_showOnlyActiveConnected && !client.isConnected) {
                        return false;
                      }
                      if (_categoryFilter == ClientCategoryFilter.wired &&
                          (!client.isConnected || client.connectionType != ConnectionType.wired)) {
                        return false;
                      }
                      if (_categoryFilter == ClientCategoryFilter.wireless &&
                          (!client.isConnected || client.connectionType != ConnectionType.wireless)) {
                        return false;
                      }
                      final query = _searchQuery.toLowerCase();
                      return client.displayName.toLowerCase().contains(query) ||
                          client.hostname.toLowerCase().contains(query) ||
                          client.ipAddress.toLowerCase().contains(query) ||
                          client.macAddress.toLowerCase().contains(query) ||
                          (client.vendor != null &&
                              client.vendor!.toLowerCase().contains(query)) ||
                          (client.dnsName != null &&
                              client.dnsName!.toLowerCase().contains(query)) ||
                          (client.ssid != null &&
                              client.ssid!.toLowerCase().contains(query));
                    }).toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: TextField(
                            autofocus: false,
                            onChanged: (value) {
                              // No need to setState here, listener handles it
                            },
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name, IP, MAC, vendor...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                      tooltip: 'Clear search',
                                    )
                                  : null,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                                borderSide: BorderSide.none,
                              ),
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _showOnlyActiveConnected
                                        ? Icons.wifi_tethering
                                        : Icons.devices_other,
                                    size: 15,
                                    color: _showOnlyActiveConnected
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active Connected Only',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _showOnlyActiveConnected ? FontWeight.bold : FontWeight.w500,
                                      color: _showOnlyActiveConnected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Transform.scale(
                                scale: 0.75,
                                child: Switch(
                                  value: _showOnlyActiveConnected,
                                  activeThumbColor: colorScheme.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _showOnlyActiveConnected = val;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildClientSummaryRow(clients, colorScheme, theme.textTheme),
                        const SizedBox(height: 4),
                        Expanded(
                          child: filteredClients.isEmpty
                              ? LuciEmptyState(
                                  title: _searchQuery.isEmpty
                                      ? 'No Active Clients Found'
                                      : 'No Matching Clients',
                                  message: _searchQuery.isEmpty
                                      ? 'No clients are currently connected to the router. Pull down to refresh the list.'
                                      : 'No clients match your search criteria. Try a different search term.',
                                  icon: Icons.people_outline,
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  separatorBuilder: (context, idx) =>
                                      const SizedBox(height: 4),
                                  itemCount: filteredClients.length,
                                  itemBuilder: (context, index) {
                                    final client = filteredClients[index];
                                    final isExpanded = _expandedClientMacs
                                        .contains(client.macAddress);

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: _UnifiedClientCard(
                                        client: client,
                                        isExpanded: isExpanded,
                                        allClients: clients,
                                        onRefreshNeeded: () {
                                          setState(() {
                                            _computeClientsFuture();
                                          });
                                        },
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedClientMacs.remove(
                                                client.macAddress,
                                              );
                                            } else {
                                              _expandedClientMacs.add(
                                                client.macAddress,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),

                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientSummaryRow(
    List<Client> clients,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final totalCount = _showOnlyActiveConnected
        ? clients.where((c) => c.isConnected).length
        : clients.length;

    final wiredCount = clients.where((c) => c.isConnected && c.connectionType == ConnectionType.wired).length;
    final wirelessCount = clients.where((c) => c.isConnected && c.connectionType == ConnectionType.wireless).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              icon: Icons.devices_rounded,
              label: 'Total',
              count: totalCount,
              color: colorScheme.primary,
              isSelected: _categoryFilter == ClientCategoryFilter.all,
              onTap: () {
                setState(() {
                  _categoryFilter = ClientCategoryFilter.all;
                });
              },
              colorScheme: colorScheme,
            ),
            Container(width: 1, height: 20, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            _buildSummaryItem(
              icon: Icons.lan_outlined,
              label: 'Wired',
              count: wiredCount,
              color: colorScheme.secondary,
              isSelected: _categoryFilter == ClientCategoryFilter.wired,
              onTap: () {
                setState(() {
                  _categoryFilter = ClientCategoryFilter.wired;
                });
              },
              colorScheme: colorScheme,
            ),
            Container(width: 1, height: 20, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            _buildSummaryItem(
              icon: Icons.wifi_rounded,
              label: 'Wireless',
              count: wirelessCount,
              color: colorScheme.tertiary,
              isSelected: _categoryFilter == ClientCategoryFilter.wireless,
              onTap: () {
                setState(() {
                  _categoryFilter = ClientCategoryFilter.wireless;
                });
              },
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final activeColor = isSelected ? color : colorScheme.onSurfaceVariant;
    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: activeColor),
              const SizedBox(width: 5),
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: activeColor,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String normalizeMac(String mac) => mac.toUpperCase().replaceAll('-', ':');
}

class _UnifiedClientCard extends StatefulWidget {
  final Client client;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Client> allClients;
  final VoidCallback onRefreshNeeded;

  const _UnifiedClientCard({
    required this.client,
    required this.isExpanded,
    required this.onTap,
    this.allClients = const [],
    required this.onRefreshNeeded,
  });

  @override
  State<_UnifiedClientCard> createState() => _UnifiedClientCardState();
}

class _UnifiedClientCardState extends State<_UnifiedClientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showAllIpv6 = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_UnifiedClientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  // --- Three-state neighbor reachability helpers ---

  /// Opacity for the entire card based on neighbor reachability state.
  double _clientOpacity(Client client) {
    if (!client.isConnected) return 0.55;
    switch (client.neighState) {
      case NeighborReachability.reachable:
        return 1.0;
      case NeighborReachability.stale:
        return 0.75;
      case NeighborReachability.failed:
        return 0.55;
      case NeighborReachability.unknown:
        // /proc/net/arp fallback: use legacy binary behavior
        return client.isConnected ? 1.0 : 0.55;
    }
  }

  /// Status dot color: green (reachable), amber (stale/idle), grey (offline).
  Color _statusDotColor(Client client) {
    if (!client.isConnected) return Colors.grey.shade400;
    switch (client.neighState) {
      case NeighborReachability.reachable:
        return LuciStatusColors.connected;
      case NeighborReachability.stale:
        return LuciStatusColors.warning;
      case NeighborReachability.failed:
        return Colors.grey.shade400;
      case NeighborReachability.unknown:
        return client.isConnected ? LuciStatusColors.connected : Colors.grey.shade400;
    }
  }

  /// Tooltip describing the connectivity state in plain language.
  String _statusTooltip(Client client) {
    if (!client.isConnected) return 'Client is offline (Lease active)';
    switch (client.neighState) {
      case NeighborReachability.reachable:
        return 'Client is online';
      case NeighborReachability.stale:
        return 'Client is idle (no recent traffic)';
      case NeighborReachability.failed:
        return 'Client is offline (Lease active)';
      case NeighborReachability.unknown:
        return client.isConnected ? 'Client is online' : 'Client is offline (Lease active)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: widget.isExpanded ? 6 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedScale(
        scale: widget.isExpanded ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Column(
          children: [
            Opacity(
              opacity: _clientOpacity(widget.client),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(18.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: widget.client.isConnected ? 0.13 : 0.05,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: AnimatedScale(
                              scale: widget.isExpanded ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.elasticOut,
                              child: Icon(
                                Icons.person_outline,
                                color: widget.client.isConnected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                size: 22,
                                semanticLabel: 'Client icon',
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Tooltip(
                              message: _statusTooltip(widget.client),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _statusDotColor(widget.client),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.client.displayName,
                              style: LuciTextStyles.cardTitle(context),
                              semanticsLabel:
                                  'Client name: ${widget.client.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: LuciSpacing.xs),
                            Container(
                              margin: const EdgeInsets.only(right: 32),
                              child: Divider(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.10),
                                thickness: 1,
                                height: 8,
                              ),
                            ),
                            Text(
                              _buildMinimalClientSubtitle(widget.client),
                              style: LuciTextStyles.cardSubtitle(context),
                              semanticsLabel:
                                  'Client details: ${_buildMinimalClientSubtitle(widget.client)}',
                            ),
                            if (widget.client.vendor != null &&
                                widget.client.vendor!.isNotEmpty)
                              Text(
                                widget.client.vendor!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                semanticsLabel: 'Vendor: ${widget.client.vendor}',
                              ),
                          ],
                        ),
                      ),
                      _buildStatusBadges(
                        context,
                        widget.client,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                        size: 26,
                        semanticLabel: widget.isExpanded
                            ? 'Collapse details'
                            : 'Expand details',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.isExpanded)
              Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildClientDetails(context, widget.client),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadges(BuildContext context, Client client) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badges = <Widget>[];

    if (client.isStatic) {
      badges.add(
        Chip(
          label: const Text('STATIC'),
          avatar: const Icon(Icons.push_pin, size: 13, color: Colors.teal),
          backgroundColor: Colors.teal.withValues(alpha: 0.15),
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (client.isConnected && client.connectionType == ConnectionType.wireless) {
      final bgColor = colorScheme.primaryContainer;
      final fgColor = colorScheme.onPrimaryContainer;
      badges.add(
        Chip(
          label: const Text('Wi-Fi'),
          avatar: Icon(Icons.wifi, size: 14, color: fgColor),
          backgroundColor: bgColor,
          labelStyle: theme.textTheme.labelSmall?.copyWith(color: fgColor, fontSize: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      if (client.ssid != null && client.ssid!.isNotEmpty) {
        badges.add(
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SSID: ${client.ssid}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );
      }
    } else if (client.isConnected && client.connectionType == ConnectionType.wired) {
      final bgColor = colorScheme.secondaryContainer;
      final fgColor = colorScheme.onSecondaryContainer;
      badges.add(
        Chip(
          label: const Text('Wired'),
          avatar: Icon(Icons.lan, size: 14, color: fgColor),
          backgroundColor: bgColor,
          labelStyle: theme.textTheme.labelSmall?.copyWith(color: fgColor, fontSize: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: badges,
    );
  }

  /// Classifies an IPv6 address into a human-readable type label.
  static String _classifyIPv6(String ipv6) {
    final lower = ipv6.toLowerCase().split('/').first.split('%').first;
    if (lower.startsWith('fe80')) return 'Link-Local IPv6';
    if (lower.startsWith('fd') || lower.startsWith('fc')) return 'Private IPv6 (ULA)';
    return 'Public IPv6';
  }

  /// Sort priority for IPv6 types: public first, private second, link-local last.
  static int _ipv6SortPriority(String label) {
    if (label.startsWith('Public')) return 0;
    if (label.startsWith('Private')) return 1;
    return 2;
  }

  Widget _buildClientDetails(BuildContext context, Client client) {
    final theme = Theme.of(context);

    Widget detailRow(
      String title,
      String value, {
      Color? valueColor,
      VoidCallback? onTap,
      String? semanticsLabel,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LuciSpacing.md,
            vertical: LuciSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: LuciTextStyles.detailLabel(context),
                semanticsLabel: title,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SelectableText(
                        value,
                        style: valueColor != null
                            ? LuciTextStyles.detailValue(
                                context,
                              ).copyWith(color: valueColor)
                            : LuciTextStyles.detailValue(context),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    if (onTap != null)
                      GestureDetector(
                        onTap: onTap,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.copy_all_outlined,
                            size: 16,
                            semanticLabel: 'Copy',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build classified IPv6 rows, sorted: public → private → link-local
    List<Widget> ipv6Rows = [];
    if (client.ipv6Addresses != null && client.ipv6Addresses!.isNotEmpty) {
      // Deduplicate IPv6 list
      final uniqueV6 = <String>{};
      final deduplicatedV6 = <String>[];
      for (final addr in client.ipv6Addresses!) {
        final norm = addr.trim().toLowerCase();
        if (norm.isNotEmpty && uniqueV6.add(norm)) {
          deduplicatedV6.add(addr.trim());
        }
      }

      final classified = deduplicatedV6.map((ipv6) {
        final label = _classifyIPv6(ipv6);
        return (label: label, address: ipv6);
      }).toList();
      classified.sort((a, b) => _ipv6SortPriority(a.label).compareTo(_ipv6SortPriority(b.label)));

      final displayEntries = (classified.length > 1 && !_showAllIpv6)
          ? classified.take(1).toList()
          : classified;

      ipv6Rows = displayEntries.map(
        (entry) => detailRow(
          entry.label,
          entry.address,
          onTap: () => _copyToClipboard(context, entry.address, entry.label),
          semanticsLabel: '${entry.label}: ${entry.address}',
        ),
      ).toList();

      if (classified.length > 1) {
        final remainingCount = classified.length - 1;
        ipv6Rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showAllIpv6 = !_showAllIpv6;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllIpv6
                          ? 'Collapse IPv6 addresses'
                          : 'Show $remainingCount more IPv6 address${remainingCount > 1 ? 'es' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllIpv6 ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.18,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        children: [
          detailRow(
            'IP Address',
            client.ipAddress,
            onTap: () =>
                _copyToClipboard(context, client.ipAddress, 'IP Address'),
            semanticsLabel: 'IP Address: ${client.ipAddress}',
          ),
          ...ipv6Rows,
          detailRow(
            'MAC Address',
            client.macAddress,
            onTap: () =>
                _copyToClipboard(context, client.macAddress, 'MAC Address'),
            semanticsLabel: 'MAC Address: ${client.macAddress}',
          ),
          if (client.vendor != null && client.vendor!.isNotEmpty)
            detailRow(
              'Vendor',
              client.vendor!,
              semanticsLabel: 'Vendor: ${client.vendor}',
            ),
          if (client.ssid != null && client.ssid!.isNotEmpty)
            detailRow(
              'Connected Wireless SSID',
              client.ssid!,
              semanticsLabel: 'SSID: ${client.ssid}',
            ),
          if (client.dnsName != null && client.dnsName!.isNotEmpty)
            detailRow(
              'DNS Name',
              client.dnsName!,
              onTap: () =>
                  _copyToClipboard(context, client.dnsName!, 'DNS Name'),
              semanticsLabel: 'DNS Name: ${client.dnsName}',
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          detailRow(
            'Lease Time Remaining',
            client.formattedLeaseTime,
            valueColor: client.formattedLeaseTime == 'Expired'
                ? theme.colorScheme.error
                : (client.formattedLeaseTime == 'No active lease'
                    ? theme.colorScheme.onSurfaceVariant
                    : null),
            semanticsLabel:
                'Lease Time Remaining: ${client.formattedLeaseTime}',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              children: [
                // Option 1: Temporarily pause local network access / internet access
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (ctx, _) {
                    final appState = AppState.instance;
                    final isPaused = appState.isInternetPaused(client.macAddress);
                    final canPause = client.isConnected || isPaused;
                    return Column(
                      children: [
                        if (canPause)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _toggleInternetPause(context, client, !isPaused),
                              icon: Icon(
                                isPaused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                color: isPaused ? LuciStatusColors.connected : Colors.orange,
                                size: 20,
                              ),
                              label: Text(
                                isPaused ? 'Resume Internet Access' : 'Pause Internet Access',
                                style: TextStyle(
                                  color: isPaused ? LuciStatusColors.connected : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isPaused ? LuciStatusColors.connected : Colors.orange.shade600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (!client.isStatic && !_isIpv6Only(client)) ...[
                          if (canPause) const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddStaticLeaseDialog(context, client),
                              icon: const Icon(
                                Icons.push_pin_outlined,
                                color: Colors.teal,
                                size: 20,
                              ),
                              label: Text(
                                'Add to Static Leases',
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.teal.shade600),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (client.isStatic) ...[
                          if (canPause) const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddStaticLeaseDialog(context, client),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.teal,
                                size: 20,
                              ),
                              label: Text(
                                'Edit Static Lease',
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.teal.shade600),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmRemoveStaticLease(context, client),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              label: const Text(
                                'Remove from Static Leases',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidIPv4(String ip) {
    if (ip == 'N/A' || ip.trim().isEmpty) return false;
    final reg = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.){3}(25[0-5]|(2[0-4]|1\d|[1-9]|)\d)$');
    return reg.hasMatch(ip.trim());
  }

  bool _isIpv6Only(Client client) {
    final hasV4 = _isValidIPv4(client.ipAddress);
    final hasV6 = client.ipv6Addresses != null && client.ipv6Addresses!.isNotEmpty;
    return !hasV4 && hasV6;
  }

  void _showAddStaticLeaseDialog(BuildContext context, Client client) {
    final appState = AppState.instance;
    final dhcpOverview = DhcpDnsOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );
    DhcpStaticMapping? existingMapping;
    final normMac = client.macAddress.toUpperCase().replaceAll('-', ':');
    for (final s in dhcpOverview.staticMappings) {
      if (s.macAddress.toUpperCase().replaceAll('-', ':') == normMac) {
        existingMapping = s;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AddStaticLeaseDialog(
        client: client,
        allClients: widget.allClients,
        existingMapping: existingMapping,
        onSaved: widget.onRefreshNeeded,
      ),
    );
  }

  Future<void> _confirmRemoveStaticLease(BuildContext context, Client client) async {
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
          'Are you sure you want to remove the static IP reservation for "${client.displayName}" (${client.macAddress})?',
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
          content: Text('Removing static lease for ${client.displayName}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final appState = AppState.instance;
      final success = await appState.deleteStaticLease(
        macAddress: client.macAddress,
        context: context,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Static lease removed for ${client.displayName}.'
                : 'Failed to remove static lease for ${client.displayName}.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        widget.onRefreshNeeded();
      }
    }
  }

  Future<void> _toggleInternetPause(BuildContext context, Client client, bool pause) async {
    if (pause) {
      final safe = await SelfDeviceGuard.checkSelfActionGuardrail(
        context,
        actionName: 'Pause Internet Access',
        targetMac: client.macAddress,
        targetIp: client.ipAddress,
        targetHostname: client.displayName,
      );
      if (!safe) return;
      if (!context.mounted) return;
    }

    final appState = AppState.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pause ? "Pausing" : "Resuming"} internet for ${client.displayName}...'),
        duration: const Duration(seconds: 2),
      ),
    );
    final success = await appState.pauseClientInternet(
      client.macAddress,
      pause: pause,
      context: context,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Internet ${pause ? "paused" : "restored"} for ${client.displayName}.'
              : 'Failed to ${pause ? "pause" : "resume"} internet for ${client.displayName}.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    setState(() {});
  }

  String _buildMinimalClientSubtitle(Client client) {
    final v4 = client.ipAddress;
    final v6s = client.ipv6Addresses ?? [];
    final v6 = v6s.isNotEmpty ? v6s.first : null;
    String? shown;
    int extra = 0;
    if (v4 != 'N/A') {
      shown = v4;
      if (v6 != null) extra++;
    } else if (v6 != null) {
      shown = v6;
    }
    if (shown == null) return '';
    if (extra > 0) {
      return '$shown  +$extra';
    } else {
      return shown;
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

