import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/charting_screen.dart';

class ChartingModule extends LuciModule {
  @override
  String get id => 'charting';

  @override
  String get name => 'Real-Time Charts';

  @override
  String get description => 'Dynamic real-time charting system for CPU, RAM, and Network RX/TX throughput';

  @override
  IconData get icon => Icons.show_chart_outlined;

  @override
  IconData get selectedIcon => Icons.show_chart;

  @override
  LuciModuleCategory get category => LuciModuleCategory.monitoring;

  @override
  int get priority => 18;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const ChartingScreen();
  }
}
