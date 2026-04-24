import 'dart:convert';
import 'dart:developer' as developer;

import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/append_result.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/storage/wedged_fifo_summary.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

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
  static const _ingestSequenceKey = 'ingest_sequence_counter';
  static const _ingestTailHashKey = 'ingest_tail_event_hash';

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
  /// The row's `entry_id` is a freshly-minted v4 UUID and has no
  /// relationship to the events the row carries — callers that need
  /// to correlate against events use `eventIds` / `eventIdRange`.
  ///
  /// Rejects (throws `ArgumentError`):
  /// - empty [batch] (REQ-d00128-A).
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
  /// v4-UUID `entry_id` minting, `sequence_in_queue` assignment,
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

  /// Transition the target row's `final_status` to [status] inside
  /// [txn]. The legal transitions, enforced by a guard below, are:
  ///
  /// - `wedged -> null` — rehabilitate's flip to pre-terminal
  ///   (REQ-d00132-B).
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
  /// Preserves `attempts[]` verbatim on every transition (REQ-d00132-B
  /// rehabilitate and REQ-d00144-B tombstoneAndRefill both require it).
  /// `sent_at` is set on `null -> sent`, cleared on `-> null` (defensive
  /// clear — rehabilitated rows are no longer terminal), and untouched
  /// on every other transition.
  ///
  /// Throws [StateError] on a missing target row: callers verify
  /// existence before opening the transaction, so a missing row here
  /// indicates a concurrent delete race that these ops do not close.
  // Implements: REQ-d00132-B — `wedged -> null` flip; preserves
  // attempts[], clears sent_at.
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
        'row not found. Callers must verify existence (readFifoRow or '
        'readFifoHead) before opening the transaction; a missing row '
        'here indicates a concurrent delete race.',
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
    //  - wedged -> null         (rehabilitate)
    final valid =
        (current == null &&
            (status == FinalStatus.sent ||
                status == FinalStatus.wedged ||
                status == FinalStatus.tombstoned)) ||
        (current == FinalStatus.wedged && status == FinalStatus.tombstoned) ||
        (current == FinalStatus.wedged && status == null);
    if (!valid) {
      throw StateError(
        'setFinalStatusTxn($destinationId, $entryId): illegal transition '
        '$current -> $status. Legal transitions: null -> {sent, wedged, '
        'tombstoned}; wedged -> {tombstoned, null}. (REQ-d00119-D '
        'one-way rule.)',
      );
    }
    updated['final_status'] = status?.toJson();
    if (status == FinalStatus.sent) {
      // Drain-terminal SendOk stamps sent_at.
      updated['sent_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (status == null) {
      // Rehabilitated row is no longer terminal; clear any stale
      // sent_at defensively. In practice a wedged row has sent_at ==
      // null already (only `sent` ever sets it).
      updated['sent_at'] = null;
    }
    // attempts[] is deliberately NOT touched — REQ-d00132-B rehabilitate
    // and REQ-d00144-B tombstoneAndRefill both require verbatim
    // preservation; the drain-terminal null->{sent,wedged} path has
    // already appended its attempts via appendAttempt before calling
    // markFinal/setFinalStatusTxn.
    await store.record(record.key).put(t._sembastTxn, updated);
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
    return store.delete(
      t._sembastTxn,
      finder: Finder(
        filter: Filter.and([
          Filter.isNull('final_status'),
          Filter.greaterThan('sequence_in_queue', afterSequenceInQueue),
        ]),
      ),
    );
  }

  // -------- Destination-role (ingest) write path --------

  /// Reserve-and-increment the per-destination ingest counter within [txn].
  /// Mirrors [nextSequenceNumber] for the ingest-side Chain 2 counter.
  // Implements: REQ-d00115-I; supports REQ-d00145-E+J.
  @override
  Future<int> nextIngestSequenceNumber(Txn txn) async {
    final t = _requireValidTxn(txn);
    final current =
        (await _backendStateStore.record(_ingestSequenceKey).get(t._sembastTxn)
            as int?) ??
        0;
    final next = current + 1;
    await _backendStateStore
        .record(_ingestSequenceKey)
        .put(t._sembastTxn, next);
    return next;
  }

  /// Read the current Chain 2 tail (last ingest seq + last event_hash).
  /// Non-transactional; reads the last-committed value.
  // Implements: REQ-d00115-H; supports REQ-d00145-E.
  @override
  Future<(int, String?)> readIngestTail() async {
    final db = _database();
    final seq =
        (await _backendStateStore.record(_ingestSequenceKey).get(db) as int?) ??
        0;
    final hash =
        await _backendStateStore.record(_ingestTailHashKey).get(db) as String?;
    return (seq, hash);
  }

  /// Transactional variant of [readIngestTail]. Reads within [txn] so
  /// writes already staged in the same transaction are visible.
  @override
  Future<(int, String?)> readIngestTailInTxn(Txn txn) async {
    final t = _requireValidTxn(txn);
    final seq =
        (await _backendStateStore.record(_ingestSequenceKey).get(t._sembastTxn)
            as int?) ??
        0;
    final hash =
        await _backendStateStore.record(_ingestTailHashKey).get(t._sembastTxn)
            as String?;
    return (seq, hash);
  }

  /// Append [event] to the event log keyed by its ingest_sequence_number.
  /// Atomically updates the Chain 2 tail (last ingest seq + last event_hash)
  /// in the same [txn]. Does NOT advance [nextSequenceNumber]'s origin counter.
  // Implements: REQ-d00145-E.
  @override
  Future<void> appendIngestedEvent(Txn txn, StoredEvent event) async {
    final t = _requireValidTxn(txn);

    // Extract the receiver's stamped ingest_sequence_number from the last
    // ProvenanceEntry in event.metadata.provenance.
    final provenance = event.metadata['provenance'] as List<Object?>;
    final lastEntry = provenance.last as Map<String, Object?>;
    final ingestSeq = lastEntry['ingest_sequence_number'] as int;

    // Persist to the events store using ingestSeq as the key.
    await _eventStore.record(ingestSeq).put(t._sembastTxn, event.toMap());

    // Update the Chain 2 tail atomically in the same txn.
    await _backendStateStore
        .record(_ingestSequenceKey)
        .put(t._sembastTxn, ingestSeq);
    await _backendStateStore
        .record(_ingestTailHashKey)
        .put(t._sembastTxn, event.eventHash);
  }

  /// Read a single event by `event_id` within [txn]. Returns `null` when no
  /// event with that id is present. Used by ingest's idempotency check
  /// (REQ-d00145-D).
  // Implements: REQ-d00145-D.
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

  /// Enumerate events by ingest_sequence_number (the Sembast int key used by
  /// [appendIngestedEvent]) ascending, filtered to the closed range [from, to].
  /// When [to] is null the range has no upper bound — all events at or above
  /// [from] are returned.
  ///
  /// The Sembast events store uses the ingest_sequence_number as its key
  /// (an `int`) when written via [appendIngestedEvent]. Records whose key
  /// falls outside [from..to] are filtered out in Dart after the sorted scan
  /// to keep the query simple and consistent with the key-based storage.
  // Implements: REQ-d00146-C — storage read for verifyIngestChain walk.
  @override
  Future<List<StoredEvent>> findEventsByIngestSeqRange({
    required int from,
    int? to,
  }) async {
    final db = _database();
    final records = await _eventStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    final result = <StoredEvent>[];
    for (final record in records) {
      final key = record.key;
      if (key < from) continue;
      if (to != null && key > to) continue;
      result.add(
        StoredEvent.fromMap(Map<String, Object?>.from(record.value), key),
      );
    }
    return result;
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
