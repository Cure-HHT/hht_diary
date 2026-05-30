// Implements: DIARY-GUI-epistaxis-record/A
//   Refines: DIARY-PRD-epistaxis-capture-standard
// Implements: DIARY-PRD-entry-time-restrictions/D — stores Entry Justification when supplied.
//
// Per-app diary Actions for the two whole-day markers: "no nosebleed today" and
// "I don't remember". Both record a finalized event on the canonical per-day
// aggregate `{patientId}:{localDate}` (shared `dayAggregateId`), so re-recording
// the same day updates the same aggregate rather than duplicating it. Same
// layering note as RecordEpistaxisEventAction: `validate` is pure-structural;
// duration/justification/lock rules live in their UI/config/guard layers.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Parsed input: the day marker plus an optional late-entry justification.
class DayMarkerInput {
  const DayMarkerInput({required this.payload, this.entryJustification});

  final DayMarkerPayload payload;
  final String? entryJustification;
}

/// Shared base for the two day-marker actions; subclasses set [name] and
/// [entryTypeId].
abstract class RecordDayMarkerAction extends Action<DayMarkerInput, String> {
  const RecordDayMarkerAction();

  /// The entry-type id this action records (`no_epistaxis_event` / `unknown_day_event`).
  String get entryTypeId;

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_entry'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  DayMarkerInput parseInput(Map<String, Object?> raw) {
    final DayMarkerPayload payload;
    try {
      payload = DayMarkerPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid $entryTypeId payload: $e');
    }
    final justification = raw['entryJustification'];
    if (justification != null && justification is! String) {
      throw const FormatException('entryJustification must be a string');
    }
    return DayMarkerInput(
      payload: payload,
      entryJustification: justification as String?,
    );
  }

  @override
  void validate(DayMarkerInput input) {
    if (canonicalEntryDate(entryTypeId, input.payload.toJson()) == null) {
      throw ArgumentError.value(
        input.payload.date,
        'date',
        'must be a yyyy-MM-dd[...] date',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    DayMarkerInput input,
    ActionContext ctx,
  ) async {
    final principal = ctx.principal;
    if (principal is! UserPrincipal) {
      throw StateError(
        'recording a day marker requires an identified participant',
      );
    }
    final localDate = canonicalEntryDate(entryTypeId, input.payload.toJson())!;
    final aggregateId = dayAggregateId(principal.userId, localDate);
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
          entryType: entryTypeId,
          eventType: 'finalized',
          data: data,
        ),
      ],
    );
  }
}

/// Records a "no nosebleed today" marker.
class RecordNoEpistaxisDayAction extends RecordDayMarkerAction {
  const RecordNoEpistaxisDayAction();
  @override
  String get name => 'record_no_epistaxis_day';
  @override
  String get entryTypeId => 'no_epistaxis_event';
  @override
  String get description => 'Participant records a no-nosebleed day.';
}

/// Records an "I don't remember this day" marker.
class RecordUnknownDayAction extends RecordDayMarkerAction {
  const RecordUnknownDayAction();
  @override
  String get name => 'record_unknown_day';
  @override
  String get entryTypeId => 'unknown_day_event';
  @override
  String get description => "Participant records a day they don't remember.";
}
