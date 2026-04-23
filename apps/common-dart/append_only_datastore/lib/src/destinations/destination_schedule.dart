/// Persisted schedule for a registered `Destination`.
///
/// The pair `(startDate, endDate)` defines the wall-clock window during
/// which events match this destination's time-window filter
/// (REQ-d00129-I). Both fields are nullable at construction:
///
/// - `startDate == null` is the "dormant" state a destination enters on
///   initial `addDestination` before any `setStartDate` call. Dormant
///   destinations do not accept any FIFO rows regardless of current time
///   (REQ-d00129-A + REQ-d00129-C).
/// - `endDate == null` is "no scheduled end" — the destination is active
///   for all time once `startDate` has elapsed. A later `setEndDate` call
///   may populate it (REQ-d00129-F).
///
/// The value type is deliberately immutable; `DestinationRegistry`
/// mutations construct a new `DestinationSchedule` and persist it.
// Implements: REQ-d00129-A — initial schedule is dormant (startDate = null).
// Implements: REQ-d00129-C — startDate, once set, is immutable at the
// value-type level (setStartDate in the registry enforces one-shot write).
// Implements: REQ-d00129-F — isActiveAt / closed/scheduled/applied
// classification drives SetEndDateResult.
class DestinationSchedule {
  /// Construct a schedule. Either field may be null — see class doc.
  const DestinationSchedule({this.startDate, this.endDate});

  /// Inverse of [toJson]. `null` fields parse back to `null` DateTime.
  factory DestinationSchedule.fromJson(Map<String, Object?> json) {
    final start = json['start_date'] as String?;
    final end = json['end_date'] as String?;
    return DestinationSchedule(
      startDate: start == null ? null : DateTime.parse(start),
      endDate: end == null ? null : DateTime.parse(end),
    );
  }

  /// Wall-clock time at which this destination starts accepting events.
  /// Null means "dormant" — no `startDate` has been assigned yet.
  final DateTime? startDate;

  /// Wall-clock time at which this destination stops accepting new events.
  /// Null means "no scheduled end" — active indefinitely once `startDate`
  /// has elapsed.
  final DateTime? endDate;

  /// True when no `startDate` has been assigned; the destination is
  /// registered but not yet active for any wall-clock time.
  bool get isDormant => startDate == null;

  /// True iff `startDate <= now < endDate`, treating a null `endDate` as
  /// an open-ended right bound. A dormant schedule (null `startDate`) is
  /// never active — dormant is strictly pre-active.
  bool isActiveAt(DateTime now) =>
      startDate != null &&
      startDate!.compareTo(now) <= 0 &&
      (endDate == null || endDate!.compareTo(now) > 0);

  /// JSON representation used by `StorageBackend.writeSchedule`. Both
  /// fields serialize to either an ISO-8601 string or `null`.
  Map<String, Object?> toJson() => {
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DestinationSchedule &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);

  @override
  String toString() =>
      'DestinationSchedule(startDate: $startDate, endDate: $endDate)';
}

/// Return code from `DestinationRegistry.setEndDate`.
///
/// Exactly one of the three is returned per call (REQ-d00129-F):
///
/// - `closed` — the call transitions the destination from currently active
///   to currently closed (new `endDate <= now`, prior state was active).
/// - `scheduled` — the new `endDate` is in the future, either from an
///   active state (closure is scheduled later) or from a previously-closed
///   state reopened with a future end.
/// - `applied` — no change in the current active-vs-closed classification
///   relative to `now`. For example, overwriting a past `endDate` with a
///   different past value, or replacing a future-dated `endDate` with
///   another future-dated one that does not cross the `now` boundary.
// Implements: REQ-d00129-F — SetEndDateResult enum: closed, scheduled, applied.
enum SetEndDateResult { closed, scheduled, applied }

/// Result of `DestinationRegistry.unjamDestination` (Task 14). Kept in
/// this file so later tasks don't introduce import churn. Carries two
/// operator-visible counts: how many pending rows were dropped, and the
/// value the `fill_cursor` was rewound to after the unjam.
// Implements: REQ-d00131 — UnjamResult carries deletedPending + rewoundTo
// for operator diagnostics. Consumed by Task 14.
class UnjamResult {
  const UnjamResult({required this.deletedPending, required this.rewoundTo});

  /// Count of `pending` rows dropped from the destination's FIFO by the
  /// unjam.
  final int deletedPending;

  /// Value that `fill_cursor_<destId>` was set to after the unjam. `-1`
  /// when no surviving `sent` row exists (rewound to pre-start).
  final int rewoundTo;
}
