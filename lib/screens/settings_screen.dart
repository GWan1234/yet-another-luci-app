import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/providers/entitlement_provider.dart';
import 'package:luci_mobile/screens/paywall_screen.dart';
import 'package:luci_mobile/widgets/banner_ad_widget.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/screens/dashboard_settings_list_screen.dart';
import 'package:luci_mobile/services/update_checker_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showReviewerModeResetDialog(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appStateProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Reviewer Mode?'),
        content: const Text(
          'This will disable reviewer mode and return to normal authentication. '
          'You will need to log in with real router credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await appState.setReviewerMode(false);
              appState.logout();
              if (context.mounted) {
                unawaited(
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false),
                );
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const LuciAppBar(title: 'Settings', showBack: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Builder(
            builder: (context) {
              final appState = ref.watch(appStateProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                    child: Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: appState.themeMode,
                    onChanged: (mode) {
                      if (mode != null) appState.setThemeMode(mode);
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('System Default'),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Light'),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Dark'),
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.dashboard_customize,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Customize Dashboard',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Configure interface visibility and throughput monitoring'),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const DashboardSettingsListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Router Diagnostics & Surface',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Re-detect Router Capabilities',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        appState.capabilities != null
                            ? 'Engine: ${appState.capabilities!.packageEngine.name.toUpperCase()} • Firewall: ${appState.capabilities!.firewallBackend.name.toUpperCase()} • Network: ${appState.capabilities!.networkModel.name.toUpperCase()}'
                            : 'Probe active router ubus objects & features',
                      ),
                      trailing: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () async {
                        await appState.redetectCapabilities();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Router capabilities re-detected & cached successfully!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  if (AppConfig.isMonetizationEnabled && AppConfig.isSupportDevEnabled) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Subscription',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Manage Subscription',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Consumer(
                          builder: (context, ref, _) {
                            final entitlement = ref.watch(entitlementProvider);
                            return Text('Current Tier: ${entitlement.tier.displayName}');
                          },
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PaywallScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (AppConfig.isCommunityFlavor) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'App Updates',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.system_update_rounded,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Check for Updates',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Check for new releases on GitHub'),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          UpdateCheckerService.checkForUpdates(context);
                        },
                      ),
                    ),
                  ],
                  if (appState.reviewerModeEnabled) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Reviewer Mode',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                      ),
                      title: Row(
                        children: [
                          const Text('Reviewer Mode Active'),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Bypasses live router connection and populates mock metrics for testing and review.',
                            child: Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Mock data is being used for demonstration',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: FilledButton.icon(
                        onPressed: () =>
                            _showReviewerModeResetDialog(context, ref),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Exit Reviewer Mode'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const BannerAdWidget(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
