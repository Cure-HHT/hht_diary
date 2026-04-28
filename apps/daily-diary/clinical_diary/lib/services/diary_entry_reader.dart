// Implements: REQ-p00013-A+B+E (full history view);
//   REQ-p00004-E+L (event-derived view).

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Derived status for a calendar day, based on nosebleed-reporting compliance.
///
/// - [recorded]: at least one `epistaxis_event` (not tombstoned) exists.
/// - [noNosebleeds]: no epistaxis entries, but at least one `no_epistaxis_event`.
/// - [unknown]: neither of the above, but at least one `unknown_day_event`.
/// - [empty]: no nosebleed-related entries at all (questionnaires are ignored).
enum DayStatus { recorded, noNosebleeds, unknown, empty }

/// Entry-type identifiers that affect [DiaryEntryReader.dayStatus].
const _kEpistaxisType = 'epistaxis_event';
const _kNoEpistaxisType = 'no_epistaxis_event';
const _kUnknownDayType = 'unknown_day_event';

/// Thin wrapper around [SembastBackend.findEntries] that adds diary-shaped
/// [dayStatus] derivation and date-range query conveniences.
///
/// The reader never mutates the backend; it is a pure read facade. All
/// filtering that [SembastBackend.findEntries] cannot perform natively (e.g.,
/// local-calendar-day matching) is done in Dart on the returned list.
// Implements: REQ-p00013-A+B+E — full history of diary entries surfaced to
// callers without mutation; each query reflects the latest materialized view.
// Implements: REQ-p00004-E+L — event-derived materialized view rows are the
// sole source for this reader; no raw-event access required.
class DiaryEntryReader {
  DiaryEntryReader({required SembastBackend backend}) : _backend = backend;

  final SembastBackend _backend;

  // ---------------------------------------------------------------------------
  // entriesForDate
  // ---------------------------------------------------------------------------

  /// Returns all [DiaryEntry] rows whose [DiaryEntry.effectiveDate] falls on
  /// [date]'s local calendar day. If [entryType] is supplied, the result is
  /// further filtered to that entry type only.
  ///
  /// "Local calendar day" means the year/month/day triple as seen in the
  /// device's current time zone. The comparison is done in Dart after
  /// fetching the full (or entry-type-filtered) list from the backend,
  /// because [SembastBackend.findEntries] date filters operate on UTC ISO
  /// strings and cannot express local-date boundaries.
  Future<List<DiaryEntry>> entriesForDate(
    DateTime date, {
    String? entryType,
  }) async {
    final all = await _backend.findEntries(entryType: entryType);
    final localDate = _localDateOnly(date);
    return all
        .where((e) => e.effectiveDate != null)
        .where((e) => _localDateOnly(e.effectiveDate!) == localDate)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // entriesForDateRange
  // ---------------------------------------------------------------------------

  /// Returns all [DiaryEntry] rows whose [DiaryEntry.effectiveDate] falls
  /// within the inclusive date range [[from], [to]] (full local calendar days).
  ///
  /// Both bounds are compared as local calendar days (year/month/day triples).
  /// All entry types are included. Entries with a null [DiaryEntry.effectiveDate]
  /// are excluded.
  Future<List<DiaryEntry>> entriesForDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final all = await _backend.findEntries();
    final localFrom = _localDateOnly(from);
    final localTo = _localDateOnly(to);
    return all.where((e) => e.effectiveDate != null).where((e) {
      final localDate = _localDateOnly(e.effectiveDate!);
      return !localDate.isBefore(localFrom) && !localDate.isAfter(localTo);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // incompleteEntries
  // ---------------------------------------------------------------------------

  /// Returns all entries whose [DiaryEntry.isComplete] is `false`. If
  /// [entryType] is supplied, the result is filtered to that type only.
  ///
  /// The `is_complete == false` filter is passed directly to
  /// [SembastBackend.findEntries], which handles it natively.
  Future<List<DiaryEntry>> incompleteEntries({String? entryType}) async {
    return _backend.findEntries(entryType: entryType, isComplete: false);
  }

  // ---------------------------------------------------------------------------
  // hasEntriesForYesterday
  // ---------------------------------------------------------------------------

  /// Returns `true` iff there is at least one nosebleed-related entry
  /// (any of `epistaxis_event`, `no_epistaxis_event`, or `unknown_day_event`)
  /// whose [DiaryEntry.effectiveDate] falls on the local calendar day for
  /// yesterday.
  ///
  /// This mirrors the set of entry types that affect [dayStatus], so the
  /// return value is a compliance proxy: "did the patient report anything
  /// yesterday?"
  Future<bool> hasEntriesForYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    for (final type in [_kEpistaxisType, _kNoEpistaxisType, _kUnknownDayType]) {
      final entries = await entriesForDate(yesterday, entryType: type);
      if (entries.isNotEmpty) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // dayStatus
  // ---------------------------------------------------------------------------

  /// Derives a [DayStatus] for [date] from the nosebleed-related entries on
  /// that local calendar day.
  ///
  /// Precedence (highest to lowest):
  /// 1. [DayStatus.recorded] — at least one non-tombstoned `epistaxis_event`.
  /// 2. [DayStatus.noNosebleeds] — no epistaxis, but a non-tombstoned
  ///    `no_epistaxis_event`.
  /// 3. [DayStatus.unknown] — neither of the above, but a non-tombstoned
  ///    `unknown_day_event`.
  /// 4. [DayStatus.empty] — none of the above.
  ///
  /// Tombstoned entries ([DiaryEntry.isDeleted] == `true`) are excluded from
  /// all categories. Questionnaire entries (e.g., `nose_hht_survey`) are
  /// ignored entirely — they do not affect the compliance status for a day.
  // Implements: REQ-p00013-A+B+E — day-level compliance status derived from
  // the event-sourced materialized view; tombstones respected.
  // Implements: REQ-p00004-E+L — read path uses only the materialized view.
  Future<DayStatus> dayStatus(DateTime date) async {
    bool hasLive(List<DiaryEntry> entries) => entries.any((e) => !e.isDeleted);

    final epistaxis = await entriesForDate(date, entryType: _kEpistaxisType);
    if (hasLive(epistaxis)) return DayStatus.recorded;

    final noEpistaxis = await entriesForDate(
      date,
      entryType: _kNoEpistaxisType,
    );
    if (hasLive(noEpistaxis)) return DayStatus.noNosebleeds;

    final unknownDay = await entriesForDate(date, entryType: _kUnknownDayType);
    if (hasLive(unknownDay)) return DayStatus.unknown;

    return DayStatus.empty;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a [DateTime] representing midnight (00:00:00) in local time for
  /// the given [dt]'s local year/month/day. The returned value is used only
  /// for equality comparison, so the timezone of [dt] does not matter — we
  /// always read back the local triple.
  static DateTime _localDateOnly(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
