import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

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

    FifoEntry mkEntry({
      required String entryId,
      required int sequenceInQueue,
      FinalStatus finalStatus = FinalStatus.pending,
      DateTime? sentAt,
      List<AttemptResult> attempts = const <AttemptResult>[],
    }) {
      return FifoEntry(
        entryId: entryId,
        eventId: 'event-$entryId',
        sequenceInQueue: sequenceInQueue,
        wirePayload: const <String, Object?>{'k': 'v'},
        wireFormat: 'json-v1',
        transformVersion: null,
        enqueuedAt: DateTime.utc(2026, 4, 22, 10, sequenceInQueue),
        attempts: attempts,
        finalStatus: finalStatus,
        sentAt: sentAt,
      );
    }

    Future<void> enqueue(String destId, FifoEntry entry) =>
        backend.transaction((txn) async {
          await backend.enqueueFifo(txn, destId, entry);
        });

    // -------- enqueueFifo + validation --------

    test('enqueueFifo + readFifoHead round-trip', () async {
      final e = mkEntry(entryId: 'e1', sequenceInQueue: 1);
      await enqueue('primary', e);
      final head = await backend.readFifoHead('primary');
      expect(head, equals(e));
    });

    // Verifies: REQ-d00117-E + REQ-d00119-C — enqueueFifo rejects a
    // non-pending entry; the storage contract states that an entry enters
    // the FIFO pending with an empty attempts list.
    test('enqueueFifo rejects non-pending entry', () async {
      final badStatus = mkEntry(
        entryId: 'e1',
        sequenceInQueue: 1,
        finalStatus: FinalStatus.sent,
      );
      await expectLater(
        backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'primary', badStatus);
        }),
        throwsArgumentError,
      );
    });

    test('enqueueFifo rejects entry with non-empty attempts', () async {
      final badAttempts = mkEntry(
        entryId: 'e1',
        sequenceInQueue: 1,
        attempts: [
          AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
        ],
      );
      await expectLater(
        backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'primary', badAttempts);
        }),
        throwsArgumentError,
      );
    });

    test('enqueueFifo rejects entry with non-null sent_at', () async {
      final badSentAt = mkEntry(
        entryId: 'e1',
        sequenceInQueue: 1,
        sentAt: DateTime.utc(2026, 4, 22, 11),
      );
      await expectLater(
        backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'primary', badSentAt);
        }),
        throwsArgumentError,
      );
    });

    test('enqueueFifo rejects duplicate entry_id in same FIFO', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await expectLater(
        backend.transaction((txn) async {
          await backend.enqueueFifo(
            txn,
            'primary',
            mkEntry(entryId: 'e1', sequenceInQueue: 2),
          );
        }),
        throwsStateError,
      );
    });

    test('same entry_id is allowed in DIFFERENT FIFOs', () async {
      await enqueue('A', mkEntry(entryId: 'shared', sequenceInQueue: 1));
      await enqueue('B', mkEntry(entryId: 'shared', sequenceInQueue: 1));
      expect((await backend.readFifoHead('A'))?.entryId, 'shared');
      expect((await backend.readFifoHead('B'))?.entryId, 'shared');
    });

    // -------- FIFO ordering --------

    // Verifies: REQ-d00119-A — insertion order is preserved; readFifoHead
    // returns the oldest pending entry each time.
    test('REQ-d00119-A: multiple enqueues preserve insertion order', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 2));
      await enqueue('primary', mkEntry(entryId: 'e3', sequenceInQueue: 3));

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e1');
    });

    test('per-destination isolation', () async {
      await enqueue('A', mkEntry(entryId: 'a-only', sequenceInQueue: 1));
      await enqueue('B', mkEntry(entryId: 'b-only', sequenceInQueue: 1));

      expect((await backend.readFifoHead('A'))?.entryId, 'a-only');
      expect((await backend.readFifoHead('B'))?.entryId, 'b-only');
    });

    // -------- appendAttempt --------

    test('appendAttempt appends without changing final_status', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));

      final attempt = AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 11),
        outcome: 'transient',
        errorMessage: 'timeout',
        httpStatus: 503,
      );
      await backend.appendAttempt('primary', 'e1', attempt);

      final head = await backend.readFifoHead('primary');
      expect(head?.attempts, [attempt]);
      expect(head?.finalStatus, FinalStatus.pending);

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
        await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
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
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      // After marking sent, readFifoHead moves past it to the next pending.
      expect(await backend.readFifoHead('primary'), isNull);

      // The entry persists: a follow-up appendAttempt on a different entry
      // works while e1 stays parked. We verify by querying the raw FIFO
      // via a second enqueue + head read.
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 2));
      final nextHead = await backend.readFifoHead('primary');
      expect(nextHead?.entryId, 'e2');
    });

    test('markFinal sent sets sent_at', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      final before = DateTime.now().toUtc();
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      final after = DateTime.now().toUtc();

      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 2));
      await backend.markFinal('primary', 'e2', FinalStatus.sent);

      // We can't easily query non-pending entries through readFifoHead, so
      // inspect the second e2 entry - it should have sent_at set between
      // before/after.
      await enqueue('primary', mkEntry(entryId: 'e3', sequenceInQueue: 3));
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
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.exhausted);

      // Raw store name must match SembastBackend._fifoStore(destinationId).
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      expect(raw.single.value['sent_at'], isNull);
    });

    test('after markFinal sent, readFifoHead returns next pending', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 2));

      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e2');
    });

    test(
      'after markFinal exhausted, readFifoHead returns null (wedged)',
      () async {
        await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
        await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 2));

        await backend.markFinal('primary', 'e1', FinalStatus.exhausted);

        expect(await backend.readFifoHead('primary'), isNull);
      },
    );

    // Verifies: REQ-d00127-A — markFinal on a missing row is a no-op, does
    // NOT throw. Closes the drain/unjam + drain/delete race (design §6.6):
    // drain awaits send() outside a transaction, so a concurrent user op
    // may remove the target row before drain's subsequent markFinal
    // transaction runs.
    test('REQ-d00127-A: markFinal no-ops when entry does not exist', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      // Must not throw.
      await backend.markFinal('primary', 'ghost', FinalStatus.sent);
      // e1 still at head, still pending.
      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, 'e1');
      expect(head?.finalStatus, FinalStatus.pending);
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
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', 'e1', FinalStatus.sent),
        throwsStateError,
      );
    });

    test('markFinal rejects sent -> exhausted transition', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', 'e1', FinalStatus.exhausted),
        throwsStateError,
      );
    });

    // -------- anyFifoExhausted + exhaustedFifos --------

    test('anyFifoExhausted true iff any FIFO is wedged', () async {
      await enqueue('A', mkEntry(entryId: 'a1', sequenceInQueue: 1));
      await enqueue('B', mkEntry(entryId: 'b1', sequenceInQueue: 1));

      expect(await backend.anyFifoExhausted(), isFalse);

      await backend.markFinal('A', 'a1', FinalStatus.exhausted);
      expect(await backend.anyFifoExhausted(), isTrue);
    });

    test('exhaustedFifos returns one summary per wedged FIFO', () async {
      await enqueue('A', mkEntry(entryId: 'a1', sequenceInQueue: 1));
      await enqueue('B', mkEntry(entryId: 'b1', sequenceInQueue: 1));
      await enqueue('C', mkEntry(entryId: 'c1', sequenceInQueue: 1));

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
      await backend.markFinal('A', 'a1', FinalStatus.exhausted);
      await backend.markFinal('C', 'c1', FinalStatus.exhausted);

      final summaries = await backend.exhaustedFifos();
      final byDest = {for (final s in summaries) s.destinationId: s};
      expect(byDest.keys.toSet(), {'A', 'C'});
      expect(byDest['A']!.headEntryId, 'a1');
      expect(byDest['A']!.headEventId, 'event-a1');
      expect(byDest['A']!.lastError, 'HTTP 400: bad request');
      expect(byDest['A']!.exhaustedAt, DateTime.utc(2026, 4, 22, 12, 30));
    });

    test('exhaustedFifos returns empty when nothing is wedged', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      expect(await backend.exhaustedFifos(), isEmpty);
    });

    test('exhaustedFifos reports sensible fallbacks when exhausted with no '
        'attempts', () async {
      final enqueuedAt = DateTime.utc(2026, 4, 22, 10, 1);
      await enqueue(
        'primary',
        FifoEntry(
          entryId: 'e-bare',
          eventId: 'event-e-bare',
          sequenceInQueue: 1,
          wirePayload: const <String, Object?>{'k': 'v'},
          wireFormat: 'json-v1',
          transformVersion: null,
          enqueuedAt: enqueuedAt,
          attempts: const <AttemptResult>[],
          finalStatus: FinalStatus.pending,
          sentAt: null,
        ),
      );
      await backend.markFinal('primary', 'e-bare', FinalStatus.exhausted);

      final summary = (await backend.exhaustedFifos()).single;
      expect(summary.destinationId, 'primary');
      expect(summary.headEntryId, 'e-bare');
      expect(summary.headEventId, 'event-e-bare');
      expect(summary.exhaustedAt, enqueuedAt);
      expect(summary.lastError, contains('no attempts'));
    });

    test('a FIFO with only sent entries is NOT wedged', () async {
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      expect(await backend.anyFifoExhausted(), isFalse);
      expect(await backend.exhaustedFifos(), isEmpty);
    });

    // -------- Phase-2 Prereq A, Option 1: backend-owned sequence_in_queue --

    // Verifies that the backend ignores the caller-supplied
    // `sequence_in_queue` on enqueue and assigns its own monotonic value.
    // Locks Phase-2 Prereq A, Option 1: FifoEntry.sequenceInQueue is an
    // output-only field on the read side; input values are ignored.
    test('enqueueFifo ignores caller-supplied sequence_in_queue and assigns '
        'its own monotonic value (Prereq A, Option 1)', () async {
      // Caller passes nonsense values; backend overwrites with 1, 2, 3.
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 9999));
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: -7));
      await enqueue('primary', mkEntry(entryId: 'e3', sequenceInQueue: 0));

      // Inspect the raw store to verify the stored sequence_in_queue
      // values are 1, 2, 3 regardless of caller input.
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
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.markFinal('primary', 'e1', FinalStatus.sent);
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 1));
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
      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 0));
      await enqueue('primary', mkEntry(entryId: 'e2', sequenceInQueue: 0));

      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      for (final record in raw) {
        expect(record.value['sequence_in_queue'], record.key);
      }
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

      await enqueue('primary', mkEntry(entryId: 'e1', sequenceInQueue: 1));
      await backend.appendAttempt(
        'primary',
        'e1',
        AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
      );
      await backend.markFinal('primary', 'e1', FinalStatus.sent);

      expect(logs, isEmpty);
    });
  });
}
