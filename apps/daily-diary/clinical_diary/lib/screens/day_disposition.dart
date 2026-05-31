// Implements: DIARY-PRD-day-disposition/B
//   Shared re-disposition orchestration used by both CalendarScreen and
//   HomeScreen so the marker-tap / convert flow lives in one place. Pure
//   orchestration over existing actions (record_no_epistaxis_day /
//   record_unknown_day / record_epistaxis_event + delete_entry) — no new action
//   and no recording-screen "convert" mode (see
//   docs/superpowers/specs/2026-05-31-day-disposition-conversion-design.md).
import 'dart:async';

import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// The marker an in-progress re-disposition / convert may need to tombstone.
/// Identifies the aggregate + its entry type (`no_epistaxis_event` /
/// `unknown_day_event`) so the conversion can supersede it.
class MarkerToReplace {
  const MarkerToReplace({required this.aggregateId, required this.entryType});

  final String aggregateId;
  final String entryType;
}

/// Submit a whole-day marker (`record_no_epistaxis_day` / `record_unknown_day`)
/// for [localDate] (`yyyy-MM-dd`) through the scope's action submitter.
// Implements: DIARY-DEV-action-write-path/A
Future<void> _submitDayMarker(
  BuildContext context,
  String actionName,
  String localDate,
) async {
  await ReActionScope.of(context).actionSubmitter.submit(
    ActionSubmission(
      actionName: actionName,
      rawInput: <String, Object?>{'date': localDate},
    ),
  );
}

/// Tombstone a superseded [marker] with `changeReason: 'corrected'`. Failures
/// are non-fatal: the day transiently shows both entries until a later delete.
// Implements: DIARY-PRD-day-disposition/A+C
Future<void> _tombstoneMarker(
  BuildContext context,
  MarkerToReplace marker,
) async {
  await ReActionScope.of(context).actionSubmitter.submit(
    ActionSubmission(
      actionName: 'delete_entry',
      rawInput: <String, Object?>{
        'aggregateId': marker.aggregateId,
        'entryType': marker.entryType,
        'changeReason': 'corrected',
      },
    ),
  );
}

/// Push the recording screen for a NEW nosebleed on [localDay]; on a successful
/// save (the screen pops a non-null aggregate id) and when a [marker] is present
/// to replace, tombstone that marker. Returns the saved aggregate id, or null if
/// the participant backed out without saving (the marker is left untouched).
// Implements: DIARY-PRD-day-disposition/A+C
Future<String?> recordNosebleedReplacingMarker(
  BuildContext context, {
  required DateTime localDay,
  MarkerToReplace? marker,
}) async {
  final savedId = await Navigator.push<String?>(
    context,
    AppPageRoute(builder: (context) => RecordingScreen(initialDate: localDay)),
  );
  if (savedId != null && savedId.isNotEmpty && marker != null) {
    if (context.mounted) {
      await _tombstoneMarker(context, marker);
    }
  }
  return savedId;
}

/// Open the 3-choice [DaySelectionScreen] for [localDay] / [localDate], wiring:
/// - No nosebleeds → `record_no_epistaxis_day`.
/// - I don't recall → `record_unknown_day`.
/// - Record nosebleed → recording screen; on save, tombstone [marker] if present.
///
/// [marker] is the marker being re-dispositioned (null for a genuinely empty day
/// — nothing to tombstone). [DaySelectionScreen] itself stays callback-driven and
/// unchanged.
// Implements: DIARY-PRD-day-disposition/B
Future<void> showDayDispositionPicker(
  BuildContext context, {
  required DateTime localDay,
  required String localDate,
  MarkerToReplace? marker,
}) async {
  await Navigator.push<void>(
    context,
    AppPageRoute(
      builder: (pickerContext) => DaySelectionScreen(
        date: localDay,
        onAddNosebleed: () {
          Navigator.pop(pickerContext);
          // Fire-and-forget: the picker is already dismissed; the recording
          // flow + tombstone run against the parent screen's context.
          unawaited(
            recordNosebleedReplacingMarker(
              context,
              localDay: localDay,
              marker: marker,
            ),
          );
        },
        onNoNosebleeds: () async {
          await _submitDayMarker(context, 'record_no_epistaxis_day', localDate);
          if (pickerContext.mounted) {
            Navigator.pop(pickerContext);
          }
        },
        onUnknown: () async {
          await _submitDayMarker(context, 'record_unknown_day', localDate);
          if (pickerContext.mounted) {
            Navigator.pop(pickerContext);
          }
        },
      ),
    ),
  );
}
