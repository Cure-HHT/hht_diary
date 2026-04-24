// Regression test for REQ-d00119-D "continue past exhausted" drift.
//
// The Phase 4.6 demo surfaced that an exhausted head row did not block a
// trailing pending row: drain skipped past the wedged head and shipped
// the next row, producing out-of-order delivery to receipt-order-
// committing destinations. The concrete repro was "#60 shipped before
// #59" — event 59 wedged with a SendPermanent (schema skew), and drain
// then attempted and succeeded on event 60 before the operator could
// resolve 59.
//
// This test asserts the POST-FIX behavior:
//   1. drain halts at the wedged head (strict-order delivery);
//   2. the trailing row stays pre-terminal (null final_status) — NOT
//      shipped ahead of the wedged head;
//   3. the recording destination receives zero events until the operator
//      acts;
//   4. after `tombstoneAndRefill` on the wedged head, the next
//      fillBatch + drain cycle re-enqueues and delivers events in
//      sequence order (wedged event first, then trailing event).
//
// Verifies: REQ-d00124-D+H (drain halts at wedged head; trail is NOT
// attempted), REQ-d00144-A+B+C+D+F (tombstoneAndRefill contract + fresh
// re-promotion by the next fillBatch).

import 'dart:convert';
import 'dart:typed_data';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Append one event to the event log via the real sequence-number path:
/// `nextSequenceNumber` then `appendEvent` inside a single transaction,
/// mirroring `EntryService.record`'s contract without dragging in the
/// EntryTypeRegistry. Returns the appended `StoredEvent` so the caller
/// can assert its `sequenceNumber`.
Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  required DateTime clientTimestamp,
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: 'agg-1',
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      eventType: 'finalized',
      sequenceNumber: seq,
      data: const <String, dynamic>{},
      metadata: const <String, dynamic>{},
      initiator: const UserInitiator('u'),
      clientTimestamp: clientTimestamp,
      eventHash: 'hash-$eventId',
    );
    await backend.appendEvent(txn, event);
    return event;
  });
}

/// Minimal concrete Destination that
///   * carries the batch's `sequence_number`s forward into the stored
///     wire payload (so `send()` can observe them when drain re-encodes
///     the payload and hands it back);
///   * returns scripted `SendResult`s by popping a queue; falls through
///     to `SendOk` once the queue is empty (simulating the operator
///     "deploying a fix" — the destination is healthy for later sends);
///   * records the sequence_number of every successfully-delivered
///     payload for assertions about strict-order delivery.
///
/// `batchCapacity = 1` forces one event per FIFO row, matching the
/// Phase 4.6 demo's per-event drift where each event was its own row.
class _RecordingDestination extends Destination {
  _RecordingDestination({
    required this.id,
    required List<SendResult> plannedOutcomes,
  }) : _plannedOutcomes = plannedOutcomes;

  @override
  final String id;

  final List<SendResult> _plannedOutcomes;

  /// sequence_numbers of every payload this destination accepted with
  /// `SendOk`, in the order they were received by `send()`.
  final List<int> deliveredSeqs = <int>[];

  /// Number of `send()` invocations on this destination, regardless of
  /// outcome.
  int sendCallCount = 0;

  /// Clear remaining planned outcomes. Used to simulate the operator
  /// "deploying a fix" mid-test: subsequent sends fall through to
  /// `SendOk`.
  void deployFix() => _plannedOutcomes.clear();

  @override
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  String get wireFormat => 'recording-v1';

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) {
    // batchCapacity = 1: one event per batch row.
    return currentBatch.isEmpty;
  }

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    if (batch.isEmpty) {
      throw ArgumentError(
        '_RecordingDestination.transform called with empty batch',
      );
    }
    // Persist the batch's sequence_numbers into the wire payload so
    // `send()` can recover them via the stored-map -> bytes re-encoding
    // the drain path performs.
    final payload = <String, Object?>{
      'seqs': batch.map((e) => e.sequenceNumber).toList(),
      'event_ids': batch.map((e) => e.eventId).toList(),
    };
    return WirePayload(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      contentType: 'recording-v1',
      transformVersion: 'recording-v1',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sendCallCount += 1;
    final result = _plannedOutcomes.isNotEmpty
        ? _plannedOutcomes.removeAt(0)
        : const SendOk();
    if (result is SendOk) {
      final decoded =
          jsonDecode(utf8.decode(payload.bytes)) as Map<String, Object?>;
      final seqs = (decoded['seqs']! as List).cast<int>();
      deliveredSeqs.addAll(seqs);
    }
    return result;
  }
}

