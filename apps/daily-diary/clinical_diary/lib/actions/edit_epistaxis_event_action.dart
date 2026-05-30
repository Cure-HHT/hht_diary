// Implements: DIARY-GUI-epistaxis-record/A
//   Refines: DIARY-PRD-epistaxis-capture-standard
// Implements: DIARY-PRD-entry-time-restrictions/D — stores Entry Justification when supplied.
//
// Per-app diary Action: edit an EXISTING nosebleed. Emits another finalized
// `epistaxis_event` on the SAME aggregate (the projection merge-folds it),
// stamped `changeReason: edited`. Same layering as RecordEpistaxisEventAction
// (pure structural validate; lock/justification/duration in UI/config/guard).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Parsed input: the existing aggregate id plus the (full) revised payload and
/// an optional late-entry justification.
class EditEpistaxisInput {
  const EditEpistaxisInput({
    required this.aggregateId,
    required this.payload,
    this.entryJustification,
  });

  final String aggregateId;
  final EpistaxisEventPayload payload;
  final String? entryJustification;
}

/// Edits an existing nosebleed; returns the (unchanged) aggregate id.
class EditEpistaxisEventAction extends Action<EditEpistaxisInput, String> {
  const EditEpistaxisEventAction();

  @override
  String get name => 'edit_epistaxis_event';

  @override
  String get description =>
      'Participant edits an existing nosebleed (re-finalizes the aggregate).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_entry'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  EditEpistaxisInput parseInput(Map<String, Object?> raw) {
    final aggregateId = raw['aggregateId'];
    if (aggregateId is! String || aggregateId.isEmpty) {
      throw const FormatException('aggregateId is required for an edit');
    }
    final EpistaxisEventPayload payload;
    try {
      payload = EpistaxisEventPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid epistaxis_event payload: $e');
    }
    final justification = raw['entryJustification'];
    if (justification != null && justification is! String) {
      throw const FormatException('entryJustification must be a string');
    }
    return EditEpistaxisInput(
      aggregateId: aggregateId,
      payload: payload,
      entryJustification: justification as String?,
    );
  }

  @override
  void validate(EditEpistaxisInput input) {
    final start = DateTime.tryParse(input.payload.startTime);
    if (start == null) {
      throw ArgumentError.value(
        input.payload.startTime,
        'startTime',
        'must be an ISO 8601 timestamp',
      );
    }
    final endRaw = input.payload.endTime;
    if (endRaw != null) {
      final end = DateTime.tryParse(endRaw);
      if (end == null) {
        throw ArgumentError.value(
          endRaw,
          'endTime',
          'must be an ISO 8601 timestamp',
        );
      }
      if (!end.isAfter(start)) {
        throw ArgumentError.value(endRaw, 'endTime', 'must be after startTime');
      }
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    EditEpistaxisInput input,
    ActionContext ctx,
  ) async {
    final data = <String, Object?>{
      ...input.payload.toJson(),
      'changeReason': 'edited',
      if (input.entryJustification != null)
        'entryJustification': input.entryJustification,
    };
    return ExecutionResult<String>(
      result: input.aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: input.aggregateId,
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: data,
        ),
      ],
    );
  }
}
