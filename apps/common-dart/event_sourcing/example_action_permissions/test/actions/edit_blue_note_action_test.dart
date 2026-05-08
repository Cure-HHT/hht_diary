// Verifies: REQ-d00166 (Action interface), REQ-d00170 (idempotency optional),
//           REQ-d00172 (site-scoped permission)
import 'package:action_permissions_demo/server/actions/edit_blue_note_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx() => ActionContext(
  principal: const Principal.user(
    userId: 'blue-user',
    roles: <String>{'BlueTeam'},
    activeRole: 'BlueTeam',
    activeSite: 'blue-workspace',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 5, 8, 12),
);

void main() {
  group('EditBlueNoteAction', () {
    final action = EditBlueNoteAction();

    test(
      'REQ-d00166-A: declares site-scoped notes.write.blue, idempotency optional',
      () {
        expect(action.name, 'EditBlueNoteAction');
        expect(
          action.permissions,
          contains(
            const Permission('notes.write.blue', scope: ScopeClass.site),
          ),
        );
        expect(action.idempotency, Idempotency.optional);
      },
    );

    test('REQ-d00166-C: parseInput accepts {noteId,title,body}: String', () {
      final input = action.parseInput(<String, Object?>{
        'noteId': 'n1',
        'title': 't',
        'body': 'b',
      });
      expect(input.noteId, 'n1');
      expect(input.title, 't');
      expect(input.body, 'b');
    });

    test('REQ-d00166-C: parseInput throws FormatException on wrong shape', () {
      expect(
        () => action.parseInput(<String, Object?>{'noteId': 'n1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => action.parseInput(<String, Object?>{
          'noteId': 'n1',
          'title': 't',
          'body': 42,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'REQ-d00166-D: validate rejects empty title or noteId with ArgumentError',
      () {
        expect(
          () => action.validate(
            const EditBlueNoteInput(noteId: 'n1', title: '', body: 'b'),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => action.validate(
            const EditBlueNoteInput(noteId: '', title: 't', body: 'b'),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'REQ-d00166-E: execute emits one demo_note event with workspace=blue',
      () async {
        final result = await action.execute(
          const EditBlueNoteInput(noteId: 'n1', title: 't', body: 'b'),
          _ctx(),
        );
        expect(result.events, hasLength(1));
        final draft = result.events.single;
        expect(draft.eventType, 'demo_note');
        expect(draft.aggregateType, 'demo_note');
        expect(draft.aggregateId, 'n1');
        expect(draft.entryType, 'demo_note');
        expect(draft.data['workspace'], 'blue');
        expect(draft.data['title'], 't');
        expect(draft.data['body'], 'b');
        expect(result.result.noteId, 'n1');
      },
    );
  });
}
