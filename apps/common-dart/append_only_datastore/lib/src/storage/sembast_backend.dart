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

  /// Persist [event] and advance the sequence counter in a single
  /// atomic transaction step (REQ-d00117-C). [event]'s `sequenceNumber`
  /// MUST be exactly one greater than the current persisted counter value
  /// (equivalently, it MUST equal the value returned by an immediately-
  /// preceding [nextSequenceNumber] call inside the same [txn] body). An
  /// out-of-range sequence number is treated as a caller bug and throws
  /// `StateError`, preventing silent counter regression or duplicate
  /// sequence numbers.
  // Implements: REQ-d00117-C — appendEvent co-atomic with sequence counter.
  // Implements: REQ-p00004-A+B — append-only event, hash chain stamped by
  // caller and persisted verbatim.
  @override
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event) async {
    final t = _requireValidTxn(txn);
    final currentRaw = await _backendStateStore
        .record(_sequenceKey)
        .get(t._sembastTxn);
    final current = (currentRaw as int?) ?? 0;
    final expected = current + 1;
    if (event.sequenceNumber != expected) {
      throw StateError(
        'appendEvent: event.sequenceNumber (${event.sequenceNumber}) '
        'must equal current counter + 1 ($expected). Prior counter: $current. '
        'Did the caller forget to pair nextSequenceNumber with appendEvent?',
      );
    }
    await _eventStore.add(t._sembastTxn, event.toMap());
    await _backendStateStore
        .record(_sequenceKey)
        .put(t._sembastTxn, event.sequenceNumber);
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

  @override
  Future<int> nextSequenceNumber(Txn txn) async {
    final t = _requireValidTxn(txn);
    final current = await _backendStateStore
        .record(_sequenceKey)
        .get(t._sembastTxn);
    return ((current as int?) ?? 0) + 1;
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
    // Reject a duplicate entry_id in the same FIFO. Without this check,
    // later appendAttempt/markFinal calls would quietly pick one of the
    // duplicates and the other would drift out of sync.
    final existing = await _fifoStore(destinationId).find(
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
    await _fifoStore(destinationId).add(t._sembastTxn, entry.toJson());
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
        throw StateError(
          'FIFO $destinationId has no entry with entry_id=$entryId',
        );
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
  // Implements: REQ-d00119-D — non-pending entries are retained as
  // permanent send-log records.
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
        throw StateError(
          'FIFO $destinationId has no entry with entry_id=$entryId',
        );
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
