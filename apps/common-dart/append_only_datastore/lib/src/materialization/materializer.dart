import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Folds an [StoredEvent] into the next [DiaryEntry] row in the
/// materialized view.
///
/// Pure function of its inputs — identical inputs always produce identical
/// outputs. The same function drives both the write path (called under
/// transaction in Phase 5's `EntryService.record`) and the offline rebuild
/// path (`rebuildMaterializedView`). Keeping the fold pure is what makes the
/// `diary_entries` store a cache: any divergence between the store and a
/// fresh rebuild is a bug, not a semantic difference.
///
/// Event-type folding rules per design-doc §6.2:
/// - `finalized`: whole-replace `current_answers` from `event.data.answers`;
///   `is_complete = true`.
/// - `checkpoint`: same replacement; `is_complete = false`.
/// - `tombstone`: flip `is_deleted = true`; preserve other fields from the
///   previous row. Tombstone-from-scratch is accepted and yields an empty,
///   deleted row.
///
/// `effective_date` walks `def.effectiveDatePath` as a dotted JSON path into
/// `current_answers`; when the path is null, does not resolve, or resolves
/// to a value that cannot be parsed as a `DateTime`, the result falls back
/// to `firstEventTimestamp`.
// Implements: REQ-d00121-A — pure function; no I/O, no clock, no randomness.
class Materializer {
  Materializer._();

  // Implements: REQ-d00121-B+C+D+E+F — fold event into view row per event_type;
  // whole-replacement answers for finalized/checkpoint, tombstone preserves
  // fields and flips is_deleted; latest_event_id/updated_at track event
  // identity; effective_date resolved via dotted-path lookup with fallback.
  static DiaryEntry apply({
    required DiaryEntry? previous,
    required StoredEvent event,
    required EntryTypeDefinition def,
    required DateTime firstEventTimestamp,
  }) {
    final eventAnswers = _extractAnswers(event);

    switch (event.eventType) {
      case 'tombstone':
        return DiaryEntry(
          entryId: event.aggregateId,
          entryType: previous?.entryType ?? event.entryType,
          effectiveDate:
              previous?.effectiveDate ??
              _resolveEffectiveDate(eventAnswers, def, firstEventTimestamp),
          currentAnswers: previous?.currentAnswers ?? const <String, Object?>{},
          isComplete: previous?.isComplete ?? false,
          isDeleted: true,
          latestEventId: event.eventId,
          updatedAt: event.clientTimestamp,
        );

      case 'finalized':
      case 'checkpoint':
        final isComplete = event.eventType == 'finalized';
        return DiaryEntry(
          entryId: event.aggregateId,
          entryType: event.entryType,
          effectiveDate: _resolveEffectiveDate(
            eventAnswers,
            def,
            firstEventTimestamp,
          ),
          currentAnswers: eventAnswers,
          isComplete: isComplete,
          isDeleted: previous?.isDeleted ?? false,
          latestEventId: event.eventId,
          updatedAt: event.clientTimestamp,
        );

      default:
        throw StateError(
          'Materializer.apply: unknown event_type "${event.eventType}" on '
          'event ${event.eventId}; expected finalized | checkpoint | tombstone',
        );
    }
  }

  static Map<String, Object?> _extractAnswers(StoredEvent event) {
    final raw = event.data['answers'];
    if (raw is Map) {
      return Map<String, Object?>.unmodifiable(Map<String, Object?>.from(raw));
    }
    return const <String, Object?>{};
  }

  // Implements: REQ-d00121-F — dotted-path dialect; arrays and filters out of
  // scope. Null path, unresolved path, or unparseable resolved value all fall
  // back to firstEventTimestamp.
  static DateTime _resolveEffectiveDate(
    Map<String, Object?> answers,
    EntryTypeDefinition def,
    DateTime firstEventTimestamp,
  ) {
    final path = def.effectiveDatePath;
    if (path == null || path.isEmpty) {
      return firstEventTimestamp;
    }
    final resolved = _walkDottedPath(answers, path);
    if (resolved is! String) {
      return firstEventTimestamp;
    }
    return DateTime.tryParse(resolved) ?? firstEventTimestamp;
  }

  static Object? _walkDottedPath(Map<String, Object?> root, String path) {
    final segments = path.split('.');
    Object? current = root;
    for (final segment in segments) {
      if (current is! Map) return null;
      if (!current.containsKey(segment)) return null;
      current = current[segment];
    }
    return current;
  }
}
