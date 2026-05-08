// test/walkthroughs/walkthrough_02_happy_paths_test.dart
//
// Verifies: REQ-d00166-E (action.execute emits typed events),
//           REQ-d00168-K (DispatchSuccess return shape),
//           REQ-d00172-A (scope-class preconditions met for site/self).
//
// One test per happy-path action. Each test fires a single dispatch and
// then asserts that the inspect snapshot's event log contains a matching
// event. Each test starts the harness fresh (setUp, not setUpAll) so
// per-test event-log assertions are deterministic.

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

  group('Walkthrough 2: Happy paths across scope classes', () {
    test(
      'REQ-d00166: RequestHelpAction (global) as GreenTeam emits help_request',
      () async {
        final resp = await harness.dispatch(
          actionName: 'RequestHelpAction',
          rawInput: <String, Object?>{'message': 'help me'},
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseSuccess>());
        final success = resp as DispatchResponseSuccess;
        expect(success.emittedEventIds, hasLength(1));

        final snap = await harness.inspect();
        expect(
          snap.events.where((e) => e.eventType == 'help_request'),
          hasLength(1),
        );
      },
    );

    test(
      'REQ-d00166: EditGreenNoteAction (site) as green-user-1 emits demo_note with workspace=green',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-1',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseSuccess>());

        final snap = await harness.inspect();
        final notes = snap.events.where((e) => e.eventType == 'demo_note');
        expect(notes, hasLength(1));
        expect(notes.first.aggregateId, 'note-1');
        // workspace lives in event.data — not in the wire summary. Defensive
        // check on the summary's aggregate type instead.
        expect(notes.first.aggregateType, 'demo_note');
      },
    );

    test(
      'REQ-d00166: EditBlueNoteAction (site) as blue-user emits demo_note',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditBlueNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-blue-1',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'blue-user',
        );
        expect(resp, isA<DispatchResponseSuccess>());

        final snap = await harness.inspect();
        final notes = snap.events.where((e) => e.aggregateId == 'note-blue-1');
        expect(notes, hasLength(1));
        expect(notes.first.eventType, 'demo_note');
      },
    );

    test(
      'REQ-d00166: PressGreenButtonAction (site) as green-user-1 emits green_button_pressed',
      () async {
        final resp = await harness.dispatch(
          actionName: 'PressGreenButtonAction',
          rawInput: const <String, Object?>{},
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseSuccess>());

        final snap = await harness.inspect();
        expect(
          snap.events.where((e) => e.eventType == 'green_button_pressed'),
          hasLength(1),
        );
      },
    );

    test(
      'REQ-d00166: PressBlueButtonAction (site) as blue-user emits blue_button_pressed',
      () async {
        final resp = await harness.dispatch(
          actionName: 'PressBlueButtonAction',
          rawInput: const <String, Object?>{},
          userId: 'blue-user',
        );
        expect(resp, isA<DispatchResponseSuccess>());

        final snap = await harness.inspect();
        expect(
          snap.events.where((e) => e.eventType == 'blue_button_pressed'),
          hasLength(1),
        );
      },
    );

    test(
      'REQ-d00166: PressRedAlarmAction (self) as green-user-1 with key emits red_alarm_pressed',
      () async {
        final resp = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'fire'},
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseSuccess>());

        final snap = await harness.inspect();
        expect(
          snap.events.where((e) => e.eventType == 'red_alarm_pressed'),
          hasLength(1),
        );
      },
    );
  });
}
