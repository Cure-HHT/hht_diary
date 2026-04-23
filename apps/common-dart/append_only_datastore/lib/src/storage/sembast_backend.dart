import 'dart:convert';
import 'dart:developer' as developer;

import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:append_only_datastore/src/storage/wedged_fifo_summary.dart';
import 'package:sembast/sembast.dart';

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
  /// `package:append_only_datastore/src/storage/sembast_backend_in_memory.dart`
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

  final StoreRef<int, Map<String, Object?>> _eventStore = intMapStoreFactory
      .store('events');
  final StoreRef<String, Object?> _backendStateStore =
      StoreRef<String, Object?>('backend_state');
  final StoreRef<String, Map<String, Object?>> _entriesStore =
      stringMapStoreFactory.store('diary_entries');

  StoreRef<int, Map<String, Object?>> _fifoStore(String destinationId) =>
      intMapStoreFactory.store('fifo_$destinationId');

  Database _database() => _db;

  /// Close the underlying Sembast database. The caller that supplied the
  /// database via the constructor is responsible for deciding when to close.
  ///
  /// Not safe to call concurrently with an in-flight [transaction]. The
  /// caller is responsible for awaiting outstanding work before closing.
  Future<void> close() async {
    await _db.close();
  }

  /// Exposes the underlying Sembast [Database] for tests that need to
  /// inspect raw store contents. Not for production use.
  // ignore: library_private_types_in_public_api
  Database debugDatabase() => _database();

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
    return db.transaction((sembastTxn) async {
      final txn = _SembastTxn._(sembastTxn);
      try {
        return await body(txn);
      } finally {
        txn._invalidate();
      }
    });
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
  /// `anyFifoExhausted` / `wedgedFifos` no longer iterate it.
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
    // Remove the id from the known-FIFOs registry so exhausted-FIFO
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
  }

  // Implements: REQ-d00140-F — deleteViewRowInTxn row-scoped delete.
  @override
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key) async {
    final t = _requireValidTxn(txn);
    await _viewStore(viewName).record(key).delete(t._sembastTxn);
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
  @override
  Future<void> clearViewInTxn(Txn txn, String viewName) async {
    final t = _requireValidTxn(txn);
    await _viewStore(viewName).delete(t._sembastTxn);
  }

  // -------- FIFO --------

  /// Append a batch-shaped row to destination [destinationId]'s FIFO. The
  /// row covers every event in [batch] and carries a single [wirePayload]
  /// (REQ-d00128-C).
  ///
  /// Opens its own atomic transaction and delegates the actual row
  /// construction to [enqueueFifoTxn]. Callers already composing a larger
  /// transaction (replay, fill_batch) SHALL use [enqueueFifoTxn] so the
  /// enqueue and any accompanying writes (e.g., fill_cursor advance)
  /// commit co-atomically.
  ///
  /// The backend owns `sequence_in_queue`: it is assigned as
  /// `max(existing store key) + 1` inside the transaction, so the
  /// Sembast int key and the payload `sequence_in_queue` are in lockstep
  /// (Phase-2 Prereq A, Option 1).
  ///
  /// The returned `FifoEntry` is the persisted record. Callers that
  /// need to advance a per-destination cursor use
  /// `result.eventIdRange.lastSeq` as the inclusive upper bound of the
  /// batch on the event log.
  ///
  /// Rejects (throws `ArgumentError` / `StateError`):
  /// - empty [batch] (REQ-d00128-A);
  /// - `entryId` collision within the destination's FIFO (would let a
  ///   later `markFinal` / `appendAttempt` pick the wrong row).
  // Implements: REQ-d00117-E — enqueue initial state (pending, no
  // attempts, no sent_at).
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue (standalone
  // variant; opens its own transaction and delegates to enqueueFifoTxn).
  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) async {
    return _database().transaction((sembastTxn) async {
      final txn = _SembastTxn._(sembastTxn);
      try {
        return await enqueueFifoTxn(txn, destinationId, batch, wirePayload);
      } finally {
        txn._invalidate();
      }
    });
  }

  /// Transactional variant of [enqueueFifo]: participates in the
  /// surrounding [txn] so the FIFO-row write and the caller's
  /// accompanying writes commit or roll back together. Used by
  /// `fillBatch` to keep the enqueue + fill_cursor advance co-atomic,
  /// and (in a later task) by replay to compose a larger walk of the
  /// event log into a single transaction.
  ///
  /// Centralizes all row-construction logic: empty-batch rejection,
  /// duplicate-entryId rejection, `sequence_in_queue` assignment,
  /// wire-payload decoding, and the known-FIFOs registry bookkeeping
  /// all live here; [enqueueFifo] is a thin `transaction(...)` wrapper.
  // Implements: REQ-d00117-E — enqueue initial state (pending, no
  // attempts, no sent_at).
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue (transactional
  // variant; used by fillBatch to co-commit enqueue + fill_cursor).
  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) async {
    if (batch.isEmpty) {
      throw ArgumentError.value(
        batch,
        'batch',
        'enqueueFifo requires a non-empty batch (REQ-d00128-A)',
      );
    }
    final t = _requireValidTxn(txn);
    final eventIds = batch.map((e) => e.eventId).toList(growable: false);
    final eventIdRange = (
      firstSeq: batch.first.sequenceNumber,
      lastSeq: batch.last.sequenceNumber,
    );
    // The stored `wire_payload` is a Map (structured JSON); we decode the
    // WirePayload bytes back to a Map for persistence so drain's read
    // path can re-encode deterministically. The bytes MUST be valid JSON
    // encoding a Map — destinations that transform to bytes representing
    // a top-level JSON object conform; other shapes are rejected with
    // ArgumentError rather than corrupting the FIFO row.
    Map<String, Object?> payloadMap;
    try {
      final decoded = jsonDecode(utf8.decode(wirePayload.bytes));
      if (decoded is! Map) {
        throw ArgumentError.value(
          wirePayload,
          'wirePayload',
          'enqueueFifo requires wirePayload.bytes to encode a JSON object '
              '(Map); got ${decoded.runtimeType}',
        );
      }
      payloadMap = Map<String, Object?>.from(decoded);
    } on FormatException catch (e) {
      throw ArgumentError.value(
        wirePayload,
        'wirePayload',
        'enqueueFifo requires wirePayload.bytes to be UTF-8 JSON: '
            '${e.message}',
      );
    }
    // Use the first event_id in the batch as the row's entry_id (stable
    // correlation into diary_entries for single-event batches; for
    // multi-event batches a future task may introduce a distinct batch
    // id, but none of the Phase-4 call sites construct a multi-event
    // batch yet).
    final entryId = batch.first.eventId;
    final enqueuedAt = DateTime.now().toUtc();
    final store = _fifoStore(destinationId);
    // Reject a duplicate entry_id in the same FIFO. Without this
    // check, later appendAttempt/markFinal calls would quietly pick
    // one of the duplicates and the other would drift out of sync.
    final existing = await store.find(
      t._sembastTxn,
      finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
    );
    if (existing.isNotEmpty) {
      throw StateError(
        'FIFO $destinationId already has an entry with '
        'entry_id=$entryId',
      );
    }
    // Assign the next sequence_in_queue from a persisted per-destination
    // counter (backend_state/fifo_seq_counter_<destinationId>). The
    // counter advances strictly monotonically and is NEVER reset: even
    // when a row is deleted (trail sweep per REQ-d00144-C, or the
    // legacy unjam `deletePendingRowsTxn`), the deleted slot is NOT
    // re-used. The resulting invariant (REQ-d00119-E) is load-bearing
    // for event-log cursor math and for the send-log's auditability —
    // two different rows with the same sequence_in_queue would produce
    // ambiguous "which row was deleted?" diagnostics.
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
      wireFormat: wirePayload.contentType,
      transformVersion: wirePayload.transformVersion,
      enqueuedAt: enqueuedAt,
      attempts: const <AttemptResult>[],
      finalStatus: null,
      sentAt: null,
    );
    await store.record(assigned).put(t._sembastTxn, entry.toJson());
    await _registerFifoDestinationSembast(t._sembastTxn, destinationId);
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

  /// Oldest pre-terminal entry in [destinationId]'s FIFO, or null when
  /// every row is terminal (any mix of `sent`, `wedged`, and/or
  /// `tombstoned`) or the FIFO is empty. All non-null-finalStatus rows
  /// are SKIPPED; only a row whose `final_status` IS NULL is returned.
  ///
  /// Pre-Phase-4.3-Task-8, this method returned null as soon as it
  /// encountered a terminal row — the FIFO was "wedged" at the
  /// backend level. From Task 8 forward, the wedge is enforced by the
  /// drain loop's switch-case (SendPermanent / SendTransient-at-max
  /// stops drain), not by readFifoHead; this lets the batch-FIFO
  /// continue-past-terminal semantics be introduced without changing
  /// the method's caller-facing contract in drain.
  // Implements: REQ-d00124-A — readFifoHead returns the first row whose
  // final_status == null in sequence_in_queue order; any row with a
  // non-null terminal status (sent, wedged, tombstoned) is skipped.
  // Drain's wedge behavior is preserved by drain.dart's SendPermanent /
  // SendTransient-at-max returning rather than by readFifoHead
  // returning null at the first wedged row.
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) async {
    final db = _database();
    final store = _fifoStore(destinationId);
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.isNull('final_status'),
        sortOrders: [SortOrder('sequence_in_queue')],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    return FifoEntry.fromJson(Map<String, Object?>.from(records.single.value));
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
    final db = _database();
    await db.transaction((sembastTxn) async {
      final store = _fifoStore(destinationId);
      final records = await store.find(
        sembastTxn,
        finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
      );
      if (records.isEmpty) {
        debugLogSink?.call(
          'appendAttempt: entry $entryId absent from FIFO '
          '$destinationId; skipping (expected during drain/unjam or '
          'drain/delete race)',
        );
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
      await store.record(record.key).put(sembastTxn, updated);
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
  /// The one-way transition rule (null -> terminal only) is
  /// preserved: an already-terminal entry still throws `StateError` to
  /// prevent silent re-stamping of `sent_at`.
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
    final db = _database();
    await db.transaction((sembastTxn) async {
      final store = _fifoStore(destinationId);
      final records = await store.find(
        sembastTxn,
        finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
      );
      if (records.isEmpty) {
        debugLogSink?.call(
          'markFinal: entry $entryId absent from FIFO $destinationId; '
          'skipping (expected during drain/unjam or drain/delete race)',
        );
        return;
      }
      final record = records.single;
      final updated = Map<String, Object?>.from(record.value);
      final currentRaw = updated['final_status'];
      final currentStatus = currentRaw == null
          ? null
          : FinalStatus.fromJson(currentRaw as String);
      // final_status is one-way: null -> sent|wedged|tombstoned.
      // Re-transitioning a terminal entry would silently re-stamp sent_at
      // and corrupt the send-log timestamp, so reject it.
      if (currentStatus != null) {
        throw StateError(
          'markFinal($destinationId, $entryId, $status): entry is already '
          '$currentStatus; final_status transitions are one-way.',
        );
      }
      updated['final_status'] = status.toJson();
      if (status == FinalStatus.sent) {
        updated['sent_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await store.record(record.key).put(sembastTxn, updated);
    });
  }

  @override
  Future<bool> anyFifoExhausted() async {
    for (final dest in await _knownFifoDestinations()) {
      if (await _exhaustedHead(dest) != null) return true;
    }
    return false;
  }

  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() async {
    final result = <WedgedFifoSummary>[];
    for (final dest in await _knownFifoDestinations()) {
      final head = await _exhaustedHead(dest);
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

  // -------- Unjam helpers (REQ-d00131) --------

  /// Delete every `pending` row in [destinationId]'s FIFO inside [txn]
  /// and return the number of rows deleted. Rows in terminal states
  /// (`sent`, `exhausted`) are untouched — those are audit records
  /// preserved across an unjam. Returns `0` on an unknown destination
  /// (Sembast store is lazily-created, so an absent store simply has
  /// zero records).
  // Implements: REQ-d00131-B — delete every pending row in one
  // transactional step; returns the count deleted for UnjamResult.
  // Implements: REQ-d00131-C — `sent` and `exhausted` rows are not
  // candidates for deletion: the filter pins `final_status` to
  // `pending` exclusively.
  @override
  Future<int> deletePendingRowsTxn(Txn txn, String destinationId) async {
    final t = _requireValidTxn(txn);
    final store = _fifoStore(destinationId);
    // Sembast's `StoreRef.delete(..., finder: ...)` returns the count of
    // deleted records for stores with scalar keys. On this backend the
    // FIFO store is an `intMapStoreFactory` so the return is `int`.
    return store.delete(
      t._sembastTxn,
      finder: Finder(filter: Filter.isNull('final_status')),
    );
  }

  /// Return the largest `event_id_range.last_seq` across rows whose
  /// `final_status == sent` in [destinationId]'s FIFO, read inside
  /// [txn]. Returns `null` when the destination has no `sent` rows
  /// (including the "never successfully delivered" case and the
  /// never-registered-store case).
  ///
  /// Implemented as a `find` sorted by `event_id_range.last_seq`
  /// descending with `limit: 1`. Sembast supports dotted field paths
  /// into stored `Map<String, Object?>` values, so the sort orders
  /// on the nested `last_seq` field directly.
  // Implements: REQ-d00131-D — max(event_id_range.last_seq) across
  // sent rows; null -> caller substitutes -1 for the rewind target.
  @override
  Future<int?> maxSentSequenceTxn(Txn txn, String destinationId) async {
    final t = _requireValidTxn(txn);
    final store = _fifoStore(destinationId);
    final records = await store.find(
      t._sembastTxn,
      finder: Finder(
        filter: Filter.equals('final_status', FinalStatus.sent.toJson()),
        sortOrders: [SortOrder('event_id_range.last_seq', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    final rangeRaw = records.single.value['event_id_range'];
    if (rangeRaw is! Map) {
      debugLogSink?.call(
        'maxSentSequenceTxn: sent row on $destinationId has malformed '
        'event_id_range (not a Map); treating as no sent rows. This '
        'should not happen under the current FifoEntry shape.',
      );
      return null;
    }
    final lastSeq = rangeRaw['last_seq'];
    if (lastSeq is! int) {
      debugLogSink?.call(
        'maxSentSequenceTxn: sent row on $destinationId has missing or '
        'non-int event_id_range.last_seq; treating as no sent rows. '
        'This should not happen under the current FifoEntry shape.',
      );
      return null;
    }
    return lastSeq;
  }

  // -------- Rehabilitate helpers (REQ-d00132) --------

  /// Read a single FIFO row identified by [entryId] on [destinationId],
  /// or `null` when no such row exists. Non-transactional.
  ///
  /// In Sembast a never-written FIFO store simply has zero records,
  /// so the unknown-destination case and the unknown-row case both
  /// fall through to the `records.isEmpty` branch without needing a
  /// separate store-exists probe.
  // Implements: REQ-d00132-A — readFifoRow returns null on unknown
  // row / unknown destination; rehabilitate promotes null to
  // ArgumentError at the call site.
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

  /// Return every `exhausted` row on [destinationId] in
  /// `sequence_in_queue` ascending order. Empty list when no exhausted
  /// row exists.
  // Implements: REQ-d00132-C — exhaustedRowsOf enumerates the bulk-rehab
  // targets; order is stable (sequence_in_queue asc) so callers iterating
  // them observe deterministic FIFO-order rehabilitation.
  @override
  Future<List<FifoEntry>> exhaustedRowsOf(String destinationId) async {
    final db = _database();
    final records = await _fifoStore(destinationId).find(
      db,
      finder: Finder(
        filter: Filter.equals('final_status', FinalStatus.wedged.toJson()),
        sortOrders: [SortOrder('sequence_in_queue')],
      ),
    );
    return records
        .map((r) => FifoEntry.fromJson(Map<String, Object?>.from(r.value)))
        .toList();
  }

  /// Flip the target row's `final_status` from `wedged` back to the
  /// pre-terminal state (`null`) inside [txn]. Rejects any non-null
  /// [status] — the one-way `null -> sent|wedged|tombstoned` path is
  /// owned by [markFinal] and is deliberately kept separate so its
  /// invariants are not weakened by a second write path.
  ///
  /// Preserves the row's `attempts[]` unchanged (REQ-d00132-B) and
  /// clears `sent_at` (a rehabilitated row is no longer terminal,
  /// so a stale `sent_at` would confuse the send-log; in practice
  /// `sent_at` is null on every wedged row — the column is only
  /// ever set on `sent` — but the clear is defensive).
  ///
  /// Throws [StateError] on a missing target row: rehabilitate's
  /// caller verifies existence via [readFifoRow] before opening the
  /// transaction, so a missing row here indicates a concurrent delete
  /// race that rehabilitate does not close.
  ///
  /// This method's narrow contract (wedged -> null) is inherited from
  /// Phase-4.6 rehabilitate. Phase-4.7 Task 6 will widen it to
  /// participate in tombstoneAndRefill; for now its sole caller remains
  /// rehabilitate.
  // Implements: REQ-d00132-B — `wedged -> null` flip; preserves
  // attempts[], clears sent_at. Rejects non-null status so
  // markFinal's one-way rule is not weakened.
  @override
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  ) async {
    if (status != null) {
      throw ArgumentError.value(
        status,
        'status',
        'setFinalStatusTxn only supports rehabilitate (wedged -> '
            'null); use markFinal for null -> sent|wedged|tombstoned '
            'transitions.',
      );
    }
    final t = _requireValidTxn(txn);
    final store = _fifoStore(destinationId);
    final records = await store.find(
      t._sembastTxn,
      finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
    );
    if (records.isEmpty) {
      throw StateError(
        'setFinalStatusTxn($destinationId, $entryId, $status): target '
        'row not found. Rehabilitate callers must verify existence via '
        'readFifoRow before opening the transaction; a missing row '
        'here indicates a concurrent delete race.',
      );
    }
    final record = records.single;
    final updated = Map<String, Object?>.from(record.value);
    updated['final_status'] = null;
    // Clear sent_at defensively: a wedged row should not have one,
    // but if any ever leaks through, leaving it here would make the
    // newly-pre-terminal row look like it had already been sent.
    updated['sent_at'] = null;
    // attempts[] is deliberately NOT touched — REQ-d00132-B.
    await store.record(record.key).put(t._sembastTxn, updated);
  }

  /// The first non-sent entry in the FIFO when it is `wedged`. Returns
  /// null when either the FIFO has no entries, all entries are `sent`, or
  /// the earliest non-sent entry is pre-terminal (null final_status) or
  /// tombstoned (not wedged).
  Future<FifoEntry?> _exhaustedHead(String destinationId) async {
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
