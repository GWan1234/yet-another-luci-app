import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/package_manager_screen.dart';
import 'widgets/package_manager_card.dart';

class PackageManagerModule extends LuciModule {
  @override
  String get id => 'package_manager';

  @override
  String get name => 'OPKG/APK Package Manager';

  @override
  String get description => 'OPKG package manager, repository updates, and dynamic LuCI application discovery';

  @override
  IconData get icon => Icons.inventory_2_outlined;

  @override
  IconData get selectedIcon => Icons.inventory_2;

  @override
  LuciModuleCategory get category => LuciModuleCategory.system;

  @override
  int get priority => 60;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const PackageManagerScreen();
  }

  @override
  Widget? buildDashboardWidget(BuildContext context) {
    return null;
  }
}
