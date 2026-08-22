// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:yet_another_luci_app/state/app_state.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:yet_another_luci_app/utils/os_platform_integration.dart';
import 'package:yet_another_luci_app/utils/self_device_guard.dart';
import '../models/parental_profile.dart';
import '../models/parental_controls_store.dart';
import '../widgets/add_edit_profile_dialog.dart';
import '../widgets/parental_profile_card.dart';

class ParentalControlsScreen extends ConsumerStatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  ConsumerState<ParentalControlsScreen> createState() => _ParentalControlsScreenState();
}

class _ParentalControlsScreenState extends ConsumerState<ParentalControlsScreen>
    with WidgetsBindingObserver {
  final _store = ParentalControlsStore.instance;
  Timer? _expiryTimer;
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startExpiryTimer();
    _loadStore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChange);
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPausesAndSchedules();
    }
  }

  /// Fired only after `_loadStore` completes so we never write back an empty state.
  void _onStoreChange() {
    if (!mounted) return;
    setState(() {});
    _persistStore();
  }

  Future<void> _loadStore() async {
    final appState = ref.read(appStateProvider);
    final raw = await appState.secureRead('parental_controls_store_v1');
    if (!mounted) return;
    // Register listener AFTER load to avoid persisting the initial empty→loaded
    // transition back to storage (which would overwrite an existing good value).
    _store.loadFromString(raw);
    _storeLoaded = true;
    _store.addListener(_onStoreChange);
    if (mounted) setState(() {});
  }

  Future<void> _persistStore() async {
    if (!_storeLoaded) return;
    final appState = ref.read(appStateProvider);
    await appState.secureWrite('parental_controls_store_v1', _store.toJsonString());
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _checkPausesAndSchedules();
    });
  }

  /// Auto-resume expired manual pauses and sync active scheduled time blocks.
  void _checkPausesAndSchedules() {
    final appState = ref.read(appStateProvider);
    for (final profile in _store.profiles) {
      // 1. Auto-resume any timed manual pauses that have expired
      if (profile.isPaused &&
          profile.pauseExpiresAt != null &&
          profile.pauseExpiresAt!.isBefore(DateTime.now().toUtc())) {
        _resumeProfile(profile, appState: appState, auto: true);
      }

      // 2. Sync scheduled access windows for active (non-bypassed) profiles
      if (profile.isEnabled && profile.hasSchedule) {
        final inScheduleWindow = profile.schedule!.isTimeInBlockWindow();
        for (final mac in profile.macAddresses) {
          final currentlyPaused = appState.isInternetPaused(mac);
          if (inScheduleWindow && !currentlyPaused) {
            // Schedule block window active: enforce firewall block
            appState.pauseClientInternet(mac, pause: true, context: null);
          } else if (!inScheduleWindow && !profile.isPaused && currentlyPaused) {
            // Schedule block window ended: restore internet access
            appState.pauseClientInternet(mac, pause: false, context: null);
          }
        }
      }
    }
  }

  Future<void> _pauseProfile(ParentalProfile profile, PauseDuration duration) async {
    if (!mounted) return;
    final appState = ref.read(appStateProvider);
    final caps = appState.capabilities;
    final hasFirewall = caps == null || caps.hasUciWriteAccess;

    if (!hasFirewall) {
      if (mounted) {
        context.showToastError('Firewall write access unavailable. Cannot pause internet.');
      }
      return;
    }

    for (final mac in profile.macAddresses) {
      final safe = await SelfDeviceGuard.checkSelfActionGuardrail(
        context,
        actionName: 'Pause Internet for ${profile.name}',
        targetMac: mac,
      );
      if (!safe) return;
    }

    DateTime? expiresAt;
    if (duration == PauseDuration.untilTomorrow) {
      final now = DateTime.now().toLocal();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 7, 0);
      expiresAt = tomorrow.toUtc();
    } else if (duration.duration != null) {
      expiresAt = DateTime.now().toUtc().add(duration.duration!);
    }

    final actionKey = 'pause_profile_${profile.id}';
    if (mounted) {
      context.showToastLoading('Pausing internet for ${profile.name}…', actionKey: actionKey);
    }

    bool allOk = true;
    for (final mac in profile.macAddresses) {
      // ignore: use_build_context_synchronously — context checked via mounted guard above
      final ok = await appState.pauseClientInternet(mac, pause: true, context: null);
      if (!ok) allOk = false;
    }

    if (!mounted) return;

    if (allOk || profile.macAddresses.isEmpty) {
      _store.markProfilePaused(profile.id, expiresAt: expiresAt);
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.medium));
      final msg = expiresAt != null
          ? 'Internet paused for ${profile.name} (${duration.label}).'
          : 'Internet paused for ${profile.name}.';
      if (mounted) context.showToastSuccess(msg, actionKey: actionKey);
    } else {
      unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.heavy));
      if (mounted) {
        context.showToastError(
          'Some devices could not be paused. Check router connection.',
          actionKey: actionKey,
        );
      }
    }
  }

  Future<void> _resumeProfile(
    ParentalProfile profile, {
    required AppState appState,
    bool auto = false,
  }) async {
    final actionKey = 'resume_profile_${profile.id}';

    if (!auto && mounted) {
      context.showToastLoading('Resuming internet for ${profile.name}…', actionKey: actionKey);
    }

    bool allOk = true;
    for (final mac in profile.macAddresses) {
      final ok = await appState.pauseClientInternet(mac, pause: false, context: null);
      if (!ok) allOk = false;
    }

    if (allOk || profile.macAddresses.isEmpty) {
      _store.markProfileResumed(profile.id);
      if (!auto) unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.medium));
      if (!auto && mounted) {
        context.showToastSuccess('Internet resumed for ${profile.name}.', actionKey: actionKey);
      }
    } else {
      if (!auto && mounted) {
        unawaited(OsPlatformIntegration.triggerHaptic(OsHapticType.heavy));
        context.showToastError('Failed to resume for some devices.', actionKey: actionKey);
      }
    }
  }

  void _openAddProfile() {
    showDialog(
      context: context,
      builder: (ctx) => AddEditProfileDialog(
        allProfiles: _store.profiles,
        onSave: (profile) async {
          _store.addProfile(profile);
          if (profile.isCurrentlyBlocked) {
            final appState = ref.read(appStateProvider);
            for (final mac in profile.macAddresses) {
              await appState.pauseClientInternet(mac, pause: true, context: null);
            }
          }
        },
      ),
    );
  }

  void _openEditProfile(ParentalProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditProfileDialog(
        existing: profile,
        allProfiles: _store.profiles,
        onSave: (updated) async {
          final oldMacs = Set<String>.from(profile.macAddresses);
          final newMacs = Set<String>.from(updated.macAddresses);
          _store.updateProfile(updated);

          final appState = ref.read(appStateProvider);
          // 1. MACs removed from profile: unblock if no other profile blocks them
          final removedMacs = oldMacs.difference(newMacs);
          for (final mac in removedMacs) {
            if (!_store.isMacPaused(mac)) {
              await appState.pauseClientInternet(mac, pause: false, context: null);
            }
          }
          // 2. MACs newly added to profile: block if profile is currently blocked
          final addedMacs = newMacs.difference(oldMacs);
          if (updated.isCurrentlyBlocked) {
            for (final mac in addedMacs) {
              await appState.pauseClientInternet(mac, pause: true, context: null);
            }
          }
        },
      ),
    );
  }

  void _confirmDeleteProfile(ParentalProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
          'Delete "${profile.name}"? This will not affect current firewall rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _store.deleteProfile(profile.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = ref.watch(appStateProvider);
    final caps = appState.capabilities;
    final isReviewerMode = appState.reviewerModeEnabled;
    final hasFirewall = caps == null || caps.hasUciWriteAccess;
    final hasFileExec = caps == null || caps.hasFileExec;
    final profiles = _store.profiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Activity Log',
            onPressed: () => _showActivityLog(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Capability banners ──────────────────────────────────────
          if (!hasFirewall)
            _CapabilityBanner(
              icon: Icons.shield_outlined,
              color: Colors.orange,
              message:
                  'No UCI write access detected. Internet pause and content filter '
                  'features require root/admin access to the router.',
            ),
          if (!hasFileExec)
            _CapabilityBanner(
              icon: Icons.schedule_rounded,
              color: Colors.blue,
              message:
                  'File execution unavailable. Time schedules require '
                  'the file.exec ubus method (available when luci-mod-rpc is installed).',
            ),
          if (isReviewerMode)
            _CapabilityBanner(
              icon: Icons.rate_review_outlined,
              color: theme.colorScheme.primary,
              message: 'Reviewer Mode — changes are simulated and not sent to a real router.',
            ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: !_storeLoaded
                ? const Center(child: CircularProgressIndicator())
                : profiles.isEmpty
                    ? _EmptyState(onAdd: _openAddProfile)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final profile = profiles[i];
                          return ParentalProfileCard(
                            profile: profile,
                            hasFirewall: hasFirewall,
                            hasFileExec: hasFileExec,
                            onPause: (duration) => _pauseProfile(profile, duration),
                            onResume: () => _resumeProfile(
                              profile,
                              appState: ref.read(appStateProvider),
                            ),
                            onEdit: () => _openEditProfile(profile),
                            onDelete: () => _confirmDeleteProfile(profile),
                            onToggleEnabled: () async {
                              _store.toggleProfileEnabled(profile.id);
                              final updated = _store.getProfile(profile.id);
                              if (updated != null && mounted) {
                                final isNowEnabled = updated.isEnabled;
                                final appState = ref.read(appStateProvider);
                                if (!isNowEnabled) {
                                  // Profile is now bypassed: remove active firewall block for assigned devices
                                  for (final mac in updated.macAddresses) {
                                    await appState.pauseClientInternet(mac, pause: false, context: null);
                                  }
                                } else if (updated.isCurrentlyBlocked) {
                                  // Profile re-enabled and currently blocked: re-apply firewall block for assigned devices
                                  for (final mac in updated.macAddresses) {
                                    await appState.pauseClientInternet(mac, pause: true, context: null);
                                  }
                                }
                                if (mounted) {
                                  // ignore: use_build_context_synchronously — mounted guard checked above
                                  context.showToastInfo(
                                    isNowEnabled
                                        ? 'Rules re-enabled for ${profile.name}'
                                        : 'Restrictions bypassed for ${profile.name}',
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProfile,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Profile'),
      ),
    );
  }

  void _showActivityLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final theme = Theme.of(ctx2);
            final log = _store.activityLog;
            return Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Activity Log',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (log.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _store.clearActivityLog();
                            setSheetState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: log.isEmpty
                      ? Center(
                          child: Text(
                            'No activity recorded yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: ctrl,
                          itemCount: log.length,
                          itemBuilder: (_, i) {
                            final e = log[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                _iconForEvent(e.eventType),
                                size: 20,
                                color: _colorForEvent(e.eventType, theme),
                              ),
                              title: Text('${e.profileName}: ${e.eventType.label}'),
                              subtitle: Text(
                                _formatTs(e.timestamp) +
                                    (e.detail != null ? ' · ${e.detail}' : ''),
                                style: theme.textTheme.bodySmall,
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
    );
  }

  static IconData _iconForEvent(ParentalEventType t) {
    switch (t) {
      case ParentalEventType.paused:
      case ParentalEventType.schedulePaused:
      case ParentalEventType.limitReached:
        return Icons.pause_circle_outline;
      case ParentalEventType.resumed:
      case ParentalEventType.scheduleResumed:
      case ParentalEventType.limitOverridden:
        return Icons.play_circle_outline;
      case ParentalEventType.profileCreated:
        return Icons.person_add_outlined;
      case ParentalEventType.profileDeleted:
        return Icons.person_remove_outlined;
      case ParentalEventType.profileUpdated:
        return Icons.edit_outlined;
      case ParentalEventType.contentFilterApplied:
        return Icons.dns_outlined;
    }
  }

  static Color _colorForEvent(ParentalEventType t, ThemeData theme) {
    switch (t) {
      case ParentalEventType.paused:
      case ParentalEventType.schedulePaused:
      case ParentalEventType.limitReached:
        return Colors.orange;
      case ParentalEventType.resumed:
      case ParentalEventType.scheduleResumed:
      case ParentalEventType.limitOverridden:
        return Colors.green;
      case ParentalEventType.profileCreated:
      case ParentalEventType.profileDeleted:
      case ParentalEventType.profileUpdated:
      case ParentalEventType.contentFilterApplied:
        return theme.colorScheme.primary;
    }
  }

  static String _formatTs(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '${l.day}/${l.month} $h:$m';
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _CapabilityBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _CapabilityBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: color.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom_rounded,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No Profiles Yet',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a profile for each family member or device group. '
              'Assign devices to a profile to manage internet access, '
              'schedules, and content filtering.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
