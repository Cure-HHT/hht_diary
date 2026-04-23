import 'dart:convert';
import 'dart:developer' as developer;

import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/exhausted_fifo_summary.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
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
  /// `anyFifoExhausted` / `exhaustedFifos` no longer iterate it.
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

  // -------- FIFO --------

  /// Append a batch-shaped row to destination [destinationId]'s FIFO. The
  /// row covers every event in [batch] and carries a single [wirePayload]
  /// (REQ-d00128-C).
  ///
  /// Opens its own atomic transaction. Phase-4.3 later adds an
  /// `enqueueFifoTxn(txn, ...)` overload for callers (replay,
  /// fill_batch) that are already composing a larger transaction; this
  /// public method is the standalone variant.
  ///
  /// The backend owns `sequence_in_queue`: it is assigned as
  /// `max(existing store key) + 1` inside the internal transaction, so
  /// the Sembast int key and the payload `sequence_in_queue` are in
  /// lockstep (Phase-2 Prereq A, Option 1).
  ///
  /// The returned `FifoEntry` is the persisted record. Callers that
  /// need to advance a per-destination cursor use
  /// `result.eventIdRange.lastSeq` as the inclusive upper bound of the
  /// batch on the event log.
  ///
  /// Rejects (throws `ArgumentError`):
  /// - empty [batch] (REQ-d00128-A);
  /// - `entryId` collision within the destination's FIFO (would let a
  ///   later `markFinal` / `appendAttempt` pick the wrong row).
  // Implements: REQ-d00117-E — enqueue initial state (pending, no
  // attempts, no sent_at).
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  // Implements: REQ-d00128-A+B+C — batch-per-row enqueue.
  @override
  Future<FifoEntry> enqueueFifo(
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
    return _database().transaction((sembastTxn) async {
      final store = _fifoStore(destinationId);
      // Reject a duplicate entry_id in the same FIFO. Without this
      // check, later appendAttempt/markFinal calls would quietly pick
      // one of the duplicates and the other would drift out of sync.
      final existing = await store.find(
        sembastTxn,
        finder: Finder(filter: Filter.equals('entry_id', entryId), limit: 1),
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'FIFO $destinationId already has an entry with '
          'entry_id=$entryId',
        );
      }
      // Compute the next sequence_in_queue as max(existing key) + 1 so
      // the value is monotonic across surviving (sent/exhausted)
      // entries and the Sembast int key matches the payload's
      // sequence_in_queue field.
      final maxRec = await store.find(
        sembastTxn,
        finder: Finder(sortOrders: [SortOrder(Field.key, false)], limit: 1),
      );
      final assigned = maxRec.isEmpty ? 1 : (maxRec.first.key) + 1;
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
        finalStatus: FinalStatus.pending,
        sentAt: null,
      );
      await store.record(assigned).put(sembastTxn, entry.toJson());
      await _registerFifoDestinationSembast(sembastTxn, destinationId);
      return entry;
    });
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

  /// Oldest pending entry in [destinationId]'s FIFO, or null when every
  /// row is terminal (a mix of `sent` and/or `exhausted`) or the FIFO is
  /// empty. Both `sent` and `exhausted` rows are SKIPPED; only a `pending`
  /// row is returned.
  ///
  /// Pre-Phase-4.3-Task-8, this method returned null as soon as it
  /// encountered an exhausted row — the FIFO was "wedged" at the
  /// backend level. From Task 8 forward, the wedge is enforced by the
  /// drain loop's switch-case (SendPermanent / SendTransient-at-max
  /// stops drain), not by readFifoHead; this lets the batch-FIFO
  /// continue-past-exhausted semantics be introduced without changing
  /// the method's caller-facing contract in drain.
  // Implements: REQ-d00124-A — readFifoHead returns the first row whose
  // final_status == pending in sequence_in_queue order; sent and
  // exhausted rows are skipped. Drain's wedge behavior is preserved by
  // drain.dart's SendPermanent / SendTransient-at-max returning rather
  // than by readFifoHead returning null at the first exhausted row.
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) async {
    final db = _database();
    final store = _fifoStore(destinationId);
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.equals('final_status', FinalStatus.pending.toJson()),
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
  /// The one-way transition rule (pending -> terminal only) is
  /// preserved: an already-terminal entry still throws `StateError` to
  /// prevent silent re-stamping of `sent_at`.
  // Implements: REQ-d00119-D — non-pending entries are retained as
  // permanent send-log records.
  // Implements: REQ-d00127-A — markFinal is a no-op on missing row /
  // missing FIFO store, with a warning-level diagnostic.
  @override
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  ) async {
    if (status == FinalStatus.pending) {
      throw ArgumentError.value(
        status,
        'status',
        'markFinal requires a terminal status (sent or exhausted)',
      );
    }
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
      final currentStatus = FinalStatus.fromJson(
        updated['final_status']! as String,
      );
      // final_status is one-way: pending -> sent|exhausted. Re-transitioning
      // a terminal entry would silently re-stamp sent_at and corrupt the
      // send-log timestamp, so reject it.
      if (currentStatus != FinalStatus.pending) {
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
  Future<List<ExhaustedFifoSummary>> exhaustedFifos() async {
    final result = <ExhaustedFifoSummary>[];
    for (final dest in await _knownFifoDestinations()) {
      final head = await _exhaustedHead(dest);
      if (head == null) continue;
      final hasAttempts = head.attempts.isNotEmpty;
      result.add(
        ExhaustedFifoSummary(
          destinationId: dest,
          headEntryId: head.entryId,
          // For batch rows, the summary reports the first event_id as a
          // stable single-string identifier for operators. Multi-event
          // batches' full id list is accessible via readFifoHead.
          headEventId: head.eventIds.first,
          exhaustedAt: hasAttempts
              ? head.attempts.last.attemptedAt
              : head.enqueuedAt,
          lastError: hasAttempts
              ? (head.attempts.last.errorMessage ?? '<no error message>')
              : '<exhausted with no attempts recorded>',
        ),
      );
    }
    return result;
  }

  /// The first non-sent entry in the FIFO when it is `exhausted`. Returns
  /// null when either the FIFO has no entries, all entries are `sent`, or
  /// the earliest non-sent entry is `pending` (not wedged).
  Future<FifoEntry?> _exhaustedHead(String destinationId) async {
    final db = _database();
    final records = await _fifoStore(
      destinationId,
    ).find(db, finder: Finder(sortOrders: [SortOrder('sequence_in_queue')]));
    for (final record in records) {
      final entry = FifoEntry.fromJson(Map<String, Object?>.from(record.value));
      switch (entry.finalStatus) {
        case FinalStatus.sent:
          continue;
        case FinalStatus.exhausted:
          return entry;
        case FinalStatus.pending:
          return null;
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
