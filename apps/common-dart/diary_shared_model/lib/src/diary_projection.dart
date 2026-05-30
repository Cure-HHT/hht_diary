// Implements: DIARY-DEV-shared-events-catalog/A+C+E
//   Refines: DIARY-PRD-epistaxis-capture-standard, DIARY-PRD-diary-start-day
//
// The canonical cross-wire projection for diary clinical entries, shared so the
// diary app and the portal fold the SAME finalized event log into the SAME
// rows (anti-drift). Only `finalized` events fold into the canonical view; a
// `tombstone` event deletes the aggregate's row. `checkpoint` (partial,
// resume-on-kill) events stay diary-LOCAL and are NOT part of the shared
// canonical state (frozen surface P6) — incomplete-day tracking is a per-app
// diary concern, not shared.
library;

import 'package:event_sourcing/event_sourcing.dart';

/// View name of the canonical diary-entries projection.
const String diaryEntriesViewName = 'diary_entries';

/// Aggregate type stamped on every diary entry event (clinical + survey).
const String diaryEntryAggregateType = 'DiaryEntry';

/// Canonical projection: one row per finalized diary entry aggregate
/// (`epistaxis_event` / `no_epistaxis_event` / `unknown_day_event` /
/// `<id>_survey`). Filtering by [diaryEntryAggregateType] captures the
/// dynamically-registered survey types too. A `tombstone` deletes the row.
const AggregateProjectionSpec diaryEntriesProjection = AggregateProjectionSpec(
  viewName: diaryEntriesViewName,
  interest: SubscriptionFilter(
    aggregateTypes: {diaryEntryAggregateType},
    eventTypes: {'finalized', 'tombstone'},
  ),
  tombstoneEventTypes: {'tombstone'},
);

/// The canonical local calendar date (`yyyy-MM-dd`) an entry falls on, derived
/// deterministically from the entry's OWN captured local timestamp — never the
/// reader's device timezone. For `epistaxis_event` it is the date component of
/// `startTime`; for `no_epistaxis_event` / `unknown_day_event` it is `date`.
///
/// The stored timestamps are already in the capture-timezone wall clock (their
/// ISO offset matches the captured `startTimeZone`), so the leading `yyyy-MM-dd`
/// component IS the canonical local day — no timezone conversion is needed,
/// which keeps the result replayable and device-independent. Returns `null`
/// when the field is absent or not a `yyyy-MM-dd[...]` string.
String? canonicalEntryDate(String entryTypeId, Map<String, Object?> payload) {
  final Object? raw = switch (entryTypeId) {
    'epistaxis_event' => payload['startTime'],
    'no_epistaxis_event' || 'unknown_day_event' => payload['date'],
    _ => null,
  };
  if (raw is! String || raw.isEmpty) return null;
  final tIndex = raw.indexOf('T');
  final datePart = tIndex >= 0 ? raw.substring(0, tIndex) : raw;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) return null;
  return datePart;
}
