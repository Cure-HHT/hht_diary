import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/storage/append_result.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/storage/wedged_fifo_summary.dart';

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

  /// Events for one aggregate, read within [txn] so the result reflects
  /// writes already staged in the same transaction body. Sorted by
  /// `sequence_number` ascending. Used by callers (e.g., `EntryService`)
  /// that need hash-chain / no-op-detection reads to be coherent with
  /// the same-transaction append.
  Future<List<StoredEvent>> findEventsForAggregateInTxn(
    Txn txn,
    String aggregateId,
  );

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

  /// Reactive event stream. See REQ-d00149.
  ///
  /// Returns a broadcast Stream that, on subscribe, first emits every
  /// event in the log with `sequence_number > afterSequence` (or every
  /// event when `afterSequence` is null) in ascending order, then
  /// transitions to live emission of events appended or ingested while
  /// the subscription is open. Multiple subscribers receive identical
  /// sequences. The stream closes when the backend is closed; calling
  /// this method after close SHALL throw `StateError`.
  ///
  /// Consumers SHALL share a single `StorageBackend` instance per
  /// backing storage (REQ-d00149-E) — broadcast deduplication is the
  /// coordination mechanism, applicable to any `StorageBackend`
  /// implementation.
  ///
  /// **Do not call `pause()` on the returned subscription.** The
  /// underlying broadcast stream is lossy under pause — events emitted
  /// while a subscription is paused are dropped, not buffered (Dart
  /// broadcast contract). If a consumer needs to throttle, do the work
  /// asynchronously inside `onData` (return a Future, await internally),
  /// or cancel and re-subscribe with `afterSequence:` to replay-then-live
  /// from the last known sequence.
  // Implements: REQ-d00149-A+B+C+D+E.
  Stream<StoredEvent> watchEvents({int? afterSequence});

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

  /// Read a single `diary_entries` row by `entryId` within [txn] so
  /// in-transaction callers (e.g., `EntryService.record` folding the
  /// materializer's `priorRow` lookup into the same transaction as the
  /// append + upsert) see writes staged earlier in the same body.
  /// Returns null when the row does not exist.
  Future<DiaryEntry?> readEntryInTxn(Txn txn, String entryId);

  // -------- Generic view storage (Phase 4.4) --------
  //
  // Materializers read and write view rows via these methods. The view
  // namespace is flat — one store per `viewName`, keyed on a caller-
  // supplied string. The backend does not own schema for view rows; the
  // materializer and its readers interpret the row map. Reserved view
  // names: `diary_entries` (owned by `DiaryEntriesMaterializer`) and
  // `security_context` (reserved for the sidecar store).

  /// Read one row from [viewName] by [key] inside [txn], or null when
  /// the row is absent.
  // Implements: REQ-d00140-F — generic view-row read.
  Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
  );

  /// Whole-row upsert into [viewName] at [key] inside [txn].
  // Implements: REQ-d00140-F — generic view-row upsert.
  Future<void> upsertViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
    Map<String, dynamic> row,
  );

  /// Delete the row at [key] in [viewName] inside [txn].
  // Implements: REQ-d00140-F — generic view-row delete.
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key);

  /// Iterate rows in [viewName] with optional `limit` / `offset`.
  /// Non-transactional.
  // Implements: REQ-d00140-F — generic view-row iteration.
  Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {
    int? limit,
    int? offset,
  });

  /// Empty all rows in [viewName] inside [txn]. Other views are untouched.
  // Implements: REQ-d00140-F — generic view clear.
  Future<void> clearViewInTxn(Txn txn, String viewName);

  // -------- View target versions (Phase 4.19) --------

  /// Read the persisted target version for [viewName]/[entryType], or `null`
  /// if no entry has been registered. Used by `Materializer.targetVersionFor`
  /// per REQ-d00140-I+L.
  // Implements: REQ-d00140-I.
  Future<int?> readViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
  );

  /// Persist [targetVersion] for the [viewName]/[entryType] pair.
  /// Idempotent on repeat writes of the same value.
  // Implements: REQ-d00140-I.
  Future<void> writeViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
    int targetVersion,
  );

  /// Read all entry-type → target-version entries for [viewName].
  /// Used by `rebuildView`'s strict-superset check (REQ-d00140-D).
  // Implements: REQ-d00140-I.
  Future<Map<String, int>> readAllViewTargetVersionsInTxn(
    Txn txn,
    String viewName,
  );

  /// Remove every target-version entry for [viewName]. Used by
  /// `rebuildView` before re-recording, and by view drop helpers.
  // Implements: REQ-d00140-I.
  Future<void> clearViewTargetVersionsInTxn(Txn txn, String viewName);

  // -------- FIFO (per destination) --------

  /// Append a batch-shaped entry to destination [destinationId]'s FIFO
  /// (REQ-d00117-E). The batch covers every event in [batch], which MUST
  /// be non-empty (REQ-d00128-A). The returned `FifoEntry` carries the
  /// backend-assigned `sequence_in_queue` and the constructed
  /// `event_ids` (REQ-d00128-A) + `event_id_range` (REQ-d00128-B) fields.
  ///
  /// The backend opens its own atomic transaction for the write so
  /// callers that are not already composing a larger transaction can
  /// enqueue in one call. Callers composing a larger transaction (e.g.,
  /// replay, fill_batch) use [enqueueFifoTxn] instead.
  ///
  /// Exactly one of [wirePayload] / [nativeEnvelope] SHALL be non-null
  /// (REQ-d00152-B+E). The two payload shapes are mutually exclusive:
  ///
  /// - [wirePayload] (3rd-party path) — destination owns the wire format
  ///   and produced opaque bytes via `Destination.transform`. The bytes
  ///   MUST encode a JSON object; the decoded map is persisted under
  ///   `wire_payload`, with `wire_format = wirePayload.contentType` and
  ///   `envelope_metadata = null`. Drain hands the bytes back to
  ///   `Destination.send` verbatim.
  /// - [nativeEnvelope] (native `esd/batch@1` path) — caller (typically
  ///   `fillBatch`) built the envelope identity from the local
  ///   `Source`. The metadata is persisted under `envelope_metadata`,
  ///   with `wire_payload = null` and `wire_format = "esd/batch@1"`.
  ///   Drain reconstructs wire bytes deterministically (RFC 8785 JCS)
  ///   from `envelope_metadata` + `event_ids`-resolved events on each
  ///   send attempt.
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
  /// `ArgumentError`, SHALL reject a non-XOR `(wirePayload,
  /// nativeEnvelope)` pair with `ArgumentError`, and SHALL register the
  /// destination on first use so `anyFifoWedged`/`wedgedFifos` can
  /// iterate all known FIFOs.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue contract.
  // Implements: REQ-d00152-B+E — XOR wirePayload / nativeEnvelope payload
  // shape; native path persists envelope_metadata and nulls wire_payload.
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  });

  /// Transactional variant of [enqueueFifo]: participates in the
  /// surrounding transaction's atomicity so the FIFO-row write and the
  /// accompanying writes (e.g., fill_cursor advance in `fillBatch`) commit
  /// or roll back together. Same contract as [enqueueFifo] otherwise:
  /// rejects empty [batch], enforces the XOR `(wirePayload,
  /// nativeEnvelope)` precondition, mints a fresh v4-UUID `entry_id`,
  /// assigns monotonically-increasing `sequence_in_queue`, and registers
  /// the destination on first use.
  ///
  /// Implementations SHALL centralize row-construction logic here;
  /// [enqueueFifo] delegates to [enqueueFifoTxn] inside its own
  /// `transaction((txn) => ...)` wrapper.
  // Implements: REQ-d00128-A+B+C — transactional batch-per-row enqueue
  // (co-atomic with the surrounding transaction; used by fillBatch).
  // Implements: REQ-d00152-B+E — XOR wirePayload / nativeEnvelope payload
  // shape on the transactional variant.
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  });

  /// Return the head row of [destinationId]'s FIFO — the first row in
  /// `sequence_in_queue` order whose `final_status` is either `null`
  /// (pre-terminal; drain may attempt) or [FinalStatus.wedged] (blocking
  /// terminal; drain halts). Rows whose `final_status` is
  /// [FinalStatus.sent] or [FinalStatus.tombstoned] SHALL be skipped.
  /// Returns `null` when no such row exists (the FIFO is empty, or
  /// every row is terminal-passable).
  ///
  /// Callers enforce the wedge: `drain` returns without calling
  /// `Destination.send` when the returned row's `final_status` is
  /// [FinalStatus.wedged]. Recovery from a wedged head is
  /// `tombstoneAndRefill` (REQ-d00144). Returning the wedged row here
  /// (rather than filtering it out) lets UI surfaces observe the
  /// wedge via this single entry point without a separate
  /// `wedgedFifos` probe.
  // Implements: REQ-d00124-A — readFifoHead returns first {null, wedged};
  // skips {sent, tombstoned}.
  Future<FifoEntry?> readFifoHead(String destinationId);

  /// Enumerate FIFO entries for [destinationId], ordered by
  /// `sequence_in_queue` ascending. Optionally sliced by
  /// [afterSequenceInQueue] (exclusive lower bound) and [limit] (cap on
  /// returned size, taken from the start of the ordered range).
  ///
  /// Returns typed [FifoEntry] objects — never raw maps. When
  /// [destinationId] has no registered FIFO store, returns an empty list
  /// (consistent with [readFifoHead] returning `null` for the same case).
  ///
  /// Callers SHALL NOT open the `fifo_<destinationId>` sembast store
  /// directly to read FIFO entries — the store name is an implementation
  /// detail of the sembast backend and is not part of the public storage
  /// contract; this method is the supported enumeration API.
  // Implements: REQ-d00148-A+B+C+D — typed enumeration with exclusive
  // afterSequenceInQueue slicing and optional limit; empty list on
  // unknown destination; no raw-map exposure; sole supported public
  // enumeration path (no fifo_<id> store reach-around).
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  });

  /// Reactive snapshot stream of a destination's FIFO. See REQ-d00150.
  ///
  /// Emits the current queue snapshot on subscribe and on every
  /// mutation to the destination's FIFO. Snapshots are
  /// `List<FifoEntry>` ordered by `sequence_in_queue` ascending.
  /// Multiple subscribers per destination receive identical sequences.
  /// The stream closes when the backend is closed; calling this method
  /// after close SHALL throw `StateError`.
  ///
  /// Consumers SHALL share a single `StorageBackend` instance per
  /// backing storage (REQ-d00150-E, ref REQ-d00149-E).
  ///
  /// **Do not call `pause()` on the returned subscription.** The
  /// underlying broadcast stream is lossy under pause — snapshot
  /// emissions for FIFO mutations that occur while a subscription is
  /// paused are dropped, not buffered (Dart broadcast contract). If a
  /// consumer needs to throttle, do the work asynchronously inside
  /// `onData`, or cancel and re-subscribe (the new subscription emits a
  /// fresh snapshot via `listFifoEntries` on attach, recovering current
  /// state in one read).
  // Implements: REQ-d00150-A+B+C+D+E.
  Stream<List<FifoEntry>> watchFifo(String destinationId);

  /// Reactive snapshot stream of a materialized view by name. See
  /// REQ-d00153.
  ///
  /// Emits the current view rows on subscribe and on every mutation to
  /// any row in [viewName] (upsert / delete / clear). Snapshots are
  /// `List<Map<String, Object?>>` matching `findViewRows(viewName)` — no
  /// implicit ordering; consumers that need a deterministic order sort
  /// in the view layer. Multiple subscribers per view receive identical
  /// sequences. The stream closes when the backend is closed; calling
  /// this method after close SHALL throw `StateError`.
  ///
  /// Cross-view isolation: a mutation on view A SHALL NOT trigger an
  /// emission to a `watchView(B)` subscriber.
  ///
  /// Consumers SHALL share a single `StorageBackend` instance per
  /// backing storage (REQ-d00153-E, ref REQ-d00149-E).
  ///
  /// **Do not call `pause()` on the returned subscription.** Same
  /// semantics as [watchEvents] / [watchFifo]: emissions during pause
  /// are dropped, not buffered. Cancel and re-subscribe to recover
  /// current state via a fresh `findViewRows` snapshot on attach.
  // Implements: REQ-d00153-A+B+C+D+E.
  Stream<List<Map<String, Object?>>> watchView(String viewName);

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
  /// (REQ-d00127-C).
  ///
  /// **Idempotent on matching already-final rows.** When the entry's
  /// current `final_status` equals [status] the call returns without
  /// throwing and without performing any additional write. This closes
  /// the at-least-once drain race: concurrent drainers may both reach
  /// `markFinal` after the first one succeeds; the second observes the
  /// already-correct terminal state and returns cleanly.
  ///
  /// **Throws `StateError` on a status mismatch.** When the entry is
  /// already terminal with a *different* status (e.g. already `sent`,
  /// asked to mark `wedged`) the implementations SHALL throw `StateError`
  /// with both the existing and requested statuses in the message —
  /// this signals real corruption and loud failure is correct.
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  );

  /// True iff any registered destination's FIFO head is `wedged`.
  Future<bool> anyFifoWedged();

  /// Summarize every destination whose head row is wedged.
  Future<List<WedgedFifoSummary>> wedgedFifos();

  // -------- Backend state (KV bookkeeping) --------

  /// Read the current schema version from `backend_state`. Returns 0 when
  /// the backend has never been written to.
  Future<int> readSchemaVersion();

  /// Write [version] into `backend_state` inside [txn]. Used by the schema
  /// migration path at boot; typical production flow writes the version once
  /// and leaves it alone until a migration.
  Future<void> writeSchemaVersion(Txn txn, int version);

  /// Read the per-destination fill cursor — the highest `sequence_number`
  /// that has been promoted into any FIFO row (null, sent, wedged, or tombstoned)
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

  /// Read a single event by `event_id` within [txn]. Returns `null` when no
  /// event with that id is present. Used by ingest's idempotency check
  /// (REQ-d00145-D). Reads the unified event log; origin-appended events
  /// and ingest-appended events occupy a single store keyed by
  /// `sequence_number`.
  // Implements: REQ-d00145-D — unified-store idempotency lookup.
  Future<StoredEvent?> findEventByIdInTxn(Txn txn, String eventId);

  /// Read a single event by `event_id` outside any transaction. Returns
  /// `null` when no event with that id is present. Indexed lookup on the
  /// sembast backend; abstract contract requires equivalent single-row
  /// lookup, not a scan.
  ///
  /// Callers needing read-coherence with writes staged in the same
  /// transaction body SHALL use [findEventByIdInTxn] (REQ-d00145) instead.
  // Implements: REQ-d00147-A+B+C — non-transactional indexed lookup by event_id.
  Future<StoredEvent?> findEventById(String eventId);

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

  /// Read a single FIFO row identified by [entryId] on [destinationId],
  /// or `null` when no such row exists (either the FIFO store was never
  /// written to, or the row was deleted). Non-transactional.
  ///
  /// Exposed as an explicit row-read by `entry_id` (distinct from
  /// [readFifoHead], which always returns the head). Used by
  /// integration tests and tooling that needs to inspect a specific
  /// FIFO row by id.
  Future<FifoEntry?> readFifoRow(String destinationId, String entryId);

  /// Set the row's `final_status` to [status] inside [txn]. The legal
  /// transitions are:
  ///
  /// - `null -> sent` — drain-terminal (SendOk).
  /// - `null -> wedged` — drain-terminal (SendPermanent, or
  ///   SendTransient at max attempts).
  /// - `null -> tombstoned` — `tombstoneAndRefill` on a still-pending
  ///   head.
  /// - `wedged -> tombstoned` — `tombstoneAndRefill` on a wedged head.
  ///
  /// Any other transition is illegal and SHALL throw `StateError`.
  /// `sent` and `tombstoned` are terminal end-states and cannot
  /// transition further. The one-way rule for `null -> terminal` owned
  /// by [markFinal] is subsumed here but the narrower contract on
  /// [markFinal] (null-targets only) remains in force for its callers.
  ///
  /// On `null -> sent` the implementation SHALL stamp
  /// `sent_at = DateTime.now().toUtc()`. On every other transition
  /// `attempts[]` and `sent_at` SHALL be left untouched —
  /// tombstoneAndRefill preserves the wedged row's attempts[] verbatim
  /// (REQ-d00144-B).
  ///
  /// Implementations SHALL throw [StateError] when the target row is
  /// absent — callers are expected to have verified existence (via
  /// [readFifoHead] for tombstoneAndRefill) before opening the
  /// transaction, so a missing row at this point indicates a
  /// concurrent delete race that these ops do not close.
  // Implements: REQ-d00144-B — `null|wedged -> tombstoned` flip,
  // preserves attempts[] verbatim.
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  );

  /// Delete every FIFO row on [destinationId] whose `sequence_in_queue`
  /// is strictly greater than [afterSequenceInQueue] AND whose
  /// `final_status IS null`. Returns the count of rows deleted.
  ///
  /// Used by `tombstoneAndRefill` to sweep the trail behind a
  /// tombstoned target in one transaction (REQ-d00144-C). Rows whose
  /// `final_status` is terminal (any of {sent, wedged, tombstoned})
  /// are left untouched regardless of their `sequence_in_queue` — per
  /// REQ-d00119-D all non-null rows are retained forever.
  // Implements: REQ-d00144-C — trail-delete predicate for tombstoneAndRefill.
  Future<int> deleteNullRowsAfterSequenceInQueueTxn(
    Txn txn,
    String destinationId,
    int afterSequenceInQueue,
  );

  // -------- Audit query (REQ-d00151) --------

  /// Cross-store audit query joining the event log with the security-
  /// context sidecar, filtered by the supplied predicates and paginated
  /// by an opaque [cursor]. Returned rows are sorted by
  /// `recordedAt DESC, eventId DESC` so a stable forward walk is
  /// possible without ties-induced reordering across pages.
  ///
  /// Filters (all optional, AND-combined):
  ///
  /// - [initiator] — match `event.initiator` exactly.
  /// - [flowToken] — match `event.flowToken` exactly.
  /// - [ipAddress] — match `securityContext.ipAddress` exactly.
  /// - [from] / [to] — bound `securityContext.recordedAt` inclusively.
  ///
  /// [limit] SHALL be in `[1, 1000]`; values outside the range throw
  /// `ArgumentError`. [cursor] SHALL be either null (first page) or a
  /// value previously returned in [PagedAudit.nextCursor]; corrupt
  /// cursors throw `ArgumentError`. Pagination is lower-bound on the
  /// `(recordedAt, eventId)` tuple from the previous page's tail, so
  /// concurrent inserts at the head of the result set do not skew
  /// page contents.
  ///
  /// Implementations SHALL perform the join inside the storage layer —
  /// consumers SHALL NOT reach past the abstraction to perform their
  /// own joins. `SembastSecurityContextStore.queryAudit` is a thin
  /// delegator that forwards to this method.
  // Implements: REQ-d00151-A — typed cross-store audit query.
  // Implements: REQ-d00151-B — join lives in storage layer.
  // Implements: REQ-d00137-F — pagination + filter contract (relocated
  // from SecurityContextStore; the same contract holds at this level).
  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  });
}
