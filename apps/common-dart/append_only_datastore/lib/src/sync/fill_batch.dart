import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/sync/drain.dart';

/// Promote matching events from the event log into a destination's FIFO
/// as batches, advancing `fill_cursor` accordingly.
///
/// Algorithm (design §6.8, REQ-d00128-E/F/G/H + REQ-d00129-I):
///
/// 1. If the destination's schedule is dormant (`startDate == null`),
///    there is nothing to do. Return.
/// 2. Compute the upper bound of the promotion window as
///    `min(endDate, now())`. If `startDate` is past that upper bound,
///    the window is closed; return.
/// 3. Read `fill_cursor_<destId>` and fetch every event with
///    `sequence_number > fill_cursor`.
/// 4. Filter by `client_timestamp ∈ [startDate, upper]` and by
///    `destination.filter.matches(event)`.
/// 5. If no events remain after filtering, advance the cursor past the
///    non-matching tail (so they are not re-evaluated on the next tick)
///    and return. REQ-d00128-H treats this as a no-op at the
///    "no new matching events" level: no FIFO row is written, and the
///    cursor advance is only the cursor-maintenance we need to keep
///    fillBatch O(new events) rather than O(log).
/// 6. Otherwise, assemble a greedy batch: start with the first matching
///    event, then add each subsequent one while `canAddToBatch` returns
///    true. Break on the first `false`.
/// 7. REQ-d00128-F — if the batch is a single event AND `maxAccumulateTime`
///    has not yet elapsed (`now() - batch.first.clientTimestamp < max`),
///    hold the batch. Do not write a FIFO row; do not advance the cursor.
///    Multi-event batches do not hit the hold — `canAddToBatch` returning
///    false for the next candidate already indicated size pressure, which
///    is an admissible flush condition.
/// 8. Transform the batch into a `WirePayload`, then atomically enqueue
///    the row and advance `fill_cursor` to `batch.last.sequenceNumber`.
///
/// The whole enqueue + cursor advance runs inside one
/// `StorageBackend.transaction`, so on a backend rollback neither the
/// FIFO row nor the cursor advance is visible.
///
/// [clock] defaults to `() => DateTime.now().toUtc()`; tests inject a
/// fixed-time closure so the `now()` reference point is deterministic.
// Implements: REQ-d00128-E+F+G+H — canAddToBatch-driven batch assembly,
// maxAccumulateTime hold on single-event batches, fill_cursor advance
// to batch.last.sequenceNumber, idempotent no-op when no new matching
// events.
// Implements: REQ-d00129-I — filter candidates by
// client_timestamp ∈ [startDate, min(endDate, now())]; events outside
// the window are never enqueued.
Future<void> fillBatch(
  Destination destination, {
  required StorageBackend backend,
  required DestinationSchedule schedule,
  ClockFn? clock,
}) async {
  final now = (clock ?? () => DateTime.now().toUtc())();

  // Dormant destination: schedule has no startDate. Nothing to promote.
  if (schedule.startDate == null) return;

  // Upper bound: min(endDate, now). When endDate is null, upper = now.
  // When endDate is in the future, upper = now (we don't promote events
  // past wall-clock time). When endDate is in the past, upper = endDate.
  final upper = schedule.endDate == null || schedule.endDate!.isAfter(now)
      ? now
      : schedule.endDate!;
  // Window entirely in the future (startDate > upper): nothing to promote.
  if (schedule.startDate!.isAfter(upper)) return;

  // Walk the event log past fill_cursor.
  final fillCursor = await backend.readFillCursor(destination.id);
  final candidates = await backend.findAllEvents(afterSequence: fillCursor);
  if (candidates.isEmpty) return;

  // Trim to the destination's time-window AND its subscription filter.
  final inWindow = candidates.where((e) {
    if (e.clientTimestamp.isBefore(schedule.startDate!)) return false;
    if (e.clientTimestamp.isAfter(upper)) return false;
    return destination.filter.matches(e);
  }).toList();

  if (inWindow.isEmpty) {
    // Advance cursor past the non-matching tail so we don't re-evaluate
    // them on the next tick. REQ-d00128-H: "no new matching events"
    // idempotency — this is not a NEW match, it's cursor maintenance to
    // keep fillBatch's work bounded by new events, not total log size.
    // Note: cursor advance here is not wrapped in an explicit
    // transaction() because writeFillCursor already opens its own
    // atomic transaction, and there is no second mutation to compose
    // with in this branch.
    await backend.writeFillCursor(
      destination.id,
      candidates.last.sequenceNumber,
    );
    return;
  }

  // Assemble a greedy batch: start with the first matching event, then
  // admit each subsequent one while canAddToBatch says yes. Break on
  // the first false.
  final batch = <StoredEvent>[inWindow.first];
  for (final c in inWindow.skip(1)) {
    if (destination.canAddToBatch(batch, c)) {
      batch.add(c);
    } else {
      break;
    }
  }

  // REQ-d00128-F: hold a single-event batch until maxAccumulateTime has
  // elapsed. Multi-event batches don't hit this hold: canAddToBatch
  // returning false for the next candidate already indicated size
  // pressure, which is an admissible flush condition.
  final oldestAge = now.difference(batch.first.clientTimestamp);
  if (batch.length == 1 && oldestAge < destination.maxAccumulateTime) {
    // Hold: do NOT advance the cursor either — the event is still a
    // live match that we want to re-evaluate on the next tick, possibly
    // joined by a newer event that clears the hold via canAddToBatch
    // batching or by time elapsing past maxAccumulateTime.
    return;
  }

  final wirePayload = await destination.transform(batch);

  // Enqueue + advance cursor atomically. Uses enqueueFifoTxn so both
  // writes participate in the same transaction — on rollback, neither
  // the FIFO row nor the cursor advance is visible.
  await backend.transaction((txn) async {
    await backend.enqueueFifoTxn(txn, destination.id, batch, wirePayload);
    await backend.writeFillCursorTxn(
      txn,
      destination.id,
      batch.last.sequenceNumber,
    );
  });
}
