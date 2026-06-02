// Test helper: build [DiaryEntry] rows shaped like nosebleed-related diary
// entries (`epistaxis_event`, `no_epistaxis_event`, `unknown_day_event`).
//
// The materialized-view shape is fixed by event_sourcing_datastore; the
// builder mirrors what `DiaryEntriesMaterializer` would produce so widget
// tests can construct entries inline without spinning up a full backend.
//
// Also provides view-model builders ([buildEpistaxisView], [buildDayMarkerView])
// for tests that use the rebased [EventListItem] API.

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    as shared
    show EpistaxisEventPayload, NosebleedIntensity;
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Build a finalized `epistaxis_event` [DiaryEntry] for use in widget tests.
DiaryEntry buildEpistaxisEntry({
  required String entryId,
  required DateTime startTime,
  DateTime? endTime,
  NosebleedIntensity? intensity,
  String? notes,
  String? startTimeTimezone,
  String? endTimeTimezone,
  bool isComplete = true,
  bool isDeleted = false,
  DateTime? updatedAt,
}) {
  // Use toIso8601String() (no offset) so DateTime.parse returns a local
  // (non-UTC) DateTime; DateFormat then renders the wall-clock time correctly
  // regardless of the test host's timezone. DateTimeFormatter.format embeds
  // the real device offset, which causes DateTime.parse to return UTC and
  // DateFormat to display the UTC hour instead of the local hour.
  final answers = <String, Object?>{
    'startTime': startTime.toIso8601String(),
    // ignore: use_null_aware_elements
    if (endTime != null) 'endTime': endTime.toIso8601String(),
    // ignore: use_null_aware_elements
    if (intensity != null) 'intensity': intensity.name,
    // ignore: use_null_aware_elements
    if (notes != null) 'notes': notes,
    // ignore: use_null_aware_elements
    if (startTimeTimezone != null) 'startTimeTimezone': startTimeTimezone,
    // ignore: use_null_aware_elements
    if (endTimeTimezone != null) 'endTimeTimezone': endTimeTimezone,
  };
  // CUR-1169: Caller can pass `isComplete: false` to exercise the incomplete
  // styling path; otherwise the default mirrors a finalized event with both
  // start and end times.
  final hasBothTimes = endTime != null && intensity != null;
  return DiaryEntry(
    entryId: entryId,
    entryType: 'epistaxis_event',
    effectiveDate: startTime,
    currentAnswers: answers,
    isComplete: isComplete && hasBothTimes,
    isDeleted: isDeleted,
    latestEventId: 'evt-$entryId',
    updatedAt: updatedAt ?? startTime,
  );
}

/// Build a finalized `no_epistaxis_event` [DiaryEntry] for the given local-day.
DiaryEntry buildNoEpistaxisEntry({
  required String entryId,
  required DateTime date,
  bool isDeleted = false,
}) {
  return DiaryEntry(
    entryId: entryId,
    entryType: 'no_epistaxis_event',
    effectiveDate: date,
    currentAnswers: <String, Object?>{'date': DateTimeFormatter.format(date)},
    isComplete: true,
    isDeleted: isDeleted,
    latestEventId: 'evt-$entryId',
    updatedAt: date,
  );
}

/// Build a finalized `unknown_day_event` [DiaryEntry] for the given local-day.
DiaryEntry buildUnknownDayEntry({
  required String entryId,
  required DateTime date,
  bool isDeleted = false,
}) {
  return DiaryEntry(
    entryId: entryId,
    entryType: 'unknown_day_event',
    effectiveDate: date,
    currentAnswers: <String, Object?>{'date': DateTimeFormatter.format(date)},
    isComplete: true,
    isDeleted: isDeleted,
    latestEventId: 'evt-$entryId',
    updatedAt: date,
  );
}

// ---------------------------------------------------------------------------
// View-model builders for the rebased EventListItem API.
// ---------------------------------------------------------------------------

/// Build an [EpistaxisEntryView] for use in widget tests that use the new API.
///
/// Constructs a [DiaryEntryRow] whose `data` is an EpistaxisEventPayload
/// JSON map so that [EpistaxisEntryView]'s eager payload parse succeeds.
EpistaxisEntryView buildEpistaxisView({
  required DateTime startTime,
  String aggregateId = 'e1',
  DateTime? endTime,
  String startTimeZone = 'UTC',
  String? endTimeZone,
  shared.NosebleedIntensity? intensity,
  bool isComplete = true,
}) {
  final payload = shared.EpistaxisEventPayload(
    startTime: startTime.toIso8601String(),
    startTimeZone: startTimeZone,
    startTimeUtcOffset: '+00:00',
    endTime: endTime?.toIso8601String(),
    endTimeZone: endTimeZone,
    endTimeUtcOffset: endTimeZone == null ? null : '+00:00',
    intensity: intensity,
  );
  final row = DiaryEntryRow(
    aggregateId: aggregateId,
    entryType: 'epistaxis_event',
    data: payload.toJson(),
  );
  return EpistaxisEntryView(row, isComplete: isComplete);
}

/// Build a [DayMarkerView] for use in widget tests that use the new API.
///
/// [entryType] defaults to `no_epistaxis_event`; pass `unknown_day_event`
/// for the unknown-day card path.
DayMarkerView buildDayMarkerView({
  required String date,
  String aggregateId = 'm1',
  String entryType = 'no_epistaxis_event',
}) {
  final row = DiaryEntryRow(
    aggregateId: aggregateId,
    entryType: entryType,
    data: <String, Object?>{'date': date},
  );
  return DayMarkerView(row);
}
