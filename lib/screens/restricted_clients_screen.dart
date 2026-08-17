// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

class RestrictedClientsScreen extends ConsumerStatefulWidget {
  const RestrictedClientsScreen({super.key});

  @override
  ConsumerState<RestrictedClientsScreen> createState() => _RestrictedClientsScreenState();
}

class _RestrictedClientsScreenState extends ConsumerState<RestrictedClientsScreen> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _liveData = {
    'restricted': [],
    'banned': [],
  };

  @override
  void initState() {
    super.initState();
    _fetchLiveData();
  }

  Future<void> _fetchLiveData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final appState = ref.read(appStateProvider);
    final data = await appState.fetchRestrictedAndBannedClientsLive(context: context);

    if (mounted) {
      final seenRestricted = <String>{};
      final cleanRestricted = <Map<String, dynamic>>[];
      for (final item in (data['restricted'] ?? [])) {
        final m = item['mac']?.toString().toUpperCase() ?? '';
        if (m.isNotEmpty && seenRestricted.add(m)) {
          cleanRestricted.add(item);
        }
      }

      final seenBanned = <String>{};
      final cleanBanned = <Map<String, dynamic>>[];
      for (final item in (data['banned'] ?? [])) {
        final m = item['mac']?.toString().toUpperCase() ?? '';
        if (m.isNotEmpty && seenBanned.add(m)) {
          cleanBanned.add(item);
        }
      }

      setState(() {
        _liveData = {
          'restricted': cleanRestricted,
          'banned': cleanBanned,
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnpause(String mac, String name) async {
    final appState = ref.read(appStateProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resuming internet for $name...')),
      );
    }

    final success = await appState.pauseClientInternet(mac, pause: false, context: context);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Internet restored for $name.' : 'Failed to restore internet for $name.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      await _fetchLiveData();
    }
  }

  Future<void> _handleUnban(String mac, String name) async {
    final appState = ref.read(appStateProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unbanning Wi-Fi access for $name...')),
      );
    }

    final success = await appState.unbanWirelessClient(mac, context: context);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Client $name unbanned successfully.' : 'Failed to unban client $name.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      await _fetchLiveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restrictedList = _liveData['restricted'] ?? [];
    final bannedList = _liveData['banned'] ?? [];
    final totalCount = restrictedList.length + bannedList.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restricted & Banned Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Live Router Fetch',
            onPressed: _fetchLiveData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching live restrictions directly from router...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLiveData,
              child: totalCount == 0
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 60),
                        Icon(
                          Icons.verified_user_outlined,
                          size: 72,
                          color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Restricted or Banned Clients',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All connected devices have full network and Wi-Fi access. Restricted or banned devices will appear here in real-time.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (restrictedList.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            title: 'Internet Paused Clients',
                            subtitle: 'Access restricted via router firewall rules',
                            icon: Icons.pause_circle_outline,
                            color: Colors.orange,
                            count: restrictedList.length,
                          ),
                          const SizedBox(height: 12),
                          ...restrictedList.map(
                            (client) => _buildRestrictedTile(
                              context,
                              client: client,
                              onAction: () => _handleUnpause(
                                client['mac'].toString(),
                                client['name'].toString(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (bannedList.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            title: 'Wi-Fi Banned Devices',
                            subtitle: 'Kicked & blacklisted from Wi-Fi association',
                            icon: Icons.block_outlined,
                            color: Colors.red,
                            count: bannedList.length,
                          ),
                          const SizedBox(height: 12),
                          ...bannedList.map(
                            (client) => _buildBannedTile(
                              context,
                              client: client,
                              onAction: () => _handleUnban(
                                client['mac'].toString(),
                                client['name'].toString(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedTile(
    BuildContext context, {
    required Map<String, dynamic> client,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    final mac = client['mac']?.toString() ?? '';
    final name = client['name']?.toString() ?? mac;
    final ip = client['ip']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: const Icon(Icons.pause, color: Colors.orange),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('IP: $ip • MAC: $mac'),
        trailing: FilledButton.tonalIcon(
          onPressed: onAction,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Resume'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.15),
            foregroundColor: Colors.green.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildBannedTile(
    BuildContext context, {
    required Map<String, dynamic> client,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    final mac = client['mac']?.toString() ?? '';
    final name = client['name']?.toString() ?? mac;
    final ip = client['ip']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withValues(alpha: 0.15),
          child: const Icon(Icons.block, color: Colors.red),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('IP: $ip • MAC: $mac'),
        trailing: FilledButton.tonalIcon(
          onPressed: onAction,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Unban'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.15),
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }
}
