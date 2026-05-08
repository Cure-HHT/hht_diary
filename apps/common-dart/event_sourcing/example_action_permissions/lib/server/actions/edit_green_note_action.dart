// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — Idempotency.optional policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
class EditGreenNoteInput {
  const EditGreenNoteInput({
    required this.noteId,
    required this.title,
    required this.body,
  });

  final String noteId;
  final String title;
  final String body;
}

@immutable
class EditGreenNoteResult {
  const EditGreenNoteResult({required this.noteId});

  final String noteId;

  Map<String, Object?> toJson() => <String, Object?>{'noteId': noteId};
}

class EditGreenNoteAction
    extends Action<EditGreenNoteInput, EditGreenNoteResult> {
  @override
  String get name => 'EditGreenNoteAction';

  @override
  String get description =>
      'GreenTeam edits a note in green-workspace. Site-scoped; '
      'optional idempotency.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('notes.write.green', scope: ScopeClass.site),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  EditGreenNoteInput parseInput(Map<String, Object?> raw) {
    final noteId = raw['noteId'];
    final title = raw['title'];
    final body = raw['body'];
    if (noteId is! String || title is! String || body is! String) {
      throw const FormatException(
        'EditGreenNoteAction expects {noteId, title, body}: String',
      );
    }
    return EditGreenNoteInput(noteId: noteId, title: title, body: body);
  }

  @override
  void validate(EditGreenNoteInput input) {
    if (input.noteId.trim().isEmpty) {
      throw ArgumentError.value(input.noteId, 'noteId', 'must be non-empty');
    }
    if (input.title.trim().isEmpty) {
      throw ArgumentError.value(input.title, 'title', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<EditGreenNoteResult>> execute(
    EditGreenNoteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<EditGreenNoteResult>(
      result: EditGreenNoteResult(noteId: input.noteId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'demo_note',
          aggregateId: input.noteId,
          entryType: 'demo_note',
          eventType: 'demo_note',
          data: <String, dynamic>{
            'title': input.title,
            'body': input.body,
            'workspace': 'green',
          },
        ),
      ],
    );
  }
}
