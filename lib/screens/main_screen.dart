// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:yet_another_luci_app/screens/dashboard_screen.dart';
import 'package:yet_another_luci_app/screens/clients_screen.dart';
import 'package:yet_another_luci_app/screens/interfaces_screen.dart';
import 'package:yet_another_luci_app/screens/more_screen.dart';
import 'package:yet_another_luci_app/modules/wireless_management/screens/wireless_management_screen.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/widgets/scroll_jitter_guard.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int? initialTab;
  final String? interfaceToScroll;

  const MainScreen({super.key, this.initialTab, this.interfaceToScroll});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  String? _currentInterfaceToScroll;
  final Set<int> _activatedTabs = {0};

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _selectedIndex = widget.initialTab!.clamp(0, 4);
    }
    _activatedTabs.add(_selectedIndex);
    _currentInterfaceToScroll = widget.interfaceToScroll;
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.interfaceToScroll != oldWidget.interfaceToScroll) {
      _currentInterfaceToScroll = widget.interfaceToScroll;
    }

    if (widget.initialTab != oldWidget.initialTab &&
        widget.initialTab != null) {
      _selectedIndex = widget.initialTab!.clamp(0, 4);
      _activatedTabs.add(_selectedIndex);
    }
  }

  void _clearInterfaceToScroll() {
    if (_currentInterfaceToScroll != null) {
      setState(() {
        _currentInterfaceToScroll = null;
      });
    }
  }

  void _onItemTapped(int index) {
    FocusScope.of(context).unfocus();
    final safeIndex = index.clamp(0, 4);
    if (_selectedIndex == safeIndex) return;
    setState(() {
      _selectedIndex = safeIndex;
      _activatedTabs.add(safeIndex);
    });

    if (_selectedIndex != 1 && _currentInterfaceToScroll != null) {
      _clearInterfaceToScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    if (appState.requestedTab != null &&
        appState.requestedTab != _selectedIndex) {
      final safeRequestedTab = appState.requestedTab!.clamp(0, 4);
      final requestedInterface = appState.requestedInterfaceToScroll;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).unfocus();
        setState(() {
          _selectedIndex = safeRequestedTab;
          _activatedTabs.add(safeRequestedTab);
          if (requestedInterface != null) {
            _currentInterfaceToScroll = requestedInterface;
          }
        });
        appState.requestedTab = null;
        appState.requestedInterfaceToScroll = null;
      });
    }

    final isRebooting = appState.isRebooting;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ScrollJitterGuard(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _activatedTabs.contains(0) ? const DashboardScreen() : const SizedBox.shrink(),
            _activatedTabs.contains(1)
                ? InterfacesScreen(
                    scrollToInterface: _currentInterfaceToScroll,
                    onScrollComplete: _clearInterfaceToScroll,
                  )
                : const SizedBox.shrink(),
            _activatedTabs.contains(2) ? const ClientsScreen() : const SizedBox.shrink(),
            _activatedTabs.contains(3) ? const WirelessManagementScreen() : const SizedBox.shrink(),
            _activatedTabs.contains(4) ? const MoreScreen() : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Flat Matt Bottom Bar Container
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Left Wing (Interfaces & Clients)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            index: 1,
                            label: 'Interfaces',
                            icon: Icons.lan_outlined,
                            selectedIcon: Icons.lan,
                            isRebooting: isRebooting,
                          ),
                          _buildNavItem(
                            index: 2,
                            label: 'Clients',
                            icon: Icons.people_outline,
                            selectedIcon: Icons.people,
                            isRebooting: isRebooting,
                            badgeCount: appState.clients.where((c) => c.isConnected).length,
                          ),
                        ],
                      ),
                    ),
                    // Center Clearance Spacer for Elevated Dashboard Badge
                    const SizedBox(width: 64),
                    // Right Wing (Wireless & More)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            index: 3,
                            label: 'Wireless',
                            icon: Icons.wifi_outlined,
                            selectedIcon: Icons.wifi,
                            isRebooting: isRebooting,
                          ),
                          _buildNavItem(
                            index: 4,
                            label: 'More',
                            icon: Icons.more_horiz_outlined,
                            selectedIcon: Icons.more_horiz,
                            isRebooting: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Solid Flat Matt Circular Center Dashboard Badge Button (Index 0)
              Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: GestureDetector(
                    onTap: () {
                      if (isRebooting) return;
                      _onItemTapped(0);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedIndex == 0
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHigh,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _selectedIndex == 0
                                ? Icons.dashboard_rounded
                                : Icons.dashboard_outlined,
                            color: _selectedIndex == 0
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedIndex == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedIndex == 0
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required bool isRebooting,
    int? badgeCount,
  }) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    final color = isRebooting
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : (isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant);

    final semanticText = '$label, tab ${index + 1} of 5. ${isSelected ? "Currently active tab." : "Double tap to switch to $label."}';

    return Semantics(
      selected: isSelected,
      button: true,
      label: semanticText,
      child: InkWell(
        onTap: isRebooting ? null : () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    color: color,
                    size: 24,
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Align(
                      alignment: Alignment.topRight,
                      child: Transform.translate(
                        offset: const Offset(8, -4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primary : colorScheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
