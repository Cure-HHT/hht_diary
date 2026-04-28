// Implements: REQ-d00133-A — sole write API for clinical_diary widgets,
//   wrapping EntryService.record with NosebleedRecord-shaped helpers so the
//   existing UI layer keeps its data model.
// Implements: REQ-p00013-A+B — record-shaped read facade over the
//   materialized DiaryEntry view for the existing nosebleed UI.

import 'dart:async';

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/diary_entry_reader.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:uuid/uuid.dart';

/// Bridge between the existing UI layer (which speaks `NosebleedRecord`) and
/// the new event-sourcing datastore (which speaks DiaryEntry rows).
///
/// This bridge exists for one reason: the legacy nosebleed service embedded
/// itself deep into the UI, and the screens still expect `NosebleedRecord` as
/// their data model. The migration to `EntryService` only needs to swap the
/// data path; the UX widgets (TimePickerDial, IntensityPicker, EventListItem,
/// CalendarOverlay, OverlapWarning) keep working exactly as before.
///
/// On the write side, [addRecord] / [updateRecord] / [deleteRecord] /
/// [markNoNosebleeds] / [markUnknown] all funnel into [EntryService.record]
/// with the appropriate entry type and event type.
///
/// On the read side, the various read methods (getLocalMaterializedRecords,
/// getRecordsForStartDate, hasRecordsForYesterday) query [DiaryEntryReader]
/// and convert each DiaryEntry row back into a [NosebleedRecord] via
/// [diaryEntryToNosebleedRecord].
class DiaryEventBridge {
  DiaryEventBridge({
    required EntryService entryService,
    required DiaryEntryReader reader,
    Uuid? uuid,
  }) : _entryService = entryService,
       _reader = reader,
       _uuid = uuid ?? const Uuid();

  final EntryService _entryService;
  final DiaryEntryReader _reader;
  final Uuid _uuid;

  /// Generate a fresh aggregate ID using uuid v7.
  String generateRecordId() => _uuid.v7();

  // --------------------------------------------------------------------------
  // Writes
  // --------------------------------------------------------------------------

  /// Append a finalized epistaxis_event for a new nosebleed record.
  ///
  /// Returns the resulting [NosebleedRecord] (with the freshly generated ID).
  Future<NosebleedRecord> addRecord({
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    final id = generateRecordId();
    // ignore: use_null_aware_elements
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

    await _entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: id,
      eventType: 'finalized',
      answers: answers,
    );

    return NosebleedRecord(
      id: id,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isIncomplete: endTime == null || intensity == null,
      createdAt: DateTime.now(),
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );
  }

  /// Append a finalized epistaxis_event that supersedes [originalRecordId].
  ///
  /// In the event-sourcing model, "update" means a new finalized event on the
  /// same aggregate. The aggregate ID stays the same as the original record.
  Future<NosebleedRecord> updateRecord({
    required String originalRecordId,
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    String? changeReason,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
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

    await _entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: originalRecordId,
      eventType: 'finalized',
      answers: answers,
      changeReason: changeReason,
    );

    return NosebleedRecord(
      id: originalRecordId,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isIncomplete: endTime == null || intensity == null,
      createdAt: DateTime.now(),
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );
  }

  /// Append a tombstone event on [recordId] with the given [reason].
  ///
  /// Read the materialized row first to learn the entry type so we can
  /// tombstone the correct aggregate (epistaxis vs no_epistaxis vs
  /// unknown_day).
  Future<void> deleteRecord({
    required String recordId,
    required String reason,
  }) async {
    final entries = await _reader.entriesForDateRange(
      DateTime.utc(1970, 1, 1),
      DateTime.utc(9999, 1, 1),
    );
    final existing = entries.where((e) => e.entryId == recordId).toList();
    final entryType = existing.isNotEmpty
        ? existing.single.entryType
        : 'epistaxis_event';

    await _entryService.record(
      entryType: entryType,
      aggregateId: recordId,
      eventType: 'tombstone',
      answers: const <String, Object?>{},
      changeReason: reason,
    );
  }

  /// Append a finalized no_epistaxis_event for the given local-day [date].
  Future<NosebleedRecord> markNoNosebleeds(DateTime date) async {
    final id = generateRecordId();
    await _entryService.record(
      entryType: 'no_epistaxis_event',
      aggregateId: id,
      eventType: 'finalized',
      answers: {'date': DateTimeFormatter.format(date)},
    );
    return NosebleedRecord(
      id: id,
      startTime: date,
      isNoNosebleedsEvent: true,
      createdAt: DateTime.now(),
    );
  }

