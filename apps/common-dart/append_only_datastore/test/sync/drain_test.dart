import 'dart:convert';

import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/sync/drain.dart';
import 'package:append_only_datastore/src/sync/sync_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';

/// Fixture — a fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Enqueue a single-event row via the Phase-4.3 Task-6 batch-aware
/// `enqueueFifo`. Under the new semantics, `entry_id` is derived from the
/// lead event's `eventId`, so we enqueue with `eventId: entryId` to keep
/// the row's identity stable across the call sites below.
Future<void> _enqueueRow(
  SembastBackend backend,
  String destId, {
  required String entryId,
  required int sequenceNumber,
}) => enqueueSingle(
  backend,
  destId,
  eventId: entryId,
  sequenceNumber: sequenceNumber,
  wirePayload: <String, Object?>{'event_id': entryId},
  wireFormat: 'fake-v1',
  transformVersion: 'fake-v1',
);

void main() {
  group('drain()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('drain-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00124-A — empty FIFO: drain returns without sending.
    test('REQ-d00124-A: empty FIFO returns without calling send', () async {
      final dest = FakeDestination();
      await drain(dest, backend: backend);
      expect(dest.sent, isEmpty);
    });

    // Verifies: REQ-d00124-C — SendOk marks entry sent and advances.
    test(
      'REQ-d00124-C: SendOk marks head sent and advances to the next head',
      () async {
        await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
        final dest = FakeDestination(script: [const SendOk()]);

        await drain(dest, backend: backend);

        expect(dest.sent, hasLength(1));
        // After markFinal sent, the head is gone; readFifoHead returns null.
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Verifies: REQ-d00124-C — after the current head is sent, drain advances
    // to the next pending entry in the same call.
    test(
      'REQ-d00124-C: drain loops across multiple SendOks in one call',
      () async {
        var seq = 0;
        for (final id in ['e1', 'e2', 'e3']) {
          seq += 1;
          await _enqueueRow(backend, 'fake', entryId: id, sequenceNumber: seq);
        }
        final dest = FakeDestination(
          script: [const SendOk(), const SendOk(), const SendOk()],
        );

        await drain(dest, backend: backend);
        expect(dest.sent, hasLength(3));
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Verifies: REQ-d00124-D — SendPermanent marks the head exhausted and
    // drain CONTINUES to the next pending row. After Phase-4.3 Task 8
    // readFifoHead skips exhausted rows, and after Task 13 the drain
    // loop's SendPermanent case flips from `return` to `continue` — so
    // a SendPermanent on e1 marks e1 exhausted, the drain loop iterates
    // back to `readFifoHead`, which returns e2 (the next pending row),
    // and drain attempts e2 in the same call.
    test('REQ-d00124-D: SendPermanent marks head exhausted and drain '
        'continues to the next pending row', () async {
      await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
      await _enqueueRow(backend, 'fake', entryId: 'e2', sequenceNumber: 2);
      final dest = FakeDestination(
        script: [
          const SendPermanent(error: 'HTTP 400'),
          const SendOk(),
        ],
      );

      await drain(dest, backend: backend);
      // Two send calls: e1 (SendPermanent) and e2 (SendOk). e2 was
      // attempted because drain continued past the exhausted e1.
      expect(dest.sent, hasLength(2));

      // e1 is exhausted; e2 is sent; no pending rows remain.
      expect(await backend.readFifoHead('fake'), isNull);
    });

    // Verifies: REQ-d00124-F+B — SendTransient below maxAttempts: attempt
    // is appended, entry remains pending, backoff gates next drain.
    test('REQ-d00124-F+B: SendTransient appends attempt; next drain honors '
        'backoff and does not call send again', () async {
      final firstAttemptAt = DateTime.utc(2026, 4, 22, 10, 0, 5);

      await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
      final dest = FakeDestination(
        script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
      );

      // First drain: uses scripted "now" = firstAttemptAt.
      await drain(dest, backend: backend, clock: () => firstAttemptAt);
      expect(dest.sent, hasLength(1));
      // Entry is still pending with one attempt.
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.attempts, hasLength(1));
      expect(head.finalStatus, isNull);

      // Re-drain immediately after (clock = firstAttemptAt + 1s). Backoff
      // is 60s from the last attempt; 1s after is well inside the window.
      await drain(
        dest,
        backend: backend,
        clock: () => firstAttemptAt.add(const Duration(seconds: 1)),
      );
      expect(dest.sent, hasLength(1)); // no new send call
    });

    // Verifies: REQ-d00124-B — once the backoff elapses, drain sends again.
    test(
      'REQ-d00124-B: after backoff elapses, drain calls send again',
      () async {
        final firstAttemptAt = DateTime.utc(2026, 4, 22, 10, 0, 5);
        // SyncPolicy.backoffFor(1) is roughly 300s (60 * 5).
        final afterBackoff = firstAttemptAt.add(
          const Duration(seconds: 300 * 2),
        ); // 10 minutes — well past

        await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
        final dest = FakeDestination(
          script: [
            const SendTransient(error: 'HTTP 503', httpStatus: 503),
            const SendOk(),
          ],
        );

        await drain(dest, backend: backend, clock: () => firstAttemptAt);
        expect(dest.sent, hasLength(1));

        await drain(dest, backend: backend, clock: () => afterBackoff);
        expect(dest.sent, hasLength(2));
        expect(await backend.readFifoHead('fake'), isNull); // sent
      },
    );

    // Verifies: REQ-d00124-E — SendTransient AT maxAttempts → exhausted,
    // and drain CONTINUES to the next pending row. Simulated by
    // pre-loading e1's attempts[] to maxAttempts-1 so the next transient
    // trips the cap; e2 is enqueued behind it so the continue-past-
    // exhausted path is observable as a send call against e2.
    test('REQ-d00124-E: SendTransient at maxAttempts marks entry exhausted '
        'and drain continues to the next pending row', () async {
      await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
      await _enqueueRow(backend, 'fake', entryId: 'e2', sequenceNumber: 2);
      // Pre-load attempts on e1: maxAttempts-1 transient records so the
      // next drain-triggered transient is the one that exhausts e1.
      final preloadAttempts = SyncPolicy.defaults.maxAttempts - 1;
      for (var i = 0; i < preloadAttempts; i++) {
        await backend.appendAttempt('fake', 'e1', _attemptResultFactory(i));
      }
      // Clock well past any backoff window.
      final longAfter = DateTime.utc(2027, 1, 1);
      final dest = FakeDestination(
        script: [
          const SendTransient(error: 'HTTP 503', httpStatus: 503),
          const SendOk(),
        ],
      );

      await drain(dest, backend: backend, clock: () => longAfter);
      // Two send calls: e1 (SendTransient-at-max → exhausted) and e2
      // (SendOk). e2 was attempted because drain continued past the
      // exhausted e1.
      expect(dest.sent, hasLength(2));
      // e1 is exhausted; e2 is sent; no pending rows remain.
      expect(await backend.readFifoHead('fake'), isNull);
    });

    // Verifies: REQ-d00124-G — every send call records an attempt, no matter
    // the outcome. Here: SendOk (e1), SendPermanent (e2), SendOk (e3).
    // Under Task-13 continue-past-exhausted semantics, drain attempts all
    // three rows in one pass: e1 is sent, e2 is exhausted, drain continues
    // to e3 (the next pending) and sends it. Each send call appends one
    // AttemptResult.
    test('REQ-d00124-G: every send call appends an AttemptResult', () async {
      var seq = 0;
      for (final id in ['e1', 'e2', 'e3']) {
        seq += 1;
        await _enqueueRow(backend, 'fake', entryId: id, sequenceNumber: seq);
      }
      final dest = FakeDestination(
        script: [
          const SendOk(),
          const SendPermanent(error: 'HTTP 400'), // exhausts e2
          const SendOk(), // drain continues past e2 and sends e3
        ],
      );

      await drain(
        dest,
        backend: backend,
        clock: () => DateTime.utc(2026, 4, 22, 11),
      );

      // Inspect the raw store: each of e1, e2, e3 has exactly 1 attempt.
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_fake',
      ).find(db);
      final attemptsByEntry = <String, int>{};
      for (final r in raw) {
        attemptsByEntry[r.value['entry_id']! as String] =
            (r.value['attempts']! as List).length;
      }
      expect(attemptsByEntry['e1'], 1);
      expect(attemptsByEntry['e2'], 1);
      expect(attemptsByEntry['e3'], 1);
    });

    // Verifies: REQ-d00124-H — strict FIFO order. Drain attempts pending
    // rows in sequence_in_queue order. Under Task-13 continue-past-
    // exhausted semantics, drain still honors FIFO ordering: an earlier
    // pending row is always attempted before a later pending row, and an
    // exhausted row is skipped in-place (its slot in the drain pass is
    // its sequence_in_queue position). Scripted SendPermanent on e1,
    // SendOk on e2, SendOk on e3 proves the ordering: the payloads land
    // in the destination in the same order the rows were enqueued.
    test(
      'REQ-d00124-H: strict FIFO — drain attempts e1, e2, e3 in enqueue order',
      () async {
        var seq = 0;
        for (final id in ['e1', 'e2', 'e3']) {
          seq += 1;
          await _enqueueRow(backend, 'fake', entryId: id, sequenceNumber: seq);
        }
        final dest = FakeDestination(
          script: [
            const SendPermanent(error: 'HTTP 400'), // e1 -> exhausted
            const SendOk(), // e2 -> sent
            const SendOk(), // e3 -> sent
          ],
        );

        await drain(
          dest,
          backend: backend,
          clock: () => DateTime.utc(2026, 4, 22, 11),
        );
        // Three send calls, in the order e1, e2, e3. The WirePayload
        // content reflects the row's event_id JSON encoding; decode it
        // to confirm the drain called send in FIFO order.
        expect(dest.sent, hasLength(3));
        final orderedEventIds = dest.sent
            .map(
              (p) =>
                  (jsonDecode(utf8.decode(p.bytes))
                          as Map<String, Object?>)['event_id']
                      as String,
            )
            .toList();
        expect(orderedEventIds, ['e1', 'e2', 'e3']);
      },
    );

    // Verifies: multi-destination independence — d1 wedged, d2 drains
    // normally. (Orchestrated via sync_cycle in Task 8; here we exercise
    // the drain-loop half of the claim by calling drain separately per
    // destination.)
    test(
      'multi-destination independence: wedge on d1 does not block d2',
      () async {
        final clockTime = DateTime.utc(2026, 4, 22, 10);
        await _enqueueRow(backend, 'd1', entryId: 'e1', sequenceNumber: 1);
        await _enqueueRow(backend, 'd2', entryId: 'e2', sequenceNumber: 2);
        final d1 = FakeDestination(
          id: 'd1',
          script: [const SendPermanent(error: 'HTTP 400')],
        );
        final d2 = FakeDestination(id: 'd2', script: [const SendOk()]);

        await drain(d1, backend: backend, clock: () => clockTime);
        await drain(d2, backend: backend, clock: () => clockTime);

        expect(d1.sent, hasLength(1));
        expect(d2.sent, hasLength(1));
        // d1's row is exhausted (SendPermanent) with no pending row after
        // it; d2's row is sent. readFifoHead skips both terminal states
        // and returns null (REQ-d00124-A, Task 8 semantics).
        expect(await backend.readFifoHead('d1'), isNull);
        expect(await backend.readFifoHead('d2'), isNull);
      },
    );

    // Verifies: REQ-d00126-B — an injected SyncPolicy's maxAttempts is what
    // drain consults (not the defaults). Pre-seed attempts[] to one below a
    // smaller injected cap; next transient attempt should wedge the entry.
    test('REQ-d00126-B: drain honors injected policy.maxAttempts', () async {
      await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);

      const smallPolicy = SyncPolicy(
        initialBackoff: Duration(seconds: 60),
        backoffMultiplier: 5.0,
        maxBackoff: Duration(hours: 2),
        jitterFraction: 0.1,
        maxAttempts: 3, // smaller cap than defaults.maxAttempts (20)
        periodicInterval: Duration(minutes: 15),
      );
      // Pre-load attempts: smallPolicy.maxAttempts - 1 transient records.
      for (var i = 0; i < smallPolicy.maxAttempts - 1; i++) {
        await backend.appendAttempt('fake', 'e1', _attemptResultFactory(i));
      }
      // Clock well past any backoff window.
      final longAfter = DateTime.utc(2027, 1, 1);
      final dest = FakeDestination(
        script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
      );

      await drain(
        dest,
        backend: backend,
        clock: () => longAfter,
        policy: smallPolicy,
      );
      expect(dest.sent, hasLength(1));
      // With a cap of 3 and 3 total attempts, the entry is wedged (head null).
      expect(await backend.readFifoHead('fake'), isNull);
    });

    // Verifies: REQ-d00126-B — a null policy falls back to SyncPolicy.defaults.
    // Sanity-check that omitting `policy` reads the defaults (20 attempts).
    test(
      'REQ-d00126-B: null policy falls back to SyncPolicy.defaults',
      () async {
        await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
        // Pre-load 2 attempts: well below the default cap of 20, so a
        // transient should leave the entry pending (head still present).
        for (var i = 0; i < 2; i++) {
          await backend.appendAttempt('fake', 'e1', _attemptResultFactory(i));
        }
        final longAfter = DateTime.utc(2027, 1, 1);
        final dest = FakeDestination(
          script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
        );

        await drain(dest, backend: backend, clock: () => longAfter);
        expect(dest.sent, hasLength(1));
        final head = await backend.readFifoHead('fake');
        expect(head, isNotNull);
        expect(head!.finalStatus, isNull);
      },
    );

    // Verifies: drain treats a thrown exception from send() as SendTransient
    // and continues rather than crashing the caller.
    test('drain treats a thrown exception as SendTransient and records an '
        'attempt', () async {
      await _enqueueRow(backend, 'fake', entryId: 'e1', sequenceNumber: 1);
      final dest = _ThrowingDestination();

      await drain(
        dest,
        backend: backend,
        clock: () => DateTime.utc(2026, 4, 22, 11),
      );

      // Entry is still pending, with one attempt whose outcome is
      // "transient".
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.attempts, hasLength(1));
      expect(head.attempts.first.outcome, 'transient');
    });
  });
}

/// Scripted AttemptResult for pre-loading transient history.
AttemptResult _attemptResultFactory(int i) => AttemptResult(
  attemptedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
  outcome: 'transient',
  errorMessage: 'pre-seeded transient #$i',
  httpStatus: 503,
);

class _ThrowingDestination extends FakeDestination {
  _ThrowingDestination() : super(id: 'fake');

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    throw StateError('boom');
  }
}
