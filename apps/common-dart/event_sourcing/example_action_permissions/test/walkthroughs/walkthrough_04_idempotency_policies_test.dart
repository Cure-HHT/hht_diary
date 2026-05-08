// test/walkthroughs/walkthrough_04_idempotency_policies_test.dart
//
// Verifies: REQ-d00170-A,B,C — idempotency policies (none, optional,
//           required), and the dispatcher's behavior under each.

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

  group('Walkthrough 4: Idempotency policies', () {
    test(
      'Idempotency.none: PressGreenButton with key replays as new success (key ignored)',
      () async {
        const key = 'ignored-by-this-action';
        final r1 = await harness.dispatch(
          actionName: 'PressGreenButtonAction',
          rawInput: const <String, Object?>{},
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'PressGreenButtonAction',
          rawInput: const <String, Object?>{},
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseSuccess>());
        // Two distinct events should be in the log.
        final events = (await harness.inspect()).events
            .where((e) => e.eventType == 'green_button_pressed')
            .toList();
        expect(events, hasLength(2));
        // Idempotency cache should be empty (none policy doesn't record).
        final idem = (await harness.inspect()).idempotency;
        expect(
          idem.where((e) => e.actionName == 'PressGreenButtonAction'),
          isEmpty,
        );
      },
    );

    test(
      'Idempotency.optional: EditGreenNote without key runs every time',
      () async {
        final r1 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{'noteId': 'a', 'title': 't', 'body': 'b'},
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{'noteId': 'b', 'title': 't', 'body': 'b'},
          userId: 'green-user-1',
        );
        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseSuccess>());
        final notes = (await harness.inspect()).events
            .where((e) => e.eventType == 'demo_note')
            .toList();
        expect(notes, hasLength(2));
      },
    );

    test(
      'Idempotency.optional: EditGreenNote with key + replay -> idempotencyHit',
      () async {
        final key = const Uuid().v4();
        final r1 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-x',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-x',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseIdempotencyHit>());
        final hit = r2 as DispatchResponseIdempotencyHit;
        // Prior event ids match the original success.
        expect(hit.priorEventIds, isNotEmpty);
        final s1 = r1 as DispatchResponseSuccess;
        expect(hit.priorEventIds, equals(s1.emittedEventIds));
        // Only one demo_note event in the log.
        final notes = (await harness.inspect()).events
            .where((e) => e.eventType == 'demo_note')
            .toList();
        expect(notes, hasLength(1));
      },
    );

    test(
      'Idempotency.required: PressRedAlarm without key -> parse_denied (MissingIdempotencyKeyError)',
      () async {
        final resp = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'fire'},
          userId: 'green-user-1',
          // no idempotencyKey
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'parse_denied');
        expect(denied.errorClass, 'MissingIdempotencyKeyError');
      },
    );

    test(
      'Idempotency.required: PressRedAlarm with key + replay -> idempotencyHit',
      () async {
        final key = const Uuid().v4();
        final r1 = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'fire'},
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'fire'},
          idempotencyKey: key,
          userId: 'green-user-1',
        );
        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseIdempotencyHit>());
        // Idempotency cache should contain one entry for this principal.
        final idem = (await harness.inspect()).idempotency
            .where((e) => e.actionName == 'PressRedAlarmAction')
            .toList();
        expect(idem, hasLength(1));
        expect(idem.first.principalUserId, 'green-user-1');
        expect(idem.first.idempotencyKey, key);
      },
    );
  });
}
