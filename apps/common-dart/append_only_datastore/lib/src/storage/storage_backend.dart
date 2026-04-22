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

  /// Read-and-increment the per-device sequence counter within [txn] and
  /// return the value assigned to the next event.
  ///
  /// This is exposed for callers that need to reserve a sequence number
  /// *before* constructing the event (for example, to include it in the
  /// hash-chain input). Callers who take this path SHALL pass the reserved
  /// number through the constructed event to [appendEvent]; [appendEvent]
  /// SHALL then persist the event without further advancing the counter.
  ///
  /// Callers who do not need advance reservation MAY skip [nextSequenceNumber]
  /// entirely and rely on [appendEvent] to advance and stamp the counter as
  /// a single step. Mixing the two paths in a single transaction (calling
  /// [nextSequenceNumber] and then [appendEvent] in a way that causes
  /// [appendEvent] to re-advance) is a caller bug.
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

  /// Append [entry] to destination [destinationId]'s FIFO (REQ-d00117-E).
  /// Conforming implementations SHALL reject the write if
  /// `entry.finalStatus != FinalStatus.pending` or `entry.attempts` is
  /// non-empty; the enqueue step is defined to produce a pending entry with
  /// no attempt history, so a caller supplying anything else is a bug.
  /// Implementations MAY throw `ArgumentError` on violation.
  Future<void> enqueueFifo(Txn txn, String destinationId, FifoEntry entry);

  /// Oldest pending entry in [destinationId]'s FIFO, or null if none. Returns
  /// null when the head of the FIFO is non-pending (e.g., `exhausted`), i.e.
  /// when the FIFO is wedged and cannot advance without operator action.
  Future<FifoEntry?> readFifoHead(String destinationId);

  /// Append [attempt] to the `attempts[]` list of the entry identified by
  /// `(destinationId, entryId)`. Does not change `final_status`.
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  );

  /// Transition an entry to a terminal `final_status`. When [status] is
  /// [FinalStatus.sent] the entry's `sent_at` is also set. Entries
  /// transitioned to terminal status are retained forever as send-log
  /// records (REQ-d00119-D); they are never deleted.
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
}
