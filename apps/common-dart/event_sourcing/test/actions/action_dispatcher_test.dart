// Uses flutter_test (not package:test) because EventStore depends on
// Sembast, which requires the Flutter test binding to run in this package.
// All other tests in event_sourcing/ that touch EventStore use flutter_test
// for the same reason (see event_store_test.dart, append_versioning_test.dart,
// etc.).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'fixtures/test_actions.dart';

ActionContext _ctx() => ActionContext(
  principal: const Principal.user(
    userId: 'u-1',
    roles: {'tester'},
    activeRole: 'tester',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.parse('2026-04-22T12:00:00Z'),
);

Future<EventStore> _bootstrapEventStore() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'dispatcher-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();

  // Register every reserved system entry type (security-context lifecycle,
  // destination-mutation audits, retention sweep, registry-initialized audit).
  for (final defn in kSystemEntryTypes) {
    registry.register(defn);
  }

  // Register the action_denial entry type that denial events require.
  // materialize: false — denials are audit records, not diary entries.
  registry.register(
    const EntryTypeDefinition(
      id: 'action_denial',
      registeredVersion: 1,
      name: 'Action denial',
      widgetId: 'action_denial_v1',
      widgetConfig: <String, Object?>{},
      materialize: false,
    ),
  );

  final securityContexts = SembastSecurityContextStore(backend: backend);

  return EventStore(
    backend: backend,
    entryTypes: registry,
    source: const Source(
      hopId: 'test-server',
      identifier: 'test-instance-1',
      softwareVersion: 'event_sourcing_test@0.0.0',
    ),
    securityContexts: securityContexts,
    materializers: const [],
  );
}

void main() {
  late ActionRegistry registry;
  late EventStore eventStore;
  late InMemoryIdempotencyStore idempotency;
  late ActionDispatcher dispatcher;

  setUp(() async {
    registry = ActionRegistry()..register(HelloAction());
    eventStore = await _bootstrapEventStore();
    idempotency = InMemoryIdempotencyStore();
    dispatcher = ActionDispatcher(
      registry: registry,
      authorization: const DenyAllAuthorizationPolicy.forTests(),
      events: eventStore,
      idempotency: idempotency,
    );
  });

  group('Stage 1 — lookup', () {
    test(
      'REQ-d00168-B: unknown action returns DispatchUnknownAction',
      () async {
        final r = await dispatcher.dispatch(
          'nope',
          const <String, Object?>{},
          _ctx(),
        );
        expect(r, isA<DispatchUnknownAction<Object?>>());
        expect((r as DispatchUnknownAction<Object?>).requestedName, 'nope');
      },
    );

    test(
      'REQ-d00168-B: unknown action emits unknown_action denial event',
      () async {
        await dispatcher.dispatch('nope', const <String, Object?>{}, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'unknown_action')
            .toList();
        expect(denials, hasLength(1));
        expect(denials.first.data['requested_name'], 'nope');
      },
    );
  });

  group('Stage 2 — invocation_id stamping', () {
    test(
      'REQ-d00168-C: every emitted event has action_invocation_id metadata',
      () async {
        await dispatcher.dispatch('nope', const <String, Object?>{}, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denial = allEvents.firstWhere(
          (e) => e.eventType == 'unknown_action',
        );
        expect(denial.metadata['action_invocation_id'], isNotNull);
        expect(denial.metadata['action_invocation_id'], isA<String>());
      },
    );

    test('REQ-d00168-C: invocation_id is unique per call', () async {
      await dispatcher.dispatch('nope', const <String, Object?>{}, _ctx());
      await dispatcher.dispatch('nope', const <String, Object?>{}, _ctx());
      final allEvents = await eventStore.backend.findAllEvents();
      final ids = allEvents
          .where((e) => e.eventType == 'unknown_action')
          .map((e) => e.metadata['action_invocation_id'] as String)
          .toSet();
      expect(ids, hasLength(2));
    });
  });
}
