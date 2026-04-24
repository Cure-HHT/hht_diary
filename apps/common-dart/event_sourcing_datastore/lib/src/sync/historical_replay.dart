import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';

/// Walk the event log past `fill_cursor` in a single transaction and
/// enqueue every event that matches [destination]'s subscription filter
/// and the time window described by [schedule], building batches with
/// the destination's own `canAddToBatch` and `transform`.
///
/// Runs inside the [txn] supplied by the caller; does NOT open its own
/// transaction. This matters for serialization: `DestinationRegistry
/// .setStartDate` invokes replay inside the same transaction that
/// persists the new schedule, so a concurrent `record()` serialized
/// behind that transaction observes the advanced `fill_cursor` and never
/// re-enqueues the events replay already promoted (REQ-d00130-C).
///
/// Algorithm (design §6.8, REQ-d00130-A+B):
///
/// 1. Compute the upper bound of the promotion window as
///    `min(endDate, now())`. When `startDate > upper`, the window is
///    empty (for example, `endDate` already in the past relative to
///    `startDate`); the call is a no-op.
/// 2. Read `fill_cursor_<destId>` and fetch every event with
///    `sequence_number > fill_cursor` using the in-transaction reader
///    so staged writes from this same transaction are visible.
/// 3. Filter by `client_timestamp ∈ [startDate, upper]` and by
///    `destination.filter.matches(event)`.
/// 4. If no events remain after filtering, advance the cursor past the
///    non-matching tail (so the next `fillBatch` tick does not re-scan)
///    and return. This mirrors `fillBatch`'s "no new matching events"
///    idempotent-cursor-maintenance branch.
/// 5. Otherwise, iterate the in-window list end-to-end, assembling
///    greedy batches via `canAddToBatch`. Each completed batch is
///    `transform`-ed and enqueued via `enqueueFifoTxn`; when the list is
///    exhausted, the cursor is advanced to the last replayed event's
///    `sequence_number` in the same transaction.
///
/// Key differences from `fillBatch`:
///
/// - Runs inside an existing [Txn]; it does not open its own
///   transaction, and reads the event log via `findAllEventsInTxn` so
///   staged writes under the same transaction are visible.
/// - Iterates to completion: replay catches up the entire historical
///   tail in one pass, not one batch per tick.
/// - Does NOT honor `maxAccumulateTime`'s hold on single-event batches.
///   Historical events are not "live" arrivals; the hold — which exists
///   to let a second event arrive and batch with a lone first event —
///   does not apply. The final trailing batch flushes even if it is a
///   single event.
// Implements: REQ-d00129-D — setStartDate(past) triggers historical
// replay synchronously in the same transaction as the schedule write.
// Implements: REQ-d00130-A — single-transaction walk of event_log from
// fill_cursor + 1 forward, filtered by subscription + time window.
// Implements: REQ-d00130-B — uses destination.canAddToBatch and
// destination.transform so rows are identical in shape to fillBatch's
// live output.
// Implements: REQ-d00130-C — runs inside the caller's transaction so a
// concurrent record() serializes behind and sees the advanced
// fill_cursor; no double-enqueue.
Future<void> runHistoricalReplay(
  Txn txn,
  Destination destination,
  DestinationSchedule schedule,
  StorageBackend backend,
) async {
  final startDate = schedule.startDate;
  if (startDate == null) {
    // Caller should not have invoked replay on a dormant schedule, but
    // defensively early-exit rather than throw: a dormant schedule has
    // no window so there is nothing to replay.
    return;
  }

  final now = DateTime.now();
  // Upper bound: min(endDate, now). Null endDate → upper = now. A
  // future endDate collapses to now because we do not replay events
  // past wall-clock time. A past endDate caps the window at endDate.
  final endDate = schedule.endDate;
  final upper = endDate == null || endDate.isAfter(now) ? now : endDate;

  // Empty window (startDate past the upper bound): nothing to replay.
  if (startDate.isAfter(upper)) return;

  // Invariant: the caller (currently only `DestinationRegistry.setStartDate`)
  // MUST NOT have staged a prior `writeFillCursorTxn` on this destination
  // within [txn] before calling `runHistoricalReplay`. The cursor read
  // below is non-transactional, so a staged-but-uncommitted cursor write
  // would be invisible and replay would redo work. The current caller
  // does not stage a cursor write before this point. If a future caller
  // needs to compose differently, add a `readFillCursorTxn` method to
  // `StorageBackend` and use it here.
  final fillCursor = await backend.readFillCursor(destination.id);
  final candidates = await backend.findAllEventsInTxn(
    txn,
    afterSequence: fillCursor,
  );
  if (candidates.isEmpty) return;

  // Trim to the destination's time-window AND its subscription filter.
  final inWindow = candidates.where((e) {
    if (e.clientTimestamp.isBefore(startDate)) return false;
    if (e.clientTimestamp.isAfter(upper)) return false;
    return destination.filter.matches(e);
  }).toList();

  if (inWindow.isEmpty) {
    // Advance the cursor past the non-matching tail so a later
    // fillBatch tick does not re-evaluate the same candidates
    // (matches fillBatch's idempotent no-op branch).
    await backend.writeFillCursorTxn(
      txn,
      destination.id,
      candidates.last.sequenceNumber,
    );
    return;
  }

  // Assemble greedy batches via canAddToBatch, flushing each completed
  // batch before moving on. Unlike fillBatch we continue past the first
  // batch so the entire historical tail is promoted in one pass.
  //
  // Convention (matches fillBatch and destination.dart's doc on
  // canAddToBatch): the first event of each batch is seeded
  // unconditionally; canAddToBatch is only consulted from the second
  // event onward. A destination that returns false for an empty
  // currentBatch still gets each event enqueued as a one-event row here;
  // rejecting the empty-batch case would silently drop events.
  var i = 0;
  while (i < inWindow.length) {
    final batch = <StoredEvent>[inWindow[i]];
    i++;
    while (i < inWindow.length &&
        destination.canAddToBatch(batch, inWindow[i])) {
      batch.add(inWindow[i]);
      i++;
    }
    final wirePayload = await destination.transform(batch);
    await backend.enqueueFifoTxn(txn, destination.id, batch, wirePayload);
  }

  // Cursor advances to the last replayed event's sequence_number.
  // REQ-d00130-C: after this write commits, a concurrent record()
  // serialized behind this transaction will re-evaluate candidates
  // strictly past this value, so no double-enqueue.
  await backend.writeFillCursorTxn(
    txn,
    destination.id,
    inWindow.last.sequenceNumber,
  );
}
