import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/security/event_security_context.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/storage/append_result.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/storage/wedged_fifo_summary.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

part 'sembast_test_support.dart';

/// Module-private v4 UUID generator used by [SembastBackend.enqueueFifoTxn]
/// to mint each FIFO row's [FifoEntry.entryId]. Held at file scope (const)
/// so every backend instance shares one generator; `Uuid.v4()` is
/// side-effect-free beyond its internal random state, so a shared
/// instance is correct.
const _uuidGen = Uuid();

/// Package-private default log sink used when a [SembastBackend] instance
/// has not overridden [SembastBackend.debugLogSink]. Routes through
/// `dart:developer` at the warning level (`level: 900`).
// Implements: REQ-d00127-C — warning-level diagnostic when markFinal or
// appendAttempt no-op on a missing target.
void _defaultLogSink(String message) {
  developer.log(message, name: 'SembastBackend', level: 900);
}

/// Concrete Sembast-backed implementation of [StorageBackend].
///
/// Opens a single Sembast database at `path` via `databaseFactory`. The
/// database hosts four logical stores:
///
/// - `events` — append-only event log, keyed by Sembast auto-increment int.
/// - `diary_entries` — materialized view, keyed by `entry_id` (string).
/// - `fifo_<destinationId>` — one per registered destination.
/// - `backend_state` — key-value bookkeeping for the sequence counter and
///   the persisted schema version. Deliberately NOT named `metadata` — that
///   name is already used on every event record as the provenance / change-
///   reason carrier, so reusing it at the store level would make code
///   references ambiguous (REQ-d00117-F).
///
/// The database is opened lazily on first use so construction is cheap and
/// test setup can instantiate many backends without paying database-open
/// cost up front.
class SembastBackend extends StorageBackend {
  /// Construct a backend over an already-opened Sembast [Database]. The
  /// caller owns the database's lifecycle; this backend does not open or
  /// close it. Tests can use `SembastBackendInMemory.open()` from
  /// `package:event_sourcing_datastore/src/storage/sembast_backend_in_memory.dart`
  /// to get a self-contained in-memory instance.
  SembastBackend({required Database database}) : _db = database;

  final Database _db;

  static const _sequenceKey = 'sequence_counter';
  static const _schemaVersionKey = 'schema_version';
  static const _knownFifosKey = 'known_fifo_destinations';

  // Per-destination monotonic `sequence_in_queue` counter key, stored in
  // `backend_state` as `fifo_seq_counter_<destinationId>`. Used by
  // `enqueueFifoTxn` to assign a never-reused sequence_in_queue value
  // (REQ-d00119-E): the counter advances on every enqueue and is never
  // reset, so a row deleted by the REQ-d00144-C trail sweep cannot have
  // its slot re-used by a later enqueue.
  static String _fifoSeqCounterKey(String destinationId) =>
      'fifo_seq_counter_$destinationId';

  static const _eventStoreName = 'events';

  final StoreRef<int, Map<String, Object?>> _eventStore = intMapStoreFactory
      .store(_eventStoreName);
  final StoreRef<String, Object?> _backendStateStore =
      StoreRef<String, Object?>('backend_state');
  final StoreRef<String, Map<String, Object?>> _entriesStore =
      stringMapStoreFactory.store('diary_entries');
  // Backend-private mirror of the `security_context` sembast store so
  // [queryAudit] can join against the event log without reaching into a
  // separate store object. The sembast `StoreRef` is just a typed name
  // handle — multiple refs to the same store name read/write the same
  // underlying records, so this cohabits cleanly with
  // `SembastSecurityContextStore`'s own ref.
  final StoreRef<String, Map<String, Object?>> _securityContextStore =
      stringMapStoreFactory.store('security_context');

  StoreRef<int, Map<String, Object?>> _fifoStore(String destinationId) =>
      intMapStoreFactory.store('fifo_$destinationId');

  Database _database() => _db;

  // Broadcast controllers — feed reactive APIs added in Phase 4.12.
  // _eventsController fed after each successful appendEvent commit
  // (REQ-d00149); origin and ingest paths both route through appendEvent
  // under the unified event store, so a single emission point covers both.
  // _fifoChangesController fed after each successful FIFO mutation;
  // payload is the destinationId (REQ-d00150). _viewChangesController fed
  // after each successful view-row mutation; payload is the viewName
  // (REQ-d00153).
  final StreamController<StoredEvent> _eventsController =
      StreamController<StoredEvent>.broadcast();
  final StreamController<String> _fifoChangesController =
      StreamController<String>.broadcast();
  final StreamController<String> _viewChangesController =
      StreamController<String>.broadcast();

  /// Per-transaction post-commit callback queue. The [transaction]
  /// wrapper swaps in a fresh inner list around each body, then runs
  /// the queued callbacks if and only if the body commits successfully.
  /// Write paths ([appendEvent], FIFO mutators) push
  /// `() => _eventsController.add(event)` /
  /// `() => _fifoChangesController.add(destinationId)` onto this list
  /// after their in-txn writes succeed; the wrapper drains them on
  /// commit. The field is mutable so the wrapper can preserve outer
  /// state across nested calls (sembast does not nest, but the swap is
  /// the cleanest race-safe pattern).
  // Implements: REQ-d00149-A+B+C — post-commit emission to broadcast
  // controllers; co-atomic with the surrounding transaction's commit.
  List<void Function()> _pendingPostCommit = <void Function()>[];

  /// Close the underlying sembast database AND the reactive broadcast
  /// controllers used by [watchEvents] / [watchFifo] / [watchView]. After
  /// close, further calls to those reactive methods SHALL throw
  /// `StateError`. Active subscribers receive `done`.
  ///
  /// Not safe to call concurrently with an in-flight [transaction]. The
  /// caller is responsible for awaiting outstanding work before closing.
  Future<void> close() async {
    await _eventsController.close();
    await _fifoChangesController.close();
    await _viewChangesController.close();
    await _db.close();
  }

  /// Visible-for-testing sink for the warning-level diagnostic emitted by
  /// [markFinal] and [appendAttempt] when they no-op on a missing target
  /// (REQ-d00127-C). Defaults to the package-private [_defaultLogSink],
  /// which writes through `dart:developer` at `level: 900` (warning).
  /// Tests install a `List<String>.add` closure to capture emitted lines
  /// without depending on a global logger. Setting this to `null`
  /// suppresses diagnostics entirely.
  // Implements: REQ-d00127-C — debugLogSink for test capture.
  void Function(String)? debugLogSink = _defaultLogSink;

  // -------- transaction --------

  @override
  Future<T> transaction<T>(Future<T> Function(Txn txn) body) async {
    final db = _database();
    final outerPending = _pendingPostCommit;
    final innerPending = <void Function()>[];
    _pendingPostCommit = innerPending;
    try {
      final result = await db.transaction((sembastTxn) async {
        final txn = _SembastTxn._(sembastTxn);
        try {
          return await body(txn);
        } finally {
          txn._invalidate();
        }
      });
      // Commit succeeded — fire post-commit callbacks. Skip emissions
      // when the corresponding controller has been closed (close() is
      // not safe to race with in-flight transactions, but a fast-cycle
      // test may still observe the closed state here).
      for (final cb in innerPending) {
        cb();
      }
      return result;
    } finally {
      _pendingPostCommit = outerPending;
    }
  }

  _SembastTxn _requireValidTxn(Txn txn) {
    if (txn is! _SembastTxn) {
      throw StateError('Txn is not a SembastBackend Txn');
    }
    if (!txn._isValid) {
      throw StateError('Txn used outside its transaction() body');
    }
    return txn;
  }

  /// Return the underlying sembast [Transaction] for [txn]. Used by
  /// adjacent sembast-family stores (e.g. `SembastSecurityContextStore`)
  /// that need to commit writes atomically with this backend's
  /// transaction. NOT part of the abstract `StorageBackend` contract —
  /// only sembast-side code should reach for this.
  // ignore: library_private_types_in_public_api
  Transaction unwrapSembastTxn(Txn txn) => _requireValidTxn(txn)._sembastTxn;

  // -------- Events --------

