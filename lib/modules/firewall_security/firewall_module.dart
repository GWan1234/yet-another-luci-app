// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/firewall_security_screen.dart';
import 'widgets/firewall_security_card.dart';

class FirewallSecurityModule extends LuciModule {
  @override
  String get id => 'firewall_security';

  @override
  String get name => 'Firewall & Security';

  @override
  String get description => 'Firewall Zones (LAN/WAN), forwarding rules, default policies, port redirects, and custom security rules';

  @override
  IconData get icon => Icons.shield_outlined;

  @override
  IconData get selectedIcon => Icons.shield;

  @override
  LuciModuleCategory get category => LuciModuleCategory.security;

  @override
  int get priority => 40;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const FirewallSecurityScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return const FirewallSecurityCard();
  }
}
