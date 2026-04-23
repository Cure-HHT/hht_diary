import 'dart:async';

import 'package:append_only_datastore/src/entry_type_registry.dart';
import 'package:append_only_datastore/src/materialization/materializer.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/sync/drain.dart';
import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';
import 'package:provenance/provenance.dart';
import 'package:uuid/uuid.dart';

/// Fire-and-forget trigger into `SyncCycle.call()`.
///
/// `EntryService.record` calls this via `unawaited(syncCycleTrigger())`
/// after a successful write (REQ-d00133-G). Production wires
/// `() => syncCycle.call()`; tests pass a spy that records calls without
/// running drain logic.
typedef SyncCycleTrigger = Future<void> Function();

/// Device-level identity that `EntryService.record` stamps on every event
/// it writes. `deviceId` and `softwareVersion` populate the first
/// `ProvenanceEntry` and (per REQ-d00133-I) mirror into the event's
/// migration-bridge top-level fields; `userId` populates the event's
/// `user_id`.
///
/// `softwareVersion` SHALL conform to the REQ-d00115-E shape
/// `"<package-name>@<semver>[+<build>]"`; `EntryService.record` does NOT
/// validate it (the shape contract is a permanent caller obligation per
/// the `ProvenanceEntry` doc), but downstream portal ingestion does.
class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.softwareVersion,
    required this.userId,
  });

  final String deviceId;
  final String softwareVersion;
  final String userId;
}

/// Sole write API invoked by widgets producing new events
/// (REQ-d00133-A).
///
/// Hides the atomic event-assembly, the materializer run, the
/// sequence-counter advance, and the no-op detection behind one call
/// whose semantics are stable across the widget/destination/transport
/// evolutions that follow.
///
/// Per-destination FIFO fan-out is DEFERRED to `fillBatch`, which runs
/// on the next `syncCycle` tick (REQ-d00133-D, revised from the original
/// Phase-5 spec). The write transaction therefore touches only the
/// event log, the sequence counter, and the `diary_entries`
/// materialized view; it does NOT call `destination.transform` or
/// `destination.send`.
// Implements: REQ-d00133-A — sole write API for widgets producing new
// events.
class EntryService {
  EntryService({
    required this.backend,
    required this.entryTypes,
    required this.syncCycleTrigger,
    required this.deviceInfo,
    ClockFn? clock,
    Uuid? uuid,
  }) : _clock = clock,
       _uuid = uuid ?? const Uuid();

  final StorageBackend backend;
  final EntryTypeRegistry entryTypes;
  final SyncCycleTrigger syncCycleTrigger;
  final DeviceInfo deviceInfo;
  final ClockFn? _clock;
  final Uuid _uuid;

