// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import '../models/services_system_info.dart';

class ServicesSystemScreen extends ConsumerStatefulWidget {
  const ServicesSystemScreen({super.key});

  @override
  ConsumerState<ServicesSystemScreen> createState() => _ServicesSystemScreenState();
}

class _ServicesSystemScreenState extends ConsumerState<ServicesSystemScreen> {
  /// Stores staged enable/disable toggles for modified init scripts.
  /// Format: {scriptName: desiredEnabledStatus}
  final Map<String, bool> _stagedInitScriptStates = {};
  bool _isSaving = false;

  bool get _hasUnsavedChanges => _stagedInitScriptStates.isNotEmpty;

  void _toggleInitScriptState(InitScript script, bool newValue) {
    setState(() {
      if (newValue == script.isEnabled) {
        _stagedInitScriptStates.remove(script.name);
      } else {
        _stagedInitScriptStates[script.name] = newValue;
      }
    });
  }

  void _discardChanges() {
    setState(() {
      _stagedInitScriptStates.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discarded all unsaved init script changes.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmAndDiscardChanges() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: Text(
          'Are you sure you want to discard staged changes for ${_stagedInitScriptStates.length} init script(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _discardChanges();
    }
  }

  Future<bool> _saveChanges() async {
    if (!_hasUnsavedChanges || _isSaving) return true;

    setState(() {
      _isSaving = true;
    });

    final appState = ref.read(appStateProvider);
    final modifiedEntries = Map<String, bool>.from(_stagedInitScriptStates);
    final succeededScripts = <String>[];
    final failedScripts = <String>[];

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Saving ${modifiedEntries.length} init script change(s)...'),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    for (final entry in modifiedEntries.entries) {
      final scriptName = entry.key;
      final targetEnabled = entry.value;
      final action = targetEnabled ? 'enable' : 'disable';

      final success = await appState.manageServiceAction(
        scriptName,
        action,
        context: context,
      );

      if (success) {
        succeededScripts.add(scriptName);
      } else {
        failedScripts.add(scriptName);
      }
    }

    setState(() {
      for (final name in succeededScripts) {
        _stagedInitScriptStates.remove(name);
      }
      _isSaving = false;
    });

    await appState.fetchDashboardData();

    if (!mounted) return failedScripts.isEmpty;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (failedScripts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${succeededScripts.length} init script(s).'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      return true;
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Init Script Save Warning'),
          content: Text(
            'Updated ${succeededScripts.length} script(s), but failed to update ${failedScripts.length} script(s):\n\n'
            '${failedScripts.join(", ")}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  Future<bool?> _showUnsavedChangesDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Init Script Changes'),
        content: Text(
          'You have ${_stagedInitScriptStates.length} unsaved change(s) to startup init scripts. Would you like to save them before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              _discardChanges();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Discard & Leave'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop(false);
              final saved = await _saveChanges();
              if (saved && mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final overview = ServicesSystemOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return PopScope(
      canPop: !_hasUnsavedChanges && !_isSaving,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldLeave = await _showUnsavedChangesDialog();
        if (shouldLeave == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Services & System'),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Discard Changes',
                onPressed: _isSaving ? null : _confirmAndDiscardChanges,
              ),
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save Changes',
                onPressed: _isSaving ? null : () => _saveChanges(),
              ),
          ],
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
              const SizedBox(height: 80),
            ],
          ),
        ),
        bottomNavigationBar: _hasUnsavedChanges ? _buildUnsavedChangesBottomBar(context) : null,
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
                      backgroundColor: svc.isRunning ? LuciStatusColors.connected.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                      child: Icon(
                        svc.isRunning ? Icons.play_arrow : Icons.stop,
                        color: svc.isRunning ? LuciStatusColors.connected : Colors.red,
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
                    color: svc.isRunning ? LuciStatusColors.connected.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    svc.isRunning ? (svc.pid != null ? 'RUNNING (PID ${svc.pid})' : 'RUNNING') : 'STOPPED',
                    style: TextStyle(
                      color: svc.isRunning ? LuciStatusColors.connected : Colors.red,
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

    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: initScripts.map((init) {
          final isStaged = _stagedInitScriptStates.containsKey(init.name);
          final currentEnabled = _stagedInitScriptStates[init.name] ?? init.isEnabled;

          return Container(
            decoration: BoxDecoration(
              color: isStaged ? theme.colorScheme.primaryContainer.withValues(alpha: 0.12) : null,
              border: isStaged
                  ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    )
                  : null,
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                child: Text(
                  '${init.startPriority}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              title: Row(
                children: [
                  Text(init.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (isStaged) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Text(
                        'STAGED',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                isStaged
                    ? 'Priority: ${init.startPriority} • Original: ${init.isEnabled ? "ENABLED" : "DISABLED"}'
                    : 'Startup Order Priority: ${init.startPriority}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: currentEnabled
                          ? LuciStatusColors.connected.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentEnabled ? 'ENABLED' : 'DISABLED',
                      style: TextStyle(
                        color: currentEnabled ? LuciStatusColors.connected : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: currentEnabled,
                    onChanged: _isSaving
                        ? null
                        : (newValue) => _toggleInitScriptState(init, newValue),
                  ),
                ],
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

  Widget _buildUnsavedChangesBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final count = _stagedInitScriptStates.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count script(s) modified',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _isSaving ? null : _confirmAndDiscardChanges,
              child: const Text('Discard'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveChanges(),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

