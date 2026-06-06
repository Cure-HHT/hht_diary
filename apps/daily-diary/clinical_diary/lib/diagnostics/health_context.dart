import 'package:event_sourcing/event_sourcing.dart' show StorageBackend;

/// Device-clock facts captured at probe time.
class ClockInfo {
  const ClockInfo({
    required this.deviceNow,
    required this.ianaZone,
    required this.utcOffsetMinutes,
  });

  final DateTime deviceNow;
  final String ianaZone;
  final int utcOffsetMinutes;
}

/// App/build/platform version facts captured at probe time.
class VersionInfo {
  const VersionInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.os,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String os;
}

/// Everything a health check or the raw-appendix builder needs to probe the
/// device. Resolved by the caller (UI layer) before running checks; the
/// pure-Dart core never reaches outside this context.
class HealthProbeContext {
  const HealthProbeContext({
    required this.backend,
    required this.destinationIds,
    required this.everLinked,
    required this.linked,
    required this.tokenLive,
    required this.clock,
    required this.version,
    required this.deviceId,
  });

  final StorageBackend backend;

  /// Destination ids resolved by the caller from the destination registry.
  final List<String> destinationIds;

  /// Whether the device has ever been linked to a sponsor.
  final bool everLinked;

  /// Whether the device is currently linked.
  final bool linked;

  /// Whether an auth token is present and unexpired.
  final bool tokenLive;

  final ClockInfo clock;
  final VersionInfo version;
  final String deviceId;
}
