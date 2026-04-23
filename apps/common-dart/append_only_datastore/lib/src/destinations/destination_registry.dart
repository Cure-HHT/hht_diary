import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/sync/historical_replay.dart';

/// Process-wide registry of synchronization destinations.
///
/// Under REQ-d00129, the registry supports a dynamic lifecycle: destinations
/// may be added at any time after bootstrap, their `startDate` may be set
/// exactly once (immutable once assigned), their `endDate` may be mutated,
/// and they may be deactivated or hard-deleted per the per-destination
/// `allowHardDelete` opt-in. The old "boot-time-only, freeze on first read"
/// contract (REQ-d00122-G, Phase 4) has been superseded by this one.
///
/// The registry is bound to a `StorageBackend` at construction so that
/// schedule mutations (`setStartDate`, `setEndDate`) and destination
/// deletions (`deleteDestination`) persist through the backend's
/// transactional contract. Production code constructs a single instance
/// during bootstrap; tests construct a fresh instance per test against
/// an in-memory `SembastBackend`.
// Implements: REQ-d00122-A — destination ids are unique in the registry.
// Implements: REQ-d00129-A — addDestination accepts registrations at any
// time after bootstrap; duplicate id is rejected.
// Implements: REQ-d00129-C — setStartDate is one-shot immutable.
// Implements: REQ-d00129-F+G — setEndDate returns SetEndDateResult;
// deactivateDestination is the now() shorthand.
// Implements: REQ-d00129-H — deleteDestination is gated on allowHardDelete
// and drops the schedule + FIFO store atomically.
class DestinationRegistry {
  /// Construct a registry bound to [backend]. The registry does not open
  /// the database — the caller retains ownership of the backend's
  /// lifecycle.
  DestinationRegistry({required this.backend});

  /// Backend used for schedule persistence and FIFO-store drop on
  /// delete. Stored as a final field so the binding is established at
  /// construction and cannot drift.
  final StorageBackend backend;

  final Map<String, Destination> _destinations = <String, Destination>{};
  final Map<String, DestinationSchedule> _schedules =
      <String, DestinationSchedule>{};

  /// Register [destination]. Seeds the in-memory schedule cache with a
  /// dormant `DestinationSchedule` (no `startDate`, no `endDate`) and
  /// persists that initial schedule so a subsequent process restart
  /// recovers the same dormant state.
  ///
  /// Throws `ArgumentError` if a destination with the same id is already
  /// registered (REQ-d00129-A).
  // Implements: REQ-d00129-A — addDestination at any time after
  // bootstrap; duplicate id rejected with ArgumentError.
  // Implements: REQ-d00129-C — addDestination preserves any persisted
  // schedule across process restart, so setStartDate's one-shot
  // immutability survives bootstrap re-running addDestination with the
  // same id. Only seeds a dormant schedule when no schedule is persisted.
  Future<void> addDestination(Destination destination) async {
    if (_destinations.containsKey(destination.id)) {
      throw ArgumentError.value(
        destination.id,
        'destination.id',
        'destination id ${destination.id} is already registered '
            '(REQ-d00129-A)',
      );
    }
    _destinations[destination.id] = destination;
    final persisted = await backend.readSchedule(destination.id);
    if (persisted != null) {
      _schedules[destination.id] = persisted;
    } else {
      const dormant = DestinationSchedule();
      _schedules[destination.id] = dormant;
      await backend.writeSchedule(destination.id, dormant);
    }
  }

  /// All registered destinations, in registration order. Returned list
  /// is unmodifiable so callers cannot mutate the registry by mutating
  /// the view.
  List<Destination> all() =>
      List<Destination>.unmodifiable(_destinations.values);

  /// Destination with [id], or null when no such destination has been
  /// registered. Does not consult persistence — only in-memory state.
  Destination? byId(String id) => _destinations[id];

  /// Read the current `DestinationSchedule` for [id]. Reads from the
  /// in-memory cache; the cache is populated by `addDestination` and
  /// kept current by `setStartDate` / `setEndDate`. Throws
  /// `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-A+C+F — schedule read surface for
  // downstream fillBatch time-window filtering.
  Future<DestinationSchedule> scheduleOf(String id) async {
    final cached = _schedules[id];
    if (cached != null) return cached;
    final persisted = await backend.readSchedule(id);
    if (persisted != null) {
      _schedules[id] = persisted;
      return persisted;
    }
    throw ArgumentError.value(
      id,
      'id',
      'no destination registered with id $id',
    );
  }

