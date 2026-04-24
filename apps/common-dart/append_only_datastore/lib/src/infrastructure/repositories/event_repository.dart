// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:convert';

import 'package:append_only_datastore/src/core/errors/datastore_exception.dart'
    as errors;
import 'package:append_only_datastore/src/infrastructure/database/database_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

/// Repository for append-only event storage.
///
/// This repository implements the event sourcing pattern where:
/// - Events are immutable once written (append-only)
/// - Each event has a unique ID and sequence number
/// - Events include cryptographic hashes for tamper detection
/// - Current state is derived by replaying events
///
/// ## FDA 21 CFR Part 11 Compliance
///
/// - **Immutability**: Events cannot be modified or deleted after creation
/// - **Audit Trail**: Every event includes timestamp, user, device info
/// - **Tamper Detection**: SHA-256 hash chain links events
/// - **Sequence Integrity**: Monotonic sequence numbers detect gaps
///
/// ## Usage
///
/// ```dart
/// final repo = EventRepository(databaseProvider: provider);
///
/// // Append a new event
/// final event = await repo.append(
///   aggregateId: 'diary-entry-123',
///   eventType: 'NosebleedRecorded',
///   data: {'severity': 'mild', 'duration': 10},
///   userId: 'user-456',
///   deviceId: 'device-789',
/// );
///
/// // Query events for an aggregate
/// final events = await repo.getEventsForAggregate('diary-entry-123');
///
/// // Get all unsynced events
/// final unsynced = await repo.getUnsyncedEvents();
/// ```
class EventRepository {
  EventRepository({required this.databaseProvider});

  /// The database provider.
  final DatabaseProvider databaseProvider;

  /// The Sembast store for events.
  final StoreRef<int, Map<String, Object?>> _eventStore = intMapStoreFactory
      .store('events');

  /// The Sembast store for metadata (sequence counter, etc).
  final StoreRef<String, Object?> _metaStore = StoreRef<String, Object?>(
    'metadata',
  );

  /// UUID generator.
  static const _uuid = Uuid();

  /// Key for the sequence counter in metadata store.
  static const _sequenceKey = 'sequence_counter';

