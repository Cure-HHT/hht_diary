import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/exhausted_fifo_summary.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';

/// Abstract persistence contract for the mobile event-sourcing pipeline.
///
/// Two concrete implementations are intended:
///
/// - `SembastBackend` — mobile device (delivered in this package).
/// - `PostgresBackend` — server-side reuse (future phase).
///
/// The contract is deliberately Dart-pure: no Sembast or postgres types leak
/// into the interface, so either backend can be swapped in without changing
/// callers. Writes are grouped into [transaction] bodies to guarantee
/// atomicity across the four logical stores (event log, diary_entries view,
/// per-destination FIFOs, backend_state KV).
// Implements: REQ-d00117-A — transaction atomicity.
// Implements: REQ-d00117-C — appendEvent co-atomic with sequence counter.
// Implements: REQ-d00117-D — upsertEntry whole-row replace.
// Implements: REQ-d00117-E — enqueueFifo initial state.
// Implements: REQ-d00117-F — backend_state KV store for schema_version and
// sequence counter (not 'metadata').
abstract class StorageBackend {
  const StorageBackend();

  /// Execute [body] inside a single atomic backend transaction. All
  /// `Txn`-bound writes performed within [body] SHALL commit together or
  /// SHALL roll back together on any thrown exception. The returned future
  /// completes with [body]'s return value on commit, or rethrows on rollback.
  ///
  /// Concrete backends SHALL invalidate the [Txn] handle when [body] returns
  /// or throws, so that a later out-of-scope use raises an error rather than
  /// silently writing against a closed transaction (REQ-d00117-B).
  Future<T> transaction<T>(Future<T> Function(Txn txn) body);

  // -------- Events --------

