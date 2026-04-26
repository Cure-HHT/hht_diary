// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';
import 'package:event_sourcing_datastore/src/core/errors/datastore_exception.dart'
    as errors;
import 'package:event_sourcing_datastore/src/infrastructure/database/database_provider.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:provenance/provenance.dart';
import 'package:uuid/uuid.dart';

export 'package:event_sourcing_datastore/src/storage/stored_event.dart'
    show StoredEvent;

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
/// ```
class EventRepository {
  /// Construct over a [DatabaseProvider]. An optional [backend] can be
  /// supplied by tests or by alternative deployments; when omitted the
  /// repository constructs a [SembastBackend] over the provider's database.
  EventRepository({required this.databaseProvider, StorageBackend? backend})
    : _backend = backend ?? SembastBackend(database: databaseProvider.database);

  /// The database provider.
  final DatabaseProvider databaseProvider;

  /// Backing storage. Owns the events store, the diary_entries view, the
  /// per-destination FIFOs, and the backend_state KV where the per-device
  /// sequence counter lives (REQ-d00117-F). All writes go through this.
  final StorageBackend _backend;

  /// UUID generator.
  static const _uuid = Uuid();

  /// Append a new event to the store.
  ///
  /// This is the primary way to record data changes. Events are immutable
  /// once written - they cannot be updated or deleted.
  ///
  /// Returns the created [StoredEvent] with all generated fields populated.
  ///
  /// Throws [errors.EventValidationException] if required fields are missing.
  /// Throws [errors.DatabaseException] if the write fails.
  // Implements: REQ-d00118-A — entry_type is a required, first-class field
  // on the event record, not buried inside metadata or data.
  // Implements: REQ-d00118-B — no device-side server_timestamp is stamped;
  // the ingesting server is the sole authority on server-side timestamps.
  /// The returned [StoredEvent] carries `key: 0` as a placeholder; the real
  /// Sembast auto-increment key is an internal implementation detail of the
  /// backend and not part of the event's identity. Callers that need the
  /// Sembast key for any reason should re-read via [getEventsForAggregate]
  /// or [getAllEvents], which populate `key` from the underlying record.
  Future<StoredEvent> append({
    required String aggregateId,
    required String entryType,
    required String eventType,
    required Map<String, dynamic> data,
    required String userId,
    required String deviceId,
    String? aggregateType,
    DateTime? clientTimestamp,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await _backend.transaction<StoredEvent>((txn) async {
        // Read the hash-chain tail and reserve the next sequence number
        // inside the same transaction that will persist the new event. This
        // makes the chain-construction and the append a single atomic step:
        // no concurrent writer can interleave between tail-read and append,
        // so the chain cannot fork even if callers fire concurrent appends.
        final previousHash = await _backend.readLatestEventHash(txn);
        final sequenceNumber = await _backend.nextSequenceNumber(txn);
        final eventId = _uuid.v4();
        final clientTs = clientTimestamp?.toUtc() ?? DateTime.now().toUtc();

        // Phase 4.4 drive-by: top-level userId/deviceId are replaced by
        // initiator (UserInitiator) and metadata.provenance[0].identifier
        // respectively. The public append() signature keeps its userId/
        // deviceId parameters to avoid disturbing NosebleedService (Phase 5
        // cutover); they are wrapped internally into the new envelope.
        final initiator = UserInitiator(userId);
        final provenance0 = ProvenanceEntry(
          hop: 'mobile-device',
          receivedAt: clientTs,
          identifier: deviceId,
          softwareVersion: '',
        );
        // Phase 4.4: inject `change_reason: 'initial'` so the hash-chain
        // input matches the `EventStore.append` path (events written
        // through either API hash identically for semantically equal
        // inputs).
        final effectiveMetadata = <String, dynamic>{
          ...?metadata,
          'change_reason': (metadata?['change_reason'] as String?) ?? 'initial',
          'provenance': <Map<String, dynamic>>[provenance0.toJson()],
        };
        final eventRecord = <String, dynamic>{
          'event_id': eventId,
          'aggregate_id': aggregateId,
          'aggregate_type': aggregateType ?? 'DiaryEntry',
          'entry_type': entryType,
          'entry_type_version': 1,
          'lib_format_version': StoredEvent.currentLibFormatVersion,
          'event_type': eventType,
          'sequence_number': sequenceNumber,
          'data': data,
          'metadata': effectiveMetadata,
          'initiator': initiator.toJson(),
          'flow_token': null,
          'client_timestamp': clientTs.toIso8601String(),
          'previous_event_hash': previousHash,
        };

        final eventHash = _calculateEventHash(eventRecord);
        eventRecord['event_hash'] = eventHash;

        // Sembast assigns its own auto-increment key on the append; the key
        // is an internal implementation detail and not part of the event's
        // identity. Pass a placeholder 0 through StoredEvent.fromMap so the
        // caller gets a StoredEvent instance; downstream code that needs
        // the Sembast key re-reads via findEventsForAggregate.
        final stored = StoredEvent.fromMap(eventRecord, 0);
        await _backend.appendEvent(txn, stored);
        return stored;
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
  Future<List<StoredEvent>> getEventsForAggregate(String aggregateId) =>
      _backend.findEventsForAggregate(aggregateId);

  /// Get all events in sequence order.
  ///
  /// Returns events oldest first.
  Future<List<StoredEvent>> getAllEvents() => _backend.findAllEvents();

  /// Get the latest sequence number — 0 if no events have been appended.
  Future<int> getLatestSequenceNumber() => _backend.readSequenceCounter();

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

  /// Calculate SHA-256 hash of event data using RFC 8785 canonical JSON.
  ///
  /// The hash input is a deterministic, sorted-keys UTF-8 byte sequence so
  /// any cross-platform receiver (Python, Postgres, Go, etc.) can
  /// independently re-canonicalize the event record and recompute the
  /// same digest. Dart's native `jsonEncode` preserves Map insertion order
  /// and has platform-specific number-formatting quirks that would not
  /// reproduce elsewhere; JCS pins those down.
  // Implements: REQ-p00004-I — tamper-evident hash chain.
  // Implements: REQ-d00120 — canonical hashing for cross-platform event
  // verification via RFC 8785 (JCS).
  String _calculateEventHash(Map<String, dynamic> eventRecord) {
    // The hashed subset excludes the hash itself and fields that are not
    // part of the event identity (aggregate_type label).
    // entry_type is included so tampering with it is detected by the chain.
    // Phase 4.4 identity-field set (REQ-d00120-B revised): event_id,
    // aggregate_id, entry_type, event_type, sequence_number, data,
    // initiator, flow_token, client_timestamp, previous_event_hash,
    // metadata. Device identity / software version live inside
    // metadata.provenance[0] and are covered transitively.
    final hashInput = <String, Object?>{
      'event_id': eventRecord['event_id'],
      'aggregate_id': eventRecord['aggregate_id'],
      'entry_type': eventRecord['entry_type'],
      'event_type': eventRecord['event_type'],
      'sequence_number': eventRecord['sequence_number'],
      'data': eventRecord['data'],
      'initiator': eventRecord['initiator'],
      'flow_token': eventRecord['flow_token'],
      'client_timestamp': eventRecord['client_timestamp'],
      'previous_event_hash': eventRecord['previous_event_hash'],
      'metadata': eventRecord['metadata'],
    };

    final bytes = canonicalizeBytes(hashInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

// StoredEvent moved to lib/src/storage/stored_event.dart and re-exported
// at the top of this file for backwards compatibility.
