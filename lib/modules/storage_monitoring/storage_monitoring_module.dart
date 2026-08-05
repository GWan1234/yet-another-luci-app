import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/storage_monitoring_screen.dart';
import 'widgets/storage_monitoring_card.dart';

class StorageMonitoringModule extends LuciModule {
  @override
  String get id => 'storage_monitoring';

  @override
  String get name => 'Storage Monitoring';

  @override
  String get description => 'Filesystem usage overview, mounted devices, overlay FS, and flash memory status';

  @override
  IconData get icon => Icons.sd_storage_outlined;

  @override
  IconData get selectedIcon => Icons.sd_storage;

  @override
  LuciModuleCategory get category => LuciModuleCategory.monitoring;

  @override
  int get priority => 16;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const StorageMonitoringScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return const StorageMonitoringCard();
  }
}
