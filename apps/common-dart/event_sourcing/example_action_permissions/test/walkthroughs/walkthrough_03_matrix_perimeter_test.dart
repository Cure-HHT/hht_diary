// test/walkthroughs/walkthrough_03_matrix_perimeter_test.dart
//
// Verifies: REQ-d00168-G (authorize stage emits authorization_denied),
//           REQ-d00171-A (denial event carries permission_denied + role),
//           REQ-d00172-A (scope-class precondition denials),
//           REQ-d00176-A (TableBackedAuthorizationPolicy decision rules).
//
// Per-test fresh server so denial-event counts are deterministic.

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

  group('Walkthrough 3: Matrix as perimeter (denial paths)', () {
    test(
      'GreenTeam trying EditBlueNote -> authorization_denied (notes.write.blue)',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditBlueNoteAction',
          rawInput: <String, Object?>{'noteId': 'n', 'title': 't', 'body': 'b'},
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'notes.write.blue');

        final events = (await harness.inspect()).events;
        expect(
          events.where((e) => e.eventType == 'authorization_denied'),
          hasLength(1),
        );
      },
    );

    test(
      'Anonymous trying PressGreen -> authorization_denied (site precondition)',
      () async {
        // Anon has no role; TableBackedAuthorizationPolicy denies anon
        // outright with notGranted, OR fails the site precondition first
        // (anon has no activeSite). Either way, the response is
        // authorization_denied for buttons.press.green.
        final resp = await harness.dispatch(
          actionName: 'PressGreenButtonAction',
          rawInput: const <String, Object?>{},
          // userId omitted -> Anon
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'buttons.press.green');
      },
    );

    test(
      'Anonymous + key trying PressRedAlarm -> authorization_denied (self precondition)',
      () async {
        // PressRedAlarm requires an idempotency key — without a key, the
        // dispatcher returns parse_denied before authorize ever runs.
        // Supply a key so we exercise the self-scope precondition denial.
        final resp = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'fire'},
          idempotencyKey: const Uuid().v4(),
          // userId omitted -> Anon
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'buttons.press.red');
      },
    );

    test(
      'Admin trying EditGreenNote -> authorization_denied (Admin lacks notes.write.green)',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{'noteId': 'n', 'title': 't', 'body': 'b'},
          idempotencyKey: const Uuid().v4(),
          userId: 'admin-user',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'notes.write.green');
      },
    );

    test(
      'Admin trying RequestHelp -> authorization_denied (Admin lacks help.ask)',
      () async {
        // Admin only has users.provision in our seed. help.ask is granted
        // only to GreenTeam and BlueTeam.
        final resp = await harness.dispatch(
          actionName: 'RequestHelpAction',
          rawInput: <String, Object?>{'message': 'help me'},
          userId: 'admin-user',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'help.ask');
      },
    );

    test(
      'every denial in this walkthrough produces exactly one authorization_denied event',
      () async {
        // Single dispatch, single denial event.
        await harness.dispatch(
          actionName: 'EditBlueNoteAction',
          rawInput: <String, Object?>{'noteId': 'n', 'title': 't', 'body': 'b'},
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        final events = (await harness.inspect()).events;
        final denials = events
            .where((e) => e.eventType == 'authorization_denied')
            .toList();
        expect(denials, hasLength(1));
        // Denial event uses entryType action_denial, aggregateType action_attempt.
        expect(denials.first.aggregateType, 'action_attempt');
      },
    );
  });
}
