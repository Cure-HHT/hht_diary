import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';

/// Maintains the `diary_entries` materialized view from events whose
/// `aggregateType == 'DiaryEntry'`. Pure fold extracted as
/// `foldPure(...)` so callers that already hold the prior row (e.g.,
/// `rebuildView` streaming accumulator) can reuse it without going
/// through the backend.
// Implements: REQ-d00140-A — concrete materializer for diary_entries.
class DiaryEntriesMaterializer extends Materializer {
  const DiaryEntriesMaterializer();

  @override
  String get viewName => 'diary_entries';

  @override
  bool appliesTo(StoredEvent event) => event.aggregateType == 'DiaryEntry';

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    final priorRowRaw = await backend.readViewRowInTxn(
      txn,
      viewName,
      event.aggregateId,
    );
    final prior = priorRowRaw == null ? null : DiaryEntry.fromJson(priorRowRaw);
    final firstTs = aggregateHistory.isEmpty
        ? event.clientTimestamp
        : aggregateHistory.first.clientTimestamp;
    final next = foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: firstTs,
    );
    await backend.upsertViewRowInTxn(
      txn,
      viewName,
      next.entryId,
      next.toJson(),
    );
  }

  /// Pure fold (no I/O). Preserves the Phase-3 `Materializer.apply` entry
  /// point for reuse by rebuild, `EntryService.record`, and unit tests.
  ///
  /// Event-type folding rules:
  /// - `finalized`: merge `event.data.answers` into `current_answers`;
  ///   `is_complete = true`.
  /// - `checkpoint`: merge `event.data.answers` into `current_answers`;
  ///   `is_complete = false`.
  /// - `tombstone`: flip `is_deleted = true`; preserve other fields.
  // Implements: REQ-d00121-B+C+D+E+F+J — fold event into view row per
  // event_type; key-wise merge of answers for finalized/checkpoint
  // (absent key preserves prior, present key overwrites including
  // null-as-clear), tombstone preserves fields and flips is_deleted;
  // effective_date resolved from merged answers via dotted-path lookup
  // with fallback.
  static DiaryEntry foldPure({
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
        final merged = mergeAnswers(
          previous?.currentAnswers ?? const <String, Object?>{},
          eventAnswers,
        );
        return DiaryEntry(
          entryId: event.aggregateId,
          entryType: event.entryType,
          effectiveDate: _resolveEffectiveDate(
            merged,
            def,
            firstEventTimestamp,
          ),
          currentAnswers: merged,
          isComplete: isComplete,
          isDeleted: previous?.isDeleted ?? false,
          latestEventId: event.eventId,
          updatedAt: event.clientTimestamp,
        );
      default:
        throw StateError(
          'DiaryEntriesMaterializer.foldPure: unknown event_type '
          '"${event.eventType}" on event ${event.eventId}; expected '
          'finalized | checkpoint | tombstone',
        );
    }
  }

  /// Merge an event's delta into the prior `current_answers` map.
  ///
  /// Each key present in [delta] overwrites the corresponding key in
  /// [prior], including when the delta's value is `null` (explicit clear).
  /// Each key absent from [delta] preserves the prior value. The iteration
  /// uses `delta.keys` rather than indexing, so "key absent" and "key
  /// present with null value" are distinguished per REQ-d00121-J.
  ///
  /// Returns an unmodifiable map.
  // Implements: REQ-d00121-B+C+J — key-wise merge that preserves the
  // absent-vs-present-null distinction via iteration over the delta's
  // key set.
  static Map<String, Object?> mergeAnswers(
    Map<String, Object?> prior,
    Map<String, Object?> delta,
  ) {
    final merged = Map<String, Object?>.from(prior);
    for (final key in delta.keys) {
      merged[key] = delta[key];
    }
    return Map<String, Object?>.unmodifiable(merged);
  }
}

Map<String, Object?> _extractAnswers(StoredEvent event) {
  final raw = event.data['answers'];
  if (raw is Map) {
    return Map<String, Object?>.unmodifiable(Map<String, Object?>.from(raw));
  }
  return const <String, Object?>{};
}

DateTime _resolveEffectiveDate(
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

Object? _walkDottedPath(Map<String, Object?> root, String path) {
  final segments = path.split('.');
  Object? current = root;
  for (final segment in segments) {
    if (current is! Map) return null;
    if (!current.containsKey(segment)) return null;
    current = current[segment];
  }
  return current;
}
