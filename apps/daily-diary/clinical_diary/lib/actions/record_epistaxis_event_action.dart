// Implements: DIARY-GUI-epistaxis-record/A
//   Refines: DIARY-PRD-epistaxis-capture-standard
// Implements: DIARY-PRD-entry-time-restrictions/D — stores the selected Entry
//   Justification with the entry record when supplied.
//
// Diary per-app Action (diary_actions): record a new nosebleed. Dispatched
// through the core ActionDispatcher and emits one finalized `epistaxis_event`.
//
// Layering note (per-item design): this Action's `validate` does only the PURE
// structural checks. The clinical rules that the entry-* PRDs describe are NOT
// pure and live in their proper layers:
//   - Duration Reasonableness (DIARY-PRD-entry-duration-check): a SOFT,
//     sponsor-configurable confirmation PROMPT shown by the UI before submit —
//     not a hard rejection here.
//   - Time-Based Entry Restrictions (DIARY-PRD-entry-time-restrictions): the
//     justification requirement and the hard lock depend on elapsed time +
//     sponsor config + trial-start; enforced at the submission boundary (UI gate
//     + guard), with the chosen justification carried in as `entryJustification`
//     and stored here (assertion D).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:uuid/uuid.dart';

/// Parsed input: the nosebleed payload plus an optional, sponsor-list-selected
/// late-entry justification (never free text — DIARY-PRD-entry-time-restrictions/C).
class RecordEpistaxisInput {
  const RecordEpistaxisInput({required this.payload, this.entryJustification});

  final EpistaxisEventPayload payload;
  final String? entryJustification;
}

/// Records a new nosebleed as a finalized `epistaxis_event` on a fresh
/// `DiaryEntry` aggregate. Returns the new aggregate id (for scroll-to-record).
class RecordEpistaxisEventAction extends Action<RecordEpistaxisInput, String> {
  RecordEpistaxisEventAction({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String get name => 'record_epistaxis_event';

  @override
  String get description =>
      'Participant records a new nosebleed (finalized epistaxis_event).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_entry'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  RecordEpistaxisInput parseInput(Map<String, Object?> raw) {
    // Normalize any parse failure (e.g. a missing required field) to a
    // FormatException so the dispatcher records a clean `parse_denied`.
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
    return RecordEpistaxisInput(
      payload: payload,
      entryJustification: justification as String?,
    );
  }

  @override
  void validate(RecordEpistaxisInput input) {
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
      if (end.isBefore(start)) {
        throw ArgumentError.value(
          endRaw,
          'endTime',
          'must not be before startTime',
        );
      }
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    RecordEpistaxisInput input,
    ActionContext ctx,
  ) async {
    final aggregateId = _uuid.v4();
    final data = <String, Object?>{
      ...input.payload.toJson(),
      if (input.entryJustification != null)
        'entryJustification': input.entryJustification,
    };
    return ExecutionResult<String>(
      result: aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: aggregateId,
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: data,
        ),
      ],
    );
  }
}