  /// Append a finalized unknown_day_event for the given local-day [date].
  Future<NosebleedRecord> markUnknown(DateTime date) async {
    final id = generateRecordId();
    await _entryService.record(
      entryType: 'unknown_day_event',
      aggregateId: id,
      eventType: 'finalized',
      answers: {'date': DateTimeFormatter.format(date)},
    );
    return NosebleedRecord(
      id: id,
      startTime: date,
      isUnknownEvent: true,
      createdAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Reads
  // --------------------------------------------------------------------------

  /// Returns all current materialized nosebleed-related records (the union of
  /// `epistaxis_event`, `no_epistaxis_event`, and `unknown_day_event`).
  /// Tombstoned entries are excluded.
  Future<List<NosebleedRecord>> getLocalMaterializedRecords() async {
    // Use a wide date range so we get every entry. The reader filters by
    // local-day, but a 1970→9999 range covers all real entries.
    final entries = await _reader.entriesForDateRange(
      DateTime.utc(1970, 1, 1),
      DateTime.utc(9999, 1, 1),
    );
    return entries
        .where(
          (e) =>
              !e.isDeleted &&
              (e.entryType == 'epistaxis_event' ||
                  e.entryType == 'no_epistaxis_event' ||
                  e.entryType == 'unknown_day_event'),
        )
        .map(diaryEntryToNosebleedRecord)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Returns nosebleed-related records for the given local calendar [date].
  Future<List<NosebleedRecord>> getRecordsForStartDate(DateTime date) async {
    final entries = await _reader.entriesForDate(date);
    return entries
        .where(
          (e) =>
              !e.isDeleted &&
              (e.entryType == 'epistaxis_event' ||
                  e.entryType == 'no_epistaxis_event' ||
                  e.entryType == 'unknown_day_event'),
        )
        .map(diaryEntryToNosebleedRecord)
        .toList();
  }

  /// True iff there is at least one nosebleed-related entry for yesterday.
  Future<bool> hasRecordsForYesterday() => _reader.hasEntriesForYesterday();

  /// Mirrors the legacy `getDayStatusRange` used by the calendar.
  Future<Map<DateTime, DayStatus>> getDayStatusRange(
    DateTime start,
    DateTime end,
  ) => _reader.dayStatusRange(start, end);

  /// Returns incomplete nosebleed-related entries (checkpointed,
  /// non-tombstoned).
  Future<List<NosebleedRecord>> getIncompleteRecords() async {
    final entries = await _reader.incompleteEntries();
    return entries
        .where(
          (e) =>
              !e.isDeleted &&
              (e.entryType == 'epistaxis_event' ||
                  e.entryType == 'no_epistaxis_event' ||
                  e.entryType == 'unknown_day_event'),
        )
        .map(diaryEntryToNosebleedRecord)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// DiaryEntry → NosebleedRecord conversion
// ---------------------------------------------------------------------------

/// Hydrate a [NosebleedRecord] from a [DiaryEntry] of one of the three
/// nosebleed-related entry types.
///
/// The conversion preserves field meaning:
/// - `entryId` becomes the record `id`.
/// - For `epistaxis_event`, fields are read from `currentAnswers` (`startTime`,
///   `endTime`, `intensity`, `notes`, `startTimeTimezone`,
///   `endTimeTimezone`).
/// - For `no_epistaxis_event` / `unknown_day_event`, the `date` answer
///   becomes both `startTime` and the day marker.
/// - `isComplete` from the materialized view drives `isIncomplete`.
/// - `isDeleted` is preserved.
NosebleedRecord diaryEntryToNosebleedRecord(DiaryEntry entry) {
  final answers = entry.currentAnswers;

  DateTime parse(String iso) => DateTimeFormatter.parse(iso);

  switch (entry.entryType) {
    case 'no_epistaxis_event':
      final date = answers['date'] is String
          ? parse(answers['date']! as String)
          : (entry.effectiveDate ?? entry.updatedAt);
      return NosebleedRecord(
        id: entry.entryId,
        startTime: date,
        isNoNosebleedsEvent: true,
        isDeleted: entry.isDeleted,
        createdAt: entry.updatedAt,
      );

    case 'unknown_day_event':
      final date = answers['date'] is String
          ? parse(answers['date']! as String)
          : (entry.effectiveDate ?? entry.updatedAt);
      return NosebleedRecord(
        id: entry.entryId,
        startTime: date,
        isUnknownEvent: true,
        isDeleted: entry.isDeleted,
        createdAt: entry.updatedAt,
      );

    case 'epistaxis_event':
    default:
      final startTimeRaw = answers['startTime'];
      final endTimeRaw = answers['endTime'];
      final intensityRaw = answers['intensity'];
      final notesRaw = answers['notes'];
      final startTzRaw = answers['startTimeTimezone'];
      final endTzRaw = answers['endTimeTimezone'];

      final startTime = startTimeRaw is String
          ? parse(startTimeRaw)
          : (entry.effectiveDate ?? entry.updatedAt);
      final endTime = endTimeRaw is String ? parse(endTimeRaw) : null;
      final intensity = intensityRaw is String
          ? NosebleedIntensity.fromString(intensityRaw)
          : null;

      // Treat the materialized-view's is_complete as authoritative for
      // is_incomplete. Tombstoned entries are filtered out by callers.
      return NosebleedRecord(
        id: entry.entryId,
        startTime: startTime,
        endTime: endTime,
        intensity: intensity,
        notes: notesRaw is String ? notesRaw : null,
        isIncomplete: !entry.isComplete,
        isDeleted: entry.isDeleted,
        startTimeTimezone: startTzRaw is String ? startTzRaw : null,
        endTimeTimezone: endTzRaw is String ? endTzRaw : null,
        createdAt: entry.updatedAt,
      );
  }
}
