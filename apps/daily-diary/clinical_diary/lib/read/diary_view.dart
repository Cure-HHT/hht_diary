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
       _incomplete = incomplete,
       incompleteDates = incomplete
           .map((r) => r.localDate)
           .whereType<String>()
           .toSet();

  final List<DiaryEntryRow> _finalized;
  final List<DiaryEntryRow> _incomplete;

  /// Local dates (`yyyy-MM-dd`) that have an open checkpoint.
  final Set<String> incompleteDates;

  /// Finalized entries as view-models, newest-first (by localDate desc, stable).
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

  /// Finalized entries whose localDate is in [days] (e.g. today + yesterday).
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
