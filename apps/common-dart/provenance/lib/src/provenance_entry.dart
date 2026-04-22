/// One hop's attribution in a cross-system event's chain-of-custody.
///
/// Mobile-device, diary-server, portal-server, and EDC hops each append one
/// `ProvenanceEntry` to `event.metadata.provenance` when they receive the
/// event. The class is pure data; the append-and-don't-mutate invariants live
/// in the `appendHop()` helper.
///
/// `receivedAt` is a UTC or timezone-offset-explicit instant; `fromJson`
/// rejects offsetless ISO 8601 strings to preserve the ALCOA+
/// *Contemporaneous* guarantee (REQ-d00115-C).
///
/// `identifier` and `softwareVersion` shape rules (REQ-d00115-D, -E) are
/// **permanent caller obligations**, not deferred validation: the source of
/// each hop — mobile device, diary server, portal — is the only place that
/// knows which shape applies, so there is no hop-ingress validator that can
/// take ownership. The type documents the contract; callers construct
/// conforming values.
///
// Implements: REQ-d00115-C+D+E+F — immutable value type carrying hop,
// received_at, identifier, software_version, and optional transform_version.
// received_at offset validation enforced at the JSON boundary;
// identifier and software_version shapes are caller obligations by design.
class ProvenanceEntry {
  const ProvenanceEntry({
    required this.hop,
    required this.receivedAt,
    required this.identifier,
    required this.softwareVersion,
    this.transformVersion,
  });

  // Implements: REQ-d00115-C — decode from snake_case JSON; reject payloads
  // missing any required field, with wrong types, or with a received_at that
  // lacks an explicit timezone offset (Z or ±HH[:]MM). An offsetless string
  // would be silently interpreted as local time, breaking the ALCOA+
  // Contemporaneous guarantee in a cross-system audit chain.
  factory ProvenanceEntry.fromJson(Map<String, Object?> json) {
    final hop = _requireString(json, 'hop');
    final receivedAtRaw = _requireString(json, 'received_at');
    final identifier = _requireString(json, 'identifier');
    final softwareVersion = _requireString(json, 'software_version');
    final transformVersionRaw = json['transform_version'];
    if (transformVersionRaw != null && transformVersionRaw is! String) {
      throw const FormatException(
        'ProvenanceEntry: "transform_version" must be a String when present',
      );
    }
    if (!_offsetPattern.hasMatch(receivedAtRaw)) {
      throw FormatException(
        'ProvenanceEntry: "received_at" must include an explicit timezone '
        'offset (Z or +/-HH[:]MM); got "$receivedAtRaw"',
      );
    }
    final DateTime receivedAt;
    try {
      receivedAt = DateTime.parse(receivedAtRaw);
    } on FormatException catch (e) {
      throw FormatException(
        'ProvenanceEntry: "received_at" is not a valid ISO 8601 string: '
        '${e.message}',
      );
    }
    return ProvenanceEntry(
      hop: hop,
      receivedAt: receivedAt,
      identifier: identifier,
      softwareVersion: softwareVersion,
      transformVersion: transformVersionRaw as String?,
    );
  }

  final String hop;

  /// The instant this hop received the event.
  ///
  /// Parsed from the `received_at` string by `DateTime.parse`, which
  /// UTC-normalizes any offsetful ISO 8601 timestamp: the absolute instant
  /// is preserved but the original offset is not retained on this field.
  /// `toJson()` therefore re-emits the value as a `Z`-suffixed UTC string
  /// via `toIso8601String()`, not as the original offset string.
  ///
  /// Consumers that need the source-side clock offset (e.g., an audit-trail
  /// inspector displaying "which wall clock wrote this?") must read the raw
  /// JSON string before parsing; it is not recoverable from this field.
  final DateTime receivedAt;
  final String identifier;
  final String softwareVersion;
  final String? transformVersion;

  // Implements: REQ-d00115-C — encode to snake_case JSON with an ISO 8601
  // `received_at` string that preserves the source timezone (Z suffix for
  // UTC).
  Map<String, Object?> toJson() => <String, Object?>{
    'hop': hop,
    'received_at': receivedAt.toIso8601String(),
    'identifier': identifier,
    'software_version': softwareVersion,
    'transform_version': transformVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvenanceEntry &&
          hop == other.hop &&
          receivedAt == other.receivedAt &&
          identifier == other.identifier &&
          softwareVersion == other.softwareVersion &&
          transformVersion == other.transformVersion;

  @override
  int get hashCode => Object.hash(
    hop,
    receivedAt,
    identifier,
    softwareVersion,
    transformVersion,
  );

  @override
  String toString() =>
      'ProvenanceEntry('
      'hop: $hop, '
      'receivedAt: ${receivedAt.toIso8601String()}, '
      'identifier: $identifier, '
      'softwareVersion: $softwareVersion, '
      'transformVersion: $transformVersion)';
}

// REQ-d00115-C timezone-offset regex: matches a trailing Z or ±HH[:]MM
// (including hour-only ±HH) at the end of the string. The positive-lookbehind
// `(?<=\d)` requires the offset to immediately follow a digit, so strings
// like "foo+0500" do not sneak past this layer (DateTime.parse rejects them
// too, so this is defense-in-depth).
final RegExp _offsetPattern = RegExp(r'(?<=\d)(Z|[+-]\d{2}(:?\d{2})?)$');

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('ProvenanceEntry: missing or non-string "$key"');
  }
  return value;
}
