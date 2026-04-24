import 'package:collection/collection.dart';

/// A row in the `diary_entries` materialized view.
///
/// One row per `aggregate_id`, kept up to date by the materializer on every
/// event append. The view is rebuildable from the event log; it is a
/// read-optimized projection, never the source of truth.
///
/// `currentAnswers` stores the latest full answer set under whole-replacement,
/// latest-wins merging semantics (see design doc §6.3). `effectiveDate` is
/// nullable — entry types without an `effective_date_path` in their
/// EntryTypeDefinition fall back to the first event's `client_timestamp`,
/// but that fallback happens in the materializer (Phase 3), not here; this
/// type simply carries whatever the materializer computed, or null if neither
/// source yielded a value.
// Implements: REQ-d00117-D — whole-row replace via upsertEntry keyed on
// entry_id; all eight columns carried by value.
class DiaryEntry {
  const DiaryEntry({
    required this.entryId,
    required this.entryType,
    required this.effectiveDate,
    required this.currentAnswers,
    required this.isComplete,
    required this.isDeleted,
    required this.latestEventId,
    required this.updatedAt,
  });

  /// Decode from snake_case JSON; throws [FormatException] on missing or
  /// wrong-typed fields. `currentAnswers` is wrapped `Map.unmodifiable` so
  /// downstream consumers cannot mutate the cached payload in place.
  factory DiaryEntry.fromJson(Map<String, Object?> json) {
    final entryId = json['entry_id'];
    if (entryId is! String) {
      throw const FormatException(
        'DiaryEntry: missing or non-string "entry_id"',
      );
    }
    final entryType = json['entry_type'];
    if (entryType is! String) {
      throw const FormatException(
        'DiaryEntry: missing or non-string "entry_type"',
      );
    }
    final effectiveDateRaw = json['effective_date'];
    if (effectiveDateRaw != null && effectiveDateRaw is! String) {
      throw const FormatException(
        'DiaryEntry: "effective_date" must be a String when present',
      );
    }
    final answersRaw = json['current_answers'];
    if (answersRaw is! Map) {
      throw const FormatException(
        'DiaryEntry: missing or non-Map "current_answers"',
      );
    }
    final isComplete = json['is_complete'];
    if (isComplete is! bool) {
      throw const FormatException(
        'DiaryEntry: missing or non-bool "is_complete"',
      );
    }
    final isDeleted = json['is_deleted'];
    if (isDeleted is! bool) {
      throw const FormatException(
        'DiaryEntry: missing or non-bool "is_deleted"',
      );
    }
    final latestEventId = json['latest_event_id'];
    if (latestEventId is! String) {
      throw const FormatException(
        'DiaryEntry: missing or non-string "latest_event_id"',
      );
    }
    final updatedAtRaw = json['updated_at'];
    if (updatedAtRaw is! String) {
      throw const FormatException(
        'DiaryEntry: missing or non-string "updated_at"',
      );
    }
    return DiaryEntry(
      entryId: entryId,
      entryType: entryType,
      effectiveDate: effectiveDateRaw == null
          ? null
          : DateTime.parse(effectiveDateRaw as String),
      currentAnswers: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(answersRaw),
      ),
      isComplete: isComplete,
      isDeleted: isDeleted,
      latestEventId: latestEventId,
      updatedAt: DateTime.parse(updatedAtRaw),
    );
  }

  /// The aggregate_id — one per diary entry, stable across all its events.
  final String entryId;

  /// Entry-type identifier (e.g., `"epistaxis_event"`, `"nose_hht_survey"`).
  final String entryType;

  /// Patient-facing date the entry pertains to (may differ from `updatedAt`).
  /// Null when neither the entry type's `effective_date_path` nor the
  /// fallback yielded a value.
  final DateTime? effectiveDate;

  /// Whole-replacement answer set from the latest event on this aggregate.
  final Map<String, Object?> currentAnswers;

  /// True iff the most recent event on this aggregate was `event_type="finalized"`.
  final bool isComplete;

  /// True iff a `tombstone` event has been observed on this aggregate.
  final bool isDeleted;

  /// Event_id of the most recent event on this aggregate; the drain cursor.
  final String latestEventId;

  /// When the materializer last updated this row.
  final DateTime updatedAt;

  /// Encode to snake_case JSON. Optional fields emit explicit null.
  ///
  /// `effective_date` and `updated_at` are normalized to UTC before
  /// serializing. This makes the persisted strings sort correctly under
  /// lexicographic comparison, which is the basis for Sembast date-range
  /// queries in `SembastBackend.findEntries`. Callers that construct a
  /// `DiaryEntry` with a non-UTC `DateTime` SHALL have that instant
  /// converted on the way out; the round-trip returns a UTC `DateTime`.
  Map<String, Object?> toJson() => <String, Object?>{
    'entry_id': entryId,
    'entry_type': entryType,
    'effective_date': effectiveDate?.toUtc().toIso8601String(),
    'current_answers': currentAnswers,
    'is_complete': isComplete,
    'is_deleted': isDeleted,
    'latest_event_id': latestEventId,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntry &&
          entryId == other.entryId &&
          entryType == other.entryType &&
          effectiveDate == other.effectiveDate &&
          _deepEquals.equals(currentAnswers, other.currentAnswers) &&
          isComplete == other.isComplete &&
          isDeleted == other.isDeleted &&
          latestEventId == other.latestEventId &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    entryId,
    entryType,
    effectiveDate,
    _deepEquals.hash(currentAnswers),
    isComplete,
    isDeleted,
    latestEventId,
    updatedAt,
  );

  @override
  String toString() =>
      'DiaryEntry(entryId: $entryId, entryType: $entryType, '
      'effectiveDate: $effectiveDate, isComplete: $isComplete, '
      'isDeleted: $isDeleted, latestEventId: $latestEventId)';
}

const DeepCollectionEquality _deepEquals = DeepCollectionEquality();