void main() {
  group('strict-order regression (REQ-d00119-D drift)', () {
    test('drain halts at wedged head; trail row stays null until '
        'tombstoneAndRefill re-enqueues and delivers in order', () async {
      final backend = await _openBackend('strict-order-regression.db');
      addTearDown(backend.close);

      // Scripted outcomes model the Phase 4.6 demo:
      //   - event #1 ("frontier sent before the wedge") -> SendOk;
      //   - event #2 ("schema-skew on seq 59") -> SendPermanent.
      // Event #3 would get SendOk, but the strict-order halt MUST
      // prevent drain from ever reaching it.
      //
      // Concrete mapping from the Phase 4.6 demo:
      //   event #1 here  <->  event 58 in the demo (prior-sent frontier)
      //   event #2 here  <->  event 59 in the demo (the wedge)
      //   event #3 here  <->  event 60 in the demo (the out-of-order ship)
      final destination = _RecordingDestination(
        id: 'secondary',
        plannedOutcomes: <SendResult>[
          const SendOk(),
          const SendPermanent(error: 'schema-skew on seq 59'),
        ],
      );

      // Register the destination BEFORE appending events so the
      // historical-replay branch (REQ-d00129-D) sees zero candidates
      // and does not pre-enqueue anything: we want every FIFO row on
      // `secondary` to be produced by the fillBatch path under test.
      final registry = DestinationRegistry(backend: backend);
      await registry.addDestination(destination);
      await registry.setStartDate(destination.id, DateTime.utc(2026, 1, 1));

      // Append three events via the real sequence-number path so their
      // sequence_numbers are assigned by `nextSequenceNumber`, not
      // hand-set. The clientTimestamp is inside the schedule window.
      final clientTs = DateTime.utc(2026, 4, 22, 10);
      final e1 = await _appendEvent(
        backend,
        eventId: 'e1',
        clientTimestamp: clientTs,
      );
      final e2 = await _appendEvent(
        backend,
        eventId: 'e2',
        clientTimestamp: clientTs,
      );
      final e3 = await _appendEvent(
        backend,
        eventId: 'e3',
        clientTimestamp: clientTs,
      );
      // Sanity: sequence numbers increment per append.
      expect(e1.sequenceNumber, 1);
      expect(e2.sequenceNumber, 2);
      expect(e3.sequenceNumber, 3);

      // fillBatch clock is past the event timestamps so the window
      // [startDate, now] covers all three events.
      final fillClock = DateTime.utc(2026, 4, 22, 12);
      final schedule = await registry.scheduleOf(destination.id);

      // Three fillBatch calls promote e1, e2, e3 into three single-
      // event FIFO rows (batchCapacity = 1).
      for (var i = 0; i < 3; i++) {
        await fillBatch(
          destination,
          backend: backend,
          schedule: schedule,
          clock: () => fillClock,
        );
      }

      // Act: drain once. The contract under test: drain ships e1
      // (SendOk), wedges e2 (SendPermanent), and halts — leaving e3
      // pending.
      await drain(destination, backend: backend, clock: () => fillClock);

      // Assert: exactly two send calls — e1 (SendOk) and e2 (wedged
      // attempt). e3 was NOT attempted.
      expect(destination.sendCallCount, 2);
      // Only e1 made it through end-to-end to the destination.
      expect(destination.deliveredSeqs, equals(<int>[1]));

      // Locate the three FIFO rows by scanning readFifoHead step by
      // step: head is now the WEDGED e2 (readFifoHead returns wedged
      // rows so drain can halt on them — REQ-d00124-H). e3's row sits
      // behind the wedged head with null final_status.
      final wedgedHead = await backend.readFifoHead(destination.id);
      expect(wedgedHead, isNotNull);
      expect(wedgedHead!.finalStatus, FinalStatus.wedged);
      expect(wedgedHead.eventIdRange.firstSeq, e2.sequenceNumber);
      expect(wedgedHead.eventIdRange.lastSeq, e2.sequenceNumber);
      expect(wedgedHead.eventIds, [e2.eventId]);
      final wedgedEntryId = wedgedHead.entryId;

      // e3's row is still pre-terminal — drain HALTED at the wedged
      // head rather than skipping past it. Look it up by scanning the
      // raw FIFO store; readFifoHead would return the wedged row, so
      // we fall back to an enumeration.
      final e3RowBefore = await _findRowCoveringSeq(
        backend,
        destination.id,
        e3.sequenceNumber,
      );
      expect(
        e3RowBefore,
        isNotNull,
        reason:
            'fillBatch should have enqueued a row for event 3 before '
            'drain ran; the row must still exist post-drain.',
      );
      expect(
        e3RowBefore!.finalStatus,
        isNull,
        reason:
            'Pre-fix drain would have shipped e3 past the wedged e2 '
            '(SendOk on e3), flipping this row to FinalStatus.sent. '
            'Post-fix drain halts at wedged e2; e3 stays pre-terminal.',
      );

      // Act: operator "deploys a fix" and runs tombstoneAndRefill on
      // the wedged row.
      destination.deployFix();
      final result = await tombstoneAndRefill(
        destination.id,
        wedgedEntryId,
        backend: backend,
      );
      expect(result, isA<TombstoneAndRefillResult>());
      expect(result.targetRowId, wedgedEntryId);
      // REQ-d00144-C: e3's pre-terminal trail row was deleted in the
      // trail sweep.
      expect(result.deletedTrailCount, 1);
      // REQ-d00144-D: fill_cursor rewound to target.first_seq - 1 =
      // e2.sequenceNumber - 1 = 1 (= e1.sequenceNumber).
      expect(result.rewoundTo, e2.sequenceNumber - 1);
      expect(
        await backend.readFillCursor(destination.id),
        e2.sequenceNumber - 1,
      );

      // Act: next sync tick — fillBatch re-promotes events 2 and 3
      // into fresh FIFO rows starting from the rewound cursor, then
      // drain ships them.
      for (var i = 0; i < 2; i++) {
        await fillBatch(
          destination,
          backend: backend,
          schedule: schedule,
          clock: () => fillClock,
        );
      }
      await drain(destination, backend: backend, clock: () => fillClock);

      // Assert: the destination now has e1, e2, e3 delivered in
      // sequence order — fresh delivery through post-fix drain, not
      // the pre-fix out-of-order path.
      expect(
        destination.deliveredSeqs,
        equals(<int>[e1.sequenceNumber, e2.sequenceNumber, e3.sequenceNumber]),
      );

      // Assert: REQ-d00144-B — the wedged row is now a tombstoned
      // archive. It coexists with the fresh rows (Task 6.5 UUID
      // entry_ids prevent collision).
      final wedgedRowAfter = await backend.readFifoRow(
        destination.id,
        wedgedEntryId,
      );
      expect(wedgedRowAfter, isNotNull);
      expect(wedgedRowAfter!.finalStatus, FinalStatus.tombstoned);
      expect(
        wedgedRowAfter.attempts.length,
        1,
        reason:
            'REQ-d00144-B: the SendPermanent attempt on the wedged '
            'row is preserved across the tombstone flip.',
      );

      // Assert: a fresh row covering e2 exists with a DIFFERENT UUID
      // entry_id and final_status == sent.
      final freshE2Row = await _findRowCoveringSeq(
        backend,
        destination.id,
        e2.sequenceNumber,
        excludeEntryId: wedgedEntryId,
      );
      expect(freshE2Row, isNotNull);
      expect(freshE2Row!.entryId, isNot(equals(wedgedEntryId)));
      expect(freshE2Row.finalStatus, FinalStatus.sent);

      // Assert: a fresh row covering e3 also exists and is sent.
      final freshE3Row = await _findRowCoveringSeq(
        backend,
        destination.id,
        e3.sequenceNumber,
      );
      expect(freshE3Row, isNotNull);
      expect(freshE3Row!.finalStatus, FinalStatus.sent);
    });
  });
}

