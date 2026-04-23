import 'dart:developer' as developer;

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

  /// Append [entry] to destination [destinationId]'s FIFO. The entry MUST
  /// arrive with `finalStatus == pending` and `attempts == []` — this is
  /// the enqueue state per the storage contract (REQ-d00117-E). We register
  /// the destination on first use so anyFifoExhausted/exhaustedFifos can
  /// iterate all known FIFOs later.
  ///
  /// The backend owns `sequence_in_queue`. The caller's
  /// `entry.sequenceInQueue` is ignored; the backend assigns the next value
  /// as `max(existing store key) + 1` inside this transaction and writes
  /// it into the persisted record. Storing records under the computed key
  /// keeps the Sembast int key, the payload `sequence_in_queue`, and the
  /// FIFO order in lockstep (Phase-2 Prereq A, Option 1).
  // Implements: REQ-d00117-E — enqueue initial state.
  // Implements: REQ-d00119-A — exactly one FIFO store per destination_id.
  @override
  Future<void> enqueueFifo(
    Txn txn,
    String destinationId,
    FifoEntry entry,
  ) async {
    final t = _requireValidTxn(txn);
    if (entry.finalStatus != FinalStatus.pending) {
      throw ArgumentError.value(
        entry.finalStatus,
        'entry.finalStatus',
        'enqueueFifo requires a pending entry '
            '(REQ-d00117-E / REQ-d00119-C)',
      );
    }
    if (entry.attempts.isNotEmpty) {
      throw ArgumentError.value(
        entry.attempts,
        'entry.attempts',
        'enqueueFifo requires an empty attempts[] list',
      );
    }
    if (entry.sentAt != null) {
      throw ArgumentError.value(
        entry.sentAt,
        'entry.sentAt',
        'enqueueFifo requires sentAt == null for a pending entry',
      );
    }
    final store = _fifoStore(destinationId);
    // Reject a duplicate entry_id in the same FIFO. Without this check,
    // later appendAttempt/markFinal calls would quietly pick one of the
    // duplicates and the other would drift out of sync.
    final existing = await store.find(
      t._sembastTxn,
      finder: Finder(
        filter: Filter.equals('entry_id', entry.entryId),
        limit: 1,
      ),
    );
    if (existing.isNotEmpty) {
      throw StateError(
        'FIFO $destinationId already has an entry with '
        'entry_id=${entry.entryId}',
      );
    }
    // Compute the next sequence_in_queue as max(existing key) + 1 so the
    // value is monotonic across surviving (sent/exhausted) entries and
    // the Sembast int key matches the payload's sequence_in_queue field.
    final maxRec = await store.find(
      t._sembastTxn,
      finder: Finder(sortOrders: [SortOrder(Field.key, false)], limit: 1),
    );
    final assigned = maxRec.isEmpty ? 1 : (maxRec.first.key) + 1;
    final payload = entry.toJson();
    payload['sequence_in_queue'] = assigned;
    await store.record(assigned).put(t._sembastTxn, payload);
    await _registerFifoDestination(t, destinationId);
  }

  Future<void> _registerFifoDestination(
    _SembastTxn t,
    String destinationId,
  ) async {
    final current =
        (await _backendStateStore.record(_knownFifosKey).get(t._sembastTxn)
                as List?)
            ?.cast<String>()
            .toList() ??
        <String>[];
    if (!current.contains(destinationId)) {
      current.add(destinationId);
      await _backendStateStore
          .record(_knownFifosKey)
          .put(t._sembastTxn, current);
    }
  }

  Future<List<String>> _knownFifoDestinations() async {
    final db = _database();
    final value = await _backendStateStore.record(_knownFifosKey).get(db);
    return (value as List?)?.cast<String>().toList() ?? const <String>[];
  }

  /// Oldest pending entry in [destinationId]'s FIFO, or null when either
  /// (a) the FIFO is empty or all entries are `sent`, or (b) the earliest
  /// non-`sent` entry is `exhausted` (the FIFO is wedged and will not
  /// advance without operator action).
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) async {
    final db = _database();
    final store = _fifoStore(destinationId);
    final records = await store.find(
      db,
      finder: Finder(sortOrders: [SortOrder('sequence_in_queue')]),
    );
    for (final record in records) {
      final entry = FifoEntry.fromJson(Map<String, Object?>.from(record.value));
      switch (entry.finalStatus) {
        case FinalStatus.sent:
          continue; // advance past successfully-sent entries
        case FinalStatus.exhausted:
          return null; // wedged
        case FinalStatus.pending:
          return entry;
      }
    }
    return null;
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
          headEventId: head.eventId,
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
