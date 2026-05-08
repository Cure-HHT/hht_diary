// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — Idempotency.optional policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
class EditBlueNoteInput {
  const EditBlueNoteInput({
    required this.noteId,
    required this.title,
    required this.body,
  });

  final String noteId;
  final String title;
  final String body;
}

@immutable
class EditBlueNoteResult {
  const EditBlueNoteResult({required this.noteId});

  final String noteId;

  Map<String, Object?> toJson() => <String, Object?>{'noteId': noteId};
}

class EditBlueNoteAction extends Action<EditBlueNoteInput, EditBlueNoteResult> {
  @override
  String get name => 'EditBlueNoteAction';

  @override
  String get description =>
      'BlueTeam edits a note in blue-workspace. Site-scoped; '
      'optional idempotency.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('notes.write.blue', scope: ScopeClass.site),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  EditBlueNoteInput parseInput(Map<String, Object?> raw) {
    final noteId = raw['noteId'];
    final title = raw['title'];
    final body = raw['body'];
    if (noteId is! String || title is! String || body is! String) {
      throw const FormatException(
        'EditBlueNoteAction expects {noteId, title, body}: String',
      );
    }
    return EditBlueNoteInput(noteId: noteId, title: title, body: body);
  }

  @override
  void validate(EditBlueNoteInput input) {
    if (input.noteId.trim().isEmpty) {
      throw ArgumentError.value(input.noteId, 'noteId', 'must be non-empty');
    }
    if (input.title.trim().isEmpty) {
      throw ArgumentError.value(input.title, 'title', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<EditBlueNoteResult>> execute(
    EditBlueNoteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<EditBlueNoteResult>(
      result: EditBlueNoteResult(noteId: input.noteId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'demo_note',
          aggregateId: input.noteId,
          entryType: 'demo_note',
          eventType: 'demo_note',
          data: <String, dynamic>{
            'title': input.title,
            'body': input.body,
            'workspace': 'blue',
          },
        ),
      ],
    );
  }
}
