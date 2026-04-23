import 'dart:async';

import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/sync/sync_cycle.dart';
import 'package:append_only_datastore/src/sync/sync_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Enqueue a single-event row through Phase-4.3 Task-6's batch-aware
/// `enqueueFifo`. `entry_id` is derived from `eventId` under the new
/// semantics, so we pass `eventId: entryId` to keep the row identity
/// stable across the call sites below.
Future<void> _enqueueOne(
  SembastBackend backend,
  String destId,
  String entryId, {
  int sequenceNumber = 1,
}) => enqueueSingle(
  backend,
  destId,
  eventId: entryId,
  sequenceNumber: sequenceNumber,
  wirePayload: <String, Object?>{'who': destId, 'which': entryId},
  wireFormat: 'fake-v1',
  transformVersion: 'fake-v1',
);

void main() {
  group('SyncCycle', () {
    late SembastBackend backend;
    late DestinationRegistry registry;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('sync-cycle-$dbCounter.db');
      registry = DestinationRegistry(backend: backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00125-A — two destinations' drains run concurrently
    // under Future.wait. Simulate via one blocking destination and one
    // fast one: the fast drain completes without being blocked on the
    // slow one.
    test(
      'REQ-d00125-A: drains run concurrently across registered destinations',
      () async {
        final gate = Completer<void>();

        final slow = FakeDestination(
          id: 'slow',
          script: [const SendOk()],
          blockBeforeSend: () => gate.future,
        );
        final fast = FakeDestination(id: 'fast', script: [const SendOk()]);

        await registry.addDestination(slow);
        await registry.addDestination(fast);

        await _enqueueOne(backend, 'slow', 'e1');
        await _enqueueOne(backend, 'fast', 'e1');

        final sync = SyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
        );
        final cycleFuture = sync.call();

        // Give the scheduler a few microtasks so the fast drain completes.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(fast.sent, hasLength(1));
        // Slow destination received the payload but is still blocked.
        expect(slow.sent, hasLength(1));
        expect(slow.returned, isEmpty); // not yet completed

        // Release the slow destination and let sync cycle finish.
        gate.complete();
        await cycleFuture;
        expect(slow.returned, hasLength(1));
      },
    );

    // Verifies: REQ-d00125-B — portalInboundPoll is called after drains.
    // Observed via a subclass that records the order of events.
    test(
      'REQ-d00125-B: portalInboundPoll runs after outbound drains complete',
      () async {
        final order = <String>[];
        final dest = _RecordingDestination(order, id: 'fake');
        await registry.addDestination(dest);

        await _enqueueOne(backend, 'fake', 'e1');

        final sync = _OrderRecordingSyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
          order: order,
        );
        await sync.call();
        expect(order, ['drain-send', 'inbound-poll']);
      },
    );

    // Verifies: REQ-d00125-C — reentrancy guard. While the first cycle is
    // in flight (a destination is awaiting a completer), a second call
    // returns immediately with no new side effects.
    test(
      'REQ-d00125-C: reentrant call returns immediately without new drain',
      () async {
        final gate = Completer<void>();
        final dest = FakeDestination(
          id: 'fake',
          script: [const SendOk()],
          blockBeforeSend: () => gate.future,
        );
        await registry.addDestination(dest);

        await _enqueueOne(backend, 'fake', 'e1');

        final sync = SyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
        );
        final first = sync.call();
        // Give the first call enough microtasks to reach `send` and block
        // on the gate.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sync.inFlight, isTrue);
        expect(dest.sent, hasLength(1));

        // Reentrant call — returns immediately, no new drain work.
        await sync.call();
        expect(dest.sent, hasLength(1));

        gate.complete();
        await first;
        expect(sync.inFlight, isFalse);
      },
    );

    // Verifies: REQ-d00125-C — after the in-flight cycle completes, a
    // subsequent call does drain normally (the guard auto-releases).
    test(
      'REQ-d00125-C: after first cycle completes, a new call drains again',
      () async {
        final dest = FakeDestination(
          id: 'fake',
          script: [const SendOk(), const SendOk()],
        );
        await registry.addDestination(dest);

        await _enqueueOne(backend, 'fake', 'e1');

        final sync = SyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
        );
        await sync.call();
        expect(dest.sent, hasLength(1));

        // Enqueue a second entry, then cycle again.
        await _enqueueOne(backend, 'fake', 'e2', sequenceNumber: 2);
        await sync.call();
        expect(dest.sent, hasLength(2));
      },
    );

    // Verifies: REQ-d00125-A — an exception from one drain does not
    // cancel another drain. Exercised via a destination whose send
    // throws, and another that completes normally.
    test(
      'REQ-d00125-A: exception in one destination does not cancel another',
      () async {
        final boomed = _AlwaysThrows(id: 'boomed');
        final healthy = FakeDestination(
          id: 'healthy',
          script: [const SendOk()],
        );
        await registry.addDestination(boomed);
        await registry.addDestination(healthy);

        await _enqueueOne(backend, 'boomed', 'e1');
        await _enqueueOne(backend, 'healthy', 'e1');

        final sync = SyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
        );
        await sync.call();

        // Both got a send call.
        expect(boomed.sent, hasLength(1));
        expect(healthy.sent, hasLength(1));
        // The healthy destination's head is marked sent.
        expect(await backend.readFifoHead('healthy'), isNull);
      },
    );

    // Verifies: REQ-d00126-B — SyncCycle propagates an injected SyncPolicy
    // through to the drain-loop's maxAttempts check. With a cap of 2 and
    // one pre-existing transient attempt, the next transient attempt made
    // by the cycle should wedge the entry.
    test(
      'REQ-d00126-B: SyncCycle propagates injected policy to drain',
      () async {
        final dest = FakeDestination(
          id: 'fake',
          script: [const SendTransient(error: 'HTTP 503', httpStatus: 503)],
        );
        await registry.addDestination(dest);

        await _enqueueOne(backend, 'fake', 'e1');
        // Pre-load one transient attempt so the next attempt trips the cap.
        await backend.appendAttempt(
          'fake',
          'e1',
          AttemptResult(
            attemptedAt: DateTime.utc(2026, 1, 1),
            outcome: 'transient',
            errorMessage: 'pre-seeded',
            httpStatus: 503,
          ),
        );

        const tinyPolicy = SyncPolicy(
          initialBackoff: Duration(seconds: 60),
          backoffMultiplier: 5.0,
          maxBackoff: Duration(hours: 2),
          jitterFraction: 0.1,
          maxAttempts: 2,
          periodicInterval: Duration(minutes: 15),
        );

        final sync = SyncCycle(
          backend: backend,
          registry: registry,
          clock: () => DateTime.utc(2027, 1, 1),
          policy: tinyPolicy,
        );
        await sync.call();
        expect(dest.sent, hasLength(1));
        // Entry should be wedged (exhausted) — head returns null.
        expect(await backend.readFifoHead('fake'), isNull);
      },
    );

    // Defensive: when no destinations are registered, the cycle is a
    // near-no-op (just invokes portalInboundPoll).
    test('empty registry: cycle runs portalInboundPoll and exits', () async {
      final sync = SyncCycle(backend: backend, registry: registry);
      await sync.call(); // no throw, no error
    });
  });
}

/// Destination that records "drain-send" in `order` each time `send` is
/// invoked. Used to verify outbound drains run before the inbound poll.
class _RecordingDestination extends FakeDestination {
  _RecordingDestination(this._order, {super.id = 'fake'})
    : super(script: [const SendOk()]);

  final List<String> _order;

  @override
  Future<SendResult> send(WirePayload payload) async {
    _order.add('drain-send');
    return super.send(payload);
  }
}

/// Subclass that records "inbound-poll" in [order] inside
/// [portalInboundPoll], so the ordering test can assert outbound-drain
/// happens before inbound-poll.
class _OrderRecordingSyncCycle extends SyncCycle {
  _OrderRecordingSyncCycle({
    required super.backend,
    required super.registry,
    required this.order,
    super.clock,
  });

  final List<String> order;

  @override
  Future<void> portalInboundPoll() async {
    order.add('inbound-poll');
    return super.portalInboundPoll();
  }
}

/// Destination whose send always throws. Used for the "exception in one
/// destination doesn't cancel another" test.
class _AlwaysThrows extends FakeDestination {
  _AlwaysThrows({required super.id}) : super(script: const []);

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    throw StateError('boom from $id');
  }
}
