// Implements: DIARY-DEV-reactive-read-path/B — typed view of a canonical diary
//   row; centralizes the clinical-field parsing that was scattered across
//   EventListItem and the recording screen. Display formatting (locale, device
//   timezone, intensity icons) stays in the widgets; this exposes typed data only.
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:trial_data_types/trial_data_types.dart' as tdt;

sealed class DiaryEntryView {
  const DiaryEntryView(this.row, {required this.isComplete});
  final DiaryEntryRow row;
  final bool isComplete;
  String get aggregateId => row.aggregateId;
  String get entryType => row.entryType;
  String? get localDate => row.localDate;
}

/// Typed view of an `epistaxis_event` row.
///
/// Constructed eagerly from `row.data` via [EpistaxisEventPayload.fromJson];
/// **throws** (`FormatException`/`TypeError`) if the row does not conform to the
/// `EpistaxisEventPayload` schema. The event log is authoritative, so a
/// non-conforming row is a bug, not a recoverable condition — callers should not
/// expect to construct this from untrusted data.
class EpistaxisEntryView extends DiaryEntryView {
  EpistaxisEntryView(super.row, {required super.isComplete})
    : _payload = EpistaxisEventPayload.fromJson(row.data);
  final EpistaxisEventPayload _payload;

  /// The start as a **device-local** `DateTime` (the app's "stored DateTime"
  /// form). The stored ISO string carries an offset, so `DateTime.parse` returns
  /// a UTC instant; `.toLocal()` converts it to the device-local representation
  /// that the renderer (`EventListItem` via `TimezoneConverter.toDisplayedDateTime`)
  /// and the recording-screen edit-init both expect. Without it, display + edit
  /// are shifted by the device's UTC offset (correct only when the device is
  /// itself UTC). `.toLocal()` preserves the instant, so interval/duration
  /// comparisons are unaffected.
  DateTime get startTime => DateTime.parse(_payload.startTime).toLocal();
  DateTime? get endTime => _payload.endTime == null
      ? null
      : DateTime.parse(_payload.endTime!).toLocal();
  String get startTimeZone => _payload.startTimeZone;
  String? get endTimeZone => _payload.endTimeZone;
  NosebleedIntensity? get intensity => _payload.intensity;
  int? get durationMinutes {
    final end = endTime;
    if (end == null) return null;
    if (end.isBefore(startTime)) return null;
    return end.difference(startTime).inMinutes;
  }

  bool get isMultiDay {
    final endTs = _payload.endTime;
    if (endTs == null) return false;
    // Compare the local wall-clock date portions directly from the raw ISO
    // timestamps. DateTime.parse normalises to UTC, so using .year/.month/.day
    // would silently shift the date for non-UTC offsets. _wallClockDate is
    // length-safe (no RangeError on a malformed short string).
    return _wallClockDate(_payload.startTime) != _wallClockDate(endTs);
  }

  /// The `yyyy-MM-dd` wall-clock date prefix of an ISO timestamp — the substring
  /// before `T`, mirroring how `canonicalEntryDate` derives the day. Length-safe.
  static String _wallClockDate(String iso) {
    final t = iso.indexOf('T');
    return t >= 0 ? iso.substring(0, t) : iso;
  }
}

/// Typed view of a `<id>_survey` row (a finalized questionnaire submission).
///
/// Constructed eagerly from `row.data` via
/// [QuestionnaireSubmissionPayload.fromJson]; **throws**
/// (`FormatException`/`TypeError`) if the row does not conform to the
/// `QuestionnaireSubmissionPayload` schema. The event log is authoritative, so a
/// non-conforming row is a bug, not a recoverable condition — callers should not
/// expect to construct this from untrusted data.
class SurveyEntryView extends DiaryEntryView {
  SurveyEntryView(super.row, {required super.isComplete})
    : _payload = QuestionnaireSubmissionPayload.fromJson(row.data);
  final QuestionnaireSubmissionPayload _payload;

  /// The questionnaire id (the `<id>` of the `<id>_survey` entry type).
  String get questionnaireType => _payload.questionnaireType;

  /// The submission moment as a **device-local** `DateTime`. The stored ISO
  /// string carries an offset, so `DateTime.parse` returns a UTC instant;
  /// `.toLocal()` converts it to the device-local representation the renderer
  /// expects (mirrors [EpistaxisEntryView.startTime]).
  DateTime get completedAt => DateTime.parse(_payload.completedAt).toLocal();

  /// Number of answered questions in the submission.
  int get responseCount => _payload.responses.length;

  /// Bridges the stored shared-model responses to the questionnaire flow's
  /// [tdt.QuestionResponse] form so a re-opened submitted survey can seed the
  /// Review Screen with its prior answers.
  ///
  /// The shared-model [QuestionResponse.value] is `Object?`; for HHT
  /// questionnaires the schema guarantees an `int` (0–4 scale), so the cast is
  /// safe — a non-conforming row is a bug in the event log, not a recoverable
  /// condition. Labels fall back to `''` when absent (free-text / numeric
  /// answers may carry no display or normalized label).
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/R
  List<tdt.QuestionResponse> get prefillResponses => _payload.responses.entries
      .map(
        (e) => tdt.QuestionResponse(
          questionId: e.key,
          value: e.value.value as int,
          displayLabel: e.value.displayLabel ?? '',
          normalizedLabel: e.value.normalizedLabel ?? '',
        ),
      )
      .toList(growable: false);
}

class DayMarkerView extends DiaryEntryView {
  DayMarkerView(super.row, {super.isComplete = true});
}

DiaryEntryView diaryEntryViewOf(DiaryEntryRow row, {required bool isComplete}) {
  if (row.entryType == 'epistaxis_event') {
    return EpistaxisEntryView(row, isComplete: isComplete);
  }
  if (row.entryType.endsWith('_survey')) {
    return SurveyEntryView(row, isComplete: isComplete);
  }
  return DayMarkerView(row, isComplete: isComplete);
}
