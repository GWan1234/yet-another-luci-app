/// Shared release channel derivation utility.
///
/// Inspects all string values in an OpenWrt `/etc/os-release` or `/etc/openwrt_release`
/// ubus response payload to determine if the router firmware is running `snapshot`,
/// `beta`, `rc`, `testing`, or `stable`.
String deriveReleaseChannel(Map<String, dynamic>? release) {
  if (release == null || release.isEmpty) {
    return 'stable';
  }

  final buffer = StringBuffer();
  // Check ALL release fields
  for (final value in release.values) {
    if (value == null) continue;
    buffer
      ..write(' ')
      ..write(value.toString().toLowerCase());
  }

  final combined = buffer.toString();

  if (combined.contains('snapshot')) {
    return 'snapshot';
  }
  if (combined.contains('beta')) {
    return 'beta';
  }
  // Use pattern matching for 'rc' to avoid false positives on words like "source"
  if (RegExp(r'[\b\-_.]rc[\d\b\-_.]').hasMatch(combined) ||
      combined.contains('-rc') ||
      combined.endsWith('rc')) {
    return 'rc';
  }
  if (combined.contains('testing')) {
    return 'testing';
  }

  return 'stable';
}
