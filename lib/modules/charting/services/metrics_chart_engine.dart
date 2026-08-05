import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Class encapsulating real-time history series data.
class RealtimeMetricsData {
  final List<double> cpuHistory;
  final List<double> ramHistory;
  final List<double> rxHistory;
  final List<double> txHistory;
  final int pollingIntervalSeconds;

  const RealtimeMetricsData({
    required this.cpuHistory,
    required this.ramHistory,
    required this.rxHistory,
    required this.txHistory,
    required this.pollingIntervalSeconds,
  });

  RealtimeMetricsData copyWith({
    List<double>? cpuHistory,
    List<double>? ramHistory,
    List<double>? rxHistory,
    List<double>? txHistory,
    int? pollingIntervalSeconds,
  }) {
    return RealtimeMetricsData(
      cpuHistory: cpuHistory ?? this.cpuHistory,
      ramHistory: ramHistory ?? this.ramHistory,
      rxHistory: rxHistory ?? this.rxHistory,
      txHistory: txHistory ?? this.txHistory,
      pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
    );
  }
}

/// Dynamic polling engine with configurable polling interval (1s-10s) and fixed history buffer (last N points).
class MetricsChartEngine extends StateNotifier<RealtimeMetricsData> {
  Timer? _timer;
  int _maxPoints;

  MetricsChartEngine({int maxPoints = 30, int intervalSeconds = 2})
      : _maxPoints = maxPoints,
        super(RealtimeMetricsData(
          cpuHistory: [],
          ramHistory: [],
          rxHistory: [],
          txHistory: [],
          pollingIntervalSeconds: intervalSeconds.clamp(1, 10),
        ));

  int get maxPoints => _maxPoints;
  set maxPoints(int count) {
    _maxPoints = count.clamp(10, 100);
  }

  void updatePollingInterval(int seconds) {
    final clamped = seconds.clamp(1, 10);
    if (state.pollingIntervalSeconds == clamped) return;

    state = state.copyWith(pollingIntervalSeconds: clamped);
  }

  /// Appends a new metric sample point to history buffer, maintaining max history size.
  void addSample({
    required double cpuUsage,
    required double ramUsage,
    required double rxRate,
    required double txRate,
  }) {
    List<double> append(List<double> list, double value) {
      final updated = List<double>.from(list)..add(value);
      if (updated.length > _maxPoints) {
        updated.removeAt(0);
      }
      return updated;
    }

    state = state.copyWith(
      cpuHistory: append(state.cpuHistory, cpuUsage),
      ramHistory: append(state.ramHistory, ramUsage),
      rxHistory: append(state.rxHistory, rxRate),
      txHistory: append(state.txHistory, txRate),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final metricsChartEngineProvider =
    StateNotifierProvider<MetricsChartEngine, RealtimeMetricsData>((ref) {
  return MetricsChartEngine();
});
