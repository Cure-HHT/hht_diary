// test/walkthroughs/walkthrough_08_audit_correlation_test.dart
//
// Verifies: REQ-d00168-C — every dispatch generates a v4 UUID
// `action_invocation_id` and stamps it onto every emitted event so the
// audit log can trace one dispatch's full effects.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUp(() async {
    harness = await DemoServerHarness.start();
  });

  tearDown(() async {
    await harness.stop();
  });

  group('Walkthrough 8: Audit correlation by action_invocation_id', () {
    test(
      'two dispatches -> events from each share an invocation_id; the two ids differ',
      () async {
        // Dispatch 1: success path — EditGreenNote emits one demo_note event.
        final r1 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'corr-note-1',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        expect(r1, isA<DispatchResponseSuccess>());

        // Dispatch 2: denial path — EditBlueNote as GreenTeam emits one
        // authorization_denied event.
        final r2 = await harness.dispatch(
          actionName: 'EditBlueNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'corr-note-blue',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        expect(r2, isA<DispatchResponseDenied>());

        final events = (await harness.inspect()).events;

        // Find the demo_note event (dispatch 1).
        final note = events.singleWhere(
          (e) => e.eventType == 'demo_note' && e.aggregateId == 'corr-note-1',
        );
        // Find the authorization_denied event (dispatch 2).
        final denial = events.singleWhere(
          (e) => e.eventType == 'authorization_denied',
        );

        // Each dispatch produced exactly one event in the log; the events
        // from different dispatches have different invocation ids.
        expect(note.actionInvocationId, isNotEmpty);
        expect(denial.actionInvocationId, isNotEmpty);
        expect(note.actionInvocationId, isNot(denial.actionInvocationId));

        // No other event in the log shares either invocation id (single
        // dispatch -> single event under the demo's actions). System
        // bootstrap events have empty invocation_id.
        expect(
          events.where((e) => e.actionInvocationId == note.actionInvocationId),
          hasLength(1),
        );
        expect(
          events.where(
            (e) => e.actionInvocationId == denial.actionInvocationId,
          ),
          hasLength(1),
        );
      },
    );

    test('system bootstrap events have empty action_invocation_id', () async {
      // The bootstrap path (entry-type registry initialized + permission
      // grants + user provisioned events from seed appliers) does not
      // run through the dispatcher, so action_invocation_id is empty
      // on those rows.
      final events = (await harness.inspect()).events;
      // At least the system_registry init event from bootstrap.
      final systemEvents = events
          .where((e) => e.actionInvocationId.isEmpty)
          .toList();
      expect(systemEvents, isNotEmpty);
    });
  });
}
