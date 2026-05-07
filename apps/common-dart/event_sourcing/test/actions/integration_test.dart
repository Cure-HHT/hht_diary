// End-to-end integration test for the full 10-stage dispatcher pipeline.
//
// Uses flutter_test (not package:test) because EventStore depends on
// Sembast, which requires the Flutter test binding to run in this package.
//
// Exercises a realistic InviteUserAction through six scenarios:
//   1. Happy path — success, event metadata stamping, idempotency record.
//   2. Idempotency replay — second dispatch with same key short-circuits.
//   3. Parse failure — missing email field → parse_denied event.
//   4. Validate failure — email without '@' → validation_denied event.
//   5. Authorize failure — DenyAll policy → authorization_denied event.
//   6. Idempotency required without key → parse_denied (MissingIdempotencyKeyError).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/test_actions.dart' show AlwaysAllowPolicy;
import 'test_support/event_store_helper.dart' show bootstrapTestEventStore;

// ---------------------------------------------------------------------------
// Minimal concrete Action under test
// ---------------------------------------------------------------------------

/// Invites a user by email. The realistic action the portal will dispatch.
class InviteUserAction extends Action<Map<String, Object?>, String> {
  @override
  String get name => 'invite_user';

  @override
  String get description => 'Invite a user by email address.';

  @override
  Set<Permission> get permissions => {
    const Permission('user.invite', scope: ScopeClass.global),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  /// Extracts `email` from [raw]. Throws [FormatException] if missing.
  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) {
    final email = raw['email'];
    if (email == null) {
      throw const FormatException('Missing required field: email');
    }
    return <String, Object?>{'email': email as String};
  }

  /// Validates that [input] contains a plausible email address (contains `@`).
  /// Throws [ArgumentError] if the check fails.
  @override
  void validate(Map<String, Object?> input) {
    final email = input['email'] as String;
    if (!email.contains('@')) {
      throw ArgumentError.value(email, 'email', 'must contain "@"');
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    final email = input['email'] as String;
    // Deterministic fake user-id derived from the email for test assertions.
    final userId = 'user-${email.hashCode.abs()}';
    return ExecutionResult<String>(
      result: userId,
      events: <EventDraft>[
        EventDraft(
          aggregateId: userId,
          aggregateType: 'user',
          entryType: 'user_invitation',
          eventType: 'invited',
          data: <String, dynamic>{'email': email},
        ),
      ],
    );
  }
}

/// Action with `Idempotency.required`; otherwise identical to InviteUserAction.
class RequiredKeyInviteAction extends InviteUserAction {
  @override
  String get name => 'required_key_invite';

  @override
  Idempotency get idempotency => Idempotency.required;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ActionContext _ctx() => ActionContext(
  principal: const Principal.user(
    userId: 'u-admin',
    roles: {'admin'},
    activeRole: 'admin',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.parse('2026-05-07T10:00:00Z'),
);

// ---------------------------------------------------------------------------
// Bootstrap helper that adds the entry types our InviteUserAction needs.
// ---------------------------------------------------------------------------

Future<EventStore> _bootstrapStore() async {
  final store = await bootstrapTestEventStore();
  // Register 'user_invitation' entry type — InviteUserAction emits this.
  store.entryTypes.register(
    const EntryTypeDefinition(
      id: 'user_invitation',
      registeredVersion: 1,
      name: 'User invitation',
      widgetId: 'user_invitation_v1',
      widgetConfig: <String, Object?>{},
      materialize: false,
    ),
  );
  return store;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Dispatcher pipeline — end-to-end integration', () {
    // ------------------------------------------------------------------
    // 1. Happy path
    // ------------------------------------------------------------------
    test(
      'E2E-1: success path — DispatchSuccess, event stamped, idempotency recorded',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const AlwaysAllowPolicy(),
          idempotency: idempotency,
          actions: [InviteUserAction()],
        );

        final ctx = _ctx();
        final result = await dispatcher.dispatch(
          'invite_user',
          const <String, Object?>{'email': 'alice@example.com'},
          ctx,
          idempotencyKey: 'k1',
        );

        // Result shape
        expect(result, isA<DispatchSuccess<Object?>>());
        final success = result as DispatchSuccess<Object?>;
        // The action returns a non-empty userId string.
        expect(success.result, isA<String>());
        expect((success.result as String).startsWith('user-'), isTrue);
        // Exactly one event was emitted.
        expect(success.emittedEventIds, hasLength(1));

        // Find the persisted 'invited' event in the store.
        final allEvents = await eventStore.backend.findAllEvents();
        final invited = allEvents
            .where((e) => e.eventType == 'invited')
            .toList();
        expect(invited, hasLength(1));

        // Metadata must carry action_invocation_id and action_name.
        final meta = invited.first.metadata;
        expect(meta['action_invocation_id'], isA<String>());
        expect(meta['action_name'], 'invite_user');

        // Idempotency entry must be recorded.
        final entry = await idempotency.lookup(
          'invite_user',
          'u-admin',
          'k1',
          now: ctx.requestStartedAt,
        );
        expect(entry, isNotNull);
        expect(entry!.emittedEventIds, equals(success.emittedEventIds));
      },
    );

    // ------------------------------------------------------------------
    // 2. Idempotency replay
    // ------------------------------------------------------------------
    test(
      'E2E-2: idempotency replay — DispatchIdempotencyHit, no new events',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const AlwaysAllowPolicy(),
          idempotency: idempotency,
          actions: [InviteUserAction()],
        );

