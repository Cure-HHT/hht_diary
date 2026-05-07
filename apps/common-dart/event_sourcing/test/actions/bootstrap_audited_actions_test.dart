// Uses flutter_test (not package:test) because EventStore depends on
// Sembast, which requires the Flutter test binding to run in this package.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/test_actions.dart' show HelloAction;
import 'test_support/event_store_helper.dart' show bootstrapTestEventStore;

void main() {
  group('bootstrapAuditedActions', () {
    test(
      'REQ-d00167-D: returns a ready ActionDispatcher with all dependencies wired',
      () async {
        final eventStore = await bootstrapTestEventStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const DenyAllAuthorizationPolicy.forTests(),
          idempotency: InMemoryIdempotencyStore(),
          actions: <Action<Object?, Object?>>[HelloAction()],
        );

        // Smoke test: dispatcher handles an unknown action name correctly.
        final result = await dispatcher.dispatch(
          'nope',
          const <String, Object?>{},
          ActionContext(
            principal: const Principal.user(
              userId: 'u',
              roles: {'r'},
              activeRole: 'r',
            ),
            security: const SecurityDetails(),
            requestStartedAt: DateTime.now(),
          ),
        );
        expect(result, isA<DispatchUnknownAction<Object?>>());
      },
    );

    test(
      'REQ-d00167-A: collision in supplied actions throws ArgumentError',
      () async {
        final eventStore = await bootstrapTestEventStore();
        expect(
          () => bootstrapAuditedActions(
            events: eventStore,
            authorization: const DenyAllAuthorizationPolicy.forTests(),
            idempotency: InMemoryIdempotencyStore(),
            actions: <Action<Object?, Object?>>[
              HelloAction(),
              HelloAction(), // duplicate name 'hello'
            ],
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
