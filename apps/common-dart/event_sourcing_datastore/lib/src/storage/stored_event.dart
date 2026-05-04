import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:provenance/provenance.dart';

/// Represents a stored event with all fields populated.
///
/// Pure data — no Sembast or Flutter dependency on its shape — so it can
/// travel through the `StorageBackend` contract without leaking backend
/// details into the abstraction. Lives in `lib/src/storage/` alongside the
/// other value types (`DiaryEntry`, `FifoEntry`, etc.).
// Implements: REQ-d00118-A — first-class entry_type field on the event record.
// Implements: REQ-d00118-B — server_timestamp is NOT stored on the event;
// the ingesting server is the sole authority on its own timestamp.
// Implements: REQ-d00118-E — entry_type_version int field on the event record,
// caller-supplied to EventStore.append.
// Implements: REQ-d00118-F — lib_format_version int field on the event record,
// stamped by the lib from currentLibFormatVersion.
// Implements: REQ-d00135-C — top-level user_id replaced by initiator; no
// top-level user_id remains on StoredEvent.
// Implements: REQ-d00136-A — flowToken is a nullable String? column on the
// event record.
// Implements: REQ-d00141-E — currentLibFormatVersion constant defined here.
class StoredEvent {
  const StoredEvent({
    required this.key,
    required this.eventId,
    required this.aggregateId,
    required this.aggregateType,
    required this.entryType,
    required this.entryTypeVersion,
    required this.libFormatVersion,
    required this.eventType,
    required this.sequenceNumber,
    required this.data,
    required this.metadata,
    required this.initiator,
    required this.clientTimestamp,
    required this.eventHash,
    this.flowToken,
    this.previousEventHash,
  });

  /// Create from a database record map.
  ///
  /// Every required field is explicitly type-checked via an `is!` guard and
  /// a thrown [FormatException] naming the offending key. A malformed event
  /// record surfaces as a typed error rather than a generic `CastError` or
  /// `TypeError` at an unrelated call site, keeping diagnosis focused on the
  /// actual bad field.
  factory StoredEvent.fromMap(Map<String, Object?> map, int key) {
    final eventId = _requireString(map, 'event_id');
    final aggregateId = _requireString(map, 'aggregate_id');
    final aggregateType = _requireString(map, 'aggregate_type');
    final entryType = _requireString(map, 'entry_type');
    final entryTypeVersion = _requireInt(map, 'entry_type_version');
    final libFormatVersion = _requireInt(map, 'lib_format_version');
    final eventType = _requireString(map, 'event_type');
    final sequenceNumber = _requireInt(map, 'sequence_number');
    final data = _requireMap(map, 'data');
    final metadataRaw = map['metadata'];
    if (metadataRaw != null && metadataRaw is! Map) {
      throw const FormatException(
        'StoredEvent: "metadata" must be a Map when present',
      );
    }
    final metadata = metadataRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(metadataRaw as Map);

    final initiatorRaw = map['initiator'];
    if (initiatorRaw is! Map) {
      throw const FormatException(
        'StoredEvent: missing or non-map "initiator"',
      );
    }
    final initiator = Initiator.fromJson(
      Map<String, dynamic>.from(initiatorRaw),
    );

    final flowTokenRaw = map['flow_token'];
    if (flowTokenRaw != null && flowTokenRaw is! String) {
      throw const FormatException(
        'StoredEvent: "flow_token" must be a String when present',
      );
    }

    final clientTimestamp = _requireDateTime(map, 'client_timestamp');
    final eventHash = _requireString(map, 'event_hash');

    final previousHashRaw = map['previous_event_hash'];
    if (previousHashRaw != null && previousHashRaw is! String) {
      throw const FormatException(
        'StoredEvent: "previous_event_hash" must be a String when present',
      );
    }
    return StoredEvent(
      key: key,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      entryType: entryType,
      entryTypeVersion: entryTypeVersion,
      libFormatVersion: libFormatVersion,
      eventType: eventType,
      sequenceNumber: sequenceNumber,
      data: Map<String, dynamic>.from(data),
      metadata: metadata,
      initiator: initiator,
      flowToken: flowTokenRaw as String?,
      clientTimestamp: clientTimestamp,
      eventHash: eventHash,
      previousEventHash: previousHashRaw as String?,
    );
  }

  /// Test-only factory for constructing a `StoredEvent` with caller-
  /// supplied fields — no real hash chain, no sequence bookkeeping.
  /// Downstream packages' in-memory `StorageBackend` doubles use this
  /// to seed events without re-implementing hash chaining.
  @visibleForTesting
  factory StoredEvent.synthetic({
    required String eventId,
    required String aggregateId,
    required String entryType,
    required Initiator initiator,
    required DateTime clientTimestamp,
    required String eventHash,
    int key = 0,
    String aggregateType = 'DiaryEntry',
    String eventType = 'finalized',
    int sequenceNumber = 0,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    String? flowToken,
    String? previousEventHash,
    int entryTypeVersion = 1,
    int libFormatVersion = 1,
  }) => StoredEvent(
    key: key,
    eventId: eventId,
    aggregateId: aggregateId,
    aggregateType: aggregateType,
    entryType: entryType,
    entryTypeVersion: entryTypeVersion,
    libFormatVersion: libFormatVersion,
    eventType: eventType,
    sequenceNumber: sequenceNumber,
    data: data ?? const <String, dynamic>{},
    metadata: metadata ?? const <String, dynamic>{},
    initiator: initiator,
    flowToken: flowToken,
    clientTimestamp: clientTimestamp,
    eventHash: eventHash,
    previousEventHash: previousEventHash,
  );

