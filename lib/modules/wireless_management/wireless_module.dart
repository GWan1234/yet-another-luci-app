// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/wireless_management_screen.dart';

class WirelessManagementModule extends LuciModule {
  @override
  String get id => 'wireless_management';

  @override
  String get name => 'Wireless Management';

  @override
  String get description => 'Radios (radio0, radio1), associated SSIDs, operating mode, channels, TX power, security and connected stations';

  @override
  IconData get icon => Icons.wifi_outlined;

  @override
  IconData get selectedIcon => Icons.wifi;

  @override
  LuciModuleCategory get category => LuciModuleCategory.wireless;

  @override
  int get priority => 25;

  @override
  bool get showInBottomNav => true;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const WirelessManagementScreen();
  }

  @override
  Widget buildDashboardWidget(BuildContext context) {
    return const SizedBox.shrink();
  }
}
