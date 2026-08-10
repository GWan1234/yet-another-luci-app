/// Representation of an individual mounted filesystem partition or device.
class MountPointItem {
  final String mountPath;
  final String device;
  final String filesystemType;
  final int sizeBytes;
  final int usedBytes;
  final int availableBytes;

  const MountPointItem({
    required this.mountPath,
    required this.device,
    required this.filesystemType,
    required this.sizeBytes,
    required this.usedBytes,
    required this.availableBytes,
  });

  factory MountPointItem.fromJson(Map<String, dynamic> json) {
    final mount = json['mount']?.toString() ??
        json['target']?.toString() ??
        json['mountpoint']?.toString() ??
        '/';
    final dev = json['device']?.toString() ?? json['dev']?.toString() ?? 'unknown';

    String fs = json['fs']?.toString() ??
        json['fstype']?.toString() ??
        json['type']?.toString() ??
        '';

    if (fs.isEmpty || fs.toLowerCase() == 'unknown') {
      if (dev.contains('ubi')) {
        fs = 'ubifs';
      } else if (dev.contains('overlay') || mount.contains('overlay')) {
        fs = 'overlayfs';
      } else if (dev == 'tmpfs' || mount == '/tmp' || mount == '/dev') {
        fs = 'tmpfs';
      } else if (dev.contains('root') || mount == '/rom') {
        fs = 'squashfs';
      } else if (dev.contains('mtdblock')) {
        fs = 'jffs2';
      } else {
        fs = 'ext4';
      }
    }

    int rawSize = (json['size'] as num?)?.toInt() ??
        (json['total'] as num?)?.toInt() ??
        (json['blocks'] as num?)?.toInt() ??
        0;

    int rawAvail = (json['avail'] as num?)?.toInt() ??
        (json['available'] as num?)?.toInt() ??
        (json['free'] as num?)?.toInt() ??
        0;

    int rawUsed = (json['used'] as num?)?.toInt() ?? 0;
    if (rawUsed == 0 && rawSize > rawAvail && rawAvail > 0) {
      rawUsed = rawSize - rawAvail;
    } else if (rawAvail == 0 && rawSize > rawUsed && rawUsed > 0) {
      rawAvail = rawSize - rawUsed;
    }

    return MountPointItem(
      mountPath: mount,
      device: dev,
      filesystemType: fs,
      sizeBytes: rawSize,
      usedBytes: rawUsed,
      availableBytes: rawAvail < 0 ? 0 : rawAvail,
    );
  }

  double get usedPercent {
    if (sizeBytes <= 0) return 0.0;
    return ((usedBytes / sizeBytes) * 100).clamp(0.0, 100.0);
  }

  bool get isOverlay =>
      mountPath == '/overlay' ||
      mountPath.contains('overlay') ||
      device.contains('overlay') ||
      device.contains('ubi');

  bool get isRoot =>
      mountPath == '/' ||
      mountPath == '/rom' ||
      device == '/dev/root' ||
      device.contains('root');

  bool get isTmp =>
      mountPath == '/tmp' ||
      mountPath == '/dev' ||
      mountPath.contains('/tmp') ||
      filesystemType == 'tmpfs' ||
      device == 'tmpfs';
}

/// Overview of router storage, overlay filesystem, flash, and mounted devices.
class StorageOverview {
  final List<MountPointItem> mountPoints;

  const StorageOverview({required this.mountPoints});

