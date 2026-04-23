import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fifo_entry_helpers.dart';

void main() {
  group('SembastBackend FIFO', () {
    late SembastBackend backend;
    var pathCounter = 0;

    setUp(() async {
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'fifo-$pathCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Phase-4.3 Task 6 shifted enqueueFifo from a caller-constructed
    // FifoEntry to (destId, List<StoredEvent>, WirePayload). Under the new
    // contract, the backend derives:
    //   entry_id       = batch.first.eventId
    //   event_ids      = batch.map((e) => e.eventId)
    //   event_id_range = (first.sequenceNumber, last.sequenceNumber)
    // So a single-event test like "enqueue eventId=ev-1 at seq=1" produces
    // a row with entry_id == 'ev-1' and event_ids == ['ev-1'].

    // -------- enqueueFifo + validation --------

    test('enqueueFifo + readFifoHead round-trip', () async {
      final enqueued = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      expect(head!.entryId, 'e1');
      expect(head.eventIds, ['e1']);
      expect(head.eventIdRange, (firstSeq: 1, lastSeq: 1));
      expect(head.finalStatus, isNull);
      expect(head.attempts, isEmpty);
      expect(head.sentAt, isNull);
      // Returned entry equals the persisted head modulo DateTime precision
      // (both derived from DateTime.now() inside the transaction).
      expect(head.entryId, enqueued.entryId);
      expect(head.sequenceInQueue, enqueued.sequenceInQueue);
    });

    // Verifies: REQ-d00128-A — an empty batch is rejected at enqueueFifo
    // rather than silently producing a zero-event row.
    test(
      'REQ-d00128-A: enqueueFifo rejects an empty batch with ArgumentError',
      () async {
        await expectLater(
          backend.enqueueFifo(
            'primary',
            const [],
            wirePayloadJson(const {'k': 'v'}),
          ),
          throwsArgumentError,
        );
      },
    );

    test('enqueueFifo rejects duplicate entry_id in same FIFO', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      // Second enqueue with the same eventId -> derived entryId collides.
      await expectLater(
        enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 2),
        throwsStateError,
      );
    });

    test('same entry_id is allowed in DIFFERENT FIFOs', () async {
      await enqueueSingle(backend, 'A', eventId: 'shared', sequenceNumber: 1);
      await enqueueSingle(backend, 'B', eventId: 'shared', sequenceNumber: 1);
      expect((await backend.readFifoHead('A'))?.entryId, 'shared');
      expect((await backend.readFifoHead('B'))?.entryId, 'shared');
    });

    // -------- FIFO ordering --------

    // Verifies: REQ-d00119-A — insertion order is preserved; readFifoHead
    // returns the oldest pending entry each time.
    test('REQ-d00119-A: multiple enqueues preserve insertion order', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e1');
    });

    test('per-destination isolation', () async {
      await enqueueSingle(backend, 'A', eventId: 'a-only', sequenceNumber: 1);
      await enqueueSingle(backend, 'B', eventId: 'b-only', sequenceNumber: 1);

      expect((await backend.readFifoHead('A'))?.entryId, 'a-only');
      expect((await backend.readFifoHead('B'))?.entryId, 'b-only');
    });

    // -------- appendAttempt --------

    test('appendAttempt appends without changing final_status', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);

      final attempt = AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 11),
        outcome: 'transient',
        errorMessage: 'timeout',
        httpStatus: 503,
      );
      await backend.appendAttempt('primary', 'e1', attempt);

      final head = await backend.readFifoHead('primary');
      expect(head?.attempts, [attempt]);
      expect(head?.finalStatus, isNull);

      // Second attempt also appends, preserving order.
      final attempt2 = AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 12),
        outcome: 'transient',
        errorMessage: 'timeout',
        httpStatus: 503,
      );
      await backend.appendAttempt('primary', 'e1', attempt2);
      final head2 = await backend.readFifoHead('primary');
      expect(head2?.attempts, [attempt, attempt2]);
    });

    // Verifies: REQ-d00127-B — appendAttempt on a missing row is a no-op,
    // does NOT throw. Closes the drain/unjam + drain/delete race (design
    // §6.6): drain awaits send() outside a transaction, so a concurrent
    // user op may remove the target row before drain's subsequent
    // appendAttempt transaction runs.
    test(
      'REQ-d00127-B: appendAttempt no-ops when entry does not exist',
      () async {
        await enqueueSingle(
          backend,
          'primary',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        // Must not throw.
        await backend.appendAttempt(
          'primary',
          'nonexistent',
          AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
        );
        // The FIFO is otherwise untouched: e1 is still pending with no
        // attempts.
        final head = await backend.readFifoHead('primary');
        expect(head?.entryId, 'e1');
        expect(head?.attempts, isEmpty);
      },
    );

    // Verifies: REQ-d00127-B — appendAttempt against a FIFO store that
    // was never registered (destination that never existed, or whose
    // store was destroyed) is a no-op. In Sembast a never-written store
    // has zero records, so the records.isEmpty path covers both.
    test(
      'REQ-d00127-B: appendAttempt no-ops when FIFO store does not exist',
      () async {
        // 'ghost-dest' was never enqueued to.
        await backend.appendAttempt(
          'ghost-dest',
          'any-entry',
          AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
        );
        // Nothing materialized in the unknown store.
        expect(await backend.readFifoHead('ghost-dest'), isNull);
      },
    );

    // -------- markFinal --------

    // Verifies: REQ-d00119-D — markFinal does NOT delete the entry; it
    // flips final_status and, for sent, stamps sent_at. The entry lives
    // on as a send-log record.
    test('REQ-d00119-D: markFinal sent retains the entry', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      // After marking sent, readFifoHead moves past it to the next pending.
      expect(await backend.readFifoHead('primary'), isNull);

      // The entry persists: a follow-up appendAttempt on a different entry
      // works while e1 stays parked. We verify by querying the raw FIFO
      // via a second enqueue + head read.
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      final nextHead = await backend.readFifoHead('primary');
      expect(nextHead?.entryId, 'e2');
    });

    test('markFinal sent sets sent_at', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      final before = DateTime.now().toUtc();
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      final after = DateTime.now().toUtc();

      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await backend.markFinal('primary', 'e2', FinalStatus.sent);

      // We can't easily query non-pending entries through readFifoHead, so
      // inspect the second e2 entry - it should have sent_at set between
      // before/after.
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);
      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e3');
      // e1 and e2 are retained but not visible at head. The sent_at check
      // is validated indirectly: markFinal would have thrown if sent_at
      // wasn't being assigned, and the retain test above proves markFinal
      // preserves the entry. Direct inspection via debugDatabase. The raw
      // store name must match SembastBackend._fifoStore(destinationId),
      // which is 'fifo_$destinationId'.
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      final e1Raw = raw.firstWhere((r) => r.value['entry_id'] == 'e1');
      final e1SentAt = DateTime.parse(e1Raw.value['sent_at']! as String);
      expect(e1SentAt.isAfter(before) || e1SentAt == before, isTrue);
      expect(e1SentAt.isBefore(after) || e1SentAt == after, isTrue);
    });

    test('markFinal exhausted does NOT set sent_at', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.wedged);

      // Raw store name must match SembastBackend._fifoStore(destinationId).
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      expect(raw.single.value['sent_at'], isNull);
    });

    test('after markFinal sent, readFifoHead returns next pending', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);

      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e2');
    });

    // Verifies: REQ-d00124-A — after Phase-4.3 Task 8, an exhausted row at
    // the head is SKIPPED; readFifoHead returns the next pending row. The
    // drain-loop "wedge" behavior (SendPermanent / SendTransient-at-max
    // stops drain) is preserved by drain.dart's switch-case, not by
    // readFifoHead returning null. This test pairs with the "no pending
    // rows remain" variant below.
    test('REQ-d00124-A: readFifoHead skips an exhausted head and returns the '
        'next pending row', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);

      await backend.markFinal('primary', 'e1', FinalStatus.wedged);

      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      expect(head!.entryId, 'e2');
      expect(head.finalStatus, isNull);
    });

    // Verifies: REQ-d00124-A — after Phase-4.3 Task 8, when every row is
    // terminal (mix of sent / exhausted) and no pending row remains,
    // readFifoHead returns null. This is the "FIFO exhausted of work"
    // signal to drain.
    test('REQ-d00124-A: readFifoHead returns null when no pending rows remain '
        '(only exhausted and sent rows present)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await backend.markFinal('primary', 'e2', FinalStatus.wedged);
      await backend.markFinal('primary', 'e3', FinalStatus.sent);

      expect(await backend.readFifoHead('primary'), isNull);
    });

    // Verifies: REQ-d00124-A — readFifoHead skips a mix of sent and
    // exhausted rows in sequence_in_queue order and returns the first
    // pending row it encounters. Pinpoints "skip past any terminal row,
    // not just the first one" so a future regression that special-cased
    // only the head position would be caught.
    test('REQ-d00124-A: readFifoHead skips a run of mixed terminal rows and '
        'returns the first pending in sequence_in_queue order', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);
      await enqueueSingle(backend, 'primary', eventId: 'e4', sequenceNumber: 4);

      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await backend.markFinal('primary', 'e2', FinalStatus.wedged);
      await backend.markFinal('primary', 'e3', FinalStatus.sent);
      // e4 is left pending.

      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      expect(head!.entryId, 'e4');
      expect(head.finalStatus, isNull);
    });

    // Verifies: REQ-d00127-A — markFinal on a missing row is a no-op, does
    // NOT throw. Closes the drain/unjam + drain/delete race (design §6.6):
    // drain awaits send() outside a transaction, so a concurrent user op
    // may remove the target row before drain's subsequent markFinal
    // transaction runs.
    test('REQ-d00127-A: markFinal no-ops when entry does not exist', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      // Must not throw.
      await backend.markFinal('primary', 'ghost', FinalStatus.sent);
      // e1 still at head, still pending.
      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e1');
      expect(head?.finalStatus, isNull);
    });

    // Verifies: REQ-d00127-A — markFinal against a FIFO store that was
    // never registered is a no-op. In Sembast a never-written store has
    // zero records, so the records.isEmpty path covers this case too.
    test(
      'REQ-d00127-A: markFinal no-ops when FIFO store does not exist',
      () async {
        await backend.markFinal('ghost-dest', 'any-entry', FinalStatus.sent);
        expect(await backend.readFifoHead('ghost-dest'), isNull);
      },
    );

    // Verifies: REQ-d00119-D — final_status transitions are one-way. A
    // second markFinal on an already-terminal entry would silently re-stamp
    // sent_at, corrupting the send-log timestamp; reject it instead.
    test('markFinal rejects a second transition '
        '(pending -> sent -> sent blocked)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', 'e1', FinalStatus.sent),
        throwsStateError,
      );
    });

    test('markFinal rejects sent -> exhausted transition', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', 'e1', FinalStatus.wedged),
        throwsStateError,
      );
    });

    // -------- anyFifoExhausted + exhaustedFifos --------

    test('anyFifoExhausted true iff any FIFO is wedged', () async {
      await enqueueSingle(backend, 'A', eventId: 'a1', sequenceNumber: 1);
      await enqueueSingle(backend, 'B', eventId: 'b1', sequenceNumber: 1);

      expect(await backend.anyFifoExhausted(), isFalse);

      await backend.markFinal('A', 'a1', FinalStatus.wedged);
      expect(await backend.anyFifoExhausted(), isTrue);
    });

    test('exhaustedFifos returns one summary per wedged FIFO', () async {
      await enqueueSingle(backend, 'A', eventId: 'a1', sequenceNumber: 1);
      await enqueueSingle(backend, 'B', eventId: 'b1', sequenceNumber: 1);
      await enqueueSingle(backend, 'C', eventId: 'c1', sequenceNumber: 1);

      // Record an attempt on A's head so the summary has a lastError.
      await backend.appendAttempt(
        'A',
        'a1',
        AttemptResult(
          attemptedAt: DateTime.utc(2026, 4, 22, 12, 30),
          outcome: 'permanent',
          errorMessage: 'HTTP 400: bad request',
          httpStatus: 400,
        ),
      );
      await backend.markFinal('A', 'a1', FinalStatus.wedged);
      await backend.markFinal('C', 'c1', FinalStatus.wedged);

      final summaries = await backend.exhaustedFifos();
      final byDest = {for (final s in summaries) s.destinationId: s};
      expect(byDest.keys.toSet(), {'A', 'C'});
      expect(byDest['A']!.headEntryId, 'a1');
      // Under Task-6 semantics, the summary reports the first event_id of
      // the batch — for a single-event batch, this equals the entry_id.
      expect(byDest['A']!.headEventId, 'a1');
      expect(byDest['A']!.lastError, 'HTTP 400: bad request');
      expect(byDest['A']!.exhaustedAt, DateTime.utc(2026, 4, 22, 12, 30));
    });

    test('exhaustedFifos returns empty when nothing is wedged', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      expect(await backend.exhaustedFifos(), isEmpty);
    });

    test('exhaustedFifos reports sensible fallbacks when exhausted with no '
        'attempts', () async {
      await enqueueSingle(
        backend,
        'primary',
        eventId: 'e-bare',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', 'e-bare', FinalStatus.wedged);

      final summary = (await backend.exhaustedFifos()).single;
      expect(summary.destinationId, 'primary');
      expect(summary.headEntryId, 'e-bare');
      expect(summary.headEventId, 'e-bare');
      expect(summary.lastError, contains('no attempts'));
    });

    test('a FIFO with only sent entries is NOT wedged', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      expect(await backend.anyFifoExhausted(), isFalse);
      expect(await backend.exhaustedFifos(), isEmpty);
    });

    // -------- Phase-2 Prereq A, Option 1: backend-owned sequence_in_queue --

    // Verifies that the backend assigns sequence_in_queue monotonically
    // starting at 1, regardless of any caller-side sequencing concerns.
    // Task-6's new signature no longer accepts a caller-supplied
    // sequence_in_queue at all (the backend constructs the FifoEntry), so
    // this test collapses from "caller supplies nonsense; backend
    // overwrites" to "backend assigns 1, 2, 3 monotonically".
    test('enqueueFifo assigns its own monotonic sequence_in_queue '
        '(Prereq A, Option 1)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      // Inspect the raw store to verify the stored sequence_in_queue
      // values are 1, 2, 3.
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      expect(raw.map((r) => r.value['sequence_in_queue']).toList(), [1, 2, 3]);
      expect(raw.map((r) => r.value['entry_id']).toList(), ['e1', 'e2', 'e3']);
    });

    // Verifies that sequence_in_queue continues to grow past surviving
    // sent/exhausted entries — the backend's max-key+1 algorithm must not
    // re-use a slot vacated by a terminal-state entry (entries are
    // retained forever per REQ-d00119-D).
    test('sequence_in_queue advances across sent/exhausted entries '
        '(Prereq A, Option 1)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      // e2 should get sequence 2, not 1.
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      final e2 = raw.firstWhere((r) => r.value['entry_id'] == 'e2');
      expect(e2.value['sequence_in_queue'], 2);
      expect(e2.key, 2);
    });

    // Verifies that the Sembast int key equals the payload's
    // sequence_in_queue (they are in lockstep by design).
    test('sequence_in_queue equals the Sembast store key (lockstep)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);

      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      for (final record in raw) {
        expect(record.value['sequence_in_queue'], record.key);
      }
    });

    // Verifies: REQ-d00119-E — sequence_in_queue is monotonic per
    // destination and NEVER reused. Even when a row is deleted from the
    // underlying Sembast store (as the REQ-d00144-C trail sweep will
    // do), a subsequent enqueue must NOT re-use the deleted row's
    // sequence_in_queue value. This test performs a raw `store.delete`
    // bypassing the backend API to simulate the deletion path, then
    // verifies the next enqueue picks up the next never-seen value
    // rather than refilling the vacated slot.
    test('REQ-d00119-E: sequence_in_queue is monotonic per destination, '
        'never reused', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      final db = backend.debugDatabase();
      final store = StoreRef<int, Map<String, Object?>>('fifo_primary');
      final before = await store.find(db);
      expect(before.map((r) => r.value['sequence_in_queue']).toList(), [
        1,
        2,
        3,
      ]);

      // Raw delete of row whose sequence_in_queue is 2 (entry_id 'e2').
      // This simulates the REQ-d00144-C trail-sweep deletion path
      // without depending on that API (which is introduced in Task 6).
      await store.record(2).delete(db);

      final afterDelete = await store.find(db);
      expect(afterDelete.map((r) => r.value['sequence_in_queue']).toList(), [
        1,
        3,
      ]);

      // Fourth enqueue MUST get sequence_in_queue 4 — NOT 2 (the
      // deleted slot) and NOT 3 (max-key after delete + 1 under the
      // old derivation would also be 4, but only because 3 already
      // exists; the defining test is the next-next one below).
      await enqueueSingle(backend, 'primary', eventId: 'e4', sequenceNumber: 4);
      final afterFirstEnqueue = await store.find(db);
      final e4Record = afterFirstEnqueue.firstWhere(
        (r) => r.value['entry_id'] == 'e4',
      );
      expect(e4Record.value['sequence_in_queue'], 4);
      expect(e4Record.key, 4);

      // Now delete row 4 (the row we just inserted, currently the
      // max-key row). Under a buggy "max(existing key) + 1"
      // derivation, the next enqueue would assign 4 again — reusing
      // the slot. The persisted counter prevents that: the next
      // enqueue must get 5.
      await store.record(4).delete(db);
      await enqueueSingle(backend, 'primary', eventId: 'e5', sequenceNumber: 5);
      final afterSecondEnqueue = await store.find(db);
      final e5Record = afterSecondEnqueue.firstWhere(
        (r) => r.value['entry_id'] == 'e5',
      );
      expect(e5Record.value['sequence_in_queue'], 5);
      expect(e5Record.key, 5);
    });

    // -------- REQ-d00127-C: warning log on missing-row no-op --------

    // Verifies: REQ-d00127-C — both markFinal and appendAttempt emit a
    // warning-level diagnostic that names the method, the entry id, and
    // the destination id when they no-op due to a missing target. Tests
    // install a capture closure via debugLogSink so the assertion doesn't
    // depend on any global logger.
    test('REQ-d00127-C: markFinal emits a warning that names method, '
        'entry id, and destination id when it no-ops', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      await backend.markFinal('primary', 'ghost', FinalStatus.sent);

      expect(logs, hasLength(1));
      final line = logs.single;
      expect(line, contains('markFinal'));
      expect(line, contains('ghost'));
      expect(line, contains('primary'));
      expect(line, contains('drain/unjam'));
      expect(line, contains('drain/delete'));
    });

    test('REQ-d00127-C: appendAttempt emits a warning that names method, '
        'entry id, and destination id when it no-ops', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      await backend.appendAttempt(
        'primary',
        'ghost',
        AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
      );

      expect(logs, hasLength(1));
      final line = logs.single;
      expect(line, contains('appendAttempt'));
      expect(line, contains('ghost'));
      expect(line, contains('primary'));
      expect(line, contains('drain/unjam'));
      expect(line, contains('drain/delete'));
    });

    // Verifies: REQ-d00127-C — the warning is NOT emitted on a successful
    // happy-path call. Prevents a future regression where a code change
    // flipped the no-op branch in both directions.
    test('REQ-d00127-C: no warning is emitted on a happy-path markFinal / '
        'appendAttempt', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await backend.appendAttempt(
        'primary',
        'e1',
        AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
      );
      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      expect(logs, isEmpty);
    });

    // -------- fill_cursor (REQ-d00128-G) --------

    // Verifies: REQ-d00128-G — readFillCursor returns -1 when no cursor has
    // ever been written for the destination, signalling "no row has yet been
    // enqueued into this FIFO".
    test('REQ-d00128-G: readFillCursor returns -1 when unset', () async {
      expect(await backend.readFillCursor('primary'), -1);
    });

    // Verifies: REQ-d00128-G — writeFillCursor persists the value under
    // backend_state/fill_cursor_<destId>; readFillCursor observes it.
    test(
      'REQ-d00128-G: writeFillCursor then readFillCursor round-trips',
      () async {
        await backend.writeFillCursor('primary', 42);
        expect(await backend.readFillCursor('primary'), 42);

        // A second write replaces the prior value (monotonic advance is
        // caller policy; the backend contract just stores what it's given).
        await backend.writeFillCursor('primary', 100);
        expect(await backend.readFillCursor('primary'), 100);
      },
    );

    // Verifies: REQ-d00128-G — the transactional writeFillCursorTxn variant
    // participates in the surrounding transaction's atomicity. If the
    // transaction body throws, the cursor write rolls back with everything
    // else and readFillCursor still returns the pre-transaction value.
    test('REQ-d00128-G: writeFillCursor inside a transaction participates in '
        'atomicity (rollback confirms cursor was NOT advanced)', () async {
      // Pre-transaction baseline.
      await backend.writeFillCursor('primary', 7);
      expect(await backend.readFillCursor('primary'), 7);

      await expectLater(
        backend.transaction((txn) async {
          await backend.writeFillCursorTxn(txn, 'primary', 99);
          throw StateError('simulated failure');
        }),
        throwsStateError,
      );

      // Rollback: cursor is still the pre-transaction value (7), NOT 99.
      expect(await backend.readFillCursor('primary'), 7);

      // And on commit, the value IS advanced.
      await backend.transaction((txn) async {
        await backend.writeFillCursorTxn(txn, 'primary', 55);
      });
      expect(await backend.readFillCursor('primary'), 55);
    });

    // Verifies: REQ-d00128-G — the fill_cursor is per-destination; writes to
    // one destination's cursor do NOT change another destination's cursor.
    test('REQ-d00128-G: fill_cursor is per-destination (two destinations have '
        'independent cursors)', () async {
      expect(await backend.readFillCursor('primary'), -1);
      expect(await backend.readFillCursor('secondary'), -1);

      await backend.writeFillCursor('primary', 10);
      expect(await backend.readFillCursor('primary'), 10);
      // secondary is untouched.
      expect(await backend.readFillCursor('secondary'), -1);

      await backend.writeFillCursor('secondary', 22);
      expect(await backend.readFillCursor('secondary'), 22);
      // primary is unchanged.
      expect(await backend.readFillCursor('primary'), 10);
    });

    // Verifies: REQ-d00128-G — writeFillCursor rejects negative values
    // smaller than the -1 sentinel so a bogus caller cannot store a value
    // outside the fill_cursor's legal domain of [-1, infinity).
    test('REQ-d00128-G: writeFillCursor rejects sequenceNumber < -1', () async {
      await expectLater(
        backend.writeFillCursor('primary', -2),
        throwsArgumentError,
      );
      // The failed write left the cursor unchanged.
      expect(await backend.readFillCursor('primary'), -1);
    });
  });
}
