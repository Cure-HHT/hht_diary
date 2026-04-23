/// Constructor-time identity of the process writing events. Stamps
/// `metadata.provenance[0]` on every event written through `EventStore`.
///
/// Renamed from `DeviceInfo` (Phase 4.4) and narrowed: the old `userId`
/// field moved out to the per-append `Initiator` argument, so one `Source`
/// instance can serve many authenticated users.
// Implements: REQ-d00142-A — rename of DeviceInfo; carries three fields
// (hopId, identifier, softwareVersion); no userId.
// Implements: REQ-d00142-B — hopId enumerates 'mobile-device' /
// 'portal-server' as well-known values; others permitted.
// Implements: REQ-d00142-C — softwareVersion follows REQ-d00115-E format;
// no runtime validation at this type.
class Source {
  const Source({
    required this.hopId,
    required this.identifier,
    required this.softwareVersion,
  });

  final String hopId;
  final String identifier;
  final String softwareVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          hopId == other.hopId &&
          identifier == other.identifier &&
          softwareVersion == other.softwareVersion);

  @override
  int get hashCode => Object.hash(hopId, identifier, softwareVersion);

  @override
  String toString() =>
      'Source(hopId: $hopId, identifier: $identifier, '
      'softwareVersion: $softwareVersion)';
}
