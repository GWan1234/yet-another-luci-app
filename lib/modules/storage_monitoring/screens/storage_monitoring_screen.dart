import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/storage_info.dart';

class StorageMonitoringScreen extends ConsumerWidget {
  const StorageMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final mountData = appState.dashboardData?['mountPoints'];
    final storage = StorageOverview.fromRpcData(mountData, isReviewerMode: appState.reviewerModeEnabled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Monitoring'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'Filesystem Usage Overview', Icons.pie_chart_outline),
            const SizedBox(height: 8),
            _buildOverallUsageCard(context, storage),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Overlay FS Status', Icons.layers_outlined),
            const SizedBox(height: 8),
            _buildOverlayFsCard(context, storage.overlayFs),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Flash Memory & Root FS', Icons.memory_outlined),
            const SizedBox(height: 8),
            _buildFlashMemoryCard(context, storage.rootFs),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Mounted Storage Devices', Icons.storage_outlined),
            const SizedBox(height: 8),
            ...storage.mountPoints.map((mp) => _buildMountPointCard(context, mp)),
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

  Widget _buildOverallUsageCard(BuildContext context, StorageOverview storage) {
    final theme = Theme.of(context);
    final percent = storage.overallUsedPercent;

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
                const Text('Total System Storage', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${percent.toStringAsFixed(1)}% Used', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent > 85 ? Colors.red : (percent > 65 ? Colors.orange : Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn('Total Space', _formatBytes(storage.totalSizeBytes)),
                _buildStatColumn('Used Space', _formatBytes(storage.totalUsedBytes)),
                _buildStatColumn('Free Space', _formatBytes(storage.totalSizeBytes - storage.totalUsedBytes)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayFsCard(BuildContext context, MountPointItem? overlay) {
    if (overlay == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Overlay filesystem (/overlay) not detected or standard squashfs/ext4 layout in use.'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('Overlay Active on ${overlay.device}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Mount Target', overlay.mountPath),
            _buildDetailRow('Block Device', overlay.device),
            _buildDetailRow('Filesystem Type', overlay.filesystemType.toUpperCase()),
            _buildDetailRow('Used Space', '${_formatBytes(overlay.usedBytes)} (${overlay.usedPercent.toStringAsFixed(1)}%)'),
            _buildDetailRow('Available Space', _formatBytes(overlay.availableBytes)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashMemoryCard(BuildContext context, MountPointItem? root) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('On-board Flash Memory Info', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDetailRow('Root Directory', root?.mountPath ?? '/'),
            _buildDetailRow('Flash Device', root?.device ?? '/dev/root'),
            _buildDetailRow('Root FS Format', (root?.filesystemType ?? 'squashfs').toUpperCase()),
            _buildDetailRow('Size', _formatBytes(root?.sizeBytes ?? 0)),
            _buildDetailRow('Free Space', _formatBytes(root?.availableBytes ?? 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildMountPointCard(BuildContext context, MountPointItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            item.isTmp ? Icons.folder_zip_outlined : Icons.sd_storage_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(item.mountPath, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.device} • ${item.filesystemType}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${item.usedPercent.toStringAsFixed(0)}% used', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${_formatBytes(item.usedBytes)} / ${_formatBytes(item.sizeBytes)}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}
