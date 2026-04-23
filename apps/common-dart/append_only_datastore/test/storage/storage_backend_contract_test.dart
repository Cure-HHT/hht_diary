import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/exhausted_fifo_summary.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageBackend contract', () {
    late _InMemoryBackend backend;

    setUp(() {
      backend = _InMemoryBackend();
    });

    // Verifies: REQ-d00117-A — transaction body that returns successfully
    // commits all writes so they are visible to subsequent reads.
    test('REQ-d00117-A: successful body commits all writes', () async {
      final event = _sampleEvent(eventId: 'ev-1');

      final result = await backend.transaction((txn) async {
        await backend.appendEvent(txn, event);
        return 'ok';
      });

      expect(result, 'ok');
      final stored = await backend.findAllEvents();
      expect(stored.map((e) => e.eventId), ['ev-1']);
    });

    // Verifies: REQ-d00117-A — a throw inside the transaction body rolls
    // back every Txn-bound write so none of them are visible afterwards.
    test('REQ-d00117-A: thrown exception rolls back all writes', () async {
      await expectLater(
        backend.transaction((txn) async {
          await backend.appendEvent(txn, _sampleEvent(eventId: 'ev-rollback'));
          throw StateError('simulated failure');
        }),
        throwsStateError,
      );

      final stored = await backend.findAllEvents();
      expect(stored, isEmpty);
    });

    // Verifies: REQ-d00117-A — a partially-successful body still rolls back
    // atomically; nothing from before the throw remains committed.
    test(
      'REQ-d00117-A: mid-body throw rolls back earlier writes too',
      () async {
        await expectLater(
          backend.transaction((txn) async {
            await backend.appendEvent(txn, _sampleEvent(eventId: 'ev-a'));
            await backend.appendEvent(txn, _sampleEvent(eventId: 'ev-b'));
            throw StateError('simulated failure');
          }),
          throwsStateError,
        );

        expect(await backend.findAllEvents(), isEmpty);
      },
    );

    // Verifies: REQ-d00117-B — using a Txn handle after the transaction body
    // returns raises StateError so accidental escape is detected instead of
    // silently writing against a closed transaction.
    test('REQ-d00117-B: Txn cannot be used after body returns', () async {
      late Txn escaped;
      await backend.transaction((txn) async {
        escaped = txn;
      });

      await expectLater(
        backend.appendEvent(escaped, _sampleEvent(eventId: 'ev-late')),
        throwsStateError,
      );
    });

    test('REQ-d00117-B: Txn cannot be used after body throws', () async {
      late Txn escaped;
      await expectLater(
        backend.transaction((txn) async {
          escaped = txn;
          throw StateError('boom');
        }),
        throwsStateError,
      );

      await expectLater(
        backend.appendEvent(escaped, _sampleEvent(eventId: 'ev-late')),
        throwsStateError,
      );
    });

    test(
      'sequential transactions: second transaction sees first commit',
      () async {
        await backend.transaction((txn) async {
          await backend.appendEvent(txn, _sampleEvent(eventId: 'ev-1'));
        });
        await backend.transaction((txn) async {
          await backend.appendEvent(txn, _sampleEvent(eventId: 'ev-2'));
        });
        final stored = await backend.findAllEvents();
        expect(stored.map((e) => e.eventId), ['ev-1', 'ev-2']);
      },
    );

    // The abstract contract is silent on whether a backend must support
    // nested transactions. This fake backend rejects them (matches Sembast,
    // which does not support re-entrant transactions either). Documenting
    // the behavior here so a second concrete backend has a known starting
    // point: if nested transactions become legal later, either relax this
    // test or make it implementation-specific.
    test('nested transaction on this fake throws', () async {
      await expectLater(
        backend.transaction((outer) async {
          await backend.transaction((inner) async {});
        }),
        throwsStateError,
      );
    });
  });
}

// -------- Fake backend --------

StoredEvent _sampleEvent({required String eventId}) => StoredEvent(
  key: 0,
  eventId: eventId,
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: 'epistaxis_event',
  eventType: 'Event',
  sequenceNumber: 0,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  initiator: const UserInitiator('u'),
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash-$eventId',
);

/// Minimal in-memory backend used only by the contract tests.
///
/// Implements just enough behavior to exercise REQ-d00117-A (transaction
/// atomicity) and REQ-d00117-B (Txn lexical scoping). All other methods
/// throw [UnimplementedError] — the real SembastBackend is covered by
/// dedicated tests in Tasks 6-8.
class _InMemoryBackend extends StorageBackend {
  /// Committed state: event_id -> stored event.
  final Map<String, StoredEvent> _events = <String, StoredEvent>{};

  /// Non-null while a [transaction] body is running; mutations inside the
  /// body go here and are promoted to [_events] only on commit.
  Map<String, StoredEvent>? _staged;

  @override
  Future<T> transaction<T>(Future<T> Function(Txn txn) body) async {
    if (_staged != null) {
      throw StateError('Nested transactions are not supported by this fake');
    }
    _staged = Map<String, StoredEvent>.from(_events);
    final txn = _InMemoryTxn(this);
    try {
      final result = await body(txn);
      _events
        ..clear()
        ..addAll(_staged!);
      return result;
    } finally {
      _staged = null;
      txn._invalidate();
    }
  }