  /// Append [event] to the event log and advance the per-device sequence
  /// counter. Both writes land atomically inside [txn]. Returns an
  /// [AppendResult] carrying the sequence number that was stamped on the
  /// event and the event hash that was persisted.
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event);

  /// Events for one aggregate, sorted by `sequence_number` ascending.
  Future<List<StoredEvent>> findEventsForAggregate(String aggregateId);

  /// All events, optionally sliced by `afterSequence` (exclusive) and
  /// `limit`. Returned in `sequence_number` order.
  Future<List<StoredEvent>> findAllEvents({int? afterSequence, int? limit});

  /// Event hash of the highest-sequence-number event currently in the log,
  /// or null when the event log is empty. Read inside [txn] so the value
  /// reflects writes already staged in the same transaction body.
  ///
  /// Provided so that callers computing the hash-chain input for the next
  /// event (i.e., `previous_event_hash`) can read the tail under the same
  /// transaction that will append the new event. Reading the tail outside
  /// the transaction would make the chain vulnerable to a concurrent writer
  /// stamping a different previous-hash between the read and the commit.
  Future<String?> readLatestEventHash(Txn txn);

  /// Events in sequence_number order, read within [txn] so the result
  /// reflects writes already staged in the same transaction body. Optionally
  /// sliced by [afterSequence] (exclusive) and [limit] so callers can stream
  /// the log in fixed-size chunks instead of materializing the whole log in
  /// memory.
  ///
  /// Used by `rebuildMaterializedView` so the event snapshot folded into the
  /// cache is coherent with the clear+upsert done under the same transaction.
  Future<List<StoredEvent>> findAllEventsInTxn(
    Txn txn, {
    int? afterSequence,
    int? limit,
  });

  /// Reserve-and-increment the per-device sequence counter within [txn] and
  /// return the reserved value.
  ///
  /// Implementations SHALL advance the counter as a side effect so that a
  /// second call in the same transaction returns `current + 2`. Callers
  /// MUST pair this with a single [appendEvent] carrying the reserved
  /// value; [appendEvent] SHALL NOT re-advance the counter. This makes
  /// hash-chain-construction and the append a single atomic step with a
  /// caller-visible reservation that cannot be silently double-consumed.
  ///
  /// Calling [appendEvent] without a prior [nextSequenceNumber] reservation
  /// in the same transaction is a caller bug; implementations SHALL reject
  /// it with a clear error rather than advancing the counter implicitly
  /// (Phase-2 Prereq B, Option 1).
  Future<int> nextSequenceNumber(Txn txn);

  /// Current value of the per-device sequence counter — i.e., the
  /// `sequence_number` of the most recently-persisted event. Returns 0
  /// when no event has been appended yet. Non-transactional, read-only.
  Future<int> readSequenceCounter();

  // -------- Materialized view --------

  /// Whole-row replace into `diary_entries` keyed on `entry.entryId`. Not a
  /// partial merge: every column in [entry] overwrites the previous row.
  Future<void> upsertEntry(Txn txn, DiaryEntry entry);

  /// Remove every row from `diary_entries`. Used by
  /// `rebuildMaterializedView` to replace the cache in one transaction
  /// step; not intended as a runtime operation. The event log is
  /// untouched.
  Future<void> clearEntries(Txn txn);

  /// Query `diary_entries` with optional filters; all filters are combined
  /// with logical AND. Returned order is unspecified — callers that need a
  /// deterministic order SHALL sort the result themselves.
  Future<List<DiaryEntry>> findEntries({
    String? entryType,
    bool? isComplete,
    bool? isDeleted,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  // -------- FIFO (per destination) --------

  /// Append a batch-shaped entry to destination [destinationId]'s FIFO
  /// (REQ-d00117-E). The batch covers every event in [batch], which MUST
  /// be non-empty (REQ-d00128-A). The returned `FifoEntry` carries the
  /// backend-assigned `sequence_in_queue` and the constructed
  /// `event_ids` (REQ-d00128-A) + `event_id_range` (REQ-d00128-B) +
  /// `wire_payload` (REQ-d00128-C) fields.
  ///
  /// The backend opens its own atomic transaction for the write so
  /// callers that are not already composing a larger transaction can
  /// enqueue in one call. Callers composing a larger transaction (e.g.,
  /// replay, fill_batch) will use the transactional variant added later
  /// in Phase 4.3.
  ///
  /// Implementations SHALL extract `event_ids` from
  /// `batch.map((e) => e.eventId)` and `event_id_range` from
  /// `(firstSeq: batch.first.sequenceNumber, lastSeq: batch.last
  /// .sequenceNumber)` — callers are responsible for passing a batch
  /// whose elements are in ascending `sequence_number` order
  /// (contiguity is enforced by the fill-batch path, not this method).
  ///
  /// Implementations SHALL assign a monotonically-increasing
  /// `sequence_in_queue` per FIFO, SHALL reject an empty [batch] with
  /// `ArgumentError`, and SHALL register the destination on first use
  /// so `anyFifoExhausted`/`exhaustedFifos` can iterate all known FIFOs.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue contract.
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  );

  /// Transactional variant of [enqueueFifo]: participates in the
  /// surrounding transaction's atomicity so the FIFO-row write and the
  /// accompanying writes (e.g., fill_cursor advance in `fillBatch`) commit
  /// or roll back together. Same contract as [enqueueFifo] otherwise:
  /// rejects empty [batch], rejects duplicate `entry_id` in the same FIFO,
  /// assigns monotonically-increasing `sequence_in_queue`, and registers
  /// the destination on first use.
  ///
  /// Implementations SHALL centralize row-construction logic here;
  /// [enqueueFifo] delegates to [enqueueFifoTxn] inside its own
  /// `transaction((txn) => ...)` wrapper.
  // Implements: REQ-d00128-A+B+C — transactional batch-per-row enqueue
  // (co-atomic with the surrounding transaction; used by fillBatch).
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  );

  /// First `pending` entry in [destinationId]'s FIFO in
  /// `sequence_in_queue` order, or null when no pending entry remains
  /// (the FIFO is empty, or every row is terminal — `sent` and/or
  /// `exhausted`). Implementations SHALL skip both `sent` and
  /// `exhausted` rows and SHALL NOT stop at the first `exhausted` row
  /// they encounter; the drain-loop "wedge" on an exhausted head is
  /// preserved by the drain loop's switch-case (REQ-d00124-D+E), not
  /// by `readFifoHead` returning null at the first terminal row.
  // Implements: REQ-d00124-A — readFifoHead returns the first pending
  // row in sequence_in_queue order; terminal rows (sent, exhausted)
  // are skipped.
  Future<FifoEntry?> readFifoHead(String destinationId);

  /// Append [attempt] to the `attempts[]` list of the entry identified by
  /// `(destinationId, entryId)`. Does not change `final_status`.
  ///
  /// Implementations SHALL be a no-op (return without throwing) when the
  /// FIFO row identified by `entryId` does not exist in the destination's
  /// FIFO store, and SHALL be a no-op when the FIFO store for
  /// `destinationId` does not exist (REQ-d00127-B). This tolerates the
  /// drain/unjam + drain/delete race: drain `await send()`s outside a
  /// storage transaction, and a concurrent user operation may remove the
  /// target row before drain's subsequent `appendAttempt` transaction
  /// runs. Implementations SHALL emit a warning-level diagnostic when
  /// they no-op (REQ-d00127-C).
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  );

  /// Transition an entry to a terminal `final_status`. When [status] is
  /// [FinalStatus.sent] the entry's `sent_at` is also set. Entries
  /// transitioned to terminal status are retained forever as send-log
  /// records (REQ-d00119-D); they are never deleted.
  ///
  /// Implementations SHALL be a no-op (return without throwing) when the
  /// FIFO row identified by `entryId` does not exist in the destination's
  /// FIFO store, and SHALL be a no-op when the FIFO store for
  /// `destinationId` does not exist (REQ-d00127-A) — see the matching
  /// note on [appendAttempt] for the race this closes. Implementations
  /// SHALL emit a warning-level diagnostic when they no-op
  /// (REQ-d00127-C). The one-way-transition rule for an already-terminal
  /// entry (pending -> sent|exhausted only; no re-transition) is
  /// orthogonal to this tolerance and remains enforced.
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  );

  /// True iff any registered destination's FIFO head is `exhausted`.
  Future<bool> anyFifoExhausted();

  /// One summary per wedged FIFO for operator diagnostics.
  Future<List<ExhaustedFifoSummary>> exhaustedFifos();

  // -------- Backend state (KV bookkeeping) --------

  /// Read the current schema version from `backend_state`. Returns 0 when
  /// the backend has never been written to.
  Future<int> readSchemaVersion();

  /// Write [version] into `backend_state` inside [txn]. Used by the schema
  /// migration path at boot; typical production flow writes the version once
  /// and leaves it alone until a migration.
  Future<void> writeSchemaVersion(Txn txn, int version);

  /// Read the per-destination fill cursor — the highest `sequence_number`
  /// that has been promoted into any FIFO row (pending, sent, or exhausted)
  /// for [destinationId]. Returns `-1` when no cursor value has yet been
  /// written, i.e., no row has yet been enqueued for this destination.
  ///
  /// Note: `-1` is both the default-when-unset sentinel and the only
  /// legal pre-start rewind value (e.g., `unjamDestination` rewinding a
  /// destination with no sent rows per REQ-d00131-D). Callers that need
  /// to distinguish "never written" from "explicitly rewound to -1" MUST
  /// do so via other bookkeeping; this method treats them as equivalent.
  ///
  /// Persisted under `backend_state` key `fill_cursor_<destinationId>`.
  /// Non-transactional, read-only.
  // Implements: REQ-d00128-G — per-destination fill cursor persisted under
  // backend_state/fill_cursor_<destinationId>, returns -1 when unset.
  Future<int> readFillCursor(String destinationId);

  /// Write the per-destination fill cursor for [destinationId] to
  /// [sequenceNumber]. Opens its own atomic transaction. Callers that are
  /// already composing a larger transaction (e.g., fill_batch) SHALL use
  /// [writeFillCursorTxn] to keep the cursor advance co-atomic with the
  /// enqueue / sequence-counter writes it accompanies.
  // Implements: REQ-d00128-G — per-destination fill cursor write
  // (standalone variant).
  Future<void> writeFillCursor(String destinationId, int sequenceNumber);

  /// Write the per-destination fill cursor for [destinationId] to
  /// [sequenceNumber] inside [txn]. Participates in the surrounding
  /// transaction's atomicity: on rollback the cursor reverts to its
  /// pre-transaction value.
  // Implements: REQ-d00128-G — per-destination fill cursor write
  // (transactional variant; co-atomic with the surrounding transaction).
  Future<void> writeFillCursorTxn(
    Txn txn,
    String destinationId,
    int sequenceNumber,
  );

  // -------- Destination schedules (REQ-d00129) --------

  /// Read the persisted `DestinationSchedule` for [destinationId], or
  /// null when no schedule has ever been written. Non-transactional.
  ///
  /// Schedules are persisted under `backend_state` key
  /// `schedule_<destinationId>` as the JSON form produced by
  /// `DestinationSchedule.toJson`.
  // Implements: REQ-d00129-A+C+F — readSchedule backs registry
  // scheduleOf/setStartDate/setEndDate persistence.
  Future<DestinationSchedule?> readSchedule(String destinationId);

  /// Write [schedule] for [destinationId] inside its own atomic
  /// transaction. Callers already composing a transaction SHALL use
  /// [writeScheduleTxn] to keep the write co-atomic with adjacent
  /// schedule / FIFO mutations.
  // Implements: REQ-d00129-A — initial dormant schedule persistence.
  Future<void> writeSchedule(
    String destinationId,
    DestinationSchedule schedule,
  );

  /// Transactional variant of [writeSchedule]: participates in the
  /// surrounding transaction's atomicity so a schedule write and the
  /// ops that accompany it (e.g. FIFO-store drop in
  /// `deleteDestination`) commit or roll back together.
  // Implements: REQ-d00129-C+F+H — transactional schedule write for
  // setStartDate / setEndDate / deleteDestination.
  Future<void> writeScheduleTxn(
    Txn txn,
    String destinationId,
    DestinationSchedule schedule,
  );

  /// Delete the `schedule_<destinationId>` record inside [txn]. Used by
  /// `deleteDestination` to drop schedule state and the FIFO store in
  /// one atomic step.
  // Implements: REQ-d00129-H — atomic drop of schedule + FIFO store.
  Future<void> deleteScheduleTxn(Txn txn, String destinationId);

  /// Drop the FIFO store for [destinationId] entirely inside [txn].
  /// Implementations SHALL remove every row and drop the store itself
  /// (not just the currently-present records), so a subsequent
  /// `readFifoHead` on the same id returns null without seeing any
  /// trailing state.
  // Implements: REQ-d00129-H — atomic FIFO-store drop in
  // deleteDestination.
  Future<void> deleteFifoStoreTxn(Txn txn, String destinationId);
}