  /// Persist [event] inside [txn] and return its [AppendResult]. Under the
  /// Phase-2 Prereq B reserve-and-increment contract, `event.sequenceNumber`
  /// MUST equal the value returned by a prior [nextSequenceNumber] call in
  /// the same transaction — i.e., it MUST equal the current persisted
  /// counter value. [appendEvent] does not advance the counter; the advance
  /// is owned by [nextSequenceNumber].
  ///
  /// A mismatch means the caller either skipped [nextSequenceNumber] or
  /// consumed the reservation with a wrong `sequenceNumber`; both are
  /// caller bugs, so `appendEvent` throws `StateError` rather than
  /// silently accepting an out-of-range value.
  // Implements: REQ-d00117-C — appendEvent co-atomic with sequence counter
  // (advance owned by nextSequenceNumber; appendEvent consumes the
  // reservation).
  // Implements: REQ-p00004-A+B — append-only event, hash chain stamped by
  // caller and persisted verbatim.
  @override
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event) async {
    final t = _requireValidTxn(txn);
    final currentRaw = await _backendStateStore
        .record(_sequenceKey)
        .get(t._sembastTxn);
    final current = (currentRaw as int?) ?? 0;
    if (event.sequenceNumber != current) {
      throw StateError(
        'appendEvent: event.sequenceNumber (${event.sequenceNumber}) '
        'must equal the reserved counter value ($current). '
        'Did the caller forget to call nextSequenceNumber in this '
        'transaction? (Phase-2 Prereq B, Option 1: reserve-and-increment; '
        'appendEvent consumes a reservation, it does not create one.)',
      );
    }
    await _eventStore.add(t._sembastTxn, event.toMap());
    // Implements: REQ-d00149-A — emit on the broadcast controller
    // post-commit so live subscribers learn of the new event in
    // sequence_number order.
    _pendingPostCommit.add(() {
      if (!_eventsController.isClosed) _eventsController.add(event);
    });
    return AppendResult(
      sequenceNumber: event.sequenceNumber,
      eventHash: event.eventHash,
    );
  }

  @override
  Future<List<StoredEvent>> findEventsForAggregate(String aggregateId) async {
    final db = _database();
    final finder = Finder(
      filter: Filter.equals('aggregate_id', aggregateId),
      sortOrders: [SortOrder('sequence_number')],
    );
    final records = await _eventStore.find(db, finder: finder);
    return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
  }

  @override
  Future<List<StoredEvent>> findEventsForAggregateInTxn(
    Txn txn,
    String aggregateId,
  ) async {
    final t = _requireValidTxn(txn);
    final finder = Finder(
      filter: Filter.equals('aggregate_id', aggregateId),
      sortOrders: [SortOrder('sequence_number')],
    );
    final records = await _eventStore.find(t._sembastTxn, finder: finder);
    return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
  }

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
  }) async {
    final db = _database();
    final finder = Finder(
      filter: afterSequence != null
          ? Filter.greaterThan('sequence_number', afterSequence)
          : null,
      sortOrders: [SortOrder('sequence_number')],
      limit: limit,
    );
    final records = await _eventStore.find(db, finder: finder);
    return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
  }

  /// Reserve-and-increment the sequence counter within [txn]. Phase-2
  /// Prereq B, Option 1: the counter is advanced as a side effect so that
  /// a second call in the same transaction returns `current + 2`. A paired
  /// [appendEvent] consumes the reservation without advancing again. If
  /// the transaction rolls back, the counter rollback falls out of
  /// Sembast's transactional semantics.
  // Implements: REQ-d00117-C — reserve-and-increment sequence counter in a
  // single atomic step with the subsequent appendEvent.
  @override
  Future<int> nextSequenceNumber(Txn txn) async {
    final t = _requireValidTxn(txn);
    final currentRaw = await _backendStateStore
        .record(_sequenceKey)
        .get(t._sembastTxn);
    final current = (currentRaw as int?) ?? 0;
    final reserved = current + 1;
    await _backendStateStore.record(_sequenceKey).put(t._sembastTxn, reserved);
    return reserved;
  }

  @override
  Future<String?> readLatestEventHash(Txn txn) async {
    final t = _requireValidTxn(txn);
    final records = await _eventStore.find(
      t._sembastTxn,
      finder: Finder(
        sortOrders: [SortOrder('sequence_number', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    return records.first.value['event_hash'] as String?;
  }

  @override
  Future<List<StoredEvent>> findAllEventsInTxn(
    Txn txn, {
    int? afterSequence,
    int? limit,
  }) async {
    final t = _requireValidTxn(txn);
    final records = await _eventStore.find(
      t._sembastTxn,
      finder: Finder(
        filter: afterSequence != null
            ? Filter.greaterThan('sequence_number', afterSequence)
            : null,
        sortOrders: [SortOrder('sequence_number')],
        limit: limit,
      ),
    );
    return records.map((r) => StoredEvent.fromMap(r.value, r.key)).toList();
  }

  // Implements: REQ-d00149-A+B+C+D+E — replay-then-live with race-safe
  // live-filter via held-cursor; broadcast; close-aware.
  //
  // The per-call controller is itself broadcast so a single
  // `watchEvents()` return value supports multiple `listen()`
  // subscribers (REQ-d00149-C). On the first listen:
  //   1. `scheduleMicrotask(startReplay)` defers the replay so the
  //      caller's `listen()` returns before any emission, ensuring no
  //      replayed event is missed.
  //   2. Replay reads `findAllEvents(afterSequence: lowerBound)` and
  //      forwards each event, advancing `lastReplayed`.
  //   3. After replay completes, attach to the package-private
  //      `_eventsController` broadcast and filter
  //      `e.sequenceNumber > lastReplayed` per REQ-d00149-B — this
  //      closes the race where an event commits between the replay
  //      snapshot read and the live attach.
  // Close on the backend's `_eventsController` propagates via
  // `onDone`. The per-call controller closes via `controller.close()`.
  @override
  Stream<StoredEvent> watchEvents({int? afterSequence}) {
    if (_eventsController.isClosed) {
      throw StateError(
        'SembastBackend.close has been called; watchEvents unavailable',
      );
    }
    final lowerBound = afterSequence ?? 0;
    final controller = StreamController<StoredEvent>.broadcast();
    var lastReplayed = lowerBound;
    StreamSubscription<StoredEvent>? liveSub;
    var started = false;

    Future<void> startReplay() async {
      try {
        final replay = await findAllEvents(afterSequence: lowerBound);
        for (final e in replay) {
          if (controller.isClosed) return;
          controller.add(e);
          lastReplayed = e.sequenceNumber;
        }
      } catch (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      }
      if (controller.isClosed) return;
      liveSub = _eventsController.stream.listen(
        (e) {
          if (e.sequenceNumber > lastReplayed) controller.add(e);
        },
        onError: controller.addError,
        onDone: controller.close,
      );
    }

    controller
      ..onListen = () {
        // Broadcast controllers fire `onListen` on every fresh listen
        // attach, but replay-then-live setup must run only once for the
        // lifetime of this watchEvents() call. The `started` guard
        // ensures multiple subscribers share a single replay + live
        // pipeline.
        if (started) return;
        started = true;
        scheduleMicrotask(startReplay);
      }
      ..onCancel = () async {
        // Broadcast `onCancel` fires when the LAST subscriber cancels;
        // tear down the upstream live subscription so the broadcast
        // controller does not leak after all subscribers detach. The
        // controller stays open so a later listener can re-attach
        // (broadcast semantics).
        await liveSub?.cancel();
        liveSub = null;
        started = false;
      };
    return controller.stream;
  }

  @override
  Future<int> readSequenceCounter() async {
    final db = _database();
    final value = await _backendStateStore.record(_sequenceKey).get(db);
    return (value as int?) ?? 0;
  }

  // -------- Backend state KV --------

  @override
  Future<int> readSchemaVersion() async {
    final db = _database();
    final value = await _backendStateStore.record(_schemaVersionKey).get(db);
    return (value as int?) ?? 0;
  }

  @override
  Future<void> writeSchemaVersion(Txn txn, int version) async {
    final t = _requireValidTxn(txn);
    await _backendStateStore
        .record(_schemaVersionKey)
        .put(t._sembastTxn, version);
  }

  static String _fillCursorKey(String destinationId) =>
      'fill_cursor_$destinationId';

  /// Read the per-destination fill cursor. Returns -1 when the key is absent
  /// (no row has yet been enqueued for this destination). Non-transactional.
  // Implements: REQ-d00128-G — per-destination fill cursor read, -1 sentinel.
  @override
  Future<int> readFillCursor(String destinationId) async {
    final db = _database();
    final value = await _backendStateStore
        .record(_fillCursorKey(destinationId))
        .get(db);
    return (value as int?) ?? -1;
  }

  /// Write the per-destination fill cursor inside its own atomic
  /// transaction.
  // Implements: REQ-d00128-G — per-destination fill cursor write
  // (standalone variant; opens its own transaction).
  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) async {
    _validateFillCursorValue(sequenceNumber);
    await _database().transaction((sembastTxn) async {
      await _backendStateStore
          .record(_fillCursorKey(destinationId))
          .put(sembastTxn, sequenceNumber);
    });
  }

  /// Write the per-destination fill cursor inside [txn] so the advance is
  /// co-atomic with the surrounding transaction. Rolls back with the rest
  /// of the transaction body on a throw.
  // Implements: REQ-d00128-G — per-destination fill cursor write
  // (transactional variant; participates in surrounding atomicity).
  @override
  Future<void> writeFillCursorTxn(
    Txn txn,
    String destinationId,
    int sequenceNumber,
  ) async {
    _validateFillCursorValue(sequenceNumber);
    final t = _requireValidTxn(txn);
    await _backendStateStore
        .record(_fillCursorKey(destinationId))
        .put(t._sembastTxn, sequenceNumber);
  }

  /// The fill cursor's legal domain is `[-1, ∞)`: `-1` is the "no row
  /// enqueued" / "rewound to pre-start" sentinel per REQ-d00128-G and
  /// REQ-d00131-D; all other values are `sequence_number`s drawn from the
  /// event log, which are non-negative ints. Reject anything smaller than
  /// `-1` at write time so a bogus caller value cannot land as a stored
  /// cursor and confuse downstream fillBatch / unjam logic.
  void _validateFillCursorValue(int sequenceNumber) {
    if (sequenceNumber < -1) {
      throw ArgumentError.value(
        sequenceNumber,
        'sequenceNumber',
        'fill_cursor must be >= -1 (-1 = unset or rewound to pre-start; '
            'all other values are event sequence_numbers)',
      );
    }
  }

  // -------- Destination schedules (REQ-d00129) --------

  static String _scheduleKey(String destinationId) => 'schedule_$destinationId';

  /// Read the persisted `DestinationSchedule` for [destinationId], or
  /// null when no schedule record exists. Non-transactional.
  // Implements: REQ-d00129-A+C+F — schedule read backs
  // DestinationRegistry.scheduleOf.
  @override
  Future<DestinationSchedule?> readSchedule(String destinationId) async {
    final db = _database();
    final value = await _backendStateStore
        .record(_scheduleKey(destinationId))
        .get(db);
    if (value == null) return null;
    return DestinationSchedule.fromJson(
      Map<String, Object?>.from(value as Map),
    );
  }

  /// Persist [schedule] for [destinationId] inside its own atomic
  /// transaction (standalone variant).
  // Implements: REQ-d00129-A — initial dormant-schedule persistence.
  @override
  Future<void> writeSchedule(
    String destinationId,
    DestinationSchedule schedule,
  ) async {
    await _database().transaction((sembastTxn) async {
      await _backendStateStore
          .record(_scheduleKey(destinationId))
          .put(sembastTxn, schedule.toJson());
    });
  }

  /// Persist [schedule] inside [txn] so the write participates in the
  /// surrounding transaction's atomicity.
  // Implements: REQ-d00129-C+F+H — transactional schedule write.
  @override
  Future<void> writeScheduleTxn(
    Txn txn,
    String destinationId,
    DestinationSchedule schedule,
  ) async {
    final t = _requireValidTxn(txn);
    await _backendStateStore
        .record(_scheduleKey(destinationId))
        .put(t._sembastTxn, schedule.toJson());
  }

  /// Delete the persisted schedule record for [destinationId] inside
  /// [txn]. Used by `deleteDestination`.
  // Implements: REQ-d00129-H — atomic schedule-record drop.
  @override
  Future<void> deleteScheduleTxn(Txn txn, String destinationId) async {
    final t = _requireValidTxn(txn);
    await _backendStateStore
        .record(_scheduleKey(destinationId))
        .delete(t._sembastTxn);
  }

  /// Drop the entire `fifo_<destinationId>` Sembast store inside [txn]
  /// and remove [destinationId] from the known-FIFOs registry so
  /// `anyFifoWedged` / `wedgedFifos` no longer iterate it.
  // Implements: REQ-d00129-H — atomic FIFO-store drop.
  @override
  Future<void> deleteFifoStoreTxn(Txn txn, String destinationId) async {
    final t = _requireValidTxn(txn);
    await _fifoStore(destinationId).drop(t._sembastTxn);
    // Also drop the fill-cursor record so a later addDestination of the
    // same id starts from a clean slate rather than inheriting a stale
    // cursor.
    await _backendStateStore
        .record(_fillCursorKey(destinationId))
        .delete(t._sembastTxn);
    // Drop the per-destination sequence_in_queue counter so a later
    // addDestination of the same id starts at 1 rather than inheriting
    // the old counter. REQ-d00119-E's "never reused" invariant is
    // scoped to a destination's lifetime; a fresh addDestination is a
    // fresh lifetime.
    await _backendStateStore
        .record(_fifoSeqCounterKey(destinationId))
        .delete(t._sembastTxn);
    // Remove the id from the known-FIFOs registry so wedged-FIFO
    // iteration does not hit a dropped store.
    final current =
        (await _backendStateStore.record(_knownFifosKey).get(t._sembastTxn)
                as List?)
            ?.cast<String>()
            .toList() ??
        <String>[];
    if (current.remove(destinationId)) {
      await _backendStateStore
          .record(_knownFifosKey)
          .put(t._sembastTxn, current);
    }
    // Implements: REQ-d00150-A — emit on the broadcast controller
    // post-commit so live `watchFifo(destinationId)` subscribers see
    // the FIFO-store drop (subsequent listFifoEntries will be empty).
    _pendingPostCommit.add(() {
      if (!_fifoChangesController.isClosed) {
        _fifoChangesController.add(destinationId);
      }
    });
  }

  // -------- diary_entries --------

  /// Whole-row replace into `diary_entries` keyed on `entry.entryId`
  /// (REQ-d00117-D). Sembast's `record(key).put(...)` semantic IS a
  /// whole-row replace; no partial merge is possible through this path.
  // Implements: REQ-d00117-D — whole-row replace, not partial merge.
  @override
  Future<void> upsertEntry(Txn txn, DiaryEntry entry) async {
    final t = _requireValidTxn(txn);
    await _entriesStore
        .record(entry.entryId)
        .put(t._sembastTxn, entry.toJson());
  }

  /// Delete every row from `diary_entries` inside [txn].
  // Implements: REQ-d00121-G — rebuild replaces the cache without reading
  // prior contents.
  @override
  Future<void> clearEntries(Txn txn) async {
    final t = _requireValidTxn(txn);
    await _entriesStore.delete(t._sembastTxn);
  }

  /// Query `diary_entries` with optional filters, all combined with logical
  /// AND. Rows whose `effective_date` is null are excluded from any query
  /// that specifies [dateFrom] or [dateTo]; pass null for both date
  /// parameters to include null-date rows.
  @override
  Future<List<DiaryEntry>> findEntries({
    String? entryType,
    bool? isComplete,
    bool? isDeleted,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final db = _database();
    final filters = <Filter>[];
    if (entryType != null) {
      filters.add(Filter.equals('entry_type', entryType));
    }
    if (isComplete != null) {
      filters.add(Filter.equals('is_complete', isComplete));
    }
    if (isDeleted != null) {
      filters.add(Filter.equals('is_deleted', isDeleted));
    }
    // ISO 8601 strings compare lexicographically in date order when they
    // share the same offset, which ours do (all UTC or all with an
    // explicit offset). Nulls are excluded because `null` fails any
    // lexicographic comparison against a String in Sembast.
    if (dateFrom != null) {
      filters.add(
        Filter.greaterThanOrEquals(
          'effective_date',
          dateFrom.toIso8601String(),
        ),
      );
    }
    if (dateTo != null) {
      filters.add(
        Filter.lessThanOrEquals('effective_date', dateTo.toIso8601String()),
      );
    }
    final finder = filters.isEmpty ? null : Finder(filter: Filter.and(filters));
    final records = await _entriesStore.find(db, finder: finder);
    return records.map((r) => DiaryEntry.fromJson(r.value)).toList();
  }

  @override
  Future<DiaryEntry?> readEntryInTxn(Txn txn, String entryId) async {
    final t = _requireValidTxn(txn);
    final raw = await _entriesStore.record(entryId).get(t._sembastTxn);
    if (raw == null) return null;
    return DiaryEntry.fromJson(raw);
  }

  // -------- Generic view storage (Phase 4.4) --------

  final Map<String, StoreRef<String, Map<String, Object?>>> _viewStoreCache =
      <String, StoreRef<String, Map<String, Object?>>>{};

  StoreRef<String, Map<String, Object?>> _viewStore(String viewName) =>
      _viewStoreCache.putIfAbsent(
        viewName,
        () => stringMapStoreFactory.store(viewName),
      );

  // Implements: REQ-d00140-F — readViewRowInTxn generic view-row read.
  @override
  Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
  ) async {
    final t = _requireValidTxn(txn);
    final raw = await _viewStore(viewName).record(key).get(t._sembastTxn);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  // Implements: REQ-d00140-F — upsertViewRowInTxn whole-row upsert.
  // Implements: REQ-d00153-A — emit on _viewChangesController post-commit
  // so watchView subscribers re-fetch the snapshot.
  @override
  Future<void> upsertViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
    Map<String, dynamic> row,
  ) async {
    final t = _requireValidTxn(txn);
    await _viewStore(
      viewName,
    ).record(key).put(t._sembastTxn, Map<String, Object?>.from(row));
    _pendingPostCommit.add(() {
      if (!_viewChangesController.isClosed) {
        _viewChangesController.add(viewName);
      }
    });
  }

  // Implements: REQ-d00140-F — deleteViewRowInTxn row-scoped delete.
  // Implements: REQ-d00153-A — emit on _viewChangesController post-commit.
  @override
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key) async {
    final t = _requireValidTxn(txn);
    await _viewStore(viewName).record(key).delete(t._sembastTxn);
    _pendingPostCommit.add(() {
      if (!_viewChangesController.isClosed) {
        _viewChangesController.add(viewName);
      }
    });
  }

  // Implements: REQ-d00140-F — findViewRows iteration with limit/offset.
  @override
  Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {
    int? limit,
    int? offset,
  }) async {
    final db = _database();
    final records = await _viewStore(viewName).find(
      db,
      finder: Finder(limit: limit, offset: offset),
    );
    return records
        .map((r) => Map<String, dynamic>.from(r.value))
        .toList(growable: false);
  }

  // Implements: REQ-d00140-F — clearViewInTxn view-scoped clear; other
  // views untouched.
  // Implements: REQ-d00153-A — emit on _viewChangesController post-commit.
  @override
  Future<void> clearViewInTxn(Txn txn, String viewName) async {
    final t = _requireValidTxn(txn);
    await _viewStore(viewName).delete(t._sembastTxn);
    _pendingPostCommit.add(() {
      if (!_viewChangesController.isClosed) {
        _viewChangesController.add(viewName);
      }
    });
  }

  // -------- View target versions (Phase 4.19) --------
  //
  // Persists the per-(viewName, entryType) target schema version that the
  // promoter pipeline reads on every materialization. One sembast store
  // (`view_target_versions`) keyed on `'<viewName>::<entryType>'`; rows
  // carry `view_name` / `entry_type` / `target_version` so `find` /
  // `delete` can scope by `view_name`.

  static const _viewTargetVersionsStore = 'view_target_versions';

  final StoreRef<String, Map<String, Object?>> _viewTargetVersionsStoreRef =
      stringMapStoreFactory.store(_viewTargetVersionsStore);

  String _viewTargetVersionsKey(String viewName, String entryType) =>
      '$viewName::$entryType';

  // Implements: REQ-d00140-I.
  @override
  Future<int?> readViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
  ) async {
    final t = _requireValidTxn(txn);
    final raw = await _viewTargetVersionsStoreRef
        .record(_viewTargetVersionsKey(viewName, entryType))
        .get(t._sembastTxn);
    if (raw == null) return null;
    final v = raw['target_version'];
    if (v is! int) {
      throw StateError(
        'view_target_versions[$viewName::$entryType]: target_version not int '
        '(got ${v.runtimeType}); database corrupted',
      );
    }
    return v;
  }

  // Implements: REQ-d00140-I.
  @override
  Future<void> writeViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
    int targetVersion,
  ) async {
    final t = _requireValidTxn(txn);
    await _viewTargetVersionsStoreRef
        .record(_viewTargetVersionsKey(viewName, entryType))
        .put(t._sembastTxn, <String, Object?>{
          'view_name': viewName,
          'entry_type': entryType,
          'target_version': targetVersion,
        });
  }

  // Implements: REQ-d00140-I.
  @override
  Future<Map<String, int>> readAllViewTargetVersionsInTxn(
    Txn txn,
    String viewName,
  ) async {
    final t = _requireValidTxn(txn);
    final records = await _viewTargetVersionsStoreRef.find(
      t._sembastTxn,
      finder: Finder(filter: Filter.equals('view_name', viewName)),
    );
    return <String, int>{
      for (final r in records)
        (r.value['entry_type'] as String): (r.value['target_version'] as int),
    };
  }

  // Implements: REQ-d00140-I.
  @override
  Future<void> clearViewTargetVersionsInTxn(Txn txn, String viewName) async {
    final t = _requireValidTxn(txn);
    await _viewTargetVersionsStoreRef.delete(
      t._sembastTxn,
      finder: Finder(filter: Filter.equals('view_name', viewName)),
    );
  }

  // -------- FIFO --------

  /// Append a batch-shaped row to destination [destinationId]'s FIFO. The
  /// row covers every event in [batch].
  ///
  /// Opens its own atomic transaction and delegates the actual row
  /// construction to [enqueueFifoTxn]. Callers already composing a larger
  /// transaction (replay, fill_batch) SHALL use [enqueueFifoTxn] so the
  /// enqueue and any accompanying writes (e.g., fill_cursor advance)
  /// commit co-atomically.
  ///
  /// Exactly one of [wirePayload] / [nativeEnvelope] SHALL be non-null
  /// (REQ-d00152-B+E). See [StorageBackend.enqueueFifo] for the contract
  /// distinguishing the two payload shapes.
  ///
  /// The backend owns `sequence_in_queue` via the persisted
  /// `fifo_seq_counter_<destinationId>` record (REQ-d00119-E):
  /// monotonic, never reused.
  ///
  /// The returned `FifoEntry` is the persisted record. Callers that
  /// need to advance a per-destination cursor use
  /// `result.eventIdRange.lastSeq` as the inclusive upper bound of the
  /// batch on the event log.
  ///
  /// The row's `entry_id` is a freshly-minted v4 UUID and has no
  /// relationship to the events the row carries — callers that need
  /// to correlate against events use `eventIds` / `eventIdRange`.
  // Implements: REQ-d00117-E — enqueue initial state (pending, no
  // attempts, no sent_at).
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue (standalone
  // variant; opens its own transaction and delegates to enqueueFifoTxn).
  // Implements: REQ-d00152-B+E — XOR (wirePayload, nativeEnvelope) shape.
  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) async {
    // Route through this backend's `transaction()` (rather than the
    // raw `_database().transaction(...)`) so the post-commit callback
    // appended inside `enqueueFifoTxn` is drained by the wrapper on
    // commit; otherwise REQ-d00150-A FIFO-change emissions on the
    // standalone enqueue path would silently drop.
    return transaction(
      (txn) => enqueueFifoTxn(
        txn,
        destinationId,
        batch,
        wirePayload: wirePayload,
        nativeEnvelope: nativeEnvelope,
      ),
    );
  }

  /// Transactional variant of [enqueueFifo]: participates in the
  /// surrounding [txn] so the FIFO-row write and the caller's
  /// accompanying writes commit or roll back together. Used by
  /// `fillBatch` to keep the enqueue + fill_cursor advance co-atomic,
  /// and by `runHistoricalReplay` to compose a larger walk of the event
  /// log into a single transaction.
  ///
  /// Exactly one of [wirePayload] / [nativeEnvelope] SHALL be non-null:
  ///
  /// - [wirePayload] (3rd-party): persists `wire_payload = decoded JSON
  ///   map`, `wire_format = wirePayload.contentType`,
  ///   `transform_version = wirePayload.transformVersion`,
  ///   `envelope_metadata = null`.
  /// - [nativeEnvelope] (native `esd/batch@1`): persists
  ///   `wire_payload = null`, `wire_format = "esd/batch@1"`,
  ///   `transform_version = null`, `envelope_metadata = nativeEnvelope`.
  ///
  /// Centralizes all row-construction logic: empty-batch rejection,
  /// XOR-shape enforcement, v4-UUID `entry_id` minting,
  /// `sequence_in_queue` assignment, and the known-FIFOs registry
  /// bookkeeping all live here; [enqueueFifo] is a thin
  /// `transaction(...)` wrapper.
  // Implements: REQ-d00117-E — enqueue initial state (pending, no
  // attempts, no sent_at).
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  // Implements: REQ-d00119-B+K — native rows store envelope_metadata +
  // null wire_payload; 3rd-party rows store wire_payload + null
  // envelope_metadata.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue (transactional
  // variant; used by fillBatch to co-commit enqueue + fill_cursor).
  // Implements: REQ-d00152-B+E — XOR (wirePayload, nativeEnvelope) shape;
  // native path stores envelope_metadata directly, no wire decode.
  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) async {
    if (batch.isEmpty) {
      throw ArgumentError.value(
        batch,
        'batch',
        'enqueueFifo requires a non-empty batch (REQ-d00128-A)',
      );
    }
    // XOR enforcement: exactly one payload shape is legal. Reject both
    // null and both non-null at the boundary so a downstream FIFO row
    // never carries an ambiguous (wire_payload, envelope_metadata) pair.
    if ((wirePayload == null) == (nativeEnvelope == null)) {
      throw ArgumentError(
        'enqueueFifo requires exactly one of wirePayload or nativeEnvelope '
        'to be non-null (REQ-d00152-B+E); got '
        'wirePayload=${wirePayload == null ? "null" : "set"}, '
        'nativeEnvelope=${nativeEnvelope == null ? "null" : "set"}',
      );
    }
    final t = _requireValidTxn(txn);
    final eventIds = batch.map((e) => e.eventId).toList(growable: false);
    final eventIdRange = (
      firstSeq: batch.first.sequenceNumber,
      lastSeq: batch.last.sequenceNumber,
    );
    // Resolve the row's wire-format / payload columns from the chosen
    // payload shape. Native rows carry envelope_metadata; 3rd-party rows
    // decode the bytes once and persist the resulting JSON map.
    Map<String, Object?>? payloadMap;
    String wireFormat;
    String? transformVersion;
    if (nativeEnvelope != null) {
      payloadMap = null;
      wireFormat = BatchEnvelope.wireFormat;
      transformVersion = null;
    } else {
      // 3rd-party: bytes MUST be valid JSON encoding a Map — destinations
      // that transform to bytes representing a top-level JSON object
      // conform; other shapes are rejected with ArgumentError rather
      // than corrupting the FIFO row.
      final wp = wirePayload!;
      try {
        final decoded = jsonDecode(utf8.decode(wp.bytes));
        if (decoded is! Map) {
          throw ArgumentError.value(
            wp,
            'wirePayload',
            'enqueueFifo requires wirePayload.bytes to encode a JSON object '
                '(Map); got ${decoded.runtimeType}',
          );
        }
        payloadMap = Map<String, Object?>.from(decoded);
      } on FormatException catch (e) {
        throw ArgumentError.value(
          wp,
          'wirePayload',
          'enqueueFifo requires wirePayload.bytes to be UTF-8 JSON: '
              '${e.message}',
        );
      }
      wireFormat = wp.contentType;
      transformVersion = wp.transformVersion;
    }
    // Mint a v4 UUID for this row's entry_id. The identifier is opaque
    // and has no relationship to the events the row carries — callers
    // that need event-level correlation use `eventIds` / `eventIdRange`.
    // UUID generation means two FIFO rows (of any final_status, including
    // tombstoned archive rows) never share an entry_id, so
    // `tombstoneAndRefill` can coexist with fresh rows re-promoting the
    // same underlying events (REQ-d00144-F).
    final entryId = _uuidGen.v4();
    final enqueuedAt = DateTime.now().toUtc();
    final store = _fifoStore(destinationId);
    // Assign the next sequence_in_queue from a persisted per-destination
    // counter (backend_state/fifo_seq_counter_<destinationId>). The
    // counter advances strictly monotonically and is NEVER reset: even
    // when a row is deleted (trail sweep per REQ-d00144-C), the deleted
    // slot is NOT re-used. The resulting invariant (REQ-d00119-E) is
    // load-bearing for event-log cursor math and for the send-log's
    // auditability — two different rows with the same sequence_in_queue
    // would produce ambiguous "which row was deleted?" diagnostics.
    //
    // Storing the counter in backend_state rather than deriving from
    // max(existing key) + 1 at read time closes the reuse path: the
    // previous derivation would reassign slot N if row N was deleted
    // and row N was the current max.
    // Implements: REQ-d00119-E — sequence_in_queue monotonic; never reused.
    final counterRec = _backendStateStore.record(
      _fifoSeqCounterKey(destinationId),
    );
    final currentCounter = (await counterRec.get(t._sembastTxn) as int?) ?? 0;
    final assigned = currentCounter + 1;
    await counterRec.put(t._sembastTxn, assigned);
    final entry = FifoEntry(
      entryId: entryId,
      eventIds: eventIds,
      eventIdRange: eventIdRange,
      sequenceInQueue: assigned,
      wirePayload: payloadMap,
      wireFormat: wireFormat,
      transformVersion: transformVersion,
      enqueuedAt: enqueuedAt,
      attempts: const <AttemptResult>[],
      finalStatus: null,
      sentAt: null,
      envelopeMetadata: nativeEnvelope,
    );
    await store.record(assigned).put(t._sembastTxn, entry.toJson());
    await _registerFifoDestinationSembast(t._sembastTxn, destinationId);
    // Implements: REQ-d00150-A — emit on the broadcast controller
    // post-commit so live `watchFifo(destinationId)` subscribers learn
    // of the new row. Pushed onto _pendingPostCommit so the emission is
    // co-atomic with the surrounding `transaction()` commit; fires only
    // if the transaction succeeds. `enqueueFifo` (the standalone
    // wrapper) routes through `transaction()` for the same reason.
    _pendingPostCommit.add(() {
      if (!_fifoChangesController.isClosed) {
        _fifoChangesController.add(destinationId);
      }
    });
    return entry;
  }

  Future<void> _registerFifoDestinationSembast(
    Transaction sembastTxn,
    String destinationId,
  ) async {
    final current =
        (await _backendStateStore.record(_knownFifosKey).get(sembastTxn)
                as List?)
            ?.cast<String>()
            .toList() ??
        <String>[];
    if (!current.contains(destinationId)) {
      current.add(destinationId);
      await _backendStateStore.record(_knownFifosKey).put(sembastTxn, current);
    }
  }

  Future<List<String>> _knownFifoDestinations() async {
    final db = _database();
    final value = await _backendStateStore.record(_knownFifosKey).get(db);
    return (value as List?)?.cast<String>().toList() ?? const <String>[];
  }

  /// Head row of [destinationId]'s FIFO: the first row in
  /// `sequence_in_queue` order whose `final_status` is either `null`
  /// (pre-terminal; drain may attempt) or [FinalStatus.wedged] (blocking
  /// terminal; drain halts on seeing this value). Rows whose
  /// `final_status` is [FinalStatus.sent] or [FinalStatus.tombstoned] are
  /// terminal-passable and are SKIPPED. Returns `null` when no row in
  /// `{null, wedged}` exists — i.e., the FIFO is empty or every row is
  /// terminal-passable.
  ///
  /// The wedge is enforced by the caller: on a wedged return value
  /// `drain` returns without calling `Destination.send`. Exposing the
  /// wedged row here (rather than filtering it out) lets UI surfaces
  /// observe the wedge via this single entry point without a separate
  /// `wedgedFifos` probe.
  // Implements: REQ-d00124-A — readFifoHead returns first {null, wedged};
  // skips {sent, tombstoned}. Recovery from a wedged head is
  // tombstoneAndRefill (REQ-d00144).
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) async {
    final db = _database();
    final store = _fifoStore(destinationId);
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.or([
          Filter.isNull('final_status'),
          Filter.equals('final_status', FinalStatus.wedged.toJson()),
        ]),
        sortOrders: [SortOrder('sequence_in_queue')],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    return FifoEntry.fromJson(Map<String, Object?>.from(records.single.value));
  }

  // Implements: REQ-d00148-A+B+C+D — listFifoEntries returns the
  // destination's FIFO rows as typed FifoEntry, ordered by
  // sequence_in_queue ascending. afterSequenceInQueue is an exclusive
  // lower bound (Filter.greaterThan); limit caps result size taken from
  // the start of the ordered range. An unknown destination falls
  // through to records.isEmpty (sembast lazily-creates stores so a
  // never-written FIFO has zero records) and returns an empty list. No
  // raw-map shape leaks; callers must use this method rather than
  // opening the fifo_<id> store by name.
  @override
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  }) async {
    final db = _database();
    final store = _fifoStore(destinationId);
    final records = await store.find(
      db,
      finder: Finder(
        filter: afterSequenceInQueue != null
            ? Filter.greaterThan('sequence_in_queue', afterSequenceInQueue)
            : null,
        sortOrders: [SortOrder('sequence_in_queue')],
        limit: limit,
      ),
    );
    return records
        .map((r) => FifoEntry.fromJson(Map<String, Object?>.from(r.value)))
        .toList();
  }

  // Implements: REQ-d00150-A+B+C+D+E — snapshot-on-subscribe + change-
  // driven re-emission filtered by destinationId; broadcast;
  // close-aware.
  //
  // Like `watchEvents`, the per-call controller is itself broadcast so a
  // single `watchFifo()` return value supports multiple `listen()`
  // subscribers (REQ-d00150-C). On the first listen:
  //   1. `scheduleMicrotask(emitSnapshot)` defers the initial snapshot so
  //      the caller's `listen()` returns before any emission.
  //   2. Subscribe to the package-private `_fifoChangesController`
  //      broadcast and re-emit a fresh snapshot whenever the changed
  //      destinationId matches this subscription's destination
  //      (REQ-d00150-C cross-destination isolation).
  // Snapshot fetch goes through `listFifoEntries`, so an unknown
  // destination produces an empty list (REQ-d00150-A) and emissions
  // carry typed `FifoEntry` (REQ-d00150-B) — no raw maps leak.
  // Close on the backend's `_fifoChangesController` propagates via
  // `onDone`. The per-call controller closes via `controller.close()`.
  @override
  Stream<List<FifoEntry>> watchFifo(String destinationId) {
    if (_fifoChangesController.isClosed) {
      throw StateError(
        'SembastBackend.close has been called; watchFifo unavailable',
      );
    }
    final controller = StreamController<List<FifoEntry>>.broadcast();
    StreamSubscription<String>? changesSub;
    var started = false;

    Future<void> emitSnapshot() async {
      try {
        final snap = await listFifoEntries(destinationId);
        if (!controller.isClosed) controller.add(snap);
      } catch (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      }
    }

    controller
      ..onListen = () {
        // Broadcast controllers fire `onListen` on every fresh listen
        // attach, but the snapshot + change-listener wiring must run
        // only once for the lifetime of this watchFifo() call. The
        // `started` guard ensures multiple subscribers share a single
        // upstream subscription.
        if (started) return;
        started = true;
        scheduleMicrotask(emitSnapshot);
        changesSub = _fifoChangesController.stream.listen(
          (changedDest) {
            if (changedDest == destinationId) {
              // Already inside a microtask delivered by the broadcast
              // controller; fire the snapshot fetch directly so the
              // re-emission lands one async tick sooner. Errors inside
              // the async body are forwarded to the per-call controller
              // via emitSnapshot's own try/catch.
              unawaited(emitSnapshot());
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      }
      ..onCancel = () async {
        // Broadcast `onCancel` fires when the LAST subscriber cancels;
        // tear down the upstream change subscription so the broadcast
        // controller does not leak after all subscribers detach.
        await changesSub?.cancel();
        changesSub = null;
        started = false;
      };
    return controller.stream;
  }

  // Implements: REQ-d00153-A+B+C+D — reactive snapshot stream of a
  // materialized view by name. Mirrors watchFifo's shape: snapshot on
  // subscribe + re-emit on every mutation (upsert / delete / clear);
  // cross-view isolation enforced by the viewName filter; broadcast so
  // multiple subscribers per view share a single upstream subscription;
  // close-aware via _viewChangesController's onDone propagation.
  @override
  Stream<List<Map<String, Object?>>> watchView(String viewName) {
    if (_viewChangesController.isClosed) {
      throw StateError(
        'SembastBackend.close has been called; watchView unavailable',
      );
    }
    final controller = StreamController<List<Map<String, Object?>>>.broadcast();
    StreamSubscription<String>? changesSub;
    var started = false;

    Future<void> emitSnapshot() async {
      try {
        final snap = await findViewRows(viewName);
        if (!controller.isClosed) {
          controller.add(snap.cast<Map<String, Object?>>());
        }
      } catch (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      }
    }

    controller
      ..onListen = () {
        if (started) return;
        started = true;
        scheduleMicrotask(emitSnapshot);
        changesSub = _viewChangesController.stream.listen(
          (changedView) {
            if (changedView == viewName) {
              unawaited(emitSnapshot());
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      }
      ..onCancel = () async {
        await changesSub?.cancel();
        changesSub = null;
        started = false;
      };
    return controller.stream;
  }

  /// Append [attempt] to the entry's attempts[]. Does not change
  /// finalStatus. Runs in its own transaction.
  ///
  /// Tolerates a missing target row or a never-registered FIFO store
  /// (REQ-d00127-B): in both cases this method returns without throwing
  /// and emits a warning-level diagnostic via [debugLogSink]. This closes
  /// the drain/unjam + drain/delete race documented in design §6.6 —
  /// drain `await send()`s outside any storage transaction, and a
  /// concurrent user operation (unjamDestination, deleteDestination) may
  /// remove the row before drain's subsequent `appendAttempt` runs.
  ///
  /// In Sembast, stores are lazily-created namespaces: a store that was
  /// never written to simply has zero records, so the `records.isEmpty`
  /// branch covers both "unknown destination" and "row deleted from a
  /// known destination". No separate "store exists?" probe is needed.
  // Implements: REQ-d00127-B — appendAttempt is a no-op on missing row /
  // missing FIFO store, with a warning-level diagnostic.
  @override
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  ) async {
    // Route through this backend's `transaction()` so post-commit FIFO
    // emissions appended below are drained on commit (REQ-d00150-A).
    await transaction((txn) async {
      final t = _requireValidTxn(txn);
      final store = _fifoStore(destinationId);
      final records = await store.find(
        t._sembastTxn,
        finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
      );
      if (records.isEmpty) {
        debugLogSink?.call(
          'appendAttempt: entry $entryId absent from FIFO '
          '$destinationId; skipping (expected during drain/unjam or '
          'drain/delete race)',
        );
        // No row mutated -> no FIFO-change emission.
        return;
      }
      final record = records.single;
      final updated = Map<String, Object?>.from(record.value);
      final attemptsRaw = <Map<String, Object?>>[
        ...(updated['attempts'] as List? ?? const <Object?>[])
            .cast<Map<String, Object?>>()
            .map(Map<String, Object?>.from),
        attempt.toJson(),
      ];
      updated['attempts'] = attemptsRaw;
      await store.record(record.key).put(t._sembastTxn, updated);
      // Implements: REQ-d00150-A — emit on the broadcast controller
      // post-commit so live `watchFifo(destinationId)` subscribers see
      // the appended attempt.
      _pendingPostCommit.add(() {
        if (!_fifoChangesController.isClosed) {
          _fifoChangesController.add(destinationId);
        }
      });
    });
  }

  /// Transition entry's finalStatus to [status]. For `sent`, also stamps
  /// `sent_at = DateTime.now().toUtc()`. The entry is RETAINED: no delete
  /// ever happens through this path (REQ-d00119-D).
  ///
  /// Tolerates a missing target row or a never-registered FIFO store
  /// (REQ-d00127-A): in both cases this method returns without throwing
  /// and emits a warning-level diagnostic via [debugLogSink]. This closes
  /// the drain/unjam + drain/delete race documented in design §6.6 —
  /// drain `await send()`s outside any storage transaction, and a
  /// concurrent user operation (unjamDestination, deleteDestination) may
  /// remove the row before drain's subsequent `markFinal` runs.
  ///
  /// In Sembast, stores are lazily-created namespaces: a store that was
  /// never written to simply has zero records, so the `records.isEmpty`
  /// branch covers both "unknown destination" and "row deleted from a
  /// known destination". No separate "store exists?" probe is needed.
  ///
  /// The one-way transition rule is preserved with idempotency: when the
  /// entry is already terminal with the SAME status as [status], the call
  /// returns cleanly (no-op, no re-stamp of `sent_at`). When the entry is
  /// already terminal with a DIFFERENT status, `StateError` is thrown —
  /// this is real corruption and loud failure is correct.
  // Implements: REQ-d00119-D — non-null terminal entries are retained as
  // permanent send-log records.
  // Implements: REQ-d00127-A — markFinal is a no-op on missing row /
  // missing FIFO store, with a warning-level diagnostic.
  @override
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  ) async {
    // markFinal transitions a pre-terminal row (final_status == null)
    // into one of the three non-null terminal states. `null` is not a
    // legal target — it is the INITIAL state and is set only by
    // enqueueFifo. The non-null target is enforced by the parameter
    // type `FinalStatus` (non-nullable); the type system makes a
    // runtime null-check unnecessary here.
    //
    // Routed through this backend's `transaction()` so post-commit
    // FIFO emissions appended below are drained on commit (REQ-d00150-A).
    await transaction((txn) async {
      final t = _requireValidTxn(txn);
      final store = _fifoStore(destinationId);
      final records = await store.find(
        t._sembastTxn,
        finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
      );
      if (records.isEmpty) {
        debugLogSink?.call(
          'markFinal: entry $entryId absent from FIFO $destinationId; '
          'skipping (expected during drain/unjam or drain/delete race)',
        );
        // No row mutated -> no FIFO-change emission.
        return;
      }
      final record = records.single;
      final updated = Map<String, Object?>.from(record.value);
      final currentRaw = updated['final_status'];
      final currentStatus = currentRaw == null
          ? null
          : FinalStatus.fromJson(currentRaw as String);
      // final_status is one-way: null -> sent|wedged|tombstoned.
      // A duplicate call with the SAME status is a no-op — drain() is
      // documented at-least-once and concurrent drainers can both reach
      // markFinal after the first completes. Matching status: return
      // cleanly. Mismatched status: real corruption; loud failure.
      if (currentStatus != null) {
        if (currentStatus == status) {
          // Idempotent duplicate — first call already wrote the correct
          // terminal state. No additional write or sent_at re-stamp needed.
          return;
        }
        throw StateError(
          'markFinal($destinationId, $entryId, $status): entry is already '
          '$currentStatus; final_status transitions are one-way.',
        );
      }
      updated['final_status'] = status.toJson();
      if (status == FinalStatus.sent) {
        updated['sent_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await store.record(record.key).put(t._sembastTxn, updated);
      // Implements: REQ-d00150-A — emit on the broadcast controller
      // post-commit so live `watchFifo(destinationId)` subscribers see
      // the terminal-status transition.
      _pendingPostCommit.add(() {
        if (!_fifoChangesController.isClosed) {
          _fifoChangesController.add(destinationId);
        }
      });
    });
  }

  @override
  Future<bool> anyFifoWedged() async {
    for (final dest in await _knownFifoDestinations()) {
      if (await _wedgedHead(dest) != null) return true;
    }
    return false;
  }

  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() async {
    final result = <WedgedFifoSummary>[];
    for (final dest in await _knownFifoDestinations()) {
      final head = await _wedgedHead(dest);
      if (head == null) continue;
      final hasAttempts = head.attempts.isNotEmpty;
      result.add(
        WedgedFifoSummary(
          destinationId: dest,
          headEntryId: head.entryId,
          // For batch rows, the summary reports the first event_id as a
          // stable single-string identifier for operators. Multi-event
          // batches' full id list is accessible via readFifoHead.
          headEventId: head.eventIds.first,
          wedgedAt: hasAttempts
              ? head.attempts.last.attemptedAt
              : head.enqueuedAt,
          lastError: hasAttempts
              ? (head.attempts.last.errorMessage ?? '<no error message>')
              : '<wedged with no attempts recorded>',
        ),
      );
    }
    return result;
  }

  /// Read a single FIFO row identified by [entryId] on [destinationId],
  /// or `null` when no such row exists. Non-transactional.
  ///
  /// In Sembast a never-written FIFO store simply has zero records,
  /// so the unknown-destination case and the unknown-row case both
  /// fall through to the `records.isEmpty` branch without needing a
  /// separate store-exists probe.
  @override
  Future<FifoEntry?> readFifoRow(String destinationId, String entryId) async {
    final db = _database();
    final records = await _fifoStore(destinationId).find(
      db,
      finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
    );
    if (records.isEmpty) return null;
    return FifoEntry.fromJson(Map<String, Object?>.from(records.single.value));
  }

  /// Transition the target row's `final_status` to [status] inside
  /// [txn]. The legal transitions, enforced by a guard below, are:
  ///
  /// - `null -> sent` — drain-terminal SendOk; stamps
  ///   `sent_at = DateTime.now().toUtc()`.
  /// - `null -> wedged` — drain-terminal SendPermanent / SendTransient
  ///   at max attempts.
  /// - `null -> tombstoned` — tombstoneAndRefill on a null head
  ///   (REQ-d00144-B).
  /// - `wedged -> tombstoned` — tombstoneAndRefill on a wedged head
  ///   (REQ-d00144-B).
  ///
  /// Any other transition throws [StateError]. In particular `sent`
  /// and `tombstoned` are terminal end-states; they cannot transition
  /// to anything else.
  ///
  /// Preserves `attempts[]` verbatim on every transition (REQ-d00144-B
  /// tombstoneAndRefill requires it). `sent_at` is set on `null -> sent`
  /// and untouched on every other transition.
  ///
  /// Throws [StateError] on a missing target row: callers verify
  /// existence before opening the transaction, so a missing row here
  /// indicates a concurrent delete race that these ops do not close.
  // Implements: REQ-d00144-B — `null|wedged -> tombstoned` flip;
  // attempts[] preserved verbatim; sent_at untouched.
  // Implements: REQ-d00119-D — one-way rule: terminal rows
  // ({sent, tombstoned}) cannot transition further.
  @override
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  ) async {
    final t = _requireValidTxn(txn);
    final store = _fifoStore(destinationId);
    final records = await store.find(
      t._sembastTxn,
      finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
    );
    if (records.isEmpty) {
      throw StateError(
        'setFinalStatusTxn($destinationId, $entryId, $status): target '
        'row not found. Callers must verify existence (readFifoHead) '
        'before opening the transaction; a missing row here indicates '
        'a concurrent delete race.',
      );
    }
    final record = records.single;
    final updated = Map<String, Object?>.from(record.value);
    final currentRaw = updated['final_status'];
    final current = currentRaw == null
        ? null
        : FinalStatus.fromJson(currentRaw as String);
    // Legal transitions (REQ-d00119-D one-way rule + REQ-d00144-B):
    //  - null  -> sent          (drain SendOk)
    //  - null  -> wedged        (drain SendPermanent / max-attempts)
    //  - null  -> tombstoned    (tombstoneAndRefill on null head)
    //  - wedged -> tombstoned   (tombstoneAndRefill on wedged head)
    final valid =
        (current == null &&
            (status == FinalStatus.sent ||
                status == FinalStatus.wedged ||
                status == FinalStatus.tombstoned)) ||
        (current == FinalStatus.wedged && status == FinalStatus.tombstoned);
    if (!valid) {
      throw StateError(
        'setFinalStatusTxn($destinationId, $entryId): illegal transition '
        '$current -> $status. Legal transitions: null -> {sent, wedged, '
        'tombstoned}; wedged -> {tombstoned}. (REQ-d00119-D one-way '
        'rule.)',
      );
    }
    updated['final_status'] = status?.toJson();
    if (status == FinalStatus.sent) {
      // Drain-terminal SendOk stamps sent_at.
      updated['sent_at'] = DateTime.now().toUtc().toIso8601String();
    }
    // attempts[] is deliberately NOT touched — REQ-d00144-B
    // tombstoneAndRefill requires verbatim preservation; the
    // drain-terminal null->{sent,wedged} path has already appended its
    // attempts via appendAttempt before calling markFinal /
    // setFinalStatusTxn.
    await store.record(record.key).put(t._sembastTxn, updated);
    // Implements: REQ-d00150-A — emit on the broadcast controller
    // post-commit so live `watchFifo(destinationId)` subscribers see
    // the final-status transition (tombstone / drain-terminal). The
    // surrounding `transaction()` drains _pendingPostCommit on commit.
    _pendingPostCommit.add(() {
      if (!_fifoChangesController.isClosed) {
        _fifoChangesController.add(destinationId);
      }
    });
  }

  /// Delete every FIFO row on [destinationId] whose `sequence_in_queue`
  /// is strictly greater than [afterSequenceInQueue] AND whose
  /// `final_status IS null`. Returns the count of rows deleted.
  ///
  /// Used by `tombstoneAndRefill` to sweep the trail behind a
  /// tombstoned target in one transaction (REQ-d00144-C). Rows whose
  /// `final_status` is terminal (any of {sent, wedged, tombstoned})
  /// are left untouched regardless of their `sequence_in_queue` — per
  /// REQ-d00119-D all non-null rows are retained forever.
  // Implements: REQ-d00144-C — trail-delete predicate
  // (final_status IS null AND sequence_in_queue > afterSequenceInQueue).
  @override
  Future<int> deleteNullRowsAfterSequenceInQueueTxn(
    Txn txn,
    String destinationId,
    int afterSequenceInQueue,
  ) async {
    final t = _requireValidTxn(txn);
    final store = _fifoStore(destinationId);
    final deleted = await store.delete(
      t._sembastTxn,
      finder: Finder(
        filter: Filter.and([
          Filter.isNull('final_status'),
          Filter.greaterThan('sequence_in_queue', afterSequenceInQueue),
        ]),
      ),
    );
    if (deleted > 0) {
      // Implements: REQ-d00150-A — emit on the broadcast controller
      // post-commit so live `watchFifo(destinationId)` subscribers see
      // the trail-sweep deletion. Skip when no rows were actually
      // removed to avoid spurious wakeups.
      _pendingPostCommit.add(() {
        if (!_fifoChangesController.isClosed) {
          _fifoChangesController.add(destinationId);
        }
      });
    }
    return deleted;
  }

  // -------- Event lookup by event_id --------

  /// Read a single event by `event_id` within [txn]. Returns `null` when no
  /// event with that id is present. Used by ingest's idempotency check
  /// (REQ-d00145-D) against the unified event store (origin and ingest
  /// appends share `_eventStore`).
  // Implements: REQ-d00145-D — unified-store idempotency lookup.
  @override
  Future<StoredEvent?> findEventByIdInTxn(Txn txn, String eventId) async {
    final t = _requireValidTxn(txn);
    final finder = Finder(filter: Filter.equals('event_id', eventId), limit: 1);
    final record = await _eventStore.findFirst(t._sembastTxn, finder: finder);
    if (record == null) return null;
    return StoredEvent.fromMap(
      Map<String, Object?>.from(record.value),
      record.key,
    );
  }

  // Implements: REQ-d00147-A+B+C — non-transactional indexed lookup by
  // event_id over the unified event store; returns null when absent.
  @override
  Future<StoredEvent?> findEventById(String eventId) async {
    final db = _database();
    final finder = Finder(filter: Filter.equals('event_id', eventId), limit: 1);
    final record = await _eventStore.findFirst(db, finder: finder);
    if (record == null) return null;
    return StoredEvent.fromMap(
      Map<String, Object?>.from(record.value),
      record.key,
    );
  }

  // -------- Audit query (REQ-d00151) --------

  // Implements: REQ-d00151-A+B — typed cross-store audit query lives at
  // the storage layer; SembastSecurityContextStore.queryAudit is a thin
  // delegator (REQ-d00151-C).
  // Implements: REQ-d00137-F — pagination + filter contract preserved
  // verbatim from the previous SecurityContextStore-hosted implementation.
  @override
  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(
        limit,
        'limit',
        'queryAudit limit must be in [1, 1000] (REQ-d00137-F)',
      );
    }

    _AuditCursorPoint? decodedCursor;
    if (cursor != null) {
      try {
        decodedCursor = _AuditCursorPoint.decode(cursor);
      } on Object catch (e) {
        throw ArgumentError.value(cursor, 'cursor', 'corrupt cursor: $e');
      }
    }

    final db = _database();

    // 1. Filter security rows by ipAddress + date range.
    final securityFilters = <Filter>[];
    if (ipAddress != null) {
      securityFilters.add(Filter.equals('ip_address', ipAddress));
    }
    if (from != null) {
      securityFilters.add(
        Filter.greaterThanOrEquals(
          'recorded_at',
          from.toUtc().toIso8601String(),
        ),
      );
    }
    if (to != null) {
      securityFilters.add(
        Filter.lessThanOrEquals('recorded_at', to.toUtc().toIso8601String()),
      );
    }
    // NOTE: we re-sort the join result in memory (see `rows.sort(...)`
    // below) so the in-memory order is authoritative for pagination; the
    // Sembast sort matches it only for clarity / debuggability.
    final securityFinder = Finder(
      filter: securityFilters.isEmpty
          ? null
          : (securityFilters.length == 1
                ? securityFilters.single
                : Filter.and(securityFilters)),
      sortOrders: [
        SortOrder('recorded_at', false),
        SortOrder(Field.key, false),
      ],
    );
    final securityRecords = await _securityContextStore.find(
      db,
      finder: securityFinder,
    );
    final securityByEventId = <String, EventSecurityContext>{
      for (final r in securityRecords)
        r.key: EventSecurityContext.fromJson(
          Map<String, Object?>.from(r.value),
        ),
    };
    if (securityByEventId.isEmpty) {
      return const PagedAudit(rows: <AuditRow>[]);
    }

    // 2. Fetch matching events.
    final eventFilters = <Filter>[
      Filter.inList('event_id', securityByEventId.keys.toList()),
    ];
    if (flowToken != null) {
      eventFilters.add(Filter.equals('flow_token', flowToken));
    }
    final eventFinder = Finder(
      filter: eventFilters.length == 1
          ? eventFilters.single
          : Filter.and(eventFilters),
    );
    final eventRecords = await _eventStore.find(db, finder: eventFinder);
    var events = eventRecords
        .map((r) => StoredEvent.fromMap(r.value, r.key))
        .toList();
    if (initiator != null) {
      events = events.where((e) => e.initiator == initiator).toList();
    }

    // 3. Inner join + sort by recordedAt desc.
    final rows = <AuditRow>[];
    for (final event in events) {
      final ctx = securityByEventId[event.eventId];
      if (ctx == null) continue;
      rows.add(AuditRow(event: event, context: ctx));
    }
    rows.sort((a, b) {
      final cmp = b.context.recordedAt.compareTo(a.context.recordedAt);
      if (cmp != 0) return cmp;
      return b.event.eventId.compareTo(a.event.eventId);
    });

    // 4. Apply cursor (lower bound) if provided.
    final filtered = decodedCursor == null
        ? rows
        : rows.where((r) {
            final cmp = r.context.recordedAt.compareTo(
              decodedCursor!.recordedAt,
            );
            if (cmp < 0) return true;
            if (cmp == 0) {
              return r.event.eventId.compareTo(decodedCursor.eventId) < 0;
            }
            return false;
          }).toList();

    // 5. Paginate.
    final page = filtered.take(limit).toList();
    final nextCursor = filtered.length > limit
        ? _AuditCursorPoint(
            recordedAt: page.last.context.recordedAt,
            eventId: page.last.event.eventId,
          ).encode()
        : null;
    return PagedAudit(rows: page, nextCursor: nextCursor);
  }

  /// The first non-sent entry in the FIFO when it is `wedged`. Returns
  /// null when either the FIFO has no entries, all entries are `sent`, or
  /// the earliest non-sent entry is pre-terminal (null final_status) or
  /// tombstoned (not wedged).
  Future<FifoEntry?> _wedgedHead(String destinationId) async {
    final db = _database();
    final records = await _fifoStore(
      destinationId,
    ).find(db, finder: Finder(sortOrders: [SortOrder('sequence_in_queue')]));
    for (final record in records) {
      final entry = FifoEntry.fromJson(Map<String, Object?>.from(record.value));
      final status = entry.finalStatus;
      if (status == null) {
        // Earliest non-sent row is pre-terminal: FIFO not wedged at head.
        return null;
      }
      switch (status) {
        case FinalStatus.sent:
          continue;
        case FinalStatus.wedged:
          return entry;
        case FinalStatus.tombstoned:
          // Tombstoned rows live in the audit trail but do not by
          // themselves wedge the FIFO; skip past and keep looking.
          continue;
      }
    }
    return null;
  }
}

class _SembastTxn extends Txn {
  _SembastTxn._(this._sembastTxn);
  final Transaction _sembastTxn;
  bool _isValid = true;
  void _invalidate() {
    _isValid = false;
  }
}

/// Opaque pagination cursor for [SembastBackend.queryAudit]. Encodes the
/// `(recorded_at, event_id)` tuple from the previous page's tail row;
/// the next page is a strict lower bound under the same sort order so
/// concurrent inserts at the head do not skew page contents.
// Implements: REQ-d00137-F — opaque cursor encoding shared by storage
// queryAudit and (transitively) the SecurityContextStore delegator.
class _AuditCursorPoint {
  const _AuditCursorPoint({required this.recordedAt, required this.eventId});

  factory _AuditCursorPoint.decode(String encoded) {
    final raw = utf8.decode(base64Url.decode(encoded));
    final parts = raw.split('|');
    if (parts.length != 2) throw const FormatException('bad cursor shape');
    return _AuditCursorPoint(
      recordedAt: DateTime.parse(parts[0]),
      eventId: parts[1],
    );
  }

  final DateTime recordedAt;
  final String eventId;

  String encode() {
    final raw = '${recordedAt.toUtc().toIso8601String()}|$eventId';
    return base64Url.encode(utf8.encode(raw));
  }
}
