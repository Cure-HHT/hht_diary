import 'dart:async';

import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/sync/sync_cycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

FifoEntry _entry(String destId, String entryId) => FifoEntry(
  entryId: entryId,
  eventId: 'ev-$destId-$entryId',
  sequenceInQueue: 0,
  wirePayload: <String, Object?>{'who': destId, 'which': entryId},
  wireFormat: 'fake-v1',
  transformVersion: 'fake-v1',
  enqueuedAt: DateTime.utc(2026, 4, 22, 10),
  attempts: const <AttemptResult>[],
  finalStatus: FinalStatus.pending,
  sentAt: null,
);

void main() {
  group('SyncCycle', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('sync-cycle-$dbCounter.db');
      DestinationRegistry.instance.reset();
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

        DestinationRegistry.instance
          ..register(slow)
          ..register(fast);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'slow', _entry('slow', 'e1'));
          await backend.enqueueFifo(txn, 'fast', _entry('fast', 'e1'));
        });

        final sync = SyncCycle(
          backend: backend,
          registry: DestinationRegistry.instance,
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
        DestinationRegistry.instance.register(dest);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'fake', _entry('fake', 'e1'));
        });

        final sync = _OrderRecordingSyncCycle(
          backend: backend,
          registry: DestinationRegistry.instance,
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
        DestinationRegistry.instance.register(dest);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'fake', _entry('fake', 'e1'));
        });

        final sync = SyncCycle(
          backend: backend,
          registry: DestinationRegistry.instance,
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
        DestinationRegistry.instance.register(dest);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'fake', _entry('fake', 'e1'));
        });

        final sync = SyncCycle(
          backend: backend,
          registry: DestinationRegistry.instance,
          clock: () => DateTime.utc(2026, 4, 22, 10),
        );
        await sync.call();
        expect(dest.sent, hasLength(1));

        // Enqueue a second entry, then cycle again.
        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'fake', _entry('fake', 'e2'));
        });
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
        DestinationRegistry.instance
          ..register(boomed)
          ..register(healthy);

        await backend.transaction((txn) async {
          await backend.enqueueFifo(txn, 'boomed', _entry('boomed', 'e1'));
          await backend.enqueueFifo(txn, 'healthy', _entry('healthy', 'e1'));
        });

        final sync = SyncCycle(
          backend: backend,
          registry: DestinationRegistry.instance,
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

    // Defensive: when no destinations are registered, the cycle is a
    // near-no-op (just invokes portalInboundPoll).
    test('empty registry: cycle runs portalInboundPoll and exits', () async {
      final sync = SyncCycle(
        backend: backend,
        registry: DestinationRegistry.instance,
      );
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
