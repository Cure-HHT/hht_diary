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
// Implements: REQ-d00129-C — value type is immutable; the registry's
// setStartDate enforces monotonic-backward semantics (later throws,
// earlier triggers gap replay) by constructing a new DestinationSchedule.
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

/// Result of `tombstoneAndRefill` — REQ-d00144-E.
///
/// Carries three operator-visible values: the `entry_id` of the target
/// row flipped to `tombstoned`, the count of trail null rows deleted in
/// the same transaction, and the value `fill_cursor` was rewound to.
// Implements: REQ-d00144-E — TombstoneAndRefillResult shape.
class TombstoneAndRefillResult {
  const TombstoneAndRefillResult({
    required this.targetRowId,
    required this.deletedTrailCount,
    required this.rewoundTo,
  });

  /// `entry_id` of the tombstoned target row.
  final String targetRowId;

  /// Count of null-finalStatus rows whose sequence_in_queue was strictly
  /// greater than the target's sequence_in_queue that were deleted from
  /// the FIFO store in the same transaction (REQ-d00144-C).
  final int deletedTrailCount;

  /// Value the per-destination fill_cursor was rewound to
  /// (REQ-d00144-D) — equals target.event_id_range.first_seq - 1.
  final int rewoundTo;
}
