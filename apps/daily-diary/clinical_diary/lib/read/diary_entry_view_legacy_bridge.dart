// TRANSITIONAL bridge: adapts a legacy [DiaryEntry] materialized-view row to a
// [DiaryEntryView] so legacy screens keep compiling during the EVS-lib cutover.
//
// DELETE at Integration phase I4 when the old `event_sourcing_datastore` module
// is removed. New code uses [diaryEntryViewOf] with a [DiaryEntryRow] instead.
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Adapter: build a [DiaryEntryView] from a legacy [DiaryEntry] materialized-
/// view row.
///
/// The legacy `currentAnswers` map uses different key names from the canonical
/// `EpistaxisEventPayload` schema (`startTimeTimezone` → `startTimeZone`,
/// `endTimeTimezone` → `endTimeZone`). This adapter translates those keys and
/// synthesises any fields required by `EpistaxisEventPayload.fromJson` that are
/// absent from the legacy schema (e.g. `startTimeUtcOffset` defaults to
/// `'+00:00'`).
///
/// **Display delta — UTC label on legacy no-timezone entries**: for a legacy
/// entry with NO stored timezone, this defaults `startTimeZone` to `'UTC'`.
/// On a non-UTC device the time is shown converted to UTC and a "UTC" label
/// appears where the legacy widget showed none. This is acceptable because the
/// legacy path is dev/test-only and is deleted at I4. Documented here so it
/// is not a surprise during interim testing.
///
/// This bridge exists only to keep legacy callers (`home_screen`,
/// `date_records_screen`) working until they are migrated to the new read
/// path. New callers should use [diaryEntryViewOf] with a [DiaryEntryRow].
DiaryEntryView diaryEntryViewFromLegacy(DiaryEntry entry) {
  if (entry.entryType == 'epistaxis_event') {
    final a = entry.currentAnswers;
    // Translate legacy keys → EpistaxisEventPayload keys.
    final translated = <String, Object?>{
      ...a,
      if (a.containsKey('startTimeTimezone') && !a.containsKey('startTimeZone'))
        'startTimeZone': a['startTimeTimezone'],
      if (a.containsKey('endTimeTimezone') && !a.containsKey('endTimeZone'))
        'endTimeZone': a['endTimeTimezone'],
      // EpistaxisEventPayload.fromJson requires startTimeUtcOffset; default to
      // '+00:00' when the legacy row doesn't carry it (display-only field).
      if (!a.containsKey('startTimeUtcOffset')) 'startTimeUtcOffset': '+00:00',
      // Ensure startTimeZone is present; fall back to 'UTC' when neither key
      // is present in the legacy answers (no timezone was stored).
      if (!a.containsKey('startTimeZone') &&
          !a.containsKey('startTimeTimezone'))
        'startTimeZone': 'UTC',
    };
    final row = DiaryEntryRow(
      aggregateId: entry.entryId,
      entryType: entry.entryType,
      data: translated,
    );
    return EpistaxisEntryView(row, isComplete: entry.isComplete);
  }
  // Day-marker types (no_epistaxis_event, unknown_day_event, …).
  final row = DiaryEntryRow(
    aggregateId: entry.entryId,
    entryType: entry.entryType,
    data: Map<String, Object?>.from(entry.currentAnswers),
  );
  return DayMarkerView(row, isComplete: entry.isComplete);
}
