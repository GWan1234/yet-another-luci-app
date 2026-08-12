/// Model representing core system vitals: CPU usage, RAM memory, Load Average, and Uptime.
class SystemMetrics {
  final int uptimeSeconds;
  final double load1m;
  final double load5m;
  final double load15m;
  final double cpuUsagePercent;
  final int totalMemoryBytes;
  final int freeMemoryBytes;
  final int bufferedMemoryBytes;
  final int cachedMemoryBytes;

  const SystemMetrics({
    required this.uptimeSeconds,
    required this.load1m,
    required this.load5m,
    required this.load15m,
    required this.cpuUsagePercent,
    required this.totalMemoryBytes,
    required this.freeMemoryBytes,
    required this.bufferedMemoryBytes,
    required this.cachedMemoryBytes,
  });

  factory SystemMetrics.fromSysInfo(Map<String, dynamic>? sysInfo) {
    if (sysInfo == null) {
      return const SystemMetrics(
        uptimeSeconds: 0,
        load1m: 0.0,
        load5m: 0.0,
        load15m: 0.0,
        cpuUsagePercent: 0.0,
        totalMemoryBytes: 0,
        freeMemoryBytes: 0,
        bufferedMemoryBytes: 0,
        cachedMemoryBytes: 0,
      );
    }

    final uptime = (sysInfo['uptime'] as num?)?.toInt() ?? 0;

    // Load averages
    double l1 = 0.0;
    double l5 = 0.0;
    double l15 = 0.0;
    final rawLoad = sysInfo['load'];
    final loadList = rawLoad is List ? rawLoad : (rawLoad is Map ? rawLoad.values.toList() : null);
    if (loadList != null && loadList.isNotEmpty) {
      double parseLoad(dynamic val) {
        if (val == null) return 0.0;
        if (val is int) {
          return val.toDouble() / 65536.0;
        }
        final double dVal = (val as num).toDouble();
        return dVal > 10.0 ? dVal / 65536.0 : dVal;
      }

      l1 = parseLoad(loadList[0]);
      if (loadList.length > 1) l5 = parseLoad(loadList[1]);
      if (loadList.length > 2) l15 = parseLoad(loadList[2]);
    }

    // CPU percentage estimate from 1m load normalized to 100%
    final cpuPercent = (l1 * 100).clamp(0.0, 100.0);

    // Memory parsing
    final memMap = sysInfo['memory'] as Map<String, dynamic>?;
    final total = (memMap?['total'] as num?)?.toInt() ?? 0;
    final free = (memMap?['free'] as num?)?.toInt() ?? 0;
    final buffered = (memMap?['buffered'] as num?)?.toInt() ?? 0;
    final cached = (memMap?['cached'] as num?)?.toInt() ?? 0;

    return SystemMetrics(
      uptimeSeconds: uptime,
      load1m: l1,
      load5m: l5,
      load15m: l15,
      cpuUsagePercent: cpuPercent,
      totalMemoryBytes: total,
      freeMemoryBytes: free,
      bufferedMemoryBytes: buffered,
      cachedMemoryBytes: cached,
    );
  }

  int get usedMemoryBytes {
    final used = totalMemoryBytes - freeMemoryBytes - bufferedMemoryBytes - cachedMemoryBytes;
    return used < 0 ? 0 : used;
  }

  double get memoryUsagePercent {
    if (totalMemoryBytes <= 0) return 0.0;
    final used = totalMemoryBytes - freeMemoryBytes - bufferedMemoryBytes;
    return ((used / totalMemoryBytes) * 100).clamp(0.0, 100.0);
  }

  String get formattedUptime {
    if (uptimeSeconds <= 0) return 'N/A';
    final days = uptimeSeconds ~/ 86400;
    final hours = (uptimeSeconds % 86400) ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  String get formattedLoadAverage {
    return '${load1m.toStringAsFixed(2)}, ${load5m.toStringAsFixed(2)}, ${load15m.toStringAsFixed(2)}';
  }

  String get formattedMemoryUsage {
    if (totalMemoryBytes <= 0) return 'N/A';
    final usedMB = (usedMemoryBytes / (1024 * 1024)).toStringAsFixed(0);
    final totalMB = (totalMemoryBytes / (1024 * 1024)).toStringAsFixed(0);
    return '$usedMB / $totalMB MB (${memoryUsagePercent.toStringAsFixed(0)}%)';
  }
}
