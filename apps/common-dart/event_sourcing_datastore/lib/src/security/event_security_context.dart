import 'package:event_sourcing_datastore/src/security/security_retention_policy.dart';

/// Sidecar row recording security telemetry for one event. Lives in its
/// own sembast store (`security_context`) keyed on `eventId`. The
/// foreign-key direction is one-way: `security_context.event_id` → the
/// event log's `event_id`. The event row holds no reference back to
/// security, so redacting telemetry never touches the legal event record.
// Implements: REQ-d00137-A+B — sidecar store separate from event log;
// one-way FK security → event.
class EventSecurityContext {
  const EventSecurityContext({
    required this.eventId,
    required this.recordedAt,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    this.geoCountry,
    this.geoRegion,
    this.requestId,
    this.redactedAt,
    this.redactionReason,
  });

  factory EventSecurityContext.fromJson(Map<String, Object?> json) {
    final eventId = json['event_id'];
    if (eventId is! String) {
      throw const FormatException(
        'EventSecurityContext: missing or non-string "event_id"',
      );
    }
    final recordedAtRaw = json['recorded_at'];
    if (recordedAtRaw is! String) {
      throw const FormatException(
        'EventSecurityContext: missing or non-string "recorded_at"',
      );
    }
    final recordedAt = DateTime.parse(recordedAtRaw);
    String? optString(String key) {
      final v = json[key];
      if (v != null && v is! String) {
        throw FormatException(
          'EventSecurityContext: "$key" must be a String when present',
        );
      }
      return v as String?;
    }

    DateTime? optDateTime(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is! String) {
        throw FormatException(
          'EventSecurityContext: "$key" must be an ISO 8601 String when present',
        );
      }
      return DateTime.parse(v);
    }

    return EventSecurityContext(
      eventId: eventId,
      recordedAt: recordedAt,
      ipAddress: optString('ip_address'),
      userAgent: optString('user_agent'),
      sessionId: optString('session_id'),
      geoCountry: optString('geo_country'),
      geoRegion: optString('geo_region'),
      requestId: optString('request_id'),
      redactedAt: optDateTime('redacted_at'),
      redactionReason: optString('redaction_reason'),
    );
  }

  final String eventId;
  final DateTime recordedAt;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final String? geoCountry;
  final String? geoRegion;
  final String? requestId;
  final DateTime? redactedAt;
  final String? redactionReason;

  Map<String, Object?> toJson() => <String, Object?>{
    'event_id': eventId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'session_id': sessionId,
    'geo_country': geoCountry,
    'geo_region': geoRegion,
    'request_id': requestId,
    'redacted_at': redactedAt?.toUtc().toIso8601String(),
    'redaction_reason': redactionReason,
  };

  /// Apply a retention policy's truncation rules to this row. Used by
  /// `EventStore.applyRetentionPolicy` on the compact sweep.
  // Implements: REQ-d00138-B — per-policy-flag truncation of IP, user
  // agent, and geo fields.
  EventSecurityContext applyTruncation(SecurityRetentionPolicy policy) {
    return EventSecurityContext(
      eventId: eventId,
      recordedAt: recordedAt,
      ipAddress: _truncateIp(ipAddress, policy),
      userAgent: policy.dropUserAgentAfterFull ? null : userAgent,
      sessionId: sessionId,
      geoCountry: policy.dropGeoAfterFull ? null : geoCountry,
      geoRegion: policy.dropGeoAfterFull ? null : geoRegion,
      requestId: requestId,
      redactedAt: redactedAt,
      redactionReason: redactionReason,
    );
  }

  static String? _truncateIp(String? ip, SecurityRetentionPolicy policy) {
    if (ip == null) return null;
    if (ip.contains('.') && policy.truncateIpv4LastOctet) {
      final octets = ip.split('.');
      if (octets.length == 4) {
        return '${octets[0]}.${octets[1]}.${octets[2]}.0';
      }
    } else if (ip.contains(':') && policy.truncateIpv6Suffix) {
      final groups = ip.split(':');
      if (groups.length >= 3) {
        final keep = groups.sublist(0, 3).join(':');
        return '$keep::';
      }
    }
    return ip;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSecurityContext &&
          eventId == other.eventId &&
          recordedAt == other.recordedAt &&
          ipAddress == other.ipAddress &&
          userAgent == other.userAgent &&
          sessionId == other.sessionId &&
          geoCountry == other.geoCountry &&
          geoRegion == other.geoRegion &&
          requestId == other.requestId &&
          redactedAt == other.redactedAt &&
          redactionReason == other.redactionReason);

  @override
  int get hashCode => Object.hash(
    eventId,
    recordedAt,
    ipAddress,
    userAgent,
    sessionId,
    geoCountry,
    geoRegion,
    requestId,
    redactedAt,
    redactionReason,
  );

  @override
  String toString() =>
      'EventSecurityContext(eventId: $eventId, recordedAt: $recordedAt, '
      'ipAddress: $ipAddress)';
}
