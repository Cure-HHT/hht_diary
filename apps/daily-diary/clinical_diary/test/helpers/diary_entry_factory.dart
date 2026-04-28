// Test helper: build [DiaryEntry] rows shaped like nosebleed-related diary
// entries (`epistaxis_event`, `no_epistaxis_event`, `unknown_day_event`).
//
// The materialized-view shape is fixed by event_sourcing_datastore; the
// builder mirrors what `DiaryEntriesMaterializer` would produce so widget
// tests can construct entries inline without spinning up a full backend.

import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
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
  final answers = <String, Object?>{
    'startTime': DateTimeFormatter.format(startTime),
    // ignore: use_null_aware_elements
    if (endTime != null) 'endTime': DateTimeFormatter.format(endTime),
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
