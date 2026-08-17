// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/dhcp_dns_screen.dart';
import 'widgets/dhcp_dns_card.dart';

class DhcpDnsModule extends LuciModule {
  @override
  String get id => 'dhcp_dns';

  @override
  String get name => 'DHCP & DNS';

  @override
  String get description => 'Active DHCP leases, static IP reservations, Dnsmasq configuration, and upstream DNS forwarders';

  @override
  IconData get icon => Icons.dns_outlined;

  @override
  IconData get selectedIcon => Icons.dns;

  @override
  LuciModuleCategory get category => LuciModuleCategory.network;

  @override
  int get priority => 35;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const DhcpDnsScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return const DhcpDnsCard();
  }
}
