// test/walkthroughs/walkthrough_07_malformed_requests_test.dart
//
// Verifies: REQ-d00171 — denial events for parse / validation /
//           unknown-action paths; each shows up in the event log with
//           the matching eventType.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUp(() async {
    harness = await DemoServerHarness.start();
  });

  tearDown(() async {
    await harness.stop();
  });

  group('Walkthrough 7: Malformed requests', () {
    test(
      'unknown action -> DispatchResponseDenied(unknown_action) + denial event',
      () async {
        final resp = await harness.dispatch(
          actionName: 'NotARealAction',
          rawInput: const <String, Object?>{},
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'unknown_action');
        expect(denied.requestedName, 'NotARealAction');

        final events = (await harness.inspect()).events
            .where((e) => e.eventType == 'unknown_action')
            .toList();
        expect(events, hasLength(1));
      },
    );

    test(
      'parse denial: EditGreenNote with wrong shape -> DispatchResponseDenied(parse_denied) + event',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: const <String, Object?>{'wrong_field': 1},
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'parse_denied');
        expect(denied.errorClass, 'FormatException');

        final events = (await harness.inspect()).events
            .where((e) => e.eventType == 'parse_denied')
            .toList();
        expect(events, hasLength(1));
      },
    );

    test(
      'validation denial: EditGreenNote with empty title -> DispatchResponseDenied(validation_denied) + event',
      () async {
        final resp = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-empty-title',
            'title': '',
            'body': 'b',
          },
          userId: 'green-user-1',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'validation_denied');
        // Action's validate throws ArgumentError on empty title/noteId.
        expect(denied.errorClass, contains('ArgumentError'));

        final events = (await harness.inspect()).events
            .where((e) => e.eventType == 'validation_denied')
            .toList();
        expect(events, hasLength(1));
      },
    );
  });
}
