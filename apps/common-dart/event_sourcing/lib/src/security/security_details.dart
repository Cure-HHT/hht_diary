/// Immutable input passed by `EventStore.append` callers when the event
/// should carry security telemetry. Dispatcher stamps `eventId` and
/// `recordedAt` on write; redaction fields are set by the retention
/// policy or explicit `clearSecurityContext`, never by the caller.
class SecurityDetails {
  const SecurityDetails({
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    this.geoCountry,
    this.geoRegion,
    this.requestId,
  });

  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final String? geoCountry;
  final String? geoRegion;
  final String? requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityDetails &&
          ipAddress == other.ipAddress &&
          userAgent == other.userAgent &&
          sessionId == other.sessionId &&
          geoCountry == other.geoCountry &&
          geoRegion == other.geoRegion &&
          requestId == other.requestId);

  @override
  int get hashCode => Object.hash(
    ipAddress,
    userAgent,
    sessionId,
    geoCountry,
    geoRegion,
    requestId,
  );
}
