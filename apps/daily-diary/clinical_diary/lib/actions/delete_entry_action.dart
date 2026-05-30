// Implements: DIARY-GUI-epistaxis-delete/A
//   Refines: DIARY-PRD-entry-overlap-resolution
//
// Per-app diary Action: delete (tombstone) an existing diary entry. Emits a
// `tombstone` event on the entry's aggregate; the canonical projection deletes
// the row. The hard lock (DIARY-PRD-entry-time-restrictions/G) that forbids
// deletion past the Lock Threshold is enforced at the submission-boundary guard
// (sponsor config + trial-start + now), not in this pure Action.
//
// NOTE (cross-wire vocabulary gap): the frozen changeReason set is
// {edited, corrected, portal-withdrawn} (D1) — it does not yet name a
// user-initiated delete reason. Until that is reconciled with the portal, this
// action only requires a non-empty changeReason rather than enforcing the set.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Parsed input for a tombstone: which aggregate + entry type, and why.
class DeleteEntryInput {
  const DeleteEntryInput({
    required this.aggregateId,
    required this.entryTypeId,
    required this.changeReason,
  });

  final String aggregateId;
  final String entryTypeId;
  final String changeReason;
}

/// Tombstones an existing diary entry aggregate. Returns the aggregate id.
class DeleteEntryAction extends Action<DeleteEntryInput, String> {
  const DeleteEntryAction();

  @override
  String get name => 'delete_entry';

  @override
  String get description =>
      'Tombstone an existing diary entry (participant- or portal-initiated).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.delete_entry'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  DeleteEntryInput parseInput(Map<String, Object?> raw) {
    final id = raw['aggregateId'];
    final entryType = raw['entryType'];
    final changeReason = raw['changeReason'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('aggregateId is required');
    }
    if (entryType is! String || entryType.isEmpty) {
      throw const FormatException('entryType is required');
    }
    if (changeReason is! String || changeReason.isEmpty) {
      throw const FormatException('changeReason is required');
    }
    return DeleteEntryInput(
      aggregateId: id,
      entryTypeId: entryType,
      changeReason: changeReason,
    );
  }

  @override
  void validate(DeleteEntryInput input) {
    // Structural only; the lock guard lives at the submission boundary.
  }

  @override
  Future<ExecutionResult<String>> execute(
    DeleteEntryInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<String>(
      result: input.aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: input.aggregateId,
          entryType: input.entryTypeId,
          eventType: 'tombstone',
          data: <String, Object?>{'changeReason': input.changeReason},
        ),
      ],
    );
  }
}
