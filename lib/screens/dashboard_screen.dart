// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/widgets/luci_animation_system.dart';
import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/modules/core/luci_module_registry.dart';
import 'package:luci_mobile/modules/wireless_management/models/wireless_info.dart';
import 'package:luci_mobile/utils/release_utils.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/models/client.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _wanScrollController = ScrollController();
  bool _dismissedRpcWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _wanScrollController.dispose();
    super.dispose();
  }

  String _formatUptime(int seconds) {
    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  String _formatCpuLoad(List<dynamic> load) {
    if (load.isEmpty) return 'N/A';
    // Use the first value as the main CPU load
    final percent = ((load[0] / 65536) * 100).clamp(0, 100);
    return '${percent.toStringAsFixed(0)}%';
  }



  ({Color background, Color foreground}) _channelColors(String channel) {
    switch (channel) {
      case 'snapshot':
        return (
          background: Colors.orange.withValues(alpha: 0.15),
          foreground: Colors.orange.shade800,
        );
      case 'beta':
        return (
          background: Colors.blue.withValues(alpha: 0.15),
          foreground: Colors.blue.shade800,
        );
      case 'rc':
        return (
          background: Colors.purple.withValues(alpha: 0.15),
          foreground: Colors.purple.shade800,
        );
      case 'testing':
        return (
          background: Colors.amber.withValues(alpha: 0.18),
          foreground: Colors.amber.shade900,
        );
      default:
        return (
          background: Colors.green.withValues(alpha: 0.15),
          foreground: Colors.green.shade800,
        );
    }
  }

  Widget _buildDeviceInfoCard(AppState appState) {
    final boardInfo =
        appState.dashboardData?['boardInfo'] as Map<String, dynamic>?;
    final model = boardInfo?['model']?.toString() ??
        (appState.capabilities?.boardName.isNotEmpty == true
            ? appState.capabilities!.boardName
            : 'N/A');
    final release = boardInfo?['release'] as Map<String, dynamic>?;

    final releaseInfo = deriveDistributionInfo(
      release ?? appState.capabilities?.releaseVersion,
      model: model,
    );

    final versionDisplay = releaseInfo.version != 'N/A'
        ? releaseInfo.version
        : (release?['version']?.toString() ?? 'N/A');
    final channelLabel = releaseInfo.channel.toUpperCase();
    final channelColors = _channelColors(releaseInfo.channel);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Model', style: labelStyle),
                  const SizedBox(height: 4),
                  Text(
                    model,
                    style: valueStyle,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(releaseInfo.distributionName, style: labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          versionDisplay,
                          style: valueStyle,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: channelColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          channelLabel,
                          style: TextStyle(
                            color: channelColors.foreground,
                            fontWeight: FontWeight.bold,
                            fontSize: Theme.of(
                              context,
                            ).textTheme.bodySmall?.fontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleWithTimestamp(String title, AppState appState) {
    Color statusColor;
    String tooltipMsg;

    switch (appState.connectionStatus) {
      case RouterConnectionStatus.connected:
        statusColor = LuciStatusColors.connectionDot;
        tooltipMsg = 'Router Connected';
        break;
      case RouterConnectionStatus.reconnecting:
        statusColor = LuciStatusColors.warning;
        tooltipMsg = 'Reconnecting to Router...';
        break;
      case RouterConnectionStatus.disconnected:
        statusColor = Theme.of(context).colorScheme.error;
        tooltipMsg = 'Router Disconnected';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Tooltip(
          message: tooltipMsg,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  double _calculateNiceMaxBits(double maxDataBytesPerSec) {
    final double bitsPerSec = maxDataBytesPerSec * 8.0;
    final double target = math.max(bitsPerSec * 1.25, 64000.0);

    final double exponent = (math.log(target) / math.ln10).floorToDouble();
    final double magnitude = math.pow(10, exponent).toDouble();
    final double residual = target / magnitude;

    double niceResidual;
    if (residual <= 1.0) {
      niceResidual = 1.0;
    } else if (residual <= 1.5) {
      niceResidual = 1.5;
    } else if (residual <= 2.0) {
      niceResidual = 2.0;
    } else if (residual <= 2.5) {
      niceResidual = 2.5;
    } else if (residual <= 5.0) {
      niceResidual = 5.0;
    } else {
      niceResidual = 10.0;
    }

    return niceResidual * magnitude;
  }

  Widget _buildRealtimeThroughputCard(AppState appState) {
    final prefs = appState.dashboardPreferences;

    List<double> rxHistory;
    List<double> txHistory;
    double currentRxRate;
    double currentTxRate;
    String throughputLabel = '';

    if (!prefs.showAllThroughput && prefs.primaryThroughputInterface != null) {
      final interface = prefs.primaryThroughputInterface!;
      rxHistory = appState.getRxHistoryForInterface(interface);
      txHistory = appState.getTxHistoryForInterface(interface);
      currentRxRate = appState.getCurrentRxRateForInterface(interface);
      currentTxRate = appState.getCurrentTxRateForInterface(interface);
      throughputLabel = ' - $interface';
    } else {
      rxHistory = appState.rxHistory;
      txHistory = appState.txHistory;
      currentRxRate = appState.currentRxRate;
      currentTxRate = appState.currentTxRate;
    }

    double maxDataVal = 0.0;
    for (final val in rxHistory) {
      if (val > maxDataVal) maxDataVal = val;
    }
    for (final val in txHistory) {
      if (val > maxDataVal) maxDataVal = val;
    }

    final double niceMaxBits = _calculateNiceMaxBits(maxDataVal);
    final double chartMaxY = niceMaxBits / 8.0;
    final double chartInterval = chartMaxY / 4.0;

    final hasValidData =
        rxHistory.isNotEmpty ||
        txHistory.isNotEmpty ||
        currentRxRate > 0 ||
        currentTxRate > 0;
    final isSwitchingRouter =
        appState.isLoading && appState.dashboardData == null;

    final card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (throughputLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text(
                  'Throughput$throughputLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSpeedIndicator(
                  Icons.arrow_downward,
                  LuciColors.rx,
                  '',
                  isSwitchingRouter ? 0.0 : currentRxRate,
                ),
                _buildSpeedIndicator(
                  Icons.arrow_upward,
                  LuciColors.tx,
                  '',
                  isSwitchingRouter ? 0.0 : currentTxRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 600,
                ),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: hasValidData && !isSwitchingRouter
                    ? Column(
                        key: const ValueKey('throughput_chart_content'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12.0,
                                left: 4.0,
                                right: 12.0,
                              ),
                              child: LineChart(
                                key: ValueKey('chart_${appState.selectedRouter?.id}'),
                                LineChartData(
                                  minX: 0,
                                  maxX: 49,
                                  minY: 0,
                                  maxY: chartMaxY,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: chartInterval > 0 ? chartInterval : 1.0,
                                    getDrawingHorizontalLine: (val) => FlLine(
                                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 72,
                                        interval: chartInterval > 0 ? chartInterval : 1.0,
                                        getTitlesWidget: (value, meta) {
                                          if (value < -0.001 || value >= chartMaxY * 0.95) {
                                            return const SizedBox.shrink();
                                          }
                                          return SideTitleWidget(
                                            meta: meta,
                                            space: 6,
                                            fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                                            child: Text(
                                              _formatSpeedCompact(value),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      fitInsideVertically: true,
                                      getTooltipColor: (LineBarSpot spot) => Theme.of(
                                        context,
                                      ).colorScheme.surface.withValues(alpha: 0.95),
                                      tooltipBorderRadius: BorderRadius.circular(8),
                                      tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      getTooltipItems:
                                          (List<LineBarSpot> touchedSpots) {
                                            return touchedSpots.map((barSpot) {
                                              final flSpot = barSpot;
                                              final isRx = barSpot.barIndex == 0;
                                              final Color color =
                                                  flSpot.bar.gradient?.colors.first ??
                                                  flSpot.bar.color ??
                                                  Colors.white;

                                              return LineTooltipItem(
                                                '${isRx ? "RX" : "TX"}: ${_formatSpeed(flSpot.y)}',
                                                TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                                textAlign: TextAlign.left,
                                              );
                                            }).toList();
                                          },
                                    ),
                                  ),
                                  lineBarsData: [
                                    _buildLineChartBarData(
                                      rxHistory,
                                      [
                                        LuciColors.rx,
                                        LuciColors.rx,
                                      ],
                                      isRx: true,
                                    ),
                                    _buildLineChartBarData(
                                      txHistory,
                                      [
                                        LuciColors.tx,
                                        LuciColors.tx,
                                      ],
                                      isRx: false,
                                    ),
                                  ],
                                ),
                                duration: Duration.zero,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        key: ValueKey('loading_${appState.selectedRouter?.id}'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSwitchingRouter
                                  ? 'Switching router...'
                                  : 'Collecting throughput data...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    return card;
  }

  Widget _buildSpeedIndicator(
    IconData icon,
    Color color,
    String label,
    double speed,
  ) {
    final displaySpeed = speed.isNaN || speed.isInfinite || speed < 0
        ? 0.0
        : speed;
    final speedText = Text(
      _formatSpeed(displaySpeed),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        if (label.isNotEmpty)
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                speedText,
              ],
            ),
          )
        else
          Flexible(child: speedText),
      ],
    );
  }

  LineChartBarData _buildLineChartBarData(
    List<double> data,
    List<Color> gradientColors, {
    int maxPoints = 50,
    bool isRx = true,
  }) {
    if (data.isEmpty) {
      return LineChartBarData(
        spots: [const FlSpot(0, 0), FlSpot((maxPoints - 1).toDouble(), 0)],
        isCurved: false,
        gradient: LinearGradient(colors: gradientColors),
        barWidth: isRx ? 2.5 : 2.0,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }

    final int n = data.length;
    final int offset = maxPoints > n ? maxPoints - n : 0;

    final spots = data.asMap().entries.map((e) {
      final x = (offset + e.key).toDouble();
      return FlSpot(x, e.value);
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: spots.length > 1,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      preventCurveOvershootingThreshold: 0.0,
      gradient: LinearGradient(colors: gradientColors),
      barWidth: 2.8,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    // Handle edge cases
    if (bytesPerSecond.isNaN ||
        bytesPerSecond.isInfinite ||
        bytesPerSecond < 0) {
      return '0 bps';
    }

    final bitsPerSecond = bytesPerSecond * 8;
    if (bitsPerSecond < 1_000) return '${bitsPerSecond.toStringAsFixed(0)} bps';
    if (bitsPerSecond < 1_000_000) {
      return '${(bitsPerSecond / 1_000).toStringAsFixed(1)} Kbps';
    }
    return '${(bitsPerSecond / 1_000_000).toStringAsFixed(2)} Mbps';
  }

  String _formatSpeedCompact(double bytesPerSecond) {
    if (bytesPerSecond.isNaN ||
        bytesPerSecond.isInfinite ||
        bytesPerSecond <= 0) {
      return '0 bps';
    }
    final bits = bytesPerSecond * 8;
    if (bits < 1000) {
      return '${bits.toStringAsFixed(0)} bps';
    } else if (bits < 1000000) {
      final val = bits / 1000;
      final str = val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
      return '$str Kbps';
    } else {
      final val = bits / 1000000;
      final str = val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
      return '$str Mbps';
    }
  }

  // Consistent card builder for all dashboard vitals and summary cards
  Widget _buildVitalsColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: valueStyle,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemVitalsCard(AppState appState) {
    final sysInfo = appState.dashboardData?['sysInfo'] as Map<String, dynamic>?;

    final uptime = (sysInfo?['uptime'] is num)
        ? (sysInfo!['uptime'] as num).toInt()
        : (sysInfo?['uptime'] is String ? int.tryParse(sysInfo!['uptime']) : null);
    final uptimeValue = uptime != null ? _formatUptime(uptime) : 'N/A';

    final rawCpuLoad = sysInfo?['load'];
    final cpuLoad = rawCpuLoad is List ? rawCpuLoad : (rawCpuLoad is Map ? rawCpuLoad.values.toList() : null);
    final cpuLoadValue = cpuLoad != null ? _formatCpuLoad(cpuLoad) : 'N/A';

    String loadAvgValue = 'N/A';
    if (cpuLoad != null && cpuLoad.isNotEmpty) {
      if (cpuLoad[0] is num) {
        final num rawVal = cpuLoad[0] as num;
        final double l1 = rawVal is int
            ? rawVal.toDouble() / 65536.0
            : (rawVal.toDouble() > 10.0
                ? rawVal.toDouble() / 65536.0
                : rawVal.toDouble());
        loadAvgValue = l1.toStringAsFixed(2);
      }
    }

    final totalMem = (sysInfo?['memory']?['total'] is num)
        ? (sysInfo!['memory']['total'] as num).toInt()
        : (sysInfo?['memory']?['total'] is String ? int.tryParse(sysInfo!['memory']['total']) ?? 0 : 0);
    final freeMem = (sysInfo?['memory']?['free'] is num)
        ? (sysInfo!['memory']['free'] as num).toInt()
        : (sysInfo?['memory']?['free'] is String ? int.tryParse(sysInfo!['memory']['free']) ?? 0 : 0);
    final bufferedMem = (sysInfo?['memory']?['buffered'] is num)
        ? (sysInfo!['memory']['buffered'] as num).toInt()
        : (sysInfo?['memory']?['buffered'] is String ? int.tryParse(sysInfo!['memory']['buffered']) ?? 0 : 0);
    final usedMem = totalMem - freeMem - bufferedMem;
    final memoryValue = totalMem > 0
        ? '${(usedMem / totalMem * 100).toStringAsFixed(0)}%'
        : 'N/A';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: _buildVitalsColumn(
                context,
                label: 'CPU Load',
                value: cpuLoadValue,
              ),
            ),
            Expanded(
              child: _buildVitalsColumn(
                context,
                label: 'RAM Usage',
                value: memoryValue,
              ),
            ),
            Expanded(
              child: _buildVitalsColumn(
                context,
                label: 'Load Avg',
                value: loadAvgValue,
              ),
            ),
            Expanded(
              child: _buildVitalsColumn(
                context,
                label: 'Uptime',
                value: uptimeValue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsSummaryCard(AppState appState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<Client>>(
      future: appState.fetchClientsForSelectedRouter(),
      builder: (context, snapshot) {
        final clients = snapshot.data ?? [];
        final connectedClients = clients.where((c) => c.isConnected).toList();
        final wiredCount = connectedClients.where((c) => c.connectionType == ConnectionType.wired).length;
        final wirelessCount = connectedClients.where((c) => c.connectionType == ConnectionType.wireless).length;
        final isLoading = snapshot.connectionState == ConnectionState.waiting && clients.isEmpty;

        Widget buildCountText(int count) {
          if (isLoading) {
            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            );
          }
          return Text(
            '$count Connected',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              appState.requestedTab = 2;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lan,
                            color: colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wired Clients',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              buildCountText(wiredCount),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.wifi,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wireless Clients',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              buildCountText(wirelessCount),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isPublicIp(String ipText) {
    if (ipText.isEmpty || ipText == 'No IPv4' || ipText == 'No IPv6' || ipText == 'N/A') {
      return false;
    }
    final raw = ipText.split('/')[0].trim();

    if (raw.contains('.')) {
      final parts = raw.split('.');
      if (parts.length != 4) return false;
      final octet1 = int.tryParse(parts[0]);
      final octet2 = int.tryParse(parts[1]);
      if (octet1 == null || octet2 == null) return false;

      // Private IPv4 ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, loopback, link-local)
      if (octet1 == 10) return false;
      if (octet1 == 172 && octet2 >= 16 && octet2 <= 31) return false;
      if (octet1 == 192 && octet2 == 168) return false;
      if (octet1 == 127) return false;
      if (octet1 == 169 && octet2 == 254) return false;

      return true;
    } else if (raw.contains(':')) {
      final lower = raw.toLowerCase();
      if (lower == '::1') return false; // Loopback
      if (lower.startsWith('fe80:') ||
          lower.startsWith('fe8') ||
          lower.startsWith('fe9') ||
          lower.startsWith('fea') ||
          lower.startsWith('feb')) {
        return false; // Link-local
      }
      if (lower.startsWith('fc') || lower.startsWith('fd')) {
        return false; // Private ULA
      }

      return true;
    }
    return false;
  }

  String _maskIpString(String ipText) {
    if (ipText == 'No IPv4' || ipText == 'No IPv6' || ipText == 'N/A' || ipText.isEmpty) {
      return ipText;
    }
    final parts = ipText.split('/');
    final rawIp = parts[0].trim();
    final prefix = parts.length > 1 ? '/${parts[1]}' : '';

    if (rawIp.contains('.')) {
      final octets = rawIp.split('.');
      if (octets.length == 4) {
        return '${octets[0]}.***.***.${octets[3]}$prefix';
      }
      return '***.***.***.***$prefix';
    }
    if (rawIp.contains(':')) {
      final segments = rawIp.split(':');
      if (segments.length >= 3) {
        return '${segments.first}:****:****::${segments.last}$prefix';
      }
      return '****:****::****$prefix';
    }
    return '••••••••$prefix';
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }

  void _showWirelessClientsBottomSheet(
    BuildContext context,
    String ssid,
    String radioName,
    String bandLabel,
    String channel,
    List<WirelessStation> stations,
    AppState appState,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final leasesRaw = appState.dashboardData?['dhcpLeases'];
        final leases = <String, Map<String, dynamic>>{};
        if (leasesRaw is Map<String, dynamic>) {
          final dhcpList = leasesRaw['dhcp_leases'] ?? leasesRaw['leases'];
          if (dhcpList is List) {
            for (final lease in dhcpList) {
              if (lease is Map<String, dynamic>) {
                final mac = lease['macaddr']?.toString().toUpperCase() ?? lease['mac']?.toString().toUpperCase();
                if (mac != null) {
                  leases[mac] = lease;
                }
              }
            }
          }
        }

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ssid,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$radioName • $bandLabel • Channel $channel',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text('${stations.length} connected'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (stations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.devices_other, size: 40, color: Colors.grey.shade500),
                          const SizedBox(height: 8),
                          Text(
                            'No clients currently associated with $radioName ($ssid).',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: stations.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final st = stations[index];
                        final normMac = st.macAddress.toUpperCase();
                        final lease = leases[normMac];
                        final hostname = lease?['hostname']?.toString() ?? lease?['name']?.toString() ?? 'Wireless Client';
                        final ip = lease?['ipaddr']?.toString() ?? lease?['ip']?.toString() ?? 'DHCP Unassigned';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.devices, color: Theme.of(context).colorScheme.primary, size: 20),
                          ),
                          title: Text(
                            hostname,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'IP: $ip\nMAC: ${st.macAddress}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    st.formattedSignal,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: st.signalDbm != null && st.signalDbm! > -65 ? LuciStatusColors.connected : Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    st.signalQualityLabel,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) async {
                                  Navigator.pop(context);
                                  final isPaused = appState.isInternetPaused(st.macAddress);
                                  if (val == 'pause') {
                                    final res = await appState.pauseClientInternet(
                                      st.macAddress,
                                      pause: !isPaused,
                                      context: context,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res
                                                ? 'Internet ${!isPaused ? "paused" : "restored"} for $hostname.'
                                                : 'Failed to update internet access for $hostname.',
                                          ),
                                          backgroundColor: res ? Colors.green : Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (ctx) {
                                  final isPaused = appState.isInternetPaused(st.macAddress);
                                  return [
                                    PopupMenuItem(
                                      value: 'pause',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                                            color: isPaused ? LuciStatusColors.connected : Colors.orange,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isPaused ? 'Resume Internet' : 'Pause Internet'),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWirelessNetworksCard(AppState appState) {
    final overview = WirelessOverview.fromDashboardData(
      appState.dashboardData,
      isReviewerMode: appState.reviewerModeEnabled,
    );

    if (overview.radios.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardWidgets = <Widget>[];

    for (final radio in overview.radios) {
      for (final iface in radio.interfaces) {
        final ssid = iface.ssid;
        final isEnabled = iface.isEnabled;

        cardWidgets.add(
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _showWirelessClientsBottomSheet(
                  context,
                  ssid,
                  radio.name,
                  radio.bandLabel,
                  iface.channel,
                  iface.stations,
                  appState,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isEnabled ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                      child: Icon(Icons.wifi, color: isEnabled ? Colors.blue : Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                ssid,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEnabled ? LuciStatusColors.connected.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isEnabled ? 'ENABLED' : 'DISABLED',
                                  style: TextStyle(
                                    color: isEnabled ? LuciStatusColors.connected : Colors.red.shade800,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Radio: ${radio.name} (${radio.bandLabel}) • Ch ${iface.channel} • ${iface.encryption}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.devices, size: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              const SizedBox(width: 4),
                              Text(
                                '${iface.stations.length} clients',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap for clients',
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cardWidgets,
    );
  }

  IconData _getInterfaceIcon(String name, String proto) {
    final lower = name.toLowerCase();

    // Check name-based patterns first
    if (lower.contains('wan')) {
      return Icons.public_rounded;
    }
    if (lower.contains('lan')) {
      return Icons.router_rounded;
    }
    if (lower.contains('iot')) {
      return Icons.sensors_rounded;
    }
    if (lower.contains('guest')) {
      return Icons.people_rounded;
    }
    if (lower.contains('dmz')) {
      return Icons.security_rounded;
    }
    if (lower.contains('docker')) {
      return Icons.computer_rounded;
    }
    if (lower.contains('bridge') || lower.startsWith('br-')) {
      return Icons.hub_rounded;
    }
    if (lower.contains('vlan')) {
      return Icons.layers_rounded;
    }
    if (lower.startsWith('eth')) {
      return Icons.cable_rounded;
    }
    if (lower.startsWith('wlan')) {
      return Icons.wifi_rounded;
    }

    // Check protocol-based patterns
    switch (proto) {
      case 'wireguard':
      case 'openvpn':
        return Icons.vpn_key_rounded;
      case 'pppoe':
        return Icons.settings_ethernet_rounded;
      case 'dhcp':
      case 'static':
        return Icons.lan_rounded;
      default:
        return Icons.lan_rounded;
    }
  }

  Widget _buildInterfaceStatusCards(AppState appState) {
    final prefs = appState.dashboardPreferences;
    final rawDump = appState.dashboardData?['interfaceDump']?['interface'];
    final interfaces = rawDump is List ? rawDump : (rawDump is Map ? rawDump.values.toList() : null);
    if (interfaces == null || interfaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final wanVpnInterfaces = interfaces.where((item) {
      final interface = item as Map<String, dynamic>;
      final name = interface['interface'] as String? ?? '';

      // Skip loopback interface
      if (name == 'loopback' || name == 'lo') return false;

      // If preferences are empty, show all interfaces by default
      if (prefs.enabledWiredInterfaces.isEmpty) {
        return true;
      }

      return prefs.enabledWiredInterfaces.contains(name);
    }).toList();

    if (wanVpnInterfaces.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> interfaceCardWidgets = [];
    for (var item in wanVpnInterfaces) {
      final interface = item as Map<String, dynamic>;
      final name = interface['interface'] as String? ?? 'N/A';
      final isUp = interface['up'] as bool? ?? false;
      final proto = (interface['proto'] as String? ?? '').toUpperCase();
      final l3Dev = interface['l3_device']?.toString() ?? interface['device']?.toString() ?? '';

      String ipText = 'No IPv4';
      if (interface['ipv4-address'] is List && (interface['ipv4-address'] as List).isNotEmpty) {
        final first = (interface['ipv4-address'] as List).first;
        if (first is Map) {
          final addr = first['address']?.toString() ?? '';
          final mask = first['mask']?.toString() ?? '';
          if (addr.isNotEmpty) {
            ipText = mask.isNotEmpty ? '$addr/$mask' : addr;
          }
        }
      } else if (interface['ipv6-address'] is List && (interface['ipv6-address'] as List).isNotEmpty) {
        final first = (interface['ipv6-address'] as List).first;
        if (first is Map) {
          final addr = first['address']?.toString() ?? '';
          if (addr.isNotEmpty) {
            ipText = addr;
          }
        }
      }

      final isPublic = _isPublicIp(ipText);
      final displayIp = (prefs.maskPublicIp && isPublic) ? _maskIpString(ipText) : ipText;

      interfaceCardWidgets.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isUp
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              final appState = ref.read(appStateProvider);
              appState.requestTab(1, interfaceToScroll: name);
            },
            onLongPress: () {
              final appState = ref.read(appStateProvider);
              appState.requestTab(1, interfaceToScroll: name);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getInterfaceIcon(name, proto),
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name.toUpperCase(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUp
                              ? LuciStatusColors.connected.withValues(alpha: 0.18)
                              : Colors.red.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isUp ? LuciStatusColors.connected : Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isUp ? 'UP' : 'DOWN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isUp ? LuciStatusColors.connected : Colors.red.shade800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.lan_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayIp,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (proto.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            proto,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (l3Dev.isNotEmpty)
                        Text(
                          'Dev: $l3Dev',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final cardWidth = 220.0;
    return SizedBox(
      height: 130,
      child: ListView.separated(
        controller: _wanScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: interfaceCardWidgets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return SizedBox(
            width: cardWidth,
            child: interfaceCardWidgets[index],
          );
        },
      ),
    );
  }

  Widget _buildReviewerModeBanner(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade900.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'REVIEWER MODE ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Using simulated router environment with full mock data',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.amber.shade900,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showExitReviewerModeDialog(context, ref),
            icon: const Icon(Icons.exit_to_app_rounded, size: 14),
            label: const Text(
              'Exit Mode',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitReviewerModeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Reviewer Mode?'),
        content: const Text(
          'This will disable reviewer mode and redirect to the login screen so you can connect to a live router.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final appState = ref.read(appStateProvider);
              await appState.setReviewerMode(false);
              await appState.logout();
              if (context.mounted) {
                await Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Exit Reviewer Mode'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final model.Router? selected = appState.selectedRouter;
    final boardInfo =
        appState.dashboardData?['boardInfo'] as Map<String, dynamic>?;
    final hostname = boardInfo?['hostname']?.toString();
    final headerText = (hostname != null && hostname.isNotEmpty)
        ? hostname
        : (appState.reviewerModeEnabled
            ? 'OpenWrt-Demo'
            : (selected?.ipAddress ?? 'Loading...'));
    return Scaffold(
      appBar: LuciAppBar(
        centerTitle: true,
        title: null, // Always use titleWidget now
        titleWidget: _buildTitleWithTimestamp(headerText, appState),
        actions: [
          if (appState.reviewerModeEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.rate_review, size: 14, color: Colors.white),
                label: const Text('REVIEWER', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber.shade900,
                side: BorderSide.none,
                onPressed: () => _showExitReviewerModeDialog(context, ref),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (appState.reviewerModeEnabled) _buildReviewerModeBanner(context, ref),
          Expanded(child: Stack(children: [_buildBody(appState)])),
        ],
      ),
    );
  }

  Widget _buildBody(AppState appState) {
    if (appState.dashboardError != null) {
      return LuciErrorDisplay(
        title: 'Connection Failed',
        message:
            'Unable to connect to the router. Please check your network connection and router settings.',
        actionLabel: 'Retry Connection',
        onAction: () => appState.fetchDashboardData(),
        icon: Icons.wifi_off_rounded,
      );
    }

    if (appState.isDashboardLoading && appState.dashboardData == null) {
      return const LuciLoadingWidget();
    }

    if (appState.dashboardData == null) {
      return LuciEmptyState(
        title: 'No Data Available',
        message:
            'Unable to fetch dashboard data. Pull down to refresh or tap the button below.',
        icon: Icons.dashboard_outlined,
        actionLabel: 'Fetch Data',
        onAction: () => appState.fetchDashboardData(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.fetchDashboardData(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;

          // Split layout handling to avoid Expanded widget conflicts with staggered animations
          if (isLandscape) {
            final landscapeContent = [
              const SizedBox(height: 16),
              _buildDeviceInfoCard(appState),
              if (appState.isMissingRpcPackages && !_dismissedRpcWarning)
                _buildRpcWarningCard(context, appState),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: _buildRealtimeThroughputCard(appState),
              ),
              const SizedBox(height: 12),
              _buildSystemVitalsCard(appState),
              const SizedBox(height: 12),
              _buildClientsSummaryCard(appState),
              const SizedBox(height: 12),
              _buildWirelessNetworksCard(appState),
              const SizedBox(height: 12),
              _buildInterfaceStatusCards(appState),
              const SizedBox(height: 12),
              ..._buildModuleDashboardWidgets(context),
              const SizedBox(height: 100),
            ];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: LuciStaggeredAnimation(
                  staggerDelay: const Duration(milliseconds: 50),
                  children: landscapeContent,
                ),
              ),
            );
          } else {
            // Portrait mode: SingleChildScrollView with all dynamic module widgets
            return RefreshIndicator(
              onRefresh: () => appState.fetchDashboardData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildDeviceInfoCard(appState),
                    if (appState.isMissingRpcPackages && !_dismissedRpcWarning)
                      _buildRpcWarningCard(context, appState),
                    _buildSectionHeader(context, 'Real-time Network Traffic', Icons.swap_vert),
                    SizedBox(
                      height: 220,
                      child: _buildRealtimeThroughputCard(appState),
                    ),
                    _buildSectionHeader(context, 'System Vitals', Icons.monitor_heart),
                    _buildSystemVitalsCard(appState),
                    _buildSectionHeader(context, 'Connected Clients Overview', Icons.devices),
                    _buildClientsSummaryCard(appState),
                    _buildSectionHeader(context, 'Wireless Radios & SSIDs', Icons.wifi),
                    _buildWirelessNetworksCard(appState),
                    _buildSectionHeader(
                      context,
                      'Network Interfaces',
                      Icons.lan,
                      action: IconButton(
                        icon: Icon(
                          appState.dashboardPreferences.maskPublicIp
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: appState.dashboardPreferences.maskPublicIp
                            ? 'Show public WAN IP address'
                            : 'Mask public WAN IP address for privacy',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final current = appState.dashboardPreferences;
                          appState.saveDashboardPreferences(
                            current.copyWith(maskPublicIp: !current.maskPublicIp),
                          );
                        },
                      ),
                    ),
                    _buildInterfaceStatusCards(appState),
                    _buildSectionHeader(context, 'System Modules & Storage', Icons.storage),
                    ..._buildModuleDashboardWidgets(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRpcWarningCard(BuildContext context, AppState appState) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.85),
      elevation: 2,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LuCI RPC Package Required',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _dismissedRpcWarning = true;
                    });
                  },
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your router is missing `luci-mod-rpc` or backend execution permissions. Some real-time wireless, package, and system control features require RPC support.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.9),
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final success = await appState.autoFixPermissions(context: context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'RPC packages and permissions installed successfully!'
                                  : 'Auto-install failed. Tap "Manual Info" for shell commands.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.build_circle_outlined, size: 18),
                    label: const Text('Auto-Install RPC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showManualRpcInstallDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text('Manual Info'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualRpcInstallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.terminal, color: Colors.blue),
            SizedBox(width: 8),
            Text('Manual RPC Installation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Connect to your router via SSH and run the following command to enable full RPC functionality:\n',
            ),
            SelectableText(
              '# OpenWrt (opkg):\n'
              'opkg update && opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status && /etc/init.d/rpcd restart\n\n'
              '# OpenWrt 25.12+ (apk):\n'
              'apk update && apk add luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status && /etc/init.d/rpcd restart',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildModuleDashboardWidgets(BuildContext context) {
    final widgets = <Widget>[];
    final modules = LuciModuleRegistry.instance.enabledModules;
    for (final module in modules) {
      if (module.showInBottomNav) continue; // Skip core tab bar screens
      final widget = module.buildDashboardWidget(context);
      if (widget != null) {
        widgets.add(
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => module.buildScreen(context),
                ),
              );
            },
            child: widget,
          ),
        );
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }
}