  /// Assign [startDate] to the destination identified by [id]. The
  /// assignment is one-shot immutable — a subsequent call throws
  /// `StateError` (REQ-d00129-C).
  ///
  /// When [startDate] is at or before `DateTime.now()`, the call
  /// triggers historical replay synchronously in the same transaction
  /// as the schedule write (REQ-d00129-D). Replay walks the event log
  /// past `fill_cursor`, builds batches via the destination's own
  /// `canAddToBatch` and `transform`, and enqueues matching events into
  /// the destination's FIFO so rows are indistinguishable from those
  /// `fillBatch` would produce during live operation (REQ-d00130-A+B).
  /// When [startDate] is in the future, no replay runs — events
  /// accumulate in `event_log` and are batched by `fillBatch` once the
  /// wall-clock crosses `startDate` (REQ-d00129-E).
  ///
  /// Throws `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-C — setStartDate throws StateError if already
  // set; the value is immutable once assigned.
  // Implements: REQ-d00129-D — past startDate triggers historical replay
  // synchronously inside the same transaction as the schedule write.
  // Implements: REQ-d00129-E — future startDate does NOT trigger replay.
  Future<void> setStartDate(String id, DateTime startDate) async {
    if (!_destinations.containsKey(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    final current = _schedules[id] ?? const DestinationSchedule();
    if (current.startDate != null) {
      throw StateError(
        'DestinationRegistry.setStartDate($id): startDate is already set '
        'to ${current.startDate}; startDate is immutable once assigned '
        '(REQ-d00129-C).',
      );
    }
    final updated = DestinationSchedule(
      startDate: startDate,
      endDate: current.endDate,
    );
    // The schedule write and (when applicable) the replay must commit
    // together. Running replay in the same transaction as the schedule
    // write provides the serialization guarantee REQ-d00130-C relies
    // on: a concurrent record() serializes behind this transaction and
    // walks candidates strictly past the advanced fill_cursor.
    await backend.transaction((txn) async {
      await backend.writeScheduleTxn(txn, id, updated);
      if (!startDate.isAfter(DateTime.now())) {
        // Implements: REQ-d00129-D — past startDate triggers replay in
        // the same transaction as the schedule write. _destinations[id]
        // is known non-null because the unknown-id check above
        // returned early otherwise.
        await runHistoricalReplay(txn, _destinations[id]!, updated, backend);
      }
      // REQ-d00129-E: future startDate takes the else branch; replay is
      // skipped.
    });
    // Update the in-memory cache only after the transaction commits, so
    // a rolled-back transaction does not leave the registry advertising
    // a schedule that was not persisted.
    _schedules[id] = updated;
  }

  /// Mutate the destination's `endDate` to [endDate] and return a
  /// `SetEndDateResult` describing the transition (REQ-d00129-F):
  ///
  /// - `closed` — call transitions currently-active to currently-closed.
  /// - `scheduled` — new `endDate` is in the future.
  /// - `applied` — no change in current active-vs-closed classification.
  ///
  /// Throws `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-F — setEndDate returns closed / scheduled /
  // applied per the three-way classification.
  Future<SetEndDateResult> setEndDate(String id, DateTime endDate) async {
    if (!_destinations.containsKey(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    final now = DateTime.now();
    final current = _schedules[id] ?? const DestinationSchedule();
    final wasActive = current.isActiveAt(now);
    final updated = DestinationSchedule(
      startDate: current.startDate,
      endDate: endDate,
    );
    final isActive = updated.isActiveAt(now);

    // Classify the two endDate snapshots (pre-call and post-call) as
    // scheduled-for-future-close or not. "Scheduled" here means "has a
    // future endDate"; it is independent of whether the destination is
    // currently active or dormant.
    final wasScheduled =
        current.endDate != null && current.endDate!.isAfter(now);
    final isScheduled = endDate.isAfter(now);

    final SetEndDateResult result;
    if (wasActive && !isActive) {
      // Active → closed at or before now.
      result = SetEndDateResult.closed;
    } else if (!wasActive && isActive) {
      // Previously closed (or dormant), now has a future endDate that
      // reopens / schedules a close window.
      result = SetEndDateResult.scheduled;
    } else if (isScheduled && !wasScheduled) {
      // No active/closed transition, but the endDate is newly in the
      // future (e.g., first assignment to a dormant destination, or
      // replacing a past endDate with a future one without crossing now).
      result = SetEndDateResult.scheduled;
    } else {
      // No state change relative to now AND no new close scheduled —
      // covers past → past, future → future without crossing now, and
      // first-time past on a dormant destination.
      result = SetEndDateResult.applied;
    }
    _schedules[id] = updated;
    await backend.writeSchedule(id, updated);
    return result;
  }

  /// Set the destination's `endDate` to `DateTime.now()`, returning
  /// `SetEndDateResult.closed` (REQ-d00129-G).
  // Implements: REQ-d00129-G — deactivateDestination is the now()
  // shorthand for setEndDate; returns closed.
  Future<SetEndDateResult> deactivateDestination(String id) =>
      setEndDate(id, DateTime.now());

  /// Unregister [id] and drop its FIFO store + schedule record in one
  /// transaction. Throws `StateError` when the destination's
  /// `allowHardDelete` getter is `false` — the default, opt-out-only
  /// gate on permanent FIFO destruction.
  // Implements: REQ-d00129-H — deleteDestination gated on
  // allowHardDelete; atomic FIFO-store + schedule drop.
  Future<void> deleteDestination(String id) async {
    final destination = _destinations[id];
    if (destination == null) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    if (!destination.allowHardDelete) {
      throw StateError(
        'DestinationRegistry.deleteDestination($id): destination '
        'allowHardDelete is false; hard deletion requires an explicit '
        'per-destination opt-in (REQ-d00129-H).',
      );
    }
    await backend.transaction((txn) async {
      await backend.deleteFifoStoreTxn(txn, id);
      await backend.deleteScheduleTxn(txn, id);
    });
    _destinations.remove(id);
    _schedules.remove(id);
  }
}