  /// Record a new event for [aggregateId] of type [entryType] with
  /// [eventType] and [answers]. Returns the appended `StoredEvent` (with
  /// `sequenceNumber`, `eventHash`, `previousEventHash`, and first
  /// `ProvenanceEntry` stamped), or `null` when the call is a no-op
  /// duplicate of the aggregate's most recent event (REQ-d00133-F).
  ///
  /// [eventType] MUST be one of `finalized`, `checkpoint`, `tombstone`
  /// (REQ-d00133-C); other values raise `ArgumentError` before any I/O.
  ///
  /// [entryType] MUST be registered in [entryTypes] (REQ-d00133-H);
  /// unregistered values raise `ArgumentError` before any I/O.
  ///
  /// [checkpointReason] is carried on the event as `data.checkpoint_reason`
  /// when present; typically used by checkpoint events to record why a
  /// partial save occurred. [changeReason] is carried on the event's
  /// `metadata.change_reason`, defaulting to `'initial'` when the caller
  /// omits it — every regulated event record requires a change reason
  /// under 21 CFR Part 11 §11.50, and the initial authoring event's
  /// implicit reason is "first-time authoring".
  ///
  /// Atomicity: the append, the materializer run, the
  /// `diary_entries` upsert, and the sequence-counter advance land in a
  /// single `StorageBackend.transaction()` (REQ-d00133-D, revised). Any
  /// failure inside the transaction aborts the whole write — no event
  /// appended, no view row written (REQ-d00133-E). Destination fan-out
  /// is NOT part of this transaction; `fillBatch` promotes events on
  /// the next `syncCycle` tick.
  // Implements: REQ-d00133-A — sole write API for widgets producing events.
  // Implements: REQ-d00133-B — assigns event_id, sequence_number,
  // previous_event_hash, event_hash, and first ProvenanceEntry atomically.
  // Implements: REQ-d00133-C — eventType in {finalized, checkpoint,
  // tombstone}; other values throw ArgumentError before any I/O.
  // Implements: REQ-d00133-D (revised) — local-only transaction; FIFO
  // fan-out deferred to fillBatch.
  // Implements: REQ-d00133-E — failure inside the transaction aborts
  // the whole write.
  // Implements: REQ-d00133-F — duplicate content hash is a no-op.
  // Implements: REQ-d00133-G — syncCycle trigger is fire-and-forget after
  // a successful write.
  // Implements: REQ-d00133-H — entryType must be registered in
  // EntryTypeRegistry; unregistered throws ArgumentError before I/O.
  // Implements: REQ-d00133-I — populate top-level client_timestamp,
  // device_id, software_version from metadata.provenance[0].
  Future<StoredEvent?> record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    // REQ-d00133-C: validate eventType before any I/O.
    if (eventType != 'finalized' &&
        eventType != 'checkpoint' &&
        eventType != 'tombstone') {
      throw ArgumentError.value(
        eventType,
        'eventType',
        'must be one of finalized, checkpoint, tombstone (REQ-d00133-C)',
      );
    }
    // REQ-d00133-H: validate entryType registration before any I/O.
    if (!entryTypes.isRegistered(entryType)) {
      throw ArgumentError.value(
        entryType,
        'entryType',
        'not registered in EntryTypeRegistry (REQ-d00133-H)',
      );
    }
    final def = entryTypes.byId(entryType)!;
    final effectiveChangeReason = changeReason ?? 'initial';

    // REQ-d00133-F: canonical-content no-op detection. Compare against
    // the most recent event on the aggregate, BEFORE opening the
    // transaction — the check is read-only and a duplicate would
    // contribute no work inside the transaction anyway.
    final aggregateHistory = await backend.findEventsForAggregate(aggregateId);
    final candidateHash = _contentHash(
      eventType: eventType,
      answers: answers,
      checkpointReason: checkpointReason,
      changeReason: effectiveChangeReason,
    );
    if (aggregateHistory.isNotEmpty) {
      final prior = aggregateHistory.last;
      final priorHash = _contentHash(
        eventType: prior.eventType,
        answers: _extractAnswers(prior.data),
        checkpointReason: prior.data['checkpoint_reason'] as String?,
        changeReason: (prior.metadata['change_reason'] as String?) ?? 'initial',
      );
      if (candidateHash == priorHash) {
        // No-op: duplicate content; return without writing.
        return null;
      }
    }

    // Build the first ProvenanceEntry OUTSIDE the transaction — it depends
    // only on wall-clock time and DeviceInfo, and keeping it out of the
    // transaction keeps the transaction body short.
    final now = (_clock ?? () => DateTime.now().toUtc())();
    final provenance0 = ProvenanceEntry(
      hop: 'mobile-device',
      receivedAt: now,
      identifier: deviceInfo.deviceId,
      softwareVersion: deviceInfo.softwareVersion,
    );