  /// Append a new event to the store.
  ///
  /// This is the primary way to record data changes. Events are immutable
  /// once written - they cannot be updated or deleted.
  ///
  /// Returns the created [StoredEvent] with all generated fields populated.
  ///
  /// Throws [errors.EventValidationException] if required fields are missing.
  /// Throws [errors.DatabaseException] if the write fails.
  Future<StoredEvent> append({
    required String aggregateId,
    required String eventType,
    required Map<String, dynamic> data,
    required String userId,
    required String deviceId,
    String? aggregateType,
    DateTime? clientTimestamp,
    Map<String, dynamic>? metadata,
  }) async {
    final db = databaseProvider.database;

    try {
      return await db.transaction((txn) async {
        // Get next sequence number
        final sequenceNumber = await _getNextSequenceNumber(txn);

        // Get previous event hash for chain
        final previousHash = await _getPreviousEventHash(txn);

        // Generate event ID
        final eventId = _uuid.v4();

        // Create timestamp
        final serverTimestamp = DateTime.now().toUtc();
        final clientTs = clientTimestamp?.toUtc() ?? serverTimestamp;

        // Build event record
        final eventRecord = <String, dynamic>{
          'event_id': eventId,
          'aggregate_id': aggregateId,
          'aggregate_type': aggregateType ?? 'DiaryEntry',
          'event_type': eventType,
          'sequence_number': sequenceNumber,
          'data': data,
          'metadata': metadata ?? <String, dynamic>{},
          'user_id': userId,
          'device_id': deviceId,
          'client_timestamp': clientTs.toIso8601String(),
          'server_timestamp': serverTimestamp.toIso8601String(),
          'previous_event_hash': previousHash,
          'synced_at': null,
        };

        // Calculate hash (includes previous hash for chain)
        final eventHash = _calculateEventHash(eventRecord);
        eventRecord['event_hash'] = eventHash;

        // Store the event
        final key = await _eventStore.add(txn, eventRecord);

        // Update sequence counter
        await _metaStore.record(_sequenceKey).put(txn, sequenceNumber);

        return StoredEvent.fromMap(eventRecord, key);
      });
    } catch (e, stackTrace) {
      if (e is errors.DatastoreException) rethrow;
      throw errors.DatabaseException(
        'Failed to append event: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all events for a specific aggregate.
  ///
  /// Returns events in sequence order (oldest first).
  Future<List<StoredEvent>> getEventsForAggregate(String aggregateId) async {
    final db = databaseProvider.database;

    try {
      final finder = Finder(
        filter: Filter.equals('aggregate_id', aggregateId),
        sortOrders: [SortOrder('sequence_number')],
      );

      final records = await _eventStore.find(db, finder: finder);

      return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to query events for aggregate $aggregateId: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all events that haven't been synced to the server.
  ///
  /// Returns events in sequence order (oldest first).
  Future<List<StoredEvent>> getUnsyncedEvents() async {
    final db = databaseProvider.database;

    try {
      final finder = Finder(
        filter: Filter.isNull('synced_at'),
        sortOrders: [SortOrder('sequence_number')],
      );

      final records = await _eventStore.find(db, finder: finder);

      return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to query unsynced events: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Mark events as synced.
  ///
  /// This updates the synced_at timestamp for the specified events.
  /// Note: This is the ONLY modification allowed on events (for sync tracking).
  Future<void> markEventsSynced(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    final db = databaseProvider.database;
    final syncedAt = DateTime.now().toUtc().toIso8601String();

    try {
      await db.transaction((txn) async {
        for (final eventId in eventIds) {
          final finder = Finder(filter: Filter.equals('event_id', eventId));
          final records = await _eventStore.find(txn, finder: finder);

          if (records.isNotEmpty) {
            final record = records.first;
            final updated = Map<String, Object?>.from(record.value);
            updated['synced_at'] = syncedAt;
            await _eventStore.record(record.key).put(txn, updated);
          }
        }
      });
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to mark events as synced: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the count of unsynced events.
  Future<int> getUnsyncedCount() async {
    final db = databaseProvider.database;

    try {
      final filter = Filter.isNull('synced_at');
      return await _eventStore.count(db, filter: filter);
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to count unsynced events: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all events in sequence order.
  ///
  /// Returns events oldest first.
  Future<List<StoredEvent>> getAllEvents() async {
    final db = databaseProvider.database;

    try {
      final finder = Finder(sortOrders: [SortOrder('sequence_number')]);
      final records = await _eventStore.find(db, finder: finder);

      return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to query all events: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the latest sequence number.
  Future<int> getLatestSequenceNumber() async {
    final db = databaseProvider.database;

    try {
      final value = await _metaStore.record(_sequenceKey).get(db);
      return (value as int?) ?? 0;
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to get latest sequence number: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Verify the integrity of the event chain.
  ///
  /// Returns true if all events have valid hashes and the chain is intact.
  /// Returns false if any tampering is detected.
  Future<bool> verifyIntegrity() async {
    final events = await getAllEvents();

    String? previousHash;
    for (final event in events) {
      // Verify hash chain
      if (event.previousEventHash != previousHash) {
        return false;
      }

      // Verify event hash
      final calculatedHash = _calculateEventHash(event.toMap());
      if (calculatedHash != event.eventHash) {
        return false;
      }

      previousHash = event.eventHash;
    }

    return true;
  }

  /// Get the next sequence number within a transaction.
  Future<int> _getNextSequenceNumber(DatabaseClient txn) async {
    final current = await _metaStore.record(_sequenceKey).get(txn);
    return ((current as int?) ?? 0) + 1;
  }

  /// Get the hash of the previous event within a transaction.
  Future<String?> _getPreviousEventHash(DatabaseClient txn) async {
    final finder = Finder(
      sortOrders: [SortOrder('sequence_number', false)],
      limit: 1,
    );

    final records = await _eventStore.find(txn, finder: finder);
    if (records.isEmpty) return null;

    return records.first.value['event_hash'] as String?;
  }

  /// Calculate SHA-256 hash of event data.
  String _calculateEventHash(Map<String, dynamic> eventRecord) {
    // Create a deterministic JSON representation (excluding the hash itself)
    final hashInput = <String, dynamic>{
      'event_id': eventRecord['event_id'],
      'aggregate_id': eventRecord['aggregate_id'],
      'event_type': eventRecord['event_type'],
      'sequence_number': eventRecord['sequence_number'],
      'data': eventRecord['data'],
      'user_id': eventRecord['user_id'],
      'device_id': eventRecord['device_id'],
      'client_timestamp': eventRecord['client_timestamp'],
      'previous_event_hash': eventRecord['previous_event_hash'],
    };

    final jsonString = jsonEncode(hashInput);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }
}

/// Represents a stored event with all fields populated.
class StoredEvent {
  const StoredEvent({
    required this.key,
    required this.eventId,
    required this.aggregateId,
    required this.aggregateType,
    required this.eventType,
    required this.sequenceNumber,
    required this.data,
    required this.metadata,
    required this.userId,
    required this.deviceId,
    required this.clientTimestamp,
    required this.serverTimestamp,
    required this.eventHash,
    this.previousEventHash,
    this.syncedAt,
  });

  /// Create from a database record map.
  factory StoredEvent.fromMap(Map<String, Object?> map, int key) {
    return StoredEvent(
      key: key,
      eventId: map['event_id'] as String,
      aggregateId: map['aggregate_id'] as String,
      aggregateType: map['aggregate_type'] as String,
      eventType: map['event_type'] as String,
      sequenceNumber: map['sequence_number'] as int,
      data: Map<String, dynamic>.from(map['data'] as Map),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      userId: map['user_id'] as String,
      deviceId: map['device_id'] as String,
      clientTimestamp: DateTime.parse(map['client_timestamp'] as String),
      serverTimestamp: DateTime.parse(map['server_timestamp'] as String),
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

  /// Type of event (e.g., 'NosebleedRecorded').
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

  /// Server-side timestamp (local clock on device).
  final DateTime serverTimestamp;

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
      'event_type': eventType,
      'sequence_number': sequenceNumber,
      'data': data,
      'metadata': metadata,
      'user_id': userId,
      'device_id': deviceId,
      'client_timestamp': clientTimestamp.toIso8601String(),
      'server_timestamp': serverTimestamp.toIso8601String(),
      'event_hash': eventHash,
      'previous_event_hash': previousEventHash,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Convert to JSON for API calls.
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'StoredEvent(eventId: $eventId, type: $eventType, seq: $sequenceNumber)';
  }
}