/// Scan every FIFO row on [destinationId] via readFifoHead-style
/// enumeration (readFifoHead itself only returns the first
/// {null, wedged} row, so it can't find rows behind a wedge or rows
/// already marked sent). We round-trip through `backend.readFifoRow`
/// for every entry_id we can discover via the raw store.
///
/// Returns the row whose eventIdRange covers [sequenceNumber], or null
/// when no such row exists. If [excludeEntryId] is non-null, rows with
/// that entryId are skipped (used to find the FRESH row after tombstone
/// + refill, ignoring the tombstoned archive).
Future<FifoEntry?> _findRowCoveringSeq(
  SembastBackend backend,
  String destinationId,
  int sequenceNumber, {
  String? excludeEntryId,
}) async {
  // The Sembast FIFO store is `fifo_<destinationId>`, keyed by
  // sequence_in_queue. We iterate via the known-FIFOs list and the raw
  // store; the readFifoRow API then gives us typed FifoEntry values.
  final db = backend.debugDatabase();
  final rawRows = await StoreRef<int, Map<String, Object?>>(
    'fifo_$destinationId',
  ).find(db);
  for (final r in rawRows) {
    final entryId = r.value['entry_id'] as String;
    if (excludeEntryId != null && entryId == excludeEntryId) continue;
    final row = await backend.readFifoRow(destinationId, entryId);
    if (row == null) continue;
    if (sequenceNumber >= row.eventIdRange.firstSeq &&
        sequenceNumber <= row.eventIdRange.lastSeq) {
      return row;
    }
  }
  return null;
}
