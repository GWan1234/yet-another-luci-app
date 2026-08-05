import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import '../services/metrics_chart_engine.dart';
import '../widgets/realtime_line_chart.dart';

class ChartingScreen extends ConsumerWidget {
  const ChartingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsData = ref.watch(metricsChartEngineProvider);
    final engine = ref.read(metricsChartEngineProvider.notifier);

    // Sync latest appState metrics into chart engine
    final appState = ref.watch(appStateProvider);
    final sysInfo = appState.dashboardData?['sysInfo'] as Map<String, dynamic>?;

    final rawLoad = sysInfo?['load'];
    final cpuLoadList = rawLoad is List ? rawLoad : (rawLoad is Map ? rawLoad.values.toList() : null);
    final cpuLoad = cpuLoadList?.firstOrNull as num?;
    final cpuVal = cpuLoad != null ? (cpuLoad > 500 ? (cpuLoad / 65536.0 * 100) : cpuLoad.toDouble() * 100).clamp(0.0, 100.0) : 0.0;

    final totalMem = (sysInfo?['memory']?['total'] as num?)?.toDouble() ?? 0.0;
    final freeMem = (sysInfo?['memory']?['free'] as num?)?.toDouble() ?? 0.0;
    final buffMem = (sysInfo?['memory']?['buffered'] as num?)?.toDouble() ?? 0.0;
    final ramVal = totalMem > 0 ? (((totalMem - freeMem - buffMem) / totalMem) * 100).clamp(0.0, 100.0) : 0.0;

    final rxVal = appState.currentRxRate;
    final txVal = appState.currentTxRate;

    // Schedule sample push post-frame if changed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      engine.addSample(
        cpuUsage: cpuVal,
        ramUsage: ramVal,
        rxRate: rxVal,
        txRate: txVal,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Metrics Charts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildConfigCard(context, ref, engine, metricsData.pollingIntervalSeconds),
          const SizedBox(height: 16),
          _buildChartCard(
            context,
            title: 'CPU Usage (%)',
            icon: Icons.memory,
            color: Colors.orange,
            chart: RealtimeLineChart(
              maxY: 100,
              valueFormatter: (v) => '${v.toStringAsFixed(1)}%',
              series: [
                ChartSeriesData(
                  spots: metricsData.cpuHistory,
                  gradientColors: [Colors.orange.shade700, Colors.orange.shade300],
                  label: 'CPU Usage',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            context,
            title: 'RAM Usage (%)',
            icon: Icons.pie_chart,
            color: Colors.blue,
            chart: RealtimeLineChart(
              maxY: 100,
              valueFormatter: (v) => '${v.toStringAsFixed(1)}%',
              series: [
                ChartSeriesData(
                  spots: metricsData.ramHistory,
                  gradientColors: [Colors.blue.shade700, Colors.blue.shade300],
                  label: 'RAM Usage',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            context,
            title: 'Network RX / TX Throughput',
            icon: Icons.swap_vert,
            color: Colors.teal,
            chart: RealtimeLineChart(
              valueFormatter: _formatSpeed,
              series: [
                ChartSeriesData(
                  spots: metricsData.rxHistory,
                  gradientColors: [Colors.green.shade700, Colors.green.shade300],
                  label: 'RX (Download)',
                ),
                ChartSeriesData(
                  spots: metricsData.txHistory,
                  gradientColors: [Colors.blue.shade700, Colors.blue.shade300],
                  label: 'TX (Upload)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfigCard(
    BuildContext context,
    WidgetRef ref,
    MetricsChartEngine engine,
    int currentInterval,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Polling Engine Interval', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${currentInterval}s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            Slider(
              value: currentInterval.toDouble(),
              min: 1.0,
              max: 10.0,
              divisions: 9,
              label: '${currentInterval}s',
              onChanged: (val) {
                engine.updatePollingInterval(val.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget chart,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            chart,
          ],
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 bps';
    final bits = bytesPerSecond * 8;
    if (bits < 1000) return '${bits.toStringAsFixed(0)} bps';
    if (bits < 1000000) return '${(bits / 1000).toStringAsFixed(1)} Kbps';
    return '${(bits / 1000000).toStringAsFixed(2)} Mbps';
  }
}
