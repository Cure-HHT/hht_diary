// test/walkthroughs/walkthrough_06_identity_decoupling_test.dart
//
// Verifies: REQ-d00177 (per-userId snapshot), event metadata carries
// initiator userId AND role distinctly so audit can correlate by either.

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

  group('Walkthrough 6: Identity decouples from role', () {
    test(
      'two GreenTeam users editing notes -> two events, same role, distinct userIds',
      () async {
        final r1 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-from-g1',
            'title': 't1',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-from-g2',
            'title': 't2',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-2',
        );
        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseSuccess>());

        final notes = (await harness.inspect()).events
            .where((e) => e.eventType == 'demo_note')
            .toList();
        expect(notes, hasLength(2));

        // Both events carry the same role.
        expect(notes.map((e) => e.initiatorRole).toSet(), <String>{
          'GreenTeam',
        });

        // But distinct initiatorUserId.
        expect(notes.map((e) => e.initiatorUserId).toSet(), <String?>{
          'green-user-1',
          'green-user-2',
        });

        // And the aggregate ids match what each user supplied.
        expect(notes.map((e) => e.aggregateId).toSet(), <String>{
          'note-from-g1',
          'note-from-g2',
        });
      },
    );
  });
}
