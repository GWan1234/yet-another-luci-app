// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/services_system_screen.dart';
import 'widgets/services_system_card.dart';

class ServicesSystemModule extends LuciModule {
  @override
  String get id => 'services_system';

  @override
  String get name => 'Services & System';

  @override
  String get description => 'Procd system services running status, service controls, startup init scripts, and system cron jobs';

  @override
  IconData get icon => Icons.settings_applications_outlined;

  @override
  IconData get selectedIcon => Icons.settings_applications;

  @override
  LuciModuleCategory get category => LuciModuleCategory.system;

  @override
  int get priority => 50;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const ServicesSystemScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return const ServicesSystemCard();
  }
}
