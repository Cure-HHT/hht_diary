/// Constructor-time identity of the process writing events. Stamps
/// `metadata.provenance[0]` on every event written through `EventStore`.
///
/// `identifier` is the per-installation unique identity (REQ-d00142-D).
/// Production callers MUST persist a globally-unique value (UUIDv4
/// recommended) on first install and pass the same value on every
/// subsequent bootstrap. The library does NOT validate the format at
/// runtime — callers that violate the global-uniqueness requirement get
/// correct lib behavior on each install in isolation but produce data
/// that collides on receivers when bridged. System audit aggregate_ids
/// equal `source.identifier` (REQ-d00134-E, REQ-d00129-J/K/L/M,
/// REQ-d00138-D/E/F/H), so two installs that share an identifier share
/// a system aggregate on any receiver they both bridge to.
///
/// `hopId` is the role-class string (e.g. `'mobile-device'`,
/// `'portal-server'` per REQ-d00142-B). Two installations of the same
/// role class are distinct originators — discrimination on
/// `EventStore.isLocallyOriginated` (REQ-d00154-B) compares
/// `identifier`, not `hopId`.
// Implements: REQ-d00142-A — three fields: hopId, identifier, softwareVersion.
// Implements: REQ-d00142-B — hopId enumerates 'mobile-device' /
//   'portal-server' as well-known values; others permitted.
// Implements: REQ-d00142-C — softwareVersion follows REQ-d00115-E format;
//   no runtime validation at this type.
// Implements: REQ-d00142-D — identifier is the per-installation unique
//   identity; library does not validate format; caller obligation to
//   persist + reuse across boots.
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
