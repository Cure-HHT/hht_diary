// Uses flutter_test (not package:test) because EventStore depends on
// Sembast, which requires the Flutter test binding to run in this package.
// All other tests in event_sourcing/ that touch EventStore use flutter_test
// for the same reason (see event_store_test.dart, append_versioning_test.dart,
// etc.).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'fixtures/test_actions.dart'
    show
        AlwaysAllowPolicy,
        BadParseAction,
        BadValidateAction,
        HelloAction,
        RequiredKeyAction,
        TwoPermissionAction;

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

  group('Stage 3 — parse', () {
    setUp(() {
      registry.register(BadParseAction());
    });

    test(
      'REQ-d00168-D: parseInput failure returns DispatchParseDenied',
      () async {
        final result = await dispatcher.dispatch(
          'bad_parse',
          const <String, Object?>{},
          _ctx(),
        );
        expect(result, isA<DispatchParseDenied<Object?>>());
      },
    );

    test('REQ-d00168-D: parseInput failure emits parse_denied event', () async {
      await dispatcher.dispatch('bad_parse', const <String, Object?>{}, _ctx());
      final allEvents = await eventStore.backend.findAllEvents();
      final denials = allEvents
          .where((e) => e.eventType == 'parse_denied')
          .toList();
      expect(denials, hasLength(1));
      expect(denials.first.data['action_name'], 'bad_parse');
    });
  });

  group('Stage 4 — idempotency check', () {
    setUp(() {
      registry.register(RequiredKeyAction());
    });

    test(
      'REQ-d00170-B: idempotency.required without key returns DispatchParseDenied',
      () async {
        final result = await dispatcher.dispatch(
          'requires_key',
          const <String, Object?>{},
          _ctx(),
          // idempotencyKey intentionally omitted
        );
        expect(result, isA<DispatchParseDenied<Object?>>());
        final error = (result as DispatchParseDenied<Object?>).error;
        expect(error.toString(), contains('idempotency'));
      },
    );

    test(
      'REQ-d00170-B: missing required key emits parse_denied before parseInput runs',
      () async {
        await dispatcher.dispatch(
          'requires_key',
          const <String, Object?>{},
          _ctx(),
        );
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'parse_denied')
            .toList();
        expect(denials, hasLength(1));
        // RequiredKeyAction inherits HelloAction.parseInput which throws a
        // TypeError when 'who' is missing. MissingIdempotencyKeyError must
        // fire first, so the error_class must be MissingIdempotencyKeyError.
        expect(denials.first.data['error_class'], 'MissingIdempotencyKeyError');
      },
    );

    test(
      'REQ-d00170-C: idempotency hit short-circuits and returns DispatchIdempotencyHit',
      () async {
        // Pre-populate the idempotency store for (requires_key, u-1, k1).
        await idempotency.record(
          actionName: 'requires_key',
          principalId: 'u-1',
          key: 'k1',
          resultJson: const <String, dynamic>{'cached': true},
          emittedEventIds: const ['prior-event-id-1'],
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final eventCountBefore =
            (await eventStore.backend.findAllEvents()).length;

        final result = await dispatcher.dispatch(
          'requires_key',
          const <String, Object?>{'who': 'tester'},
          _ctx(),
          idempotencyKey: 'k1',
        );

        expect(result, isA<DispatchIdempotencyHit<Object?>>());
        final hit = result as DispatchIdempotencyHit<Object?>;
        expect(hit.priorEmittedEventIds, contains('prior-event-id-1'));

        // No new events must have been appended.
        final eventCountAfter =
            (await eventStore.backend.findAllEvents()).length;
        expect(eventCountAfter, equals(eventCountBefore));
      },
    );

    test(
      'REQ-d00170-A: idempotency.none ignores supplied key — no store record created',
      () async {
        // HelloAction has Idempotency.none. Dispatch with a key; Stage 6
        // (authorize) now runs and DenyAllAuthorizationPolicy denies it —
        // the important thing is no idempotency record is created.
        await dispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'world'},
          _ctx(),
          idempotencyKey: 'should-be-ignored',
        );

        final entry = await idempotency.lookup(
          'hello',
          'u-1',
          'should-be-ignored',
        );
        expect(entry, isNull);
      },
    );
  });

  group('Stage 5 — validate', () {
    setUp(() {
      registry.register(BadValidateAction());
    });

    test(
      'REQ-d00168-F: validate failure returns DispatchValidationDenied',
      () async {
        final result = await dispatcher.dispatch(
          'bad_validate',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchValidationDenied<Object?>>());
      },
    );

    test(
      'REQ-d00168-F: validate failure emits validation_denied event',
      () async {
        await dispatcher.dispatch('bad_validate', const <String, Object?>{
          'who': 'world',
        }, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'validation_denied')
            .toList();
        expect(denials, hasLength(1));
        expect(
          denials.first.data['error_class'],
          StateError('').runtimeType.toString(),
        );
      },
    );
  });

  group('Stage 6 — authorize', () {
    test(
      'REQ-d00168-G: authz denial returns DispatchAuthorizationDenied',
      () async {
        // Default dispatcher uses DenyAllAuthorizationPolicy.forTests().
        // HelloAction declares permission test.hello which will be denied.
        final result = await dispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchAuthorizationDenied<Object?>>());
        final denied = result as DispatchAuthorizationDenied<Object?>;
        expect(denied.permission.name, 'test.hello');
      },
    );

    test(
      'REQ-d00168-G: authz denial emits authorization_denied event',
      () async {
        await dispatcher.dispatch('hello', const <String, Object?>{
          'who': 'world',
        }, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'authorization_denied')
            .toList();
        expect(denials, hasLength(1));
        expect(denials.first.data['permission_denied'], 'test.hello');
        // DenyAllAuthorizationPolicy always denies with DenyReason.notGranted.
        expect(denials.first.data['deny_reason'], 'notGranted');
      },
    );

    test(
      'REQ-d00168-G: first denial short-circuits — only one authorization_denied event emitted',
      () async {
        registry.register(TwoPermissionAction());
        await dispatcher.dispatch('two_perms', const <String, Object?>{
          'who': 'world',
        }, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'authorization_denied')
            .toList();
        expect(denials, hasLength(1));
      },
    );

    test(
      'REQ-d00168-G: all-Allow falls through to Stage 7 UnimplementedError',
      () async {
        final allowDispatcher = ActionDispatcher(
          registry: registry,
          authorization: const AlwaysAllowPolicy(),
          events: eventStore,
          idempotency: idempotency,
        );
        expect(
          () => allowDispatcher.dispatch('hello', const <String, Object?>{
            'who': 'world',
          }, _ctx()),
          throwsA(isA<UnimplementedError>()),
        );
      },
    );
  });
}