  @override
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event) async {
    _assertOwnValid(txn)._check();
    _staged![event.eventId] = event;
    return AppendResult(
      sequenceNumber: event.sequenceNumber,
      eventHash: event.eventHash,
    );
  }

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
  }) async {
    final sorted = _events.values.toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    return sorted;
  }

  @override
  Future<String?> readLatestEventHash(Txn txn) async {
    _assertOwnValid(txn)._check();
    final staged = _staged!;
    if (staged.isEmpty) return null;
    final sorted = staged.values.toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    return sorted.last.eventHash;
  }

  @override
  Future<List<StoredEvent>> findAllEventsInTxn(
    Txn txn, {
    int? afterSequence,
    int? limit,
  }) async {
    _assertOwnValid(txn)._check();
    final staged = _staged!;
    var sorted = staged.values.toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    if (afterSequence != null) {
      sorted = sorted.where((e) => e.sequenceNumber > afterSequence).toList();
    }
    if (limit != null && sorted.length > limit) {
      sorted = sorted.sublist(0, limit);
    }
    return sorted;
  }

  _InMemoryTxn _assertOwnValid(Txn txn) {
    if (txn is! _InMemoryTxn || txn._backend != this) {
      throw StateError('Txn does not belong to this backend');
    }
    return txn;
  }

  // The remaining methods are not exercised by the contract tests.
  @override
  Future<List<StoredEvent>> findEventsForAggregate(String aggregateId) =>
      throw UnimplementedError();
  @override
  Future<List<StoredEvent>> findEventsForAggregateInTxn(
    Txn txn,
    String aggregateId,
  ) => throw UnimplementedError();
  @override
  Future<int> nextSequenceNumber(Txn txn) => throw UnimplementedError();
  @override
  Future<int> readSequenceCounter() => throw UnimplementedError();
  @override
  Future<void> upsertEntry(Txn txn, DiaryEntry entry) =>
      throw UnimplementedError();
  @override
  Future<void> clearEntries(Txn txn) => throw UnimplementedError();
  @override
  Future<List<DiaryEntry>> findEntries({
    String? entryType,
    bool? isComplete,
    bool? isDeleted,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => throw UnimplementedError();
  @override
  Future<DiaryEntry?> readEntryInTxn(Txn txn, String entryId) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
  ) => throw UnimplementedError();
  @override
  Future<void> upsertViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
    Map<String, dynamic> row,
  ) => throw UnimplementedError();
  @override
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {
    int? limit,
    int? offset,
  }) => throw UnimplementedError();
  @override
  Future<void> clearViewInTxn(Txn txn, String viewName) =>
      throw UnimplementedError();
  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) => throw UnimplementedError();
  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) => throw UnimplementedError();
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) =>
      throw UnimplementedError();
  @override
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  ) => throw UnimplementedError();
  @override
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  ) => throw UnimplementedError();
  @override
  Future<bool> anyFifoExhausted() => throw UnimplementedError();
  @override
  Future<List<ExhaustedFifoSummary>> exhaustedFifos() =>
      throw UnimplementedError();
  @override
  Future<int> readSchemaVersion() => throw UnimplementedError();
  @override
  Future<void> writeSchemaVersion(Txn txn, int version) =>
      throw UnimplementedError();
  // Fill-cursor behavioral tests live in sembast_backend_fifo_test.dart
  // (REQ-d00128-G: default/round-trip/transactional-rollback/per-destination).
  // When a second StorageBackend implementation lands, replicate those
  // behaviors here as implementation-agnostic contract tests.
  @override
  Future<int> readFillCursor(String destinationId) =>
      throw UnimplementedError();
  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) =>
      throw UnimplementedError();
  @override
  Future<void> writeFillCursorTxn(
    Txn txn,
    String destinationId,
    int sequenceNumber,
  ) => throw UnimplementedError();
  @override
  Future<DestinationSchedule?> readSchedule(String destinationId) =>
      throw UnimplementedError();
  @override
  Future<void> writeSchedule(
    String destinationId,
    DestinationSchedule schedule,
  ) => throw UnimplementedError();
  @override
  Future<void> writeScheduleTxn(
    Txn txn,
    String destinationId,
    DestinationSchedule schedule,
  ) => throw UnimplementedError();
  @override
  Future<void> deleteScheduleTxn(Txn txn, String destinationId) =>
      throw UnimplementedError();
  @override
  Future<void> deleteFifoStoreTxn(Txn txn, String destinationId) =>
      throw UnimplementedError();
  @override
  Future<int> deletePendingRowsTxn(Txn txn, String destinationId) =>
      throw UnimplementedError();
  @override
  Future<int?> maxSentSequenceTxn(Txn txn, String destinationId) =>
      throw UnimplementedError();
  @override
  Future<FifoEntry?> readFifoRow(String destinationId, String entryId) =>
      throw UnimplementedError();
  @override
  Future<List<FifoEntry>> exhaustedRowsOf(String destinationId) =>
      throw UnimplementedError();
  @override
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  ) => throw UnimplementedError();
}

class _InMemoryTxn extends Txn {
  _InMemoryTxn(this._backend);
  final _InMemoryBackend _backend;
  bool _valid = true;

  void _invalidate() {
    _valid = false;
  }

  void _check() {
    if (!_valid) {
      throw StateError('Txn used outside its transaction() body');
    }
  }
}
