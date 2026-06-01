// lib/read/diary_overlap.dart
// Implements: DIARY-DEV-reactive-read-path/A — pure unresolved-overlap pair
//   derivation over the finalized canonical rows in a DiaryView. No stored
//   projection; same native, derive-don't-cache shape as dayStatusForLocalDate.
// Implements: DIARY-PRD-entry-overlap-resolution/A+B
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_view.dart';

/// One unresolved overlap: the [preExisting] entry (rendered on the LEFT) and
/// the [justTouched] entry (rendered on the RIGHT). "Just touched" is the row
/// with the later `updated_at`; ties break on `aggregateId`.
class OverlapPair {
  const OverlapPair({required this.preExisting, required this.justTouched});
  final EpistaxisEntryView preExisting;
  final EpistaxisEntryView justTouched;
}

/// Whether two epistaxis entries' `[start, end]` ranges intersect. An open-ended
/// entry (no end) is treated as a point at its start. Touching endpoints do NOT
/// overlap (open intervals), mirroring `overlappingEpistaxisEntries`.
bool epistaxisRangesOverlap(EpistaxisEntryView a, EpistaxisEntryView b) {
  final aEnd = a.endTime ?? a.startTime;
  final bEnd = b.endTime ?? b.startTime;
  return a.startTime.isBefore(bEnd) && aEnd.isAfter(b.startTime);
}

/// All unresolved overlapping pairs among the finalized epistaxis entries in
/// [view], one entry per pair on each side. Pairwise (a 3-way pile-up yields its
/// constituent overlapping pairs); resolution + re-derivation cascades.
List<OverlapPair> overlapPairs(DiaryView view) {
  final eps = view.finalizedRows
      .where((r) => r.entryType == 'epistaxis_event')
      // diaryEntryViewOf returns an EpistaxisEntryView for an 'epistaxis_event'
      // row, so this cast never actually drops an entry — it just narrows type.
      .map((r) => diaryEntryViewOf(r, isComplete: true))
      .whereType<EpistaxisEntryView>()
      .toList();
  final out = <OverlapPair>[];
  for (var i = 0; i < eps.length; i++) {
    for (var j = i + 1; j < eps.length; j++) {
      final x = eps[i];
      final y = eps[j];
      if (!epistaxisRangesOverlap(x, y)) continue;
      final (left, right) = _order(x, y);
      out.add(OverlapPair(preExisting: left, justTouched: right));
    }
  }
  // Steady, deterministic surface: order pairs by the earlier of the two
  // entries' start times (the chronologically-first overlap surfaces first),
  // then by the two aggregate ids. Note this is the earlier START time, which
  // is independent of which entry is preExisting/justTouched (that is by
  // recency, not start time).
  DateTime earlierStart(OverlapPair p) =>
      p.preExisting.startTime.isBefore(p.justTouched.startTime)
      ? p.preExisting.startTime
      : p.justTouched.startTime;
  out.sort((p, q) {
    final byStart = earlierStart(p).compareTo(earlierStart(q));
    if (byStart != 0) return byStart;
    final byLeft = p.preExisting.aggregateId.compareTo(
      q.preExisting.aggregateId,
    );
    if (byLeft != 0) return byLeft;
    return p.justTouched.aggregateId.compareTo(q.justTouched.aggregateId);
  });
  return out;
}

/// Orders a pair into (preExisting/left, justTouched/right) by recency.
(EpistaxisEntryView, EpistaxisEntryView) _order(
  EpistaxisEntryView a,
  EpistaxisEntryView b,
) {
  final ua = _updatedAt(a);
  final ub = _updatedAt(b);
  final cmp = ua.compareTo(ub);
  if (cmp < 0) return (a, b);
  if (cmp > 0) return (b, a);
  return a.aggregateId.compareTo(b.aggregateId) < 0 ? (a, b) : (b, a);
}

/// The entry's last-event timestamp, read from the materialized view row's
/// `updated_at` field (snake_case, emitted by the library's `DiaryEntry.toJson`
/// via `DiaryEntriesMaterializer`). Falls back to epoch on a missing/malformed
/// value — not expected on a well-formed row, where it sorts the row as oldest.
DateTime _updatedAt(EpistaxisEntryView v) {
  final raw = v.row.data['updated_at'];
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
