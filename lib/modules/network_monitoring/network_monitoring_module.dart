// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/network_monitoring_screen.dart';
import 'widgets/network_monitoring_card.dart';

class NetworkMonitoringModule extends LuciModule {
  @override
  String get id => 'network_monitoring';

  @override
  String get name => 'Network Monitoring';

  @override
  String get description => 'Network interfaces list, tabular RX/TX throughput metrics, IPv4/IPv6 addresses, and Gateway status';

  @override
  IconData get icon => Icons.hub_outlined;

  @override
  IconData get selectedIcon => Icons.hub;

  @override
  LuciModuleCategory get category => LuciModuleCategory.monitoring;

  @override
  int get priority => 17;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const NetworkMonitoringScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return const NetworkMonitoringCard();
  }
}