  factory StorageOverview.fromRpcData(dynamic data, {bool isReviewerMode = false}) {
    final list = <MountPointItem>[];

    if (data is String) {
      // Parse stdout of 'df -k' or 'df' (where blocks are given in 1K-blocks = KB)
      final lines = data.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('Filesystem')) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 6) {
          final dev = parts[0];
          final blocks = int.tryParse(parts[1]) ?? 0;
          final used = int.tryParse(parts[2]) ?? 0;
          final avail = int.tryParse(parts[3]) ?? 0;
          final target = parts[5];

          String fs = 'ext4';
          if (dev.contains('ubi')) {
            fs = 'ubifs';
          } else if (dev.contains('overlay')) {
            fs = 'overlayfs';
          } else if (dev == 'tmpfs' || target == '/tmp' || target == '/dev') {
            fs = 'tmpfs';
          } else if (dev.contains('root') || target == '/rom') {
            fs = 'squashfs';
          }

          list.add(MountPointItem(
            mountPath: target,
            device: dev,
            filesystemType: fs,
            sizeBytes: blocks * 1024,
            usedBytes: used * 1024,
            availableBytes: avail * 1024,
          ));
        }
      }
    } else if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          list.add(MountPointItem.fromJson(item));
        }
      }
    } else if (data is Map<String, dynamic>) {
      final inner = data['mountPoints'] ?? data['mounts'] ?? data['result'];
      if (inner is List) {
        for (final item in inner) {
          if (item is Map<String, dynamic>) {
            list.add(MountPointItem.fromJson(item));
          }
        }
      } else {
        data.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            final copy = Map<String, dynamic>.from(val);
            copy['mount'] ??= key;
            list.add(MountPointItem.fromJson(copy));
          }
        });
      }
    }

    // Default mock data only if in Reviewer Mode
    if (isReviewerMode && list.isEmpty) {
      list.addAll([
        const MountPointItem(
          mountPath: '/',
          device: '/dev/root',
          filesystemType: 'squashfs',
          sizeBytes: 134217728, // 128 MB
          usedBytes: 47185920,  // 45 MB
          availableBytes: 87031808,
        ),
        const MountPointItem(
          mountPath: '/overlay',
          device: '/dev/mtdblock6',
          filesystemType: 'ext4',
          sizeBytes: 67108864,  // 64 MB
          usedBytes: 16777216,  // 16 MB
          availableBytes: 50331648,
        ),
        const MountPointItem(
          mountPath: '/tmp',
          device: 'tmpfs',
          filesystemType: 'tmpfs',
          sizeBytes: 268435456, // 256 MB
          usedBytes: 2097152,   // 2 MB
          availableBytes: 266338304,
        ),
      ]);
    }

    return StorageOverview(mountPoints: list);
  }

  MountPointItem? get rootFs {
    if (mountPoints.isEmpty) return null;
    for (final m in mountPoints) {
      if (m.mountPath == '/') return m;
    }
    for (final m in mountPoints) {
      if (m.mountPath == '/rom' || m.device == '/dev/root') return m;
    }
    for (final m in mountPoints) {
      if (m.isRoot) return m;
    }
    return mountPoints.first;
  }

  MountPointItem? get overlayFs {
    if (mountPoints.isEmpty) return null;
    for (final m in mountPoints) {
      if (m.mountPath == '/overlay' || m.device.contains('ubi') || m.device.contains('overlay')) {
        return m;
      }
    }
    return null;
  }

  List<MountPointItem> get mountedDevices {
    return mountPoints;
  }

  int get totalSizeBytes {
    final primary = overlayFs ?? rootFs;
    final primarySize = primary?.sizeBytes ?? 0;
    int extraSize = 0;
    for (final m in mountPoints) {
      if (!m.isTmp && m != primary && m.mountPath != '/' && m.mountPath != '/rom' && m.mountPath != '/overlay') {
        extraSize += m.sizeBytes;
      }
    }
    return primarySize + extraSize;
  }

  int get totalUsedBytes {
    final primary = overlayFs ?? rootFs;
    final primaryUsed = primary?.usedBytes ?? 0;
    int extraUsed = 0;
    for (final m in mountPoints) {
      if (!m.isTmp && m != primary && m.mountPath != '/' && m.mountPath != '/rom' && m.mountPath != '/overlay') {
        extraUsed += m.usedBytes;
      }
    }
    return primaryUsed + extraUsed;
  }

  double get overallUsedPercent {
    final total = totalSizeBytes;
    if (total <= 0) return 0.0;
    return ((totalUsedBytes / total) * 100).clamp(0.0, 100.0);
  }
}