  /// Storage shape version the current lib build produces. Stamped on every
  /// event by `EventStore.append` and propagated over the wire. Receivers
  /// reject events whose `lib_format_version > currentLibFormatVersion` per
  /// REQ-d00145-L.
  // Implements: REQ-d00141-E.
  static const int currentLibFormatVersion = 1;

  /// Database key.
  final int key;

  /// Unique event ID (UUID v4).
  final String eventId;

  /// ID of the aggregate this event belongs to.
  final String aggregateId;

  /// Type of aggregate (e.g., 'DiaryEntry').
  final String aggregateType;

  /// Kind of patient-recorded or administered entry (e.g., 'epistaxis_event',
  /// 'nose_hht_survey'). First-class per REQ-d00118-A.
  final String entryType;

  /// Application schema version under which this event was authored.
  /// Caller-supplied to `EventStore.append`. Preserved verbatim across the
  /// wire and receiver ingest.
  // Implements: REQ-d00118-E.
  final int entryTypeVersion;

  /// Storage shape version this event was persisted with. Stamped by the
  /// lib from [currentLibFormatVersion] on every append.
  // Implements: REQ-d00118-F.
  final int libFormatVersion;

  /// User-intent discriminator for the event: 'finalized' | 'checkpoint' |
  /// 'tombstone'.
  final String eventType;

  /// Monotonically increasing sequence number.
  final int sequenceNumber;

  /// Event payload data (JSON).
  final Map<String, dynamic> data;

  /// Additional metadata; typically carries `change_reason` and
  /// `provenance[]`.
  final Map<String, dynamic> metadata;

  /// Actor that initiated this event. Replaces the Phase-4.3 top-level
  /// `userId` field.
  final Initiator initiator;

  /// Client-side timestamp when event was created.
  final DateTime clientTimestamp;

  /// Correlation token linking events that belong to the same multi-step
  /// business flow (e.g., `invite:ABC123`). Nullable; the library does not
  /// enforce format.
  final String? flowToken;

  /// SHA-256 hash of event for tamper detection.
  final String eventHash;

  /// Hash of previous event (for chain integrity).
  final String? previousEventHash;

  /// First `ProvenanceEntry` in this event's chain — the originator's hop.
  ///
  /// Materialized from `metadata['provenance'][0]` on each access. Convenience
  /// accessor for cross-hop discrimination logic (e.g.
  /// `EventStore.isLocallyOriginated`) and for read-side queries that
  /// project on originator identity. Throws `StateError` when the
  /// provenance list is missing, non-list, or empty: REQ-d00115 requires
  /// every event to carry at least one provenance entry, so an absent or
  /// empty list indicates corrupted or malformed data and surfacing it
  /// loudly is the right behavior.
  // Implements: REQ-d00154-A — originator hop convenience getter; throws
  // StateError on empty/missing provenance per the assertion contract.
  ProvenanceEntry get originatorHop {
    final raw = metadata['provenance'];
    if (raw is! List || raw.isEmpty) {
      throw StateError(
        'StoredEvent has empty or missing provenance; expected at least the '
        'originator entry per REQ-d00115',
      );
    }
    final first = raw.first;
    if (first is! Map) {
      throw StateError(
        'StoredEvent provenance[0] is not a Map; cannot decode originator hop',
      );
    }
    return ProvenanceEntry.fromJson(Map<String, Object?>.from(first));
  }

  /// Convert to a map for storage/serialization.
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'aggregate_id': aggregateId,
      'aggregate_type': aggregateType,
      'entry_type': entryType,
      'entry_type_version': entryTypeVersion,
      'lib_format_version': libFormatVersion,
      'event_type': eventType,
      'sequence_number': sequenceNumber,
      'data': data,
      'metadata': metadata,
      'initiator': initiator.toJson(),
      'flow_token': flowToken,
      'client_timestamp': clientTimestamp.toIso8601String(),
      'event_hash': eventHash,
      'previous_event_hash': previousEventHash,
    };
  }

  /// Convert to JSON for API calls.
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'StoredEvent(eventId: $eventId, entryType: $entryType, '
        'eventType: $eventType, seq: $sequenceNumber)';
  }
}

String _requireString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('StoredEvent: missing or non-string "$key"');
  }
  return value;
}

int _requireInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('StoredEvent: missing or non-int "$key"');
  }
  return value;
}

Map<Object?, Object?> _requireMap(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! Map) {
    throw FormatException('StoredEvent: missing or non-map "$key"');
  }
  return value;
}

DateTime _requireDateTime(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException(
      'StoredEvent: missing or non-string "$key" (expected ISO 8601)',
    );
  }
  try {
    return DateTime.parse(value);
  } on FormatException catch (e) {
    throw FormatException(
      'StoredEvent: "$key" is not a valid ISO 8601 string: ${e.message}',
    );
  }
}
