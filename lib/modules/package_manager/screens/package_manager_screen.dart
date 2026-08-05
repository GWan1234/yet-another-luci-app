import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../models/package_info.dart';

class PackageManagerScreen extends ConsumerStatefulWidget {
  const PackageManagerScreen({super.key});

  @override
  ConsumerState<PackageManagerScreen> createState() => _PackageManagerScreenState();
}

class _PackageManagerScreenState extends ConsumerState<PackageManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<OpenWrtPackage>? _upgradablePackages;
  bool _isCheckingUpgrades = false;
  bool _isUpgradingAll = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUpgrades() async {
    setState(() {
      _isCheckingUpgrades = true;
    });
    try {
      final list = await ref.read(appStateProvider).fetchUpgradablePackages();
      if (mounted) {
        setState(() {
          _upgradablePackages = list;
          _isCheckingUpgrades = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              list.isEmpty
                  ? 'All installed packages are up to date.'
                  : 'Found ${list.length} upgradable package(s).',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingUpgrades = false;
        });
      }
    }
  }

  Future<void> _upgradeAllPackages() async {
    if (_upgradablePackages == null || _upgradablePackages!.isEmpty) return;
    setState(() {
      _isUpgradingAll = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upgrading all packages... This may take a while.')),
    );
    final success = await ref.read(appStateProvider).managePackage(
          packageName: '',
          action: 'upgrade',
        );
    if (mounted) {
      setState(() {
        _isUpgradingAll = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'System package upgrade completed successfully.'
                : 'Failed to complete system package upgrade.',
          ),
        ),
      );
      await _checkUpgrades();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final overview = PackageManagerOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    final installedFiltered = overview.installedPackages.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.description.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(overview.managerTitle),
        actions: [
          IconButton(
            icon: _isCheckingUpgrades
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Check for Package Upgrades',
            onPressed: _isCheckingUpgrades ? null : _checkUpgrades,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(appStateProvider).fetchDashboardData();
          if (_upgradablePackages != null) {
            await _checkUpgrades();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Warning Alert Card per prompt request
            Card(
              elevation: 0,
              color: Colors.amber.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Package Recommendation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upgrading packages directly on OpenWrt routers is not recommended as it may cause system instability, break dependencies, or fill flash storage.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search packages (e.g. luci-app, wireguard)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Upgrade Action Banner
            if (_upgradablePackages == null) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Icon(Icons.system_update_alt_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap "Check Upgrades" to query available software updates from router repository.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isCheckingUpgrades ? null : _checkUpgrades,
                        icon: _isCheckingUpgrades
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search, size: 16),
                        label: Text(_isCheckingUpgrades ? 'Checking...' : 'Check Upgrades'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upgradable Packages Section (Shown only after checking/refreshing)
            if (_upgradablePackages != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(
                    context,
                    'Upgradable Packages (${_upgradablePackages!.length})',
                    Icons.system_update_outlined,
                  ),
                  if (_upgradablePackages!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isUpgradingAll ? null : _upgradeAllPackages,
                      icon: const Icon(Icons.arrow_upward, size: 14),
                      label: Text(_isUpgradingAll ? 'Upgrading...' : 'Upgrade All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_upgradablePackages!.isEmpty)
                Card(
                  elevation: 0,
                  color: Colors.green.withValues(alpha: 0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'All router packages are completely up to date.',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._upgradablePackages!.map((p) => _buildPackageCard(context, p, isInstalled: true, isUpgradable: true)),
              const SizedBox(height: 20),
            ],

            // Installed Packages Section directly fetched from router
            _buildSectionHeader(
              context,
              'Installed Packages (${installedFiltered.length})',
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 8),
            ...installedFiltered.map((p) => _buildPackageCard(context, p, isInstalled: true)),
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

  Widget _buildPackageCard(
    BuildContext context,
    OpenWrtPackage pkg, {
    required bool isInstalled,
    bool isUpgradable = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUpgradable
              ? Colors.orange.withValues(alpha: 0.15)
              : (isInstalled ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15)),
          child: Icon(
            isUpgradable ? Icons.arrow_upward : (isInstalled ? Icons.check : Icons.download),
            color: isUpgradable ? Colors.orange.shade800 : (isInstalled ? Colors.green : Colors.blue),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pkg.fileExtension,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${isUpgradable ? "Version: " : "v"}${pkg.version} • ${pkg.description}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton(
          onPressed: () async {
            final action = isUpgradable ? 'upgrade' : (isInstalled ? 'remove' : 'install');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${isUpgradable ? "Upgrading" : (isInstalled ? "Removing" : "Installing")} ${pkg.name}...')),
            );
            final success = await ref.read(appStateProvider).managePackage(
                  packageName: pkg.name,
                  action: action,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Successfully ${isUpgradable ? "upgraded" : (isInstalled ? "removed" : "installed")} ${pkg.name}'
                        : 'Failed to $action ${pkg.name}',
                  ),
                ),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: isUpgradable ? Colors.orange.shade800 : (isInstalled ? Colors.red : Colors.blue),
            ),
          ),
          child: Text(
            isUpgradable ? 'Upgrade' : (isInstalled ? 'Remove' : 'Install'),
            style: TextStyle(
              color: isUpgradable ? Colors.orange.shade800 : (isInstalled ? Colors.red : Colors.blue),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
