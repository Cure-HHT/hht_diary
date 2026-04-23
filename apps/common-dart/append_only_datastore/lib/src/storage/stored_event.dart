/// Represents a stored event with all fields populated.
///
/// Pure data — no Sembast or Flutter dependency — so it can travel through
/// the `StorageBackend` contract without leaking backend details into the
/// abstraction. Lives in `lib/src/storage/` alongside the other value types
/// (`DiaryEntry`, `FifoEntry`, etc.).
// Implements: REQ-d00118-A — first-class entry_type field on the event record.
// Implements: REQ-d00118-B — server_timestamp is NOT stored on the event;
// the ingesting server is the sole authority on its own timestamp.
class StoredEvent {
  const StoredEvent({
    required this.key,
    required this.eventId,
    required this.aggregateId,
    required this.aggregateType,
    required this.entryType,
    required this.eventType,
    required this.sequenceNumber,
    required this.data,
    required this.metadata,
    required this.userId,
    required this.deviceId,
    required this.clientTimestamp,
    required this.eventHash,
    this.softwareVersion = '',
    this.previousEventHash,
    this.syncedAt,
  });

  /// Create from a database record map.
  ///
  /// Every required field is explicitly type-checked via an `is!` guard and a
  /// thrown [FormatException] naming the offending key. A malformed event
  /// record surfaces as a typed error rather than a generic `CastError` or
  /// `TypeError` at an unrelated call site, keeping diagnosis focused on the
  /// actual bad field.
  factory StoredEvent.fromMap(Map<String, Object?> map, int key) {
    final eventId = _requireString(map, 'event_id');
    final aggregateId = _requireString(map, 'aggregate_id');
    final aggregateType = _requireString(map, 'aggregate_type');
    final entryType = _requireString(map, 'entry_type');
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
    final userId = _requireString(map, 'user_id');
    final deviceId = _requireString(map, 'device_id');
    final clientTimestamp = _requireDateTime(map, 'client_timestamp');
    final eventHash = _requireString(map, 'event_hash');
    // REQ-d00118-C / REQ-d00133-I — software_version is a migration-bridge
    // top-level field populated from metadata.provenance[0] by
    // EntryService.record. Optional on legacy records written before the
    // EntryService path was introduced; stored as empty string when absent.
    final softwareVersionRaw = map['software_version'];
    if (softwareVersionRaw != null && softwareVersionRaw is! String) {
      throw const FormatException(
        'StoredEvent: "software_version" must be a String when present',
      );
    }
    final softwareVersion = (softwareVersionRaw as String?) ?? '';
    final previousHashRaw = map['previous_event_hash'];
    if (previousHashRaw != null && previousHashRaw is! String) {
      throw const FormatException(
        'StoredEvent: "previous_event_hash" must be a String when present',
      );
    }
    final syncedAtRaw = map['synced_at'];
    if (syncedAtRaw != null && syncedAtRaw is! String) {
      throw const FormatException(
        'StoredEvent: "synced_at" must be an ISO 8601 String when present',
      );
    }
    final DateTime? syncedAt;
    if (syncedAtRaw == null) {
      syncedAt = null;
    } else {
      try {
        syncedAt = DateTime.parse(syncedAtRaw as String);
      } on FormatException catch (e) {
        throw FormatException(
          'StoredEvent: "synced_at" is not a valid ISO 8601 string: '
          '${e.message}',
        );
      }
    }
    return StoredEvent(
      key: key,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      entryType: entryType,
      eventType: eventType,
      sequenceNumber: sequenceNumber,
      data: Map<String, dynamic>.from(data),
      metadata: metadata,
      userId: userId,
      deviceId: deviceId,
      clientTimestamp: clientTimestamp,
      eventHash: eventHash,
      softwareVersion: softwareVersion,
      previousEventHash: previousHashRaw as String?,
      syncedAt: syncedAt,
    );
  }

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

  /// User-intent discriminator for the event: 'finalized' | 'checkpoint' |
  /// 'tombstone' in the target design, though legacy writers currently supply
  /// NosebleedRecorded/NosebleedDeleted until Phase 5 cuts over.
  final String eventType;

  /// Monotonically increasing sequence number.
  final int sequenceNumber;

  /// Event payload data (JSON).
  final Map<String, dynamic> data;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// User who created this event.
  final String userId;

  /// Device that created this event.
  final String deviceId;

  /// Client-side timestamp when event was created.
  final DateTime clientTimestamp;

  /// Software version that authored this event, populated from
  /// `metadata.provenance[0].software_version` by `EntryService.record`
  /// (REQ-d00118-C, REQ-d00133-I). Empty string on legacy records written
  /// before the EntryService path was introduced.
  final String softwareVersion;

  /// SHA-256 hash of event for tamper detection.
  final String eventHash;

  /// Hash of previous event (for chain integrity).
  final String? previousEventHash;

  /// When this event was synced to the server (null if not synced).
  final DateTime? syncedAt;

  /// Whether this event has been synced.
  bool get isSynced => syncedAt != null;

  /// Convert to a map for storage/serialization.
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'aggregate_id': aggregateId,
      'aggregate_type': aggregateType,
      'entry_type': entryType,
      'event_type': eventType,
      'sequence_number': sequenceNumber,
      'data': data,
      'metadata': metadata,
      'user_id': userId,
      'device_id': deviceId,
      'client_timestamp': clientTimestamp.toIso8601String(),
      'software_version': softwareVersion,
      'event_hash': eventHash,
      'previous_event_hash': previousEventHash,
      'synced_at': syncedAt?.toIso8601String(),
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
