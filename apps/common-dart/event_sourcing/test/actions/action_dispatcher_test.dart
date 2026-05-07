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
        BadExecuteAction,
        BadParseAction,
        BadValidateAction,
        HelloAction,
        MultiEventAction,
        OptionalKeyAction,
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

  // Register test-specific entry types. materialize: false — these are
  // audit records and test fixtures, not diary entries.
  registry
    ..register(
      const EntryTypeDefinition(
        id: 'action_denial',
        registeredVersion: 1,
        name: 'Action denial',
        widgetId: 'action_denial_v1',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    // greeting is emitted by HelloAction and MultiEventAction.
    ..register(
      const EntryTypeDefinition(
        id: 'greeting',
        registeredVersion: 1,
        name: 'Greeting',
        widgetId: 'greeting_v1',
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

  // Helper: dispatcher that always allows authorization.
  ActionDispatcher makeAllowDispatcher(
    ActionRegistry reg,
    EventStore es,
    InMemoryIdempotencyStore idm,
  ) => ActionDispatcher(
    registry: reg,
    authorization: const AlwaysAllowPolicy(),
    events: es,
    idempotency: idm,
  );

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
      'REQ-d00168-G: all-Allow falls through all stages and returns DispatchSuccess',
      () async {
        final allowDispatcher = ActionDispatcher(
          registry: registry,
          authorization: const AlwaysAllowPolicy(),
          events: eventStore,
          idempotency: idempotency,
        );
        final result = await allowDispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchSuccess<Object?>>());
      },
    );
  });

  group('Stage 7 — execute', () {
    late ActionDispatcher allowDispatcher;

    setUp(() {
      registry.register(BadExecuteAction());
      allowDispatcher = makeAllowDispatcher(registry, eventStore, idempotency);
    });

    test(
      'REQ-d00168-H: execute throw returns DispatchExecutionFailed',
      () async {
        final result = await allowDispatcher.dispatch(
          'bad_execute',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchExecutionFailed<Object?>>());
      },
    );

    test(
      'REQ-d00168-H: execute throw emits execution_failed denial event',
      () async {
        await allowDispatcher.dispatch('bad_execute', const <String, Object?>{
          'who': 'world',
        }, _ctx());
        final allEvents = await eventStore.backend.findAllEvents();
        final denials = allEvents
            .where((e) => e.eventType == 'execution_failed')
            .toList();
        expect(denials, hasLength(1));
        expect(denials.first.data['action_name'], 'bad_execute');
      },
    );

    test(
      'REQ-d00168-H: execute success persists events and returns DispatchSuccess',
      () async {
        // Stage 8 persists the event; Stage 9-10 complete and return success.
        final result = await allowDispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchSuccess<Object?>>());

        final allEvents = await eventStore.backend.findAllEvents();
        final greetings = allEvents
            .where((e) => e.eventType == 'hello.said')
            .toList();
        expect(greetings, hasLength(1));
        expect(greetings.first.data['who'], 'world');
      },
    );
  });

  group('Stage 8 — atomic persist', () {
    late ActionDispatcher allowDispatcher;

    setUp(() {
      registry.register(MultiEventAction());
      allowDispatcher = makeAllowDispatcher(registry, eventStore, idempotency);
    });

    test(
      'REQ-d00168-I: each emitted event has action_invocation_id and action_name in metadata',
      () async {
        final result = await allowDispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'stamp-test'},
          _ctx(),
        );
        expect(result, isA<DispatchSuccess<Object?>>());

        final allEvents = await eventStore.backend.findAllEvents();
        final greetings = allEvents
            .where((e) => e.eventType == 'hello.said')
            .toList();
        expect(greetings, hasLength(1));

        final meta = greetings.first.metadata;
        expect(meta['action_invocation_id'], isA<String>());
        expect(
          meta['action_invocation_id'] as String,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(meta['action_name'], 'hello');
      },
    );

    test(
      'REQ-d00168-I: multi-event execute persists all atomically with same action_invocation_id',
      () async {
        final result = await allowDispatcher.dispatch(
          'multi_event',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchSuccess<Object?>>());

        final allEvents = await eventStore.backend.findAllEvents();
        final greetings = allEvents
            .where((e) => e.eventType == 'hello.said')
            .toList();
        expect(greetings, hasLength(3));

        // All three events must carry the same action_invocation_id.
        final invIds = greetings
            .map((e) => e.metadata['action_invocation_id'] as String)
            .toSet();
        expect(invIds, hasLength(1));

        // All three must have action_name stamped.
        for (final e in greetings) {
          expect(e.metadata['action_name'], 'multi_event');
        }
      },
    );

    // TODO(CUR-1192): Add fault-injection test for Stage 8 rollback-on-persist-failure.
    //   This requires a seam in StorageBackend to inject mid-transaction failures.
    //   Without such a seam the rollback semantic is verified only by code inspection
    //   and the Sembast transaction contract. Track as follow-up.
  });

  group('Stages 9+10 — record idempotency + return success', () {
    late ActionDispatcher allowDispatcher;

    setUp(() {
      registry
        ..register(OptionalKeyAction())
        ..register(RequiredKeyAction())
        ..register(MultiEventAction());
      allowDispatcher = makeAllowDispatcher(registry, eventStore, idempotency);
    });

    test(
      'REQ-d00168-K: success path returns DispatchSuccess with result and emittedEventIds',
      () async {
        final result = await allowDispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'world'},
          _ctx(),
        );
        expect(result, isA<DispatchSuccess<Object?>>());
        final success = result as DispatchSuccess<Object?>;
        expect(success.result, equals('Hello, world'));
        // HelloAction emits exactly one event.
        expect(success.emittedEventIds, hasLength(1));
      },
    );

    test(
      'REQ-d00170-D: Idempotency.optional + key records entry; lookup returns entry with matching emittedEventIds',
      () async {
        final ctx = _ctx();
        final result = await allowDispatcher.dispatch(
          'optional_key',
          const <String, Object?>{'who': 'optional-world'},
          ctx,
          idempotencyKey: 'k1',
        );
        expect(result, isA<DispatchSuccess<Object?>>());
        final success = result as DispatchSuccess<Object?>;

        // Pass now = requestStartedAt so the entry is not expired at lookup time.
        final entry = await idempotency.lookup(
          'optional_key',
          'u-1',
          'k1',
          now: ctx.requestStartedAt,
        );
        expect(entry, isNotNull);
        expect(entry!.emittedEventIds, equals(success.emittedEventIds));
      },
    );

    test(
      'REQ-d00170-D: Idempotency.required + key records entry; lookup returns entry with matching emittedEventIds',
      () async {
        final ctx = _ctx();
        final result = await allowDispatcher.dispatch(
          'requires_key',
          const <String, Object?>{'who': 'required-world'},
          ctx,
          idempotencyKey: 'k2',
        );
        expect(result, isA<DispatchSuccess<Object?>>());
        final success = result as DispatchSuccess<Object?>;

        // Pass now = requestStartedAt so the entry is not expired at lookup time.
        final entry = await idempotency.lookup(
          'requires_key',
          'u-1',
          'k2',
          now: ctx.requestStartedAt,
        );
        expect(entry, isNotNull);
        expect(entry!.emittedEventIds, equals(success.emittedEventIds));
      },
    );

    test(
      'REQ-d00168-J: Idempotency.none + key supplied → no idempotency entry recorded',
      () async {
        final result = await allowDispatcher.dispatch(
          'hello',
          const <String, Object?>{'who': 'no-record'},
          _ctx(),
          idempotencyKey: 'ignored-key',
        );
        expect(result, isA<DispatchSuccess<Object?>>());

        // HelloAction has Idempotency.none; key must be silently ignored —
        // no entry written to the store.
        final entry = await idempotency.lookup('hello', 'u-1', 'ignored-key');
        expect(entry, isNull);
      },
    );
  });
}
