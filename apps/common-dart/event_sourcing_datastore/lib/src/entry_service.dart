import 'dart:async';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:crypto/crypto.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/drain.dart';
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
///
/// Phase-4.19 caveat: `EntryService.record` invokes
/// `DiaryEntriesMaterializer.foldPure` directly with `event.data` as
/// `promotedData` (identity promotion). It bypasses the materializer's
/// `promoter` field and the `view_target_versions` lookup that
/// `EventStore.append` performs. Callers MUST ensure the materializer
/// they construct uses `identityPromoter`; non-identity promoters cause
/// silent divergence between the legacy and new write paths.
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
  /// duplicate of the aggregate's current state (REQ-d00133-F).
  ///
  /// No-op detection is merge-aware: the candidate's delta is merged
  /// into the prior `current_answers`, and the call is elided only when
  /// the merge produces an unchanged state AND the lifecycle flags
  /// (`is_complete` / `is_deleted`) and reason fields (`change_reason`
  /// and `checkpoint_reason`) match the prior event. A `tombstone` over
  /// an already-tombstoned aggregate with a matching `change_reason` is
  /// likewise elided. A candidate whose delta merges to the same
  /// `current_answers` but which flips a lifecycle flag (e.g.
  /// `checkpoint` → `finalized`) is NOT a no-op.
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
  // Implements: REQ-d00133-F — merge-aware no-op detection. A candidate
  // is a duplicate when merging its delta produces an unchanged
  // current_answers AND the lifecycle (is_complete / is_deleted) and
  // reason fields match the prior event.
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

    // REQ-d00133-B + D + E + F: atomic local write. Event assembly,
    // no-op detection, hash-chain tail read, and sequence-counter
    // reservation all happen inside the transaction so the read set
    // is coherent with the append (no TOCTOU against a concurrent
    // writer on the same aggregate).
    final appended = await backend.transaction<StoredEvent?>((txn) async {
      // REQ-d00133-F: merge-aware no-op detection. Read the prior
      // event history AND the current materialized-view row INSIDE
      // the transaction so a concurrent writer that lands before us
      // cannot slip in a duplicate that this check misses.
      final aggregateHistory = await backend.findEventsForAggregateInTxn(
        txn,
        aggregateId,
      );
      final priorRow = await backend.readEntryInTxn(txn, aggregateId);

      if (aggregateHistory.isNotEmpty && priorRow != null) {
        final priorEvent = aggregateHistory.last;
        final priorCheckpointReason =
            priorEvent.data['checkpoint_reason'] as String?;
        final priorChangeReason =
            (priorEvent.metadata['change_reason'] as String?) ?? 'initial';
        final changeReasonMatches = effectiveChangeReason == priorChangeReason;
        final checkpointReasonMatches =
            checkpointReason == priorCheckpointReason;

        if (eventType == 'tombstone') {
          if (priorRow.isDeleted && changeReasonMatches) {
            // REQ-d00133-F tombstone no-op: already-tombstoned
            // aggregate with a matching change_reason.
            return null;
          }
        } else {
          // eventType is 'finalized' or 'checkpoint' (validated above).
          final eventIsComplete = eventType == 'finalized';
          final merged = DiaryEntriesMaterializer.mergeAnswers(
            priorRow.currentAnswers,
            answers,
          );
          final mergeUnchanged = const DeepCollectionEquality().equals(
            merged,
            priorRow.currentAnswers,
          );
          final isCompleteMatches = eventIsComplete == priorRow.isComplete;
          if (mergeUnchanged &&
              isCompleteMatches &&
              checkpointReasonMatches &&
              changeReasonMatches) {
            // REQ-d00133-F merge-aware no-op: the delta merges to an
            // unchanged current_answers, the lifecycle flag stays the
            // same, and reason fields match the prior event.
            return null;
          }
        }
      }

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
        'entry_type_version': 1,
        'lib_format_version': StoredEvent.currentLibFormatVersion,
        'event_type': eventType,
        'sequence_number': sequenceNumber,
        'data': data,
        'metadata': metadata,
        'initiator': UserInitiator(deviceInfo.userId).toJson(),
        'flow_token': null,
        'client_timestamp': provenance0.receivedAt.toIso8601String(),
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
      // event nor the view row visible to subsequent reads. `priorRow`
      // was read above INSIDE this transaction alongside the no-op
      // check so the read set stays coherent with the append.
      // First-event fallback for effective_date resolution: the oldest
      // event on the aggregate supplies the fallback timestamp. When
      // this is the aggregate's first event, that is `event.clientTimestamp`
      // itself; on subsequent events we use the earliest prior event's
      // client_timestamp from the in-transaction aggregateHistory read.
      final firstEventTs = aggregateHistory.isEmpty
          ? event.clientTimestamp
          : aggregateHistory.first.clientTimestamp;
      final nextRow = DiaryEntriesMaterializer.foldPure(
        previous: priorRow,
        event: event,
        // EntryService is the legacy Phase-4.3 write path. It does not run
        // the EventStore promoter pipeline, so the event's own data is
        // used directly (identity promotion).
        promotedData: event.data,
        def: def,
        firstEventTimestamp: firstEventTs,
      );
      await backend.upsertEntry(txn, nextRow);

      return event;
    });

    if (appended == null) {
      // No-op duplicate detected inside the transaction; no event
      // appended, so no sync cycle to trigger.
      return null;
    }

    // REQ-d00133-G: kick the sync cycle fire-and-forget. Errors from the
    // sync cycle SHALL NOT bubble into the caller; drain's internal
    // per-destination try/catch records failures on attempts[] rather
    // than propagating.
    unawaited(syncCycleTrigger());

    return appended;
  }

  /// Event-hash digest over the identity fields enumerated in REQ-d00120-B
  /// (Phase 4.4 revision): event_id, aggregate_id, entry_type, event_type,
  /// sequence_number, data, initiator, flow_token, client_timestamp,
  /// previous_event_hash, metadata. Device identity and software version
  /// live inside metadata.provenance[0] and are covered transitively.
  // Implements: REQ-d00120-A+B — SHA-256 over JCS-canonical bytes of the
  // identity-field subset enumerated in the Phase 4.4 revision of REQ-d00120-B.
  String _eventHash(Map<String, Object?> recordMap) {
    final hashInput = <String, Object?>{
      'event_id': recordMap['event_id'],
      'aggregate_id': recordMap['aggregate_id'],
      'entry_type': recordMap['entry_type'],
      'event_type': recordMap['event_type'],
      'sequence_number': recordMap['sequence_number'],
      'data': recordMap['data'],
      'initiator': recordMap['initiator'],
      'flow_token': recordMap['flow_token'],
      'client_timestamp': recordMap['client_timestamp'],
      'previous_event_hash': recordMap['previous_event_hash'],
      'metadata': recordMap['metadata'],
    };
    final bytes = canonicalizeBytes(hashInput);
    return sha256.convert(bytes).toString();
  }
}
