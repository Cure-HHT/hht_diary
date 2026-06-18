// Implements: DIARY-GUI-calendar-day-view/A
//   Refines: DIARY-PRD-epistaxis-capture-standard
//
// Per-app diary read layer (A4): typed rows + pure query logic over the shared
// canonical `diary_entries` projection, reproducing the legacy DiaryEntryReader
// semantics so they can be differentially compared against it. The canonical
// view holds only FINALIZED entries (checkpoints are diary-local, frozen P6), so
// every row here is complete; the `incomplete` day-status therefore comes from
// the diary-local set of aggregates that have an open checkpoint, passed in
// separately.
import 'package:diary_shared_model/diary_shared_model.dart';

/// Compliance status for a single local calendar day. Mirrors the legacy
/// `DayStatus`, highest-precedence first.
enum DayStatus { nosebleed, noNosebleed, unknown, incomplete, notRecorded }

/// A typed view of one canonical `diary_entries` row.
class DiaryEntryRow {
  const DiaryEntryRow({
    required this.aggregateId,
    required this.entryType,
    required this.data,
  });

  factory DiaryEntryRow.fromViewRow(Map<String, Object?> row) {
    return DiaryEntryRow(
      aggregateId: row['aggregateId']! as String,
      entryType: row['entryType'] as String? ?? _inferEntryType(row),
      data: row,
    );
  }

  final String aggregateId;
  final String entryType;
  final Map<String, Object?> data;

  /// The canonical local calendar date (`yyyy-MM-dd`) this entry falls on, or
  /// null if it carries no date. A `<id>_survey` derives its date from
  /// `completed_at`, so finalized surveys are dated.
  String? get localDate => canonicalEntryDate(entryType, data);

  // The view row merges the payload; entryType is carried on the event but the
  // aggregate row may not echo it, so callers should prefer passing it. As a
  // fallback we infer from the payload shape.
  static String _inferEntryType(Map<String, Object?> row) {
    if (row.containsKey('startTime')) return 'epistaxis_event';
    return 'unknown_day_event';
  }
}

/// All entries whose canonical local date equals [localDate] (`yyyy-MM-dd`),
/// optionally filtered to one [entryType].
List<DiaryEntryRow> entriesOnLocalDate(
  Iterable<DiaryEntryRow> rows,
  String localDate, {
  String? entryType,
}) {
  return rows
      .where((r) => r.localDate == localDate)
      .where((r) => entryType == null || r.entryType == entryType)
      .toList();
}

/// Derives the [DayStatus] for [localDate] from the canonical (finalized) rows,
/// applying the legacy precedence: nosebleed > noNosebleed > unknown >
/// incomplete > notRecorded. [incompleteDates] is the diary-local set of
/// `yyyy-MM-dd` days that have an open checkpoint but no finalized entry.
DayStatus dayStatusForLocalDate(
  Iterable<DiaryEntryRow> rows,
  String localDate, {
  Set<String> incompleteDates = const <String>{},
}) {
  final onDay = entriesOnLocalDate(rows, localDate);
  bool has(String t) => onDay.any((r) => r.entryType == t);
  if (has('epistaxis_event')) return DayStatus.nosebleed;
  if (has('no_epistaxis_event')) return DayStatus.noNosebleed;
  if (has('unknown_day_event')) return DayStatus.unknown;
  if (incompleteDates.contains(localDate)) return DayStatus.incomplete;
  return DayStatus.notRecorded;
}

/// The nosebleed-related entry types that contribute to day coverage.
const Set<String> nosebleedRelatedEntryTypes = <String>{
  'epistaxis_event',
  'no_epistaxis_event',
  'unknown_day_event',
};

/// Whether any nosebleed-related entry exists on [localDate] — backs the
/// "you didn't record yesterday" reminder (DIARY-PRD-notification-yesterday-entry).
bool hasNosebleedRelatedEntryOn(
  Iterable<DiaryEntryRow> rows,
  String localDate,
) {
  return entriesOnLocalDate(
    rows,
    localDate,
  ).any((r) => nosebleedRelatedEntryTypes.contains(r.entryType));
}

/// Local dates (`yyyy-MM-dd`) in the inclusive [days] window with no recorded
/// coverage (`notRecorded`) — backs the historical-gap reminder
/// (DIARY-PRD-notification-historical-gap). [days] is the caller-supplied list
/// of local calendar days to check (the caller owns timezone/calendar walking).
List<String> uncoveredDays(
  Iterable<DiaryEntryRow> rows,
  List<String> days, {
  Set<String> incompleteDates = const <String>{},
}) {
  return days
      .where(
        (d) =>
            dayStatusForLocalDate(rows, d, incompleteDates: incompleteDates) ==
            DayStatus.notRecorded,
      )
      .toList();
}

/// Whether two epistaxis time ranges intersect under the canonical `[start, end)`
/// convention: the start instant is INCLUDED, the end instant EXCLUDED (CUR-715).
/// A zero-length range (`end == start`, e.g. an open-ended entry or a candidate
/// whose end is not set yet) occupies the single `start` instant. Consequences:
///   * a point on another range's START overlaps (start is inclusive),
///   * a point on another range's END does NOT overlap (end is exclusive),
///   * adjacency (one range's end == the next range's start) does NOT overlap.
///
/// This is the single source of truth shared by [overlappingEpistaxisEntries]
/// (the warning) and `epistaxisRangesOverlap` (the pairs view) so the two never
/// drift on boundary semantics.
// Implements: DIARY-PRD-entry-overlap-resolution/B
bool epistaxisIntervalsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  final aIsPoint = !aEnd.isAfter(aStart); // aEnd <= aStart
  final bIsPoint = !bEnd.isAfter(bStart);
  if (aIsPoint && bIsPoint) return aStart.isAtSameMomentAs(bStart);
  // A point overlaps a range iff it lies in the half-open `[start, end)`:
  // start <= point < end.
  if (aIsPoint) return !aStart.isBefore(bStart) && aStart.isBefore(bEnd);
  if (bIsPoint) return !bStart.isBefore(aStart) && bStart.isBefore(aEnd);
  // Two real ranges: standard half-open intersection (touching ends excluded).
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

/// Epistaxis rows whose recorded `[startTime, endTime)` intersects the candidate
/// range `[candidateStart, candidateEnd)`. Open-ended entries (no endTime) and a
/// not-yet-ended candidate (`candidateEnd == candidateStart`) are treated as a
/// point at their startTime; start is inclusive, end exclusive (see
/// [epistaxisIntervalsOverlap]). [excludeAggregateId] drops the entry being
/// edited. Backs the overlap warning (DIARY-PRD-entry-overlap-resolution).
// Implements: DIARY-PRD-entry-overlap-resolution
List<DiaryEntryRow> overlappingEpistaxisEntries(
  Iterable<DiaryEntryRow> rows,
  DateTime candidateStart,
  DateTime candidateEnd, {
  String? excludeAggregateId,
}) {
  final out = <DiaryEntryRow>[];
  for (final r in rows) {
    if (r.entryType != 'epistaxis_event') continue;
    if (excludeAggregateId != null && r.aggregateId == excludeAggregateId) {
      continue;
    }
    final startRaw = r.data['startTime'];
    if (startRaw is! String) continue;
    final start = DateTime.tryParse(startRaw);
    if (start == null) continue;
    final endRaw = r.data['endTime'];
    final end = endRaw is String ? (DateTime.tryParse(endRaw) ?? start) : start;
    if (epistaxisIntervalsOverlap(start, end, candidateStart, candidateEnd)) {
      out.add(r);
    }
  }
  return out;
}