        final ctx = _ctx();
        const input = <String, Object?>{'email': 'alice@example.com'};

        // First dispatch — succeeds.
        final first = await dispatcher.dispatch(
          'invite_user',
          input,
          ctx,
          idempotencyKey: 'k1',
        );
        expect(first, isA<DispatchSuccess<Object?>>());

        final eventCountAfterFirst =
            (await eventStore.backend.findAllEvents()).length;

        // Second dispatch with the same key — must short-circuit.
        final second = await dispatcher.dispatch(
          'invite_user',
          input,
          ctx,
          idempotencyKey: 'k1',
        );

        expect(second, isA<DispatchIdempotencyHit<Object?>>());
        final hit = second as DispatchIdempotencyHit<Object?>;
        expect(
          hit.priorEmittedEventIds,
          equals((first as DispatchSuccess<Object?>).emittedEventIds),
        );

        // No new events must have been appended.
        final eventCountAfterSecond =
            (await eventStore.backend.findAllEvents()).length;
        expect(eventCountAfterSecond, equals(eventCountAfterFirst));
      },
    );

    // ------------------------------------------------------------------
    // 3. Parse failure
    // ------------------------------------------------------------------
    test(
      'E2E-3: parse failure — DispatchParseDenied, parse_denied event recorded',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const AlwaysAllowPolicy(),
          idempotency: idempotency,
          actions: [InviteUserAction()],
        );

        // Missing 'email' field → FormatException in parseInput.
        final result = await dispatcher.dispatch(
          'invite_user',
          const <String, Object?>{},
          _ctx(),
        );

        expect(result, isA<DispatchParseDenied<Object?>>());

        final allEvents = await eventStore.backend.findAllEvents();
        final parseDenied = allEvents
            .where((e) => e.eventType == 'parse_denied')
            .toList();
        expect(parseDenied, hasLength(1));
        expect(parseDenied.first.data['action_name'], 'invite_user');
        // Sanitized error message must be present (a non-empty string).
        expect(
          parseDenied.first.data['error_message_sanitized'],
          isA<String>(),
        );
      },
    );

    // ------------------------------------------------------------------
    // 4. Validate failure
    // ------------------------------------------------------------------
    test(
      'E2E-4: validate failure — DispatchValidationDenied, validation_denied event recorded',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const AlwaysAllowPolicy(),
          idempotency: idempotency,
          actions: [InviteUserAction()],
        );

        // 'not-an-email' passes parseInput but fails validate (no '@').
        final result = await dispatcher.dispatch(
          'invite_user',
          const <String, Object?>{'email': 'not-an-email'},
          _ctx(),
        );

        expect(result, isA<DispatchValidationDenied<Object?>>());

        final allEvents = await eventStore.backend.findAllEvents();
        final validationDenied = allEvents
            .where((e) => e.eventType == 'validation_denied')
            .toList();
        expect(validationDenied, hasLength(1));
        expect(validationDenied.first.data['action_name'], 'invite_user');
      },
    );

    // ------------------------------------------------------------------
    // 5. Authorize failure
    // ------------------------------------------------------------------
    test(
      'E2E-5: authorize failure — DispatchAuthorizationDenied, authorization_denied event with permission_denied',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        // Use DenyAll policy — every request will be denied.
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const DenyAllAuthorizationPolicy.forTests(),
          idempotency: idempotency,
          actions: [InviteUserAction()],
        );

        final result = await dispatcher.dispatch(
          'invite_user',
          const <String, Object?>{'email': 'alice@example.com'},
          _ctx(),
        );

        expect(result, isA<DispatchAuthorizationDenied<Object?>>());
        final denied = result as DispatchAuthorizationDenied<Object?>;
        expect(denied.permission.name, 'user.invite');

        final allEvents = await eventStore.backend.findAllEvents();
        final authDenied = allEvents
            .where((e) => e.eventType == 'authorization_denied')
            .toList();
        expect(authDenied, hasLength(1));
        expect(authDenied.first.data['permission_denied'], 'user.invite');
      },
    );

    // ------------------------------------------------------------------
    // 6. Idempotency required without key
    // ------------------------------------------------------------------
    test(
      'E2E-6: idempotency required without key — DispatchParseDenied (MissingIdempotencyKeyError), parse_denied recorded',
      () async {
        final eventStore = await _bootstrapStore();
        final idempotency = InMemoryIdempotencyStore();
        final dispatcher = bootstrapAuditedActions(
          events: eventStore,
          authorization: const AlwaysAllowPolicy(),
          idempotency: idempotency,
          // Use the required-key variant.
          actions: [RequiredKeyInviteAction()],
        );

        // Dispatch without supplying an idempotencyKey.
        final result = await dispatcher.dispatch(
          'required_key_invite',
          const <String, Object?>{'email': 'alice@example.com'},
          _ctx(),
          // idempotencyKey intentionally omitted.
        );

        expect(result, isA<DispatchParseDenied<Object?>>());
        final parseDenied = result as DispatchParseDenied<Object?>;
        expect(parseDenied.error, isA<MissingIdempotencyKeyError>());
        expect(parseDenied.error.toString(), contains('idempotency'));

        final allEvents = await eventStore.backend.findAllEvents();
        final parseDeniedEvents = allEvents
            .where((e) => e.eventType == 'parse_denied')
            .toList();
        expect(parseDeniedEvents, hasLength(1));
        expect(
          parseDeniedEvents.first.data['error_class'],
          'MissingIdempotencyKeyError',
        );
      },
    );
  });
}
