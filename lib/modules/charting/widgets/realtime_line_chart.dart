import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ChartSeriesData {
  final List<double> spots;
  final List<Color> gradientColors;
  final String label;

  const ChartSeriesData({
    required this.spots,
    required this.gradientColors,
    required this.label,
  });
}

/// Shared real-time line chart component built with fl_chart.
class RealtimeLineChart extends StatelessWidget {
  final List<ChartSeriesData> series;
  final String Function(double value)? valueFormatter;
  final double? minY;
  final double? maxY;
  final double height;
  final bool showGrid;

  const RealtimeLineChart({
    super.key,
    required this.series,
    this.valueFormatter,
    this.minY,
    this.maxY,
    this.height = 140,
    this.showGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.every((s) => s.spots.isEmpty)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Collecting metric samples...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live line legend text row
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: series.map((s) {
              final latestVal = s.spots.isNotEmpty ? s.spots.last : 0.0;
              final formattedText = valueFormatter != null
                  ? valueFormatter!(latestVal)
                  : latestVal.toStringAsFixed(1);
              final primaryColor = s.gradientColors.first;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label}: ',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      formattedText,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY ?? 0.0,
              maxY: maxY,
              gridData: FlGridData(
                show: showGrid,
                drawVerticalLine: false,
                horizontalInterval: maxY != null ? maxY! / 4 : null,
                getDrawingHorizontalLine: (val) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      // Suppress top Y-axis label if near peak to prevent label collision with header badges
                      if (meta.max > 0 && value >= meta.max * 0.95) {
                        return const SizedBox.shrink();
                      }
                      if (valueFormatter != null) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            valueFormatter!(value),
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      }
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                  getTooltipColor: (spot) => Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final seriesData = spot.barIndex < series.length ? series[spot.barIndex] : null;
                      final labelName = seriesData?.label ?? 'Metric';
                      final color = spot.bar.gradient?.colors.first ?? spot.bar.color ?? Colors.white;
                      final formatted = valueFormatter != null
                          ? valueFormatter!(spot.y)
                          : spot.y.toStringAsFixed(1);
                      return LineTooltipItem(
                        '$labelName: $formatted',
                        TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: series.map((s) => _buildBarData(s)).toList(),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }

  LineChartBarData _buildBarData(ChartSeriesData seriesData) {
    final data = seriesData.spots;
    final colors = seriesData.gradientColors;

    if (data.length == 1) {
      return LineChartBarData(
        spots: [FlSpot(0, data[0]), FlSpot(1, data[0])],
        isCurved: false,
        gradient: LinearGradient(colors: colors),
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: colors.map((c) => c.withValues(alpha: 0.15)).toList(),
          ),
        ),
      );
    }

    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      gradient: LinearGradient(colors: colors),
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: colors.map((c) => c.withValues(alpha: 0.25)).toList(),
        ),
      ),
    );
  }
}
