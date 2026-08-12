import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/system_monitoring_screen.dart';

class SystemMonitoringModule extends LuciModule {
  @override
  String get id => 'system_monitoring';

  @override
  String get name => 'System Monitoring';

  @override
  String get description => 'Real-time CPU, RAM memory, Load Average, and system Uptime stats';

  @override
  IconData get icon => Icons.monitor_heart_outlined;

  @override
  IconData get selectedIcon => Icons.monitor_heart;

  @override
  LuciModuleCategory get category => LuciModuleCategory.monitoring;

  @override
  int get priority => 15;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const SystemMonitoringScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return null;
  }
}
