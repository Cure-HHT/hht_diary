// Test helper: view-model builders ([buildEpistaxisView], [buildDayMarkerView])
// for tests that render the native diary read-layer view models
// (`EpistaxisEntryView`, `DayMarkerView`) without spinning up a full backend.

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    as shared
    show EpistaxisEventPayload, NosebleedIntensity;

// ---------------------------------------------------------------------------
// View-model builders for the EventListItem API.
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
    participantId: 'P-test',
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
