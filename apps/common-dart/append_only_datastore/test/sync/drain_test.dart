import 'dart:convert';

import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
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

/// Enqueue a single-event row via the Phase-4.7 batch-aware
/// `enqueueFifo`. The backend mints a v4-UUID `entry_id` at enqueue
/// time (independent of the event id); callers that need to look the
/// row up later capture the returned `FifoEntry.entryId`.
Future<String> _enqueueRow(
  SembastBackend backend,
  String destId, {
  required String eventId,
  required int sequenceNumber,
}) async {
  final entry = await enqueueSingle(
    backend,
    destId,
    eventId: eventId,
    sequenceNumber: sequenceNumber,
    wirePayload: <String, Object?>{'event_id': eventId},
    wireFormat: 'fake-v1',
    transformVersion: 'fake-v1',
  );
  return entry.entryId;
}

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
        await _enqueueRow(backend, 'fake', eventId: 'e1', sequenceNumber: 1);
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
          await _enqueueRow(backend, 'fake', eventId: id, sequenceNumber: seq);
        }
        final dest = FakeDestination(
          script: [const SendOk(), const SendOk(), const SendOk()],
        );

        await drain(dest, backend: backend);
        expect(dest.sent, hasLength(3));
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Verifies: REQ-d00124-H — drain halts at a wedged head. When the
    // head row's final_status is already FinalStatus.wedged, drain
    // SHALL return without calling Destination.send; the row is NOT
    // re-attempted, and its trail rows are NOT attempted either.
    // Recovery from a wedged head is tombstoneAndRefill (REQ-d00144).
    test(
      'REQ-d00124-H: drain halts when head is wedged, does not call send',
      () async {
        final e1RowId = await _enqueueRow(
          backend,
          'fake',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        await backend.markFinal('fake', e1RowId, FinalStatus.wedged);
        // Script would throw StateError if send() were invoked (see
        // FakeDestination.send); absence of such a throw confirms
        // drain did not call send. We script SendOk defensively so a
        // regression that DID call send would surface as a hasLength(1)
        // mismatch rather than an exhausted-script StateError.
        final dest = FakeDestination(script: [const SendOk()]);

        await drain(dest, backend: backend);

        expect(dest.sent, isEmpty);
        // The wedged row remains wedged, unchanged.
        final head = await backend.readFifoHead('fake');
        expect(head, isNotNull);
        expect(head!.entryId, e1RowId);
        expect(head.finalStatus, FinalStatus.wedged);
      },
    );

    // Verifies: REQ-d00124-D+H — SendPermanent marks the head wedged;
    // the NEXT loop iteration reads the newly-wedged row and drain
    // halts at the top-of-loop check. Concretely: drain attempts e1
    // exactly once, e1 becomes wedged, e2 (the trail row) is NEVER
    // attempted, and e1 remains at the head of readFifoHead.
    test('REQ-d00124-D+H: SendPermanent marks head wedged; drain halts on '
        'next iteration; trail row is NOT attempted', () async {
      final e1RowId = await _enqueueRow(
        backend,
        'fake',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final e2RowId = await _enqueueRow(
        backend,
        'fake',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      final dest = FakeDestination(
        script: [const SendPermanent(error: 'schema-skew')],
      );

      await drain(dest, backend: backend);
      // Exactly one send call — e1. e2 (trail) was NOT attempted.
      expect(dest.sent, hasLength(1));

      // e1 is wedged; e2 is still pre-terminal (final_status null).
      // readFifoHead returns the wedged e1 because wedged is a
      // returnable-but-halting final_status under the new contract.
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.entryId, e1RowId);
      expect(head.finalStatus, FinalStatus.wedged);

      // e2 is still pre-terminal.
      final e2 = await backend.readFifoRow('fake', e2RowId);
      expect(e2, isNotNull);
      expect(e2!.finalStatus, isNull);
    });

    // Verifies: REQ-d00124-E+H — SendTransient at the attempt cap marks
    // the head wedged; drain halts on the next iteration; the trail row
    // is NOT attempted. Uses a tiny maxAttempts policy (=1) with
    // Duration.zero backoffs so a single SendTransient trips the cap.
    test('REQ-d00124-E+H: SendTransient at maxAttempts marks head wedged; '
        'drain halts on next iteration; trail row is NOT attempted', () async {
      final e1RowId = await _enqueueRow(
        backend,
        'fake',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final e2RowId = await _enqueueRow(
        backend,
        'fake',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      const oneAttemptPolicy = SyncPolicy(
        initialBackoff: Duration.zero,
        backoffMultiplier: 1.0,
        maxBackoff: Duration.zero,
        jitterFraction: 0.0,
        maxAttempts: 1,
        periodicInterval: Duration(minutes: 15),
      );
      final dest = FakeDestination(
        script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
      );

      await drain(
        dest,
        backend: backend,
        clock: () => DateTime.utc(2026, 4, 22, 11),
        policy: oneAttemptPolicy,
      );
      // Exactly one send call — e1 tripped the cap. e2 was NOT attempted.
      expect(dest.sent, hasLength(1));

      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.entryId, e1RowId);
      expect(head.finalStatus, FinalStatus.wedged);

      // e2 remains pre-terminal.
      final e2 = await backend.readFifoRow('fake', e2RowId);
      expect(e2, isNotNull);
      expect(e2!.finalStatus, isNull);
    });

    // Verifies: REQ-d00124-F+B — SendTransient below maxAttempts: attempt
    // is appended, entry remains pending, backoff gates next drain.
    test('REQ-d00124-F+B: SendTransient appends attempt; next drain honors '
        'backoff and does not call send again', () async {
      final firstAttemptAt = DateTime.utc(2026, 4, 22, 10, 0, 5);

      await _enqueueRow(backend, 'fake', eventId: 'e1', sequenceNumber: 1);
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

        await _enqueueRow(backend, 'fake', eventId: 'e1', sequenceNumber: 1);
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

    // Verifies: REQ-d00124-G — every send call records an attempt, no
    // matter the outcome. Under strict-order drain (Phase 4.7), every
    // attempted row's final_status is either null (still pre-terminal),
    // sent, or wedged by the time drain returns. This test uses three
    // successful SendOk results so all three rows are visited without
    // triggering a halt; each send call must append exactly one
    // AttemptResult to its row.
    test('REQ-d00124-G: every send call appends an AttemptResult', () async {
      final rowIds = <String>{};
      var seq = 0;
      for (final id in ['e1', 'e2', 'e3']) {
        seq += 1;
        rowIds.add(
          await _enqueueRow(backend, 'fake', eventId: id, sequenceNumber: seq),
        );
      }
      final dest = FakeDestination(
        script: [const SendOk(), const SendOk(), const SendOk()],
      );

      await drain(
        dest,
        backend: backend,
        clock: () => DateTime.utc(2026, 4, 22, 11),
      );

      // Inspect the raw store: each row has exactly 1 attempt.
      final db = backend.debugDatabase();
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_fake',
      ).find(db);
      expect(raw, hasLength(3));
      for (final r in raw) {
        expect(rowIds.contains(r.value['entry_id']), isTrue);
        expect((r.value['attempts']! as List).length, 1);
      }
    });

    // Verifies: REQ-d00124-H — strict FIFO order. Drain attempts pending
    // rows in sequence_in_queue order. Three successful SendOks prove
    // the ordering: the payloads land in the destination in the same
    // order the rows were enqueued. (The halt-at-wedged facet of
    // REQ-d00124-H is covered by the dedicated halt-at-wedged tests
    // above.)
    test(
      'REQ-d00124-H: strict FIFO — drain attempts e1, e2, e3 in enqueue order',
      () async {
        var seq = 0;
        for (final id in ['e1', 'e2', 'e3']) {
          seq += 1;
          await _enqueueRow(backend, 'fake', eventId: id, sequenceNumber: seq);
        }
        final dest = FakeDestination(
          script: [const SendOk(), const SendOk(), const SendOk()],
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
        final d1RowId = await _enqueueRow(
          backend,
          'd1',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        await _enqueueRow(backend, 'd2', eventId: 'e2', sequenceNumber: 2);
        final d1 = FakeDestination(
          id: 'd1',
          script: [const SendPermanent(error: 'HTTP 400')],
        );
        final d2 = FakeDestination(id: 'd2', script: [const SendOk()]);

        await drain(d1, backend: backend, clock: () => clockTime);
        await drain(d2, backend: backend, clock: () => clockTime);

        expect(d1.sent, hasLength(1));
        expect(d2.sent, hasLength(1));
        // d1's row is wedged (SendPermanent); readFifoHead returns the
        // wedged row under the Phase-4.7 contract so UI surfaces can
        // observe the wedge via this one entry point.
        final d1Head = await backend.readFifoHead('d1');
        expect(d1Head, isNotNull);
        expect(d1Head!.entryId, d1RowId);
        expect(d1Head.finalStatus, FinalStatus.wedged);
        // d2's only row was sent (terminal-passable); no more rows.
        expect(await backend.readFifoHead('d2'), isNull);
      },
    );

    // Verifies: REQ-d00126-B — an injected SyncPolicy's maxAttempts is what
    // drain consults (not the defaults). Pre-seed attempts[] to one below a
    // smaller injected cap; next transient attempt should wedge the entry.
    test('REQ-d00126-B: drain honors injected policy.maxAttempts', () async {
      final e1RowId = await _enqueueRow(
        backend,
        'fake',
        eventId: 'e1',
        sequenceNumber: 1,
      );

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
        await backend.appendAttempt('fake', e1RowId, _attemptResultFactory(i));
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
      // With a cap of 3 and 3 total attempts, the entry is wedged.
      // Under the Phase-4.7 contract readFifoHead returns the wedged
      // row (it is a halt signal to drain, not a skip-past).
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.entryId, e1RowId);
      expect(head.finalStatus, FinalStatus.wedged);
    });

    // Verifies: REQ-d00126-B — a null policy falls back to SyncPolicy.defaults.
    // Sanity-check that omitting `policy` reads the defaults (20 attempts).
    test(
      'REQ-d00126-B: null policy falls back to SyncPolicy.defaults',
      () async {
        final e1RowId = await _enqueueRow(
          backend,
          'fake',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        // Pre-load 2 attempts: well below the default cap of 20, so a
        // transient should leave the entry pending (head still present).
        for (var i = 0; i < 2; i++) {
          await backend.appendAttempt(
            'fake',
            e1RowId,
            _attemptResultFactory(i),
          );
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
      await _enqueueRow(backend, 'fake', eventId: 'e1', sequenceNumber: 1);
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
