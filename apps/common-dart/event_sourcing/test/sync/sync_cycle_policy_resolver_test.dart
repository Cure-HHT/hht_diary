import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/sync/sync_cycle.dart';
import 'package:event_sourcing_datastore/src/sync/sync_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';
import '../test_support/registry_with_audit.dart';

const Initiator _testInit = AutomationInitiator(service: 'test-bootstrap');

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<({SembastBackend backend, DestinationRegistry registry})>
_bootstrap() async {
  final backend = await _openBackend(
    'sync-cycle-resolver-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final deps = buildAuditedRegistryDeps(backend);
  final registry = DestinationRegistry(
    backend: backend,
    eventStore: deps.eventStore,
  );
  return (backend: backend, registry: registry);
}

Future<String> _enqueueOne(
  SembastBackend backend,
  String destId,
  String eventId, {
  int sequenceNumber = 1,
}) async {
  final entry = await enqueueSingle(
    backend,
    destId,
    eventId: eventId,
    sequenceNumber: sequenceNumber,
    wirePayload: <String, Object?>{'who': destId, 'which': eventId},
    wireFormat: 'fake-v1',
    transformVersion: 'fake-v1',
  );
  return entry.entryId;
}

void main() {
  group('REQ-d00126-B: policyResolver invocation', () {
    // Verifies: REQ-d00126-B — resolver invoked exactly once per call().
    test('resolver called exactly once per call()', () async {
      final ctx = await _bootstrap();
      var calls = 0;
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () {
          calls += 1;
          return SyncPolicy.defaults;
        },
      );
      await cycle();
      expect(calls, 1);
      await cycle();
      expect(calls, 2);
      await ctx.backend.close();
    });

    // Verifies: REQ-d00126-B — resolver value is reused across every
    // destination's drain in a single cycle. Asserted indirectly: the
    // resolver counter increments by exactly 1 per cycle regardless of
    // how many destinations are registered. That is the load-bearing
    // assertion (resolver invoked once, value reused for all drains).
    test(
      'resolver result is the same across all destinations within one cycle',
      () async {
        final ctx = await _bootstrap();

        // Register three destinations, each with its own scripted send.
        final destA = FakeDestination(id: 'a', script: [const SendOk()]);
        final destB = FakeDestination(id: 'b', script: [const SendOk()]);
        final destC = FakeDestination(id: 'c', script: [const SendOk()]);
        await ctx.registry.addDestination(destA, initiator: _testInit);
        await ctx.registry.addDestination(destB, initiator: _testInit);
        await ctx.registry.addDestination(destC, initiator: _testInit);

        // Each destination has work to drain.
        await _enqueueOne(ctx.backend, 'a', 'e1');
        await _enqueueOne(ctx.backend, 'b', 'e1');
        await _enqueueOne(ctx.backend, 'c', 'e1');

        var calls = 0;
        final cycle = SyncCycle(
          backend: ctx.backend,
          registry: ctx.registry,
          clock: () => DateTime.utc(2026, 4, 22, 10),
          policyResolver: () {
            calls += 1;
            return SyncPolicy.defaults;
          },
        );

        await cycle();

        // All three destinations were drained in this cycle...
        expect(destA.sent, hasLength(1));
        expect(destB.sent, hasLength(1));
        expect(destC.sent, hasLength(1));
        // ...but the resolver was invoked exactly once: the resolved
        // SyncPolicy was reused across every destination's drain call.
        expect(calls, 1);

        await ctx.backend.close();
      },
    );

    // Verifies: REQ-d00126-D — resolver returning null is acceptable;
    // drain() handles a null policy by falling back to SyncPolicy.defaults
    // (already covered by drain.dart's existing contract). Here we only
    // assert that cycle() does not throw when the resolver returns null.
    test('resolver returning null falls back to SyncPolicy.defaults', () async {
      final ctx = await _bootstrap();
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () => null,
      );
      // No exception expected.
      await cycle();
      await ctx.backend.close();
    });
  });

  group('REQ-d00126-D: mutual exclusivity + throws', () {
    // Verifies: REQ-d00126-D — supplying both policy and policyResolver
    // throws ArgumentError at construction time.
    test(
      'constructing with both policy and policyResolver throws ArgumentError',
      () async {
        final ctx = await _bootstrap();
        expect(
          () => SyncCycle(
            backend: ctx.backend,
            registry: ctx.registry,
            policy: SyncPolicy.defaults,
            policyResolver: () => SyncPolicy.defaults,
          ),
          throwsArgumentError,
        );
        await ctx.backend.close();
      },
    );

    // Verifies: REQ-d00126-D — when the resolver throws, the cycle
    // aborts (exception propagates), the reentrancy guard is cleared
    // via try/finally, and a subsequent trigger may invoke call() again.
    test('resolver throws → cycle aborts; reentrancy guard cleared', () async {
      final ctx = await _bootstrap();
      var first = true;
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () {
          if (first) {
            first = false;
            throw StateError('boom');
          }
          return SyncPolicy.defaults;
        },
      );
      await expectLater(cycle(), throwsStateError);
      // Guard was released by the finally block — this call must succeed.
      expect(cycle.inFlight, isFalse);
      await cycle();
      await ctx.backend.close();
    });
  });

  group('regression', () {
    // Verifies: REQ-d00126-B — SyncCycle constructed with neither policy
    // nor resolver still works (drain falls back to SyncPolicy.defaults).
    test(
      'SyncCycle with neither policy nor resolver still works (defaults)',
      () async {
        final ctx = await _bootstrap();
        final cycle = SyncCycle(backend: ctx.backend, registry: ctx.registry);
        await cycle();
        await ctx.backend.close();
      },
    );

    // Verifies: REQ-d00126-B — explicit policy: parameter path is
    // unchanged; no resolver supplied, the field is forwarded to drain.
    test(
      'SyncCycle with explicit policy: still uses it (today behavior)',
      () async {
        final ctx = await _bootstrap();
        final cycle = SyncCycle(
          backend: ctx.backend,
          registry: ctx.registry,
          policy: SyncPolicy.defaults,
        );
        await cycle();
        await ctx.backend.close();
      },
    );
  });
}
