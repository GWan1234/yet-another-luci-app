// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:yet_another_luci_app/screens/login_screen.dart';
import 'package:yet_another_luci_app/screens/settings_screen.dart';
import 'package:yet_another_luci_app/widgets/luci_app_bar.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:yet_another_luci_app/design/luci_design_system.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/utils/http_client_manager.dart';
import 'package:yet_another_luci_app/state/app_state.dart';
import 'package:yet_another_luci_app/modules/core/luci_module_registry.dart';
import 'package:yet_another_luci_app/screens/paywall_screen.dart';
import 'package:yet_another_luci_app/widgets/theme_router_logo.dart';

class _MoreScreenSection extends StatelessWidget {
  final List<Widget> tiles;

  const _MoreScreenSection({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: LuciSpacing.md,
        vertical: LuciSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
      ),
      child: Column(
        children: ListTile.divideTiles(context: context, tiles: tiles).toList(),
      ),
    );
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    // Do not use context here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = ref.read(appStateProvider);
    _appState!.onRouterBackOnline = _showRouterBackOnlineMessage;
  }

  @override
  void dispose() {
    // Clear the callback before calling super.dispose()
    _appState?.onRouterBackOnline = null;
    super.dispose();
  }

  void _showRouterBackOnlineMessage() {
    if (mounted) {
      context.showToastSuccess(
        'Router Online',
        subtitle: 'Router is back online, reconnecting…',
        actionKey: 'router_reboot',
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final appState = ref.read(appStateProvider);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                await appState.logout();
                // Clear all accepted certificates on logout
                await HttpClientManager().clearAcceptedCertificates();
                if (context.mounted) {
                  await Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRebootDialog(BuildContext context) async {
    final appState = ref.read(appStateProvider);
    final routerName = appState.selectedRouter?.lastKnownHostname ?? appState.selectedRouter?.ipAddress ?? 'the router';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reboot Router?'),
          content: Text(
            'This will reboot $routerName. The app will lose connection until it comes back online. Continue?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('Reboot'),
              onPressed: () async {
                final parentContext = Navigator.of(context).context;
                Navigator.of(context).pop();
                const actionKey = 'router_reboot';
                if (parentContext.mounted) {
                  parentContext.showToastLoading(
                    'Rebooting Router',
                    subtitle: 'Router is rebooting... The app will automatically reconnect once online.',
                    actionKey: actionKey,
                    timeout: const Duration(seconds: 45),
                  );
                }
                final success = await appState.reboot(context: parentContext.mounted ? parentContext : null);
                if (parentContext.mounted && !success) {
                  parentContext.showToastError(
                    'Reboot Failed',
                    subtitle: 'Failed to send reboot command to router.',
                    actionKey: actionKey,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final theme = Theme.of(context);

    unawaited(
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const ThemeRouterLogo(width: 28, height: 28, showShadow: false),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Yet Another LuCI App',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Version ${info.version}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A modern, high-performance OpenWrt router management mobile application.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await launchUrlString(
                          AppConfig.githubRepositoryUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.code_rounded, size: 16),
                      label: const Text('GitHub'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final Uri mailUri = Uri(
                          scheme: 'mailto',
                          path: AppConfig.supportEmail,
                          queryParameters: {'subject': 'Yet Another LuCI App Support Request'},
                        );
                        await launchUrlString(
                          mailUri.toString(),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('Support'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LuciAppBar(title: 'More'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LuciSectionHeader('Device Management'),
            Builder(
              builder: (context) {
                final isRebooting = ref.watch(appStateProvider).isRebooting;
                return _MoreScreenSection(
                  tiles: [
                    _buildMoreTile(
                      context,
                      icon: Icons.restart_alt,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: 'Reboot Router',
                      subtitle: 'Perform a system restart',
                      onTap: isRebooting
                          ? null
                          : () => _showRebootDialog(context),
                      enabled: !isRebooting,
                      showSpinner: isRebooting,
                    ),
                  ],
                );
              },
            ),
            const LuciSectionHeader('Management Modules'),
            _MoreScreenSection(
              tiles: LuciModuleRegistry.instance.enabledModules.where((m) => !m.showInBottomNav).map((module) {
                return _buildMoreTile(
                  context,
                  icon: module.icon,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: module.name,
                  subtitle: module.description,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => module.buildScreen(context),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            const LuciSectionHeader('Application'),
            _MoreScreenSection(
              tiles: [

                if (AppConfig.isSupportDevEnabled)
                  _buildMoreTile(
                    context,
                    icon: Icons.favorite,
                    iconColor: Colors.pink.shade400,
                    title: 'Support the Developer',
                    subtitle: 'Help keep this project alive',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PaywallScreen(),
                        ),
                      );
                    },
                  ),
                _buildMoreTile(
                  context,
                  icon: Icons.settings_outlined,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: 'Settings',
                  subtitle: 'Configure app preferences',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildMoreTile(
                  context,
                  icon: Icons.info_outline,
                  iconColor: Theme.of(context).colorScheme.secondary,
                  title: 'About',
                  subtitle: 'App version and information',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildMoreTile(
                  context,
                  icon: Icons.logout,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: 'Logout',
                  subtitle: 'End your session and sign out',
                  titleColor: Theme.of(context).colorScheme.error,
                  subtitleColor: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.7),
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    Color? titleColor,
    Color? subtitleColor,
    bool showSpinner = false,
  }) {
    final theme = Theme.of(context);
    // Persistent spinning icon using AnimationController
    Widget spinningIconWidget = Icon(
      icon,
      color: iconColor,
      size: 24,
      semanticLabel: title,
    );
    if (showSpinner) {
      spinningIconWidget = _SpinningIcon(
        icon: icon,
        color: iconColor,
        label: title,
      );
    }
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(10),
          child: spinningIconWidget,
        ),
        title: Text(
          title,
          style: titleColor != null
              ? LuciTextStyles.cardTitle(context).copyWith(color: titleColor)
              : LuciTextStyles.cardTitle(context),
          semanticsLabel: title,
        ),
        subtitle: Text(
          subtitle,
          style: subtitleColor != null
              ? LuciTextStyles.cardSubtitle(
                  context,
                ).copyWith(color: subtitleColor)
              : LuciTextStyles.cardSubtitle(context),
          semanticsLabel: subtitle,
        ),
        enabled: enabled,
        onTap: enabled ? onTap : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LuciSpacing.lg,
          vertical: 10,
        ),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        minVerticalPadding: LuciSpacing.md,
        minLeadingWidth: 0,
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}

// Persistent spinning icon widget
class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SpinningIcon({
    required this.icon,
    required this.color,
    required this.label,
  });
  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 6.28319, // 2 * pi
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
            semanticLabel: widget.label,
          ),
        );
      },
    );
  }
}
