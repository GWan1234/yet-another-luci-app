import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/services_system_info.dart';

class ServicesSystemScreen extends ConsumerWidget {
  const ServicesSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final overview = ServicesSystemOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & System'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchDashboardData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(context, 'Procd System Services', Icons.miscellaneous_services_outlined),
            const SizedBox(height: 8),
            ...overview.services.map((svc) => _buildProcdServiceCard(context, ref, svc)),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Startup Init Scripts (/etc/init.d)', Icons.playlist_add_check_outlined),
            const SizedBox(height: 8),
            _buildInitScriptsCard(context, overview.initScripts),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'System Scheduled Cron Jobs', Icons.schedule_outlined),
            const SizedBox(height: 8),
            _buildCronJobsCard(context, overview.cronJobs),
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

  Widget _buildProcdServiceCard(BuildContext context, WidgetRef ref, ProcdService svc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: svc.isRunning ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                      child: Icon(
                        svc.isRunning ? Icons.play_arrow : Icons.stop,
                        color: svc.isRunning ? Colors.green : Colors.red,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(svc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(svc.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: svc.isRunning ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    svc.isRunning ? (svc.pid != null ? 'RUNNING (PID ${svc.pid})' : 'RUNNING') : 'STOPPED',
                    style: TextStyle(
                      color: svc.isRunning ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Triggered restart for ${svc.name}...')),
                    );
                    final success = await ref.read(appStateProvider).manageServiceAction(svc.name, 'restart', context: context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Successfully restarted ${svc.name}' : 'Failed to restart ${svc.name}'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Restart', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final targetAction = svc.isRunning ? 'stop' : 'start';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Triggered $targetAction for ${svc.name}...')),
                    );
                    final success = await ref.read(appStateProvider).manageServiceAction(svc.name, targetAction, context: context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Successfully performed $targetAction for ${svc.name}' : 'Failed to $targetAction ${svc.name}'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: Icon(svc.isRunning ? Icons.stop : Icons.play_arrow, size: 16),
                  label: Text(svc.isRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitScriptsCard(BuildContext context, List<InitScript> initScripts) {
    if (initScripts.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No init startup scripts found.')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: initScripts.map((init) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.withValues(alpha: 0.15),
              child: Text('${init.startPriority}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            title: Text(init.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Startup Order Priority: ${init.startPriority}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: init.isEnabled ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                init.isEnabled ? 'ENABLED' : 'DISABLED',
                style: TextStyle(
                  color: init.isEnabled ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCronJobsCard(BuildContext context, List<CronJob> cronJobs) {
    if (cronJobs.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No system cron jobs scheduled.')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: cronJobs.map((cron) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.schedule, color: Colors.orange),
            title: Text(cron.command, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
            subtitle: Text('Schedule: ${cron.expression}'),
          );
        }).toList(),
      ),
    );
  }
}
