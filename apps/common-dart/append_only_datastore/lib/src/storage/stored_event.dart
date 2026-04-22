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
    this.previousEventHash,
    this.syncedAt,
  });

  /// Create from a database record map.
  factory StoredEvent.fromMap(Map<String, Object?> map, int key) {
    final entryType = map['entry_type'];
    if (entryType is! String) {
      throw const FormatException(
        'StoredEvent: missing or non-string "entry_type"',
      );
    }
    return StoredEvent(
      key: key,
      eventId: map['event_id'] as String,
      aggregateId: map['aggregate_id'] as String,
      aggregateType: map['aggregate_type'] as String,
      entryType: entryType,
      eventType: map['event_type'] as String,
      sequenceNumber: map['sequence_number'] as int,
      data: Map<String, dynamic>.from(map['data'] as Map),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      userId: map['user_id'] as String,
      deviceId: map['device_id'] as String,
      clientTimestamp: DateTime.parse(map['client_timestamp'] as String),
      eventHash: map['event_hash'] as String,
      previousEventHash: map['previous_event_hash'] as String?,
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
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
