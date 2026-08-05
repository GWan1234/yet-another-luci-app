import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/storage_info.dart';

class StorageMonitoringCard extends ConsumerWidget {
  const StorageMonitoringCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final mountData = appState.dashboardData?['mountPoints'];
    final storage = StorageOverview.fromRpcData(mountData, isReviewerMode: appState.reviewerModeEnabled);

    final rootPercent = storage.rootFs?.usedPercent ?? 0.0;
    final overlayPercent = storage.overlayFs?.usedPercent ?? 0.0;

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
                      Icons.sd_storage_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Storage & Overlay',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${storage.mountedDevices.length} Mounts',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStorageBar(
              context,
              label: 'Root Filesystem (/)',
              percent: rootPercent,
              used: storage.rootFs?.usedBytes ?? 0,
              total: storage.rootFs?.sizeBytes ?? 0,
              color: Colors.teal,
            ),
            const SizedBox(height: 10),
            _buildStorageBar(
              context,
              label: 'Overlay FS (/overlay)',
              percent: overlayPercent,
              used: storage.overlayFs?.usedBytes ?? 0,
              total: storage.overlayFs?.sizeBytes ?? 0,
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBar(
    BuildContext context, {
    required String label,
    required double percent,
    required int used,
    required int total,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final formattedUsed = _formatBytes(used);
    final formattedTotal = _formatBytes(total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            Text(
              '$formattedUsed / $formattedTotal (${percent.toStringAsFixed(0)}%)',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(0)} MB';
  }
}