    // REQ-d00133-B + D + E: atomic local write. Event assembly runs
    // inside the transaction so the hash-chain tail read and the
    // sequence-counter reservation commit together with the append.
    final appended = await backend.transaction<StoredEvent>((txn) async {
      final previousHash = await backend.readLatestEventHash(txn);
      final sequenceNumber = await backend.nextSequenceNumber(txn);
      final eventId = _uuid.v4();

      final data = <String, Object?>{
        'answers': Map<String, Object?>.from(answers),
        'checkpoint_reason': ?checkpointReason,
      };
      final metadata = <String, Object?>{
        'change_reason': effectiveChangeReason,
        'provenance': <Map<String, Object?>>[provenance0.toJson()],
      };

      // Construct the event with a placeholder hash, compute the hash
      // over its canonical map form, and re-issue the final event.
      final recordMap = <String, Object?>{
        'event_id': eventId,
        'aggregate_id': aggregateId,
        'aggregate_type': 'DiaryEntry',
        'entry_type': entryType,
        'event_type': eventType,
        'sequence_number': sequenceNumber,
        'data': data,
        'metadata': metadata,
        'user_id': deviceInfo.userId,
        // REQ-d00133-I: migration-bridge top-level fields populated from
        // metadata.provenance[0]. received_at mirrors client_timestamp,
        // identifier mirrors device_id, software_version mirrors
        // provenance software_version.
        'device_id': provenance0.identifier,
        'client_timestamp': provenance0.receivedAt.toIso8601String(),
        'software_version': provenance0.softwareVersion,
        'previous_event_hash': previousHash,
      };
      final eventHash = _eventHash(recordMap);
      recordMap['event_hash'] = eventHash;
      final event = StoredEvent.fromMap(recordMap, 0);

      await backend.appendEvent(txn, event);

      // REQ-d00133-D (revised): run the materializer in the SAME
      // transaction as the append so the view is coherent with the log
      // at commit time. The diary_entries row is keyed on aggregateId;
      // a rolled-back transaction (REQ-d00133-E) leaves neither the
      // event nor the view row visible to subsequent reads.
      final priorRows = await backend.findEntries();
      final priorRow = priorRows.cast<DiaryEntry?>().firstWhere(
        (r) => r?.entryId == aggregateId,
        orElse: () => null,
      );
      // First-event fallback for effective_date resolution: the oldest
      // event on the aggregate supplies the fallback timestamp. When
      // this is the aggregate's first event, that is `event.clientTimestamp`
      // itself; on subsequent events we use the earliest prior event's
      // client_timestamp (aggregateHistory was read outside the transaction,
      // but for this purpose the "first event timestamp" is monotonically
      // stable — prior events cannot be deleted from the log).
      final firstEventTs = aggregateHistory.isEmpty
          ? event.clientTimestamp
          : aggregateHistory.first.clientTimestamp;
      final nextRow = Materializer.apply(
        previous: priorRow,
        event: event,
        def: def,
        firstEventTimestamp: firstEventTs,
      );
      await backend.upsertEntry(txn, nextRow);

      return event;
    });

    // REQ-d00133-G: kick the sync cycle fire-and-forget. Errors from the
    // sync cycle SHALL NOT bubble into the caller; drain's internal
    // per-destination try/catch records failures on attempts[] rather
    // than propagating.
    unawaited(syncCycleTrigger());

    return appended;
  }

  /// Canonical content hash over `(event_type, answers,
  /// checkpoint_reason, change_reason)`. Used by the no-op detector.
  /// Two calls with identical content SHALL hash to the same digest so
  /// the detector returns without writing (REQ-d00133-F).
  // Implements: REQ-d00133-F — canonical content hashing for no-op
  // detection.
  String _contentHash({
    required String eventType,
    required Map<String, Object?> answers,
    required String? checkpointReason,
    required String changeReason,
  }) {
    final input = <String, Object?>{
      'event_type': eventType,
      'answers': answers,
      'checkpoint_reason': checkpointReason,
      'change_reason': changeReason,
    };
    final bytes = canonicalizeBytes(input);
    return sha256.convert(bytes).toString();
  }

  /// Event-hash digest over the hashed subset of [recordMap]. Mirrors
  /// the shape used by the existing `EventRepository._calculateEventHash`
  /// so events written by either path verify against the same chain.
  /// Includes `software_version` so the migration-bridge field is under
  /// tamper detection from day one.
  String _eventHash(Map<String, Object?> recordMap) {
    final hashInput = <String, Object?>{
      'event_id': recordMap['event_id'],
      'aggregate_id': recordMap['aggregate_id'],
      'entry_type': recordMap['entry_type'],
      'event_type': recordMap['event_type'],
      'sequence_number': recordMap['sequence_number'],
      'data': recordMap['data'],
      'user_id': recordMap['user_id'],
      'device_id': recordMap['device_id'],
      'client_timestamp': recordMap['client_timestamp'],
      'software_version': recordMap['software_version'],
      'previous_event_hash': recordMap['previous_event_hash'],
    };
    final bytes = canonicalizeBytes(hashInput);
    return sha256.convert(bytes).toString();
  }

  static Map<String, Object?> _extractAnswers(Map<String, Object?> data) {
    final raw = data['answers'];
    if (raw is Map) {
      return Map<String, Object?>.from(raw);
    }
    return const <String, Object?>{};
  }
}
