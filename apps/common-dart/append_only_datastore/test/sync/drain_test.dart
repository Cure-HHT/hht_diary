import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/sync/drain.dart';
import 'package:append_only_datastore/src/sync/sync_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';

/// Fixture — a fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

FifoEntry _mkFifoEntry({
  required String entryId,
  required String eventId,
  required DateTime enqueuedAt,
}) => FifoEntry(
  entryId: entryId,
  eventId: eventId,
  sequenceInQueue: 0, // backend-assigned; ignored on input.
  wirePayload: <String, Object?>{'event_id': eventId},
  wireFormat: 'fake-v1',
  transformVersion: 'fake-v1',
  enqueuedAt: enqueuedAt,
  attempts: const <AttemptResult>[],
  finalStatus: FinalStatus.pending,
  sentAt: null,
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
        await backend.transaction((txn) async {
          await backend.enqueueFifo(
            txn,
            'fake',
            _mkFifoEntry(
              entryId: 'e1',
              eventId: 'ev-1',
              enqueuedAt: DateTime.utc(2026, 4, 22, 10),
            ),
          );
        });
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
        await backend.transaction((txn) async {
          for (final id in ['e1', 'e2', 'e3']) {
            await backend.enqueueFifo(
              txn,
              'fake',
              _mkFifoEntry(
                entryId: id,
                eventId: 'ev-$id',
                enqueuedAt: DateTime.utc(2026, 4, 22, 10),
              ),
            );
          }
        });
        final dest = FakeDestination(
          script: [const SendOk(), const SendOk(), const SendOk()],
        );

        await drain(dest, backend: backend);
        expect(dest.sent, hasLength(3));
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Verifies: REQ-d00124-D — SendPermanent marks exhausted and wedges;
    // subsequent drain does not advance past the wedge.
    test('REQ-d00124-D: SendPermanent wedges the FIFO; subsequent drain is a '
        'no-op', () async {
      await backend.transaction((txn) async {
        await backend.enqueueFifo(
          txn,
          'fake',
          _mkFifoEntry(
            entryId: 'e1',
            eventId: 'ev-1',
            enqueuedAt: DateTime.utc(2026, 4, 22, 10),
          ),
        );
        await backend.enqueueFifo(
          txn,
          'fake',
          _mkFifoEntry(
            entryId: 'e2',
            eventId: 'ev-2',
            enqueuedAt: DateTime.utc(2026, 4, 22, 10),
          ),
        );
      });
      final dest = FakeDestination(
        script: [const SendPermanent(error: 'HTTP 400')],
      );

      await drain(dest, backend: backend);
      expect(dest.sent, hasLength(1));
      // FIFO wedged — readFifoHead returns null.
      expect(await backend.readFifoHead('fake'), isNull);

      // Re-draining does nothing: head stays null (wedged).
      await drain(dest, backend: backend);
      expect(dest.sent, hasLength(1));
    });

    // Verifies: REQ-d00124-F+B — SendTransient below maxAttempts: attempt
    // is appended, entry remains pending, backoff gates next drain.
    test('REQ-d00124-F+B: SendTransient appends attempt; next drain honors '
        'backoff and does not call send again', () async {
      final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
      final firstAttemptAt = DateTime.utc(2026, 4, 22, 10, 0, 5);

      await backend.transaction((txn) async {
        await backend.enqueueFifo(
          txn,
          'fake',
          _mkFifoEntry(entryId: 'e1', eventId: 'ev-1', enqueuedAt: enqueuedAt),
        );
      });
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
      expect(head.finalStatus, FinalStatus.pending);

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
        final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
        final firstAttemptAt = DateTime.utc(2026, 4, 22, 10, 0, 5);
        // SyncPolicy.backoffFor(1) is roughly 300s (60 * 5).
        final afterBackoff = firstAttemptAt.add(
          const Duration(seconds: 300 * 2),
        ); // 10 minutes — well past

        await backend.transaction((txn) async {
          await backend.enqueueFifo(
            txn,
            'fake',
            _mkFifoEntry(
              entryId: 'e1',
              eventId: 'ev-1',
              enqueuedAt: enqueuedAt,
            ),
          );
        });
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

    // Verifies: REQ-d00124-E — SendTransient AT maxAttempts → exhausted.
    // Simulated by pre-loading the attempts[] to maxAttempts-1 so the next
    // transient trips the cap.
    test(
      'REQ-d00124-E: SendTransient at maxAttempts marks entry exhausted',
      () async {
        final enqueuedAt = DateTime.utc(2026, 4, 22, 10);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(
            txn,
            'fake',
            _mkFifoEntry(
              entryId: 'e1',
              eventId: 'ev-1',
              enqueuedAt: enqueuedAt,
            ),
          );
        });
        // Pre-load attempts: we append maxAttempts-1 transient records so
        // the next drain-triggered transient is the one that wedges.
        const preloadAttempts = SyncPolicy.maxAttempts - 1;
        for (var i = 0; i < preloadAttempts; i++) {
          await backend.appendAttempt('fake', 'e1', _attemptResultFactory(i));
        }
        // Clock well past any backoff window.
        final longAfter = DateTime.utc(2027, 1, 1);
        final dest = FakeDestination(
          script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
        );

        await drain(dest, backend: backend, clock: () => longAfter);
        expect(dest.sent, hasLength(1));
        // Head is wedged: readFifoHead returns null.
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Verifies: REQ-d00124-G — every send call records an attempt, no matter
    // the outcome. Here: one SendOk, one SendPermanent, one SendTransient.
    test('REQ-d00124-G: every send call appends an AttemptResult', () async {
      final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
      await backend.transaction((txn) async {
        for (final id in ['e1', 'e2', 'e3']) {
          await backend.enqueueFifo(
            txn,
            'fake',
            _mkFifoEntry(
              entryId: id,
              eventId: 'ev-$id',
              enqueuedAt: enqueuedAt,
            ),
          );
        }
      });
      final dest = FakeDestination(
        script: [
          const SendOk(),
          const SendPermanent(error: 'HTTP 400'), // wedges at e2
        ],
      );

      await drain(
        dest,
        backend: backend,
        clock: () => DateTime.utc(2026, 4, 22, 11),
      );

      // Inspect the raw store: e1 has 1 attempt (ok), e2 has 1 attempt
      // (permanent), e3 has 0 attempts (never reached because FIFO wedged).
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
      expect(attemptsByEntry['e3'], 0);
    });

    // Verifies: REQ-d00124-H — strict FIFO order. A wedge on one entry
    // prevents any later entry from being attempted.
    test(
      'REQ-d00124-H: strict FIFO — wedge on e1 prevents attempting e2/e3',
      () async {
        final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
        await backend.transaction((txn) async {
          for (final id in ['e1', 'e2', 'e3']) {
            await backend.enqueueFifo(
              txn,
              'fake',
              _mkFifoEntry(
                entryId: id,
                eventId: 'ev-$id',
                enqueuedAt: enqueuedAt,
              ),
            );
          }
        });
        final dest = FakeDestination(
          script: [const SendPermanent(error: 'HTTP 400')],
        );

        await drain(
          dest,
          backend: backend,
          clock: () => DateTime.utc(2026, 4, 22, 11),
        );
        expect(dest.sent, hasLength(1));
        // e2 and e3 are NOT attempted.
      },
    );

    // Verifies: multi-destination independence — d1 wedged, d2 drains
    // normally. (Orchestrated via sync_cycle in Task 8; here we exercise
    // the drain-loop half of the claim by calling drain separately per
    // destination.)
    test(
      'multi-destination independence: wedge on d1 does not block d2',
      () async {
        final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
        await backend.transaction((txn) async {
          await backend.enqueueFifo(
            txn,
            'd1',
            _mkFifoEntry(
              entryId: 'e1',
              eventId: 'ev-1',
              enqueuedAt: enqueuedAt,
            ),
          );
          await backend.enqueueFifo(
            txn,
            'd2',
            _mkFifoEntry(
              entryId: 'e2',
              eventId: 'ev-2',
              enqueuedAt: enqueuedAt,
            ),
          );
        });
        final d1 = FakeDestination(
          id: 'd1',
          script: [const SendPermanent(error: 'HTTP 400')],
        );
        final d2 = FakeDestination(id: 'd2', script: [const SendOk()]);

        await drain(d1, backend: backend, clock: () => enqueuedAt);
        await drain(d2, backend: backend, clock: () => enqueuedAt);

        expect(d1.sent, hasLength(1));
        expect(d2.sent, hasLength(1));
        expect(await backend.readFifoHead('d1'), isNull); // wedged
        expect(await backend.readFifoHead('d2'), isNull); // sent (drained)
      },
    );

    // Verifies: drain treats a thrown exception from send() as SendTransient
    // and continues rather than crashing the caller.
    test('drain treats a thrown exception as SendTransient and records an '
        'attempt', () async {
      final enqueuedAt = DateTime.utc(2026, 4, 22, 10);
      await backend.transaction((txn) async {
        await backend.enqueueFifo(
          txn,
          'fake',
          _mkFifoEntry(entryId: 'e1', eventId: 'ev-1', enqueuedAt: enqueuedAt),
        );
      });
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
