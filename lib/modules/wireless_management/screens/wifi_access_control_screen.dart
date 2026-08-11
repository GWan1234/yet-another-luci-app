import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/client.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import '../models/wireless_info.dart';

class WifiAccessControlScreen extends ConsumerStatefulWidget {
  const WifiAccessControlScreen({super.key});

  @override
  ConsumerState<WifiAccessControlScreen> createState() => _WifiAccessControlScreenState();
}

class _WifiAccessControlScreenState extends ConsumerState<WifiAccessControlScreen> {
  final TextEditingController _macController = TextEditingController();
  String _selectedMac = '';
  List<Client> _availableClients = [];
  bool _isLoadingClients = true;

  // Selected per-interface settings: ifaceSection -> isAllowed
  final Map<String, bool> _selectedIfaceAllows = {};

  // Current session phone MAC detection
  String? _phoneMac;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final appState = ref.read(appStateProvider);
    try {
      final clients = await appState.fetchAggregatedClients();
      if (!mounted) return;
      setState(() {
        _availableClients = clients;
        _isLoadingClients = false;
        // Attempt to auto-select phone MAC if connected
        for (final c in clients) {
          if (c.isConnected && c.connectionType == ConnectionType.wireless) {
            _phoneMac ??= _normalizeMac(c.macAddress);
          }
        }
        if (_selectedMac.isEmpty && _availableClients.isNotEmpty) {
          final first = _availableClients.first;
          _selectedMac = _normalizeMac(first.macAddress);
          _macController.text = _selectedMac;
        }
      });
      if (_isValidMac(_selectedMac)) {
        _populateCurrentIfaceStates(_selectedMac);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLoadingClients = false; });
    }
  }

  String _normalizeMac(String mac) {
    return mac.trim().toUpperCase().replaceAll('-', ':');
  }

  bool _isValidMac(String mac) {
    final norm = _normalizeMac(mac);
    return RegExp(r'^([0-9A-FA-F]{2}:){5}[0-9A-FA-F]{2}$').hasMatch(norm);
  }

  void _onClientSelected(Client? client) {
    if (client == null) return;
    final norm = _normalizeMac(client.macAddress);
    setState(() {
      _selectedMac = norm;
      _macController.text = norm;
    });
    _populateCurrentIfaceStates(norm);
  }

  void _onManualMacChanged(String val) {
    final norm = _normalizeMac(val);
    setState(() {
      _selectedMac = norm;
    });
    if (_isValidMac(norm)) {
      _populateCurrentIfaceStates(norm);
    }
  }

  Map<String, dynamic>? _findSecMap(dynamic rawUci, String secName) {
    if (rawUci == null) return null;

    if (rawUci is Map<String, dynamic>) {
      if (rawUci.containsKey(secName) && rawUci[secName] is Map<String, dynamic>) {
        return rawUci[secName] as Map<String, dynamic>;
      }

      if (rawUci.containsKey('values') && rawUci['values'] is Map<String, dynamic>) {
        final valuesMap = rawUci['values'] as Map<String, dynamic>;
        if (valuesMap.containsKey(secName) && valuesMap[secName] is Map<String, dynamic>) {
          return valuesMap[secName] as Map<String, dynamic>;
        }
      }

      for (final entry in rawUci.entries) {
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          if (entry.key == secName) return val;
          if (val['.name'] == secName || val['section'] == secName) return val;
          if (val['interfaces'] is List) {
            for (final ifc in val['interfaces']) {
              if (ifc is Map<String, dynamic>) {
                final cfg = ifc['config'] as Map<String, dynamic>?;
                if (ifc['section'] == secName || ifc['.name'] == secName || cfg?['.name'] == secName) {
                  return cfg ?? ifc;
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  void _populateCurrentIfaceStates(String targetMac) {
    final normTarget = _normalizeMac(targetMac);
    if (!_isValidMac(normTarget)) return;

    final appState = ref.read(appStateProvider);
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    final rawUci = appState.dashboardData?['uciWirelessConfig'] ?? appState.dashboardData?['wireless'];
    final newAllows = <String, bool>{};

    for (final radio in overview.radios) {
      for (final iface in radio.interfaces) {
        final secName = iface.sectionName;
        List<String> maclist = [];
        String filterMode = 'disable';

        final secMap = _findSecMap(rawUci, secName);
        if (secMap != null) {
          filterMode = secMap['macfilter']?.toString().toLowerCase() ?? 'disable';
          final rawList = secMap['maclist'];
          if (rawList is List) {
            maclist = rawList.map((e) => _normalizeMac(e.toString())).toList();
          } else if (rawList is String) {
            maclist = rawList.split(RegExp(r'\s+')).map((e) => _normalizeMac(e)).toList();
          }
        }

        final inAllowList = (filterMode == 'allow') && maclist.contains(normTarget);
        newAllows[secName] = inAllowList;
      }
    }

    setState(() {
      _selectedIfaceAllows.clear();
      _selectedIfaceAllows.addAll(newAllows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = ref.watch(appStateProvider);
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    return Scaffold(
      appBar: const LuciAppBar(title: 'Wi-Fi Access Control'),
      body: Column(
        children: [
          if (appState.isAccessControlPendingConfirmation)
            _buildAutoRevertCountdownBanner(context, appState),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 16),
                  _buildDeviceSelectionCard(context),
                  const SizedBox(height: 16),
                  if (_isValidMac(_selectedMac)) ...[
                    _buildAccessControlMatrix(context, overview, appState),
                    const SizedBox(height: 24),
                    _buildApplyButton(context, overview, appState),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.touch_app_rounded, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'Select a device or enter a valid MAC address above to configure Wi-Fi access rules.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRevertCountdownBanner(BuildContext context, AppState appState) {
    final seconds = appState.accessControlCountdownSeconds;
    return Container(
      width: double.infinity,
      color: Colors.amber.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Wi-Fi Access Control updated. Confirm changes working within ${seconds}s or auto-reverting.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: () async {
                  await appState.revertWifiAccessControlChanges(context: context);
                },
                child: const Text('Revert Now'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  await appState.confirmWifiAccessControlChanges();
                },
                child: const Text('Confirm & Keep'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.security_rounded, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAC Access Control (LuCI Filter)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Configure per-SSID MAC allow lists. Only devices present on an SSID\'s allow-list will be permitted to connect.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelectionCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Select Target Device', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_isLoadingClients)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<Client>(
                decoration: InputDecoration(
                  labelText: 'Connected Clients',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.devices_rounded),
                ),
                isExpanded: true,
                items: _availableClients.map((c) {
                  return DropdownMenuItem<Client>(
                    value: c,
                    child: Text(
                      '${c.displayName} (${c.macAddress})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onClientSelected,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('OR Manual Entry', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _macController,
              onChanged: _onManualMacChanged,
              decoration: InputDecoration(
                labelText: 'MAC Address (XX:XX:XX:XX:XX:XX)',
                hintText: 'AA:BB:CC:11:22:33',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.fingerprint_rounded),
                errorText: (_selectedMac.isNotEmpty && !_isValidMac(_selectedMac))
                    ? 'Enter valid MAC address format (e.g. AA:BB:CC:11:22:33)'
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlMatrix(BuildContext context, WirelessOverview overview, AppState appState) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Wi-Fi Allow Mode Rules for $_selectedMac',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Check SSIDs where this device should be explicitly allowed to connect.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...overview.radios.map((radio) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${radio.name.toUpperCase()} (${radio.bandLabel})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...radio.interfaces.map((iface) {
                    final secName = iface.sectionName;
                    final isAllowed = _selectedIfaceAllows[secName] ?? false;

                    final rawUci = appState.dashboardData?['uciWirelessConfig'] ?? appState.dashboardData?['wireless'];
                    final secMap = _findSecMap(rawUci, secName);
                    final currentFilterMode = secMap?['macfilter']?.toString().toLowerCase() ?? 'disable';
                    List<String> currentMacList = [];
                    final rawList = secMap?['maclist'];
                    if (rawList is List) {
                      currentMacList = rawList.map((e) => _normalizeMac(e.toString())).toList();
                    } else if (rawList is String) {
                      currentMacList = rawList.split(RegExp(r'\s+')).map((e) => _normalizeMac(e)).toList();
                    }
                    final isDeniedHere = (currentFilterMode == 'deny') && currentMacList.contains(_normalizeMac(_selectedMac));

                    String modeSubtitle;
                    if (isAllowed) {
                      modeSubtitle = 'Filter mode: Allow (Permitted)';
                    } else if (isDeniedHere) {
                      modeSubtitle = 'Filter mode: Deny (Blocked on this SSID)';
                    } else if (currentFilterMode == 'allow') {
                      modeSubtitle = 'Filter mode: Allow (Not in allow list)';
                    } else if (currentFilterMode == 'deny') {
                      modeSubtitle = 'Filter mode: Deny (Not in deny list)';
                    } else {
                      modeSubtitle = 'Filter mode: Disabled/Open';
                    }

                    return CheckboxListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: Text(
                        iface.ssid,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Interface: ${iface.ifName} ($secName) • $modeSubtitle',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: isAllowed,
                      onChanged: (val) {
                        setState(() {
                          _selectedIfaceAllows[secName] = val ?? false;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton(BuildContext context, WirelessOverview overview, AppState appState) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _handleApplyChanges(context, overview, appState),
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Apply Access Control Rules', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _handleApplyChanges(BuildContext context, WirelessOverview overview, AppState appState) async {
    final targetMac = _normalizeMac(_selectedMac);
    if (!_isValidMac(targetMac)) return;

    final rawUci = appState.dashboardData?['uciWirelessConfig'] ?? appState.dashboardData?['wireless'];

    // Construct prior snapshots & new payload map
    final priorMaclistSnapshot = <String, List<String>>{};
    final priorMacfilterSnapshot = <String, String>{};

    final newMaclistByIface = <String, List<String>>{};
    final newMacfilterByIface = <String, String>{};

    final affectedSsids = <String>[];
    bool phoneLockoutRisk = false;

    for (final radio in overview.radios) {
      for (final iface in radio.interfaces) {
        final secName = iface.sectionName;
        List<String> currentMaclist = [];
        String currentFilterMode = 'disable';

        if (rawUci is Map<String, dynamic> && rawUci.containsKey(secName)) {
          final secMap = rawUci[secName];
          if (secMap is Map<String, dynamic>) {
            currentFilterMode = secMap['macfilter']?.toString() ?? 'disable';
            final rawList = secMap['maclist'];
            if (rawList is List) {
              currentMaclist = rawList.map((e) => _normalizeMac(e.toString())).toList();
            } else if (rawList is String) {
              currentMaclist = rawList.split(RegExp(r'\s+')).map((e) => _normalizeMac(e)).toList();
            }
          }
        }

        priorMaclistSnapshot[secName] = List.from(currentMaclist);
        priorMacfilterSnapshot[secName] = currentFilterMode;

        final shouldAllow = _selectedIfaceAllows[secName] ?? false;
        final updatedMaclist = List<String>.from(currentMaclist);

        if (shouldAllow) {
          if (!updatedMaclist.contains(targetMac)) {
            updatedMaclist.add(targetMac);
          }
          newMacfilterByIface[secName] = 'allow';
          newMaclistByIface[secName] = updatedMaclist;
          affectedSsids.add('${iface.ssid} (${radio.name})');

          // Check phone lockout risk: If phone MAC is known and NOT in updated maclist for an allowed SSID
          if (_phoneMac != null && _phoneMac!.isNotEmpty && !updatedMaclist.contains(_phoneMac)) {
            phoneLockoutRisk = true;
          }
        } else {
          updatedMaclist.remove(targetMac);
          newMaclistByIface[secName] = updatedMaclist;
          // If no MACs left in list, set filter back to disable
          if (updatedMaclist.isEmpty) {
            newMacfilterByIface[secName] = 'disable';
          } else {
            newMacfilterByIface[secName] = 'allow';
          }
        }
      }
    }

    // Phone Lockout Warning Dialog
    if (phoneLockoutRisk && context.mounted) {
      final addPhone = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
          title: const Text('Device Lockout Warning'),
          content: Text(
            'You have not added this device (${_phoneMac ?? "current phone"}) to the allow-list for affected SSIDs. Enabling this filter may disconnect you from this network.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Proceed Without Phone'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Add My Current Device'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (addPhone == true && _phoneMac != null) {
        for (final secName in newMaclistByIface.keys) {
          if (newMacfilterByIface[secName] == 'allow') {
            if (!newMaclistByIface[secName]!.contains(_phoneMac!)) {
              newMaclistByIface[secName]!.add(_phoneMac!);
            }
          }
        }
      }
    }

    // Final Confirmation Dialog
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.verified_user_rounded, color: Colors.blue, size: 36),
        title: const Text('Confirm Wi-Fi Access Rules'),
        content: Text(
          'Updating Wi-Fi Access Control for $targetMac on SSIDs:\n\n'
          '${affectedSsids.isNotEmpty ? affectedSsids.join('\n') : "All (Disabled)"}\n\n'
          'Note: This affects $targetMac specifically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applying Wi-Fi Access Control changes...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await appState.applyWifiAccessControl(
        newMaclistByIface: newMaclistByIface,
        newMacfilterByIface: newMacfilterByIface,
        priorMaclistSnapshot: priorMaclistSnapshot,
        priorMacfilterSnapshot: priorMacfilterSnapshot,
        context: context,
      );

      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Control applied. Revert timer started (25s).'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to apply Wi-Fi Access Control rules.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
