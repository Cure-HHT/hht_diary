// Implements: DIARY-DEV-reactive-read-path/B+C — pure derivation over the two
//   diary views (finalized canonical + diary-local incomplete), reconstructed on
//   every emission so it holds NO authoritative state. Wraps diary_read.dart.
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';

/// Derived diary state for the current emission. Pure; rebuilt each update.
class DiaryView {
  DiaryView({
    required List<DiaryEntryRow> finalized,
    required List<DiaryEntryRow> incomplete,
  }) : _finalized = finalized,
       _incomplete = _disjointIncomplete(finalized, incomplete),
       incompleteDates = _disjointIncomplete(
         finalized,
         incomplete,
       ).map((r) => r.localDate).whereType<String>().toSet();

  /// Incomplete rows that are NOT also finalized. An aggregate that has been
  /// finalized is complete, even if a stale checkpoint row still lingers in the
  /// incomplete view (the projection's tombstone-on-finalize may be eventual);
  /// keeping the two disjoint is what makes the union a clean splice and stops
  /// the same aggregate id from rendering in both a finalized and an incomplete
  /// group (which would collide on a shared scroll-to GlobalKey).
  static List<DiaryEntryRow> _disjointIncomplete(
    List<DiaryEntryRow> finalized,
    List<DiaryEntryRow> incomplete,
  ) {
    final finalizedIds = finalized.map((r) => r.aggregateId).toSet();
    return incomplete
        .where((r) => !finalizedIds.contains(r.aggregateId))
        .toList();
  }

  final List<DiaryEntryRow> _finalized;
  final List<DiaryEntryRow> _incomplete;

  /// Local dates (`yyyy-MM-dd`) that have an open checkpoint. Exposed for direct
  /// date-membership checks; prefer [dayStatus] for precedence-aware status.
  final Set<String> incompleteDates;

  /// The raw finalized canonical rows. Exposed for row-level query helpers that
  /// operate on [DiaryEntryRow] (e.g. `overlappingEpistaxisEntries`) rather than
  /// the typed view-models.
  List<DiaryEntryRow> get finalizedRows => List.unmodifiable(_finalized);

  /// Finalized entries as view-models, newest-first (by localDate desc, stable).
  /// Null-localDate entries (e.g. surveys with no date) sort to the front
  /// (empty string precedes any `yyyy-MM-dd`).
  List<DiaryEntryView> get entries {
    final rows = [..._finalized]
      ..sort((a, b) => (b.localDate ?? '').compareTo(a.localDate ?? ''));
    return rows.map((r) => diaryEntryViewOf(r, isComplete: true)).toList();
  }

  /// In-progress (checkpoint) entries as view-models.
  List<DiaryEntryView> get incompleteEntries =>
      _incomplete.map((r) => diaryEntryViewOf(r, isComplete: false)).toList();

  /// Finalized entries on a specific local date.
  List<DiaryEntryView> entriesOn(String localDate) => entriesOnLocalDate(
    _finalized,
    localDate,
  ).map((r) => diaryEntryViewOf(r, isComplete: true)).toList();

  /// In-progress (checkpoint) entries on a specific local date. A day may hold
  /// an incomplete entry with no finalized entry (a partial recording the
  /// participant backed out of) — the day-records list surfaces these so the
  /// participant can resume them, rather than treating the day as empty.
  List<DiaryEntryView> incompleteEntriesOn(String localDate) =>
      entriesOnLocalDate(
        _incomplete,
        localDate,
      ).map((r) => diaryEntryViewOf(r, isComplete: false)).toList();

  /// Finalized entries whose localDate is in [days] (e.g. today + yesterday).
  /// Note: builds on [entries] (a copy+sort); avoid calling both in one build
  /// cycle when the sorted list is already in hand.
  List<DiaryEntryView> recent(List<String> days) => entries
      .where((v) => v.localDate != null && days.contains(v.localDate))
      .toList();

  /// Day status for the calendar / reminders (finalized + checkpoint-derived).
  DayStatus dayStatus(String localDate) => dayStatusForLocalDate(
    _finalized,
    localDate,
    incompleteDates: incompleteDates,
  );

  bool hadNosebleedOn(String localDate) =>
      hasNosebleedRelatedEntryOn(_finalized, localDate);

  List<String> uncovered(List<String> days) =>
      uncoveredDays(_finalized, days, incompleteDates: incompleteDates);
}
