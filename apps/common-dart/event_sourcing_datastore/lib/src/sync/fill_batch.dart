import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/drain.dart';
import 'package:uuid/uuid.dart';

/// Module-private v4 UUID generator used by [fillBatch] to mint each
/// native batch's `batch_id`. Held at file scope (const) so every call
/// shares one generator; `Uuid.v4()` is side-effect-free beyond its
/// internal random state, so a shared instance is correct.
const _uuidGen = Uuid();

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
/// 3. Read `readFifoHead(destination.id)`. If the returned row's
///    `final_status == FinalStatus.wedged`, return — drain halts at a
///    wedged head (REQ-d00124-H), so any row promoted now would be
///    speculative work that `tombstoneAndRefill`'s trail-delete sweep
///    (REQ-d00144-C) would undo. Recovery rewinds `fill_cursor`
///    (REQ-d00128-I) and the next `fillBatch` promotes in one pass.
/// 4. Read `fill_cursor_<destId>` and fetch every event with
///    `sequence_number > fill_cursor`.
/// 5. Filter by `client_timestamp ∈ [startDate, upper]` and by
///    `destination.filter.matches(event)`.
/// 6. If no events remain after filtering, advance the cursor past the
///    non-matching tail (so they are not re-evaluated on the next tick)
///    and return. REQ-d00128-H treats this as a no-op at the
///    "no new matching events" level: no FIFO row is written, and the
///    cursor advance is only the cursor-maintenance we need to keep
///    fillBatch O(new events) rather than O(log).
/// 7. Otherwise, assemble a greedy batch: start with the first matching
///    event, then add each subsequent one while `canAddToBatch` returns
///    true. Break on the first `false`.
/// 8. REQ-d00128-F — if the batch is a single event AND `maxAccumulateTime`
///    has not yet elapsed (`now() - batch.first.clientTimestamp < max`),
///    hold the batch. Do not write a FIFO row; do not advance the cursor.
///    Multi-event batches do not hit the hold — `canAddToBatch` returning
///    false for the next candidate already indicated size pressure, which
///    is an admissible flush condition.
/// 9. Branch on `destination.serializesNatively` (REQ-d00152-B):
///    - True: build a fresh [BatchEnvelopeMetadata] from [source] (mint
///      `batch_id`, stamp `sent_at = now`, copy `hopId` /
///      `identifier` / `softwareVersion`) and enqueue via
///      `nativeEnvelope:`. The destination's [Destination.transform] is
///      NOT called.
///    - False: call `destination.transform(batch)` and enqueue via
///      `wirePayload:`.
///   The enqueue and the `fill_cursor` advance to
///   `batch.last.sequenceNumber` run inside a single
///   `StorageBackend.transaction`, so on rollback neither is visible.
///
/// [source] is required when `destination.serializesNatively` is true
/// (the envelope identity is built from it). Callers that drive only
/// 3rd-party destinations MAY omit it; passing it is harmless.
///
/// [clock] defaults to `() => DateTime.now().toUtc()`; tests inject a
/// fixed-time closure so the `now()` reference point is deterministic.
// Implements: REQ-d00128-E+F+G+H+I — canAddToBatch-driven batch assembly,
// maxAccumulateTime hold on single-event batches, fill_cursor advance to
// batch.last.sequenceNumber, idempotent no-op when no new matching events,
// and wedge-aware early return when readFifoHead's row is wedged.
// Implements: REQ-d00129-I — filter candidates by
// client_timestamp ∈ [startDate, min(endDate, now())]; events outside
// the window are never enqueued.
// Implements: REQ-d00152-B — branch on destination.serializesNatively:
// native destinations bypass transform and receive a library-built
// envelope; non-native destinations call transform as before.
// Honors: REQ-d00124-H — drain halts on a wedged head; the wedge-skip
// branch above avoids speculative rows that tombstoneAndRefill would
// have to undo.
Future<void> fillBatch(
  Destination destination, {
  required StorageBackend backend,
  required DestinationSchedule schedule,
  Source? source,
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

  // REQ-d00128-I — wedge-aware skip. If the destination's FIFO head is
  // wedged, drain halts at it (REQ-d00124-H), so any row we promote
  // behind it would be speculative work that tombstoneAndRefill's
  // trail-delete sweep (REQ-d00144-C) would have to undo. Return
  // without promoting; recovery rewinds fill_cursor and the next
  // fillBatch fills in one pass.
  final head = await backend.readFifoHead(destination.id);
  if (head?.finalStatus == FinalStatus.wedged) return;

  // Walk the event log past fill_cursor.
  final fillCursor = await backend.readFillCursor(destination.id);
  final candidates = await backend.findAllEvents(afterSequence: fillCursor);
  if (candidates.isEmpty) return;

  // Trim to the destination's time-window AND its subscription filter.
  // Implements: REQ-d00128-J — destination admission is decided by
  //   destination.filter.matches; system events flow through to
  //   destinations that opt in via SubscriptionFilter.includeSystemEvents
  //   and are rejected by matches for destinations that do not opt in.
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

  // Branch on destination.serializesNatively. Native destinations
  // consume the library's `esd/batch@1` format; the library mints the
  // envelope identity from the local `Source` and enqueues via
  // `nativeEnvelope:`. The on-the-wire bytes are reconstructed
  // deterministically at drain time (REQ-d00119-K) so we do NOT call
  // `Destination.transform` and do NOT carry the bytes through the FIFO
  // row. Non-native destinations own their wire format and pass through
  // [transform].
  // Implements: REQ-d00152-B — fillBatch branches on serializesNatively;
  // native rows skip transform entirely and receive a library-built
  // BatchEnvelopeMetadata from `source`.
  if (destination.serializesNatively) {
    if (source == null) {
      throw ArgumentError(
        'fillBatch: destination "${destination.id}" declares '
        'serializesNatively == true but no source was supplied; '
        'native batches require a Source to stamp the envelope identity '
        '(REQ-d00152-B+E)',
      );
    }
    final envelope = BatchEnvelopeMetadata(
      batchFormatVersion: BatchEnvelope.currentBatchFormatVersion,
      batchId: _uuidGen.v4(),
      senderHop: source.hopId,
      senderIdentifier: source.identifier,
      senderSoftwareVersion: source.softwareVersion,
      sentAt: now,
    );
    await backend.transaction((txn) async {
      await backend.enqueueFifoTxn(
        txn,
        destination.id,
        batch,
        nativeEnvelope: envelope,
      );
      await backend.writeFillCursorTxn(
        txn,
        destination.id,
        batch.last.sequenceNumber,
      );
    });
    return;
  }

  final wirePayload = await destination.transform(batch);

  // Enqueue + advance cursor atomically. Uses enqueueFifoTxn so both
  // writes participate in the same transaction — on rollback, neither
  // the FIFO row nor the cursor advance is visible.
  await backend.transaction((txn) async {
    await backend.enqueueFifoTxn(
      txn,
      destination.id,
      batch,
      wirePayload: wirePayload,
    );
    await backend.writeFillCursorTxn(
      txn,
      destination.id,
      batch.last.sequenceNumber,
    );
  });
}
