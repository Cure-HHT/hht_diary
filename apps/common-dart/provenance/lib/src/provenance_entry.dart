import 'package:provenance/src/batch_context.dart';

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
// Implements: REQ-d00115-G+H+I+J+K — optional receiver-only fields:
// arrival_hash, previous_ingest_hash, ingest_sequence_number, batch_context,
// origin_sequence_number.
class ProvenanceEntry {
  const ProvenanceEntry({
    required this.hop,
    required this.receivedAt,
    required this.identifier,
    required this.softwareVersion,
    this.transformVersion,
    this.arrivalHash,
    this.previousIngestHash,
    this.ingestSequenceNumber,
    this.batchContext,
    this.originSequenceNumber,
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
    final arrivalHash = _optionalString(json, 'arrival_hash');
    final previousIngestHash = _optionalString(json, 'previous_ingest_hash');
    final ingestSequenceNumber = _optionalInt(json, 'ingest_sequence_number');
    final originSequenceNumber = _optionalInt(json, 'origin_sequence_number');
    final batchContextRaw = json['batch_context'];
    BatchContext? batchContext;
    if (batchContextRaw != null) {
      if (batchContextRaw is! Map<String, Object?>) {
        throw const FormatException(
          'ProvenanceEntry: "batch_context" must be an object when present',
        );
      }
      batchContext = BatchContext.fromJson(batchContextRaw);
    }
    return ProvenanceEntry(
      hop: hop,
      receivedAt: receivedAt,
      identifier: identifier,
      softwareVersion: softwareVersion,
      transformVersion: transformVersionRaw as String?,
      arrivalHash: arrivalHash,
      previousIngestHash: previousIngestHash,
      ingestSequenceNumber: ingestSequenceNumber,
      batchContext: batchContext,
      originSequenceNumber: originSequenceNumber,
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

  // Implements: REQ-d00115-G — SHA-256 hex digest of the wire bytes of the
  // event as received at this hop.
  final String? arrivalHash;

  // Implements: REQ-d00115-H — arrival_hash of the previous event ingested
  // at this hop, forming a per-hop hash chain.
  final String? previousIngestHash;

  // Implements: REQ-d00115-I — monotonically increasing counter for events
  // ingested at this hop, starting at 0.
  final int? ingestSequenceNumber;

  // Implements: REQ-d00115-J — batch membership context when this event was
  // received as part of an ingestBatch call.
  final BatchContext? batchContext;

  // Implements: REQ-d00115-K — preserves the originator's sequence_number on
  // the receiver-hop entry. Receivers reassign a fresh local sequence_number
  // to the stored event so that origin and ingested events share one event
  // store keyed by one monotone counter; this field carries the wire-supplied
  // value so Chain 1 reconstruction can recover the originator's identity-
  // field set. Null on originator entries.
  final int? originSequenceNumber;

  // Implements: REQ-d00115-C — encode to snake_case JSON with an ISO 8601
  // `received_at` string that preserves the source timezone (Z suffix for
  // UTC). Receiver-only fields are omitted when null.
  Map<String, Object?> toJson() => <String, Object?>{
    'hop': hop,
    'received_at': receivedAt.toIso8601String(),
    'identifier': identifier,
    'software_version': softwareVersion,
    'transform_version': transformVersion,
    if (arrivalHash != null) 'arrival_hash': arrivalHash,
    if (previousIngestHash != null) 'previous_ingest_hash': previousIngestHash,
    if (ingestSequenceNumber != null)
      'ingest_sequence_number': ingestSequenceNumber,
    if (batchContext != null) 'batch_context': batchContext!.toJson(),
    if (originSequenceNumber != null)
      'origin_sequence_number': originSequenceNumber,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvenanceEntry &&
          hop == other.hop &&
          receivedAt == other.receivedAt &&
          identifier == other.identifier &&
          softwareVersion == other.softwareVersion &&
          transformVersion == other.transformVersion &&
          arrivalHash == other.arrivalHash &&
          previousIngestHash == other.previousIngestHash &&
          ingestSequenceNumber == other.ingestSequenceNumber &&
          batchContext == other.batchContext &&
          originSequenceNumber == other.originSequenceNumber;

  @override
  int get hashCode => Object.hash(
    hop,
    receivedAt,
    identifier,
    softwareVersion,
    transformVersion,
    arrivalHash,
    previousIngestHash,
    ingestSequenceNumber,
    batchContext,
    originSequenceNumber,
  );

  @override
  String toString() =>
      'ProvenanceEntry('
      'hop: $hop, '
      'receivedAt: ${receivedAt.toIso8601String()}, '
      'identifier: $identifier, '
      'softwareVersion: $softwareVersion, '
      'transformVersion: $transformVersion, '
      'arrivalHash: $arrivalHash, '
      'previousIngestHash: $previousIngestHash, '
      'ingestSequenceNumber: $ingestSequenceNumber, '
      'batchContext: $batchContext, '
      'originSequenceNumber: $originSequenceNumber)';
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

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'ProvenanceEntry: "$key" must be a String when present',
    );
  }
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException(
      'ProvenanceEntry: "$key" must be an int when present',
    );
  }
  return value;
}
