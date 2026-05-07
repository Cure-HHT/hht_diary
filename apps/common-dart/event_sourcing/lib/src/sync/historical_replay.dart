import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:uuid/uuid.dart';

const _uuidGen = Uuid();

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
///
/// No `EntryPromoter` is invoked here. Historical replay promotes events
/// from the log into the destination's outbound FIFO, not into a
/// materialized view. The receiving destination is responsible for any
/// version translation it needs to perform on the wire (REQ-d00140-G
/// scopes the promoter to materializer folds, not destination transforms).
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
  StorageBackend backend, {
  Source? source,
}) async {
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

  // Walk candidates classifying each as deferred (upper-bound rejection)
  // or decided (in-window OR permanently rejected). Subscription-filter
  // rejection is evaluated before the upper-bound check so an event the
  // destination is permanently uninterested in does not block cursor
  // advance regardless of its client_timestamp.
  //
  // Implements: REQ-d00128-J — admission decided by
  //   destination.filter.matches.
  // Implements: REQ-d00128-K — cursor advance respects rejection reason:
  //   permanent rejections (subscription, startDate-lower) contribute to
  //   cursor advance; deferred rejections (upper bound) stop the walk so
  //   the cursor does not skip past them. Replay's parity with fillBatch
  //   is required so a destination registered with a past startDate sees
  //   the same admission semantics during catch-up as during live
  //   operation.
  final inWindow = <StoredEvent>[];
  int? lastDecidedSeq;
  for (final e in candidates) {
    if (!destination.filter.matches(e)) {
      // Permanent: subscription filter is stable.
      lastDecidedSeq = e.sequenceNumber;
      continue;
    }
    if (e.clientTimestamp.isBefore(startDate)) {
      // Permanent for the current invocation: events with
      // client_timestamp < startDate are skipped and the cursor
      // advances past them. Under REQ-d00129-C monotonic-backward
      // semantics, a later setStartDate(earlier) invocation re-promotes
      // the gap window via runGapReplay, which walks the event log
      // independent of fill_cursor and does not require these events
      // to be re-considered here.
      lastDecidedSeq = e.sequenceNumber;
      continue;
    }
    if (e.clientTimestamp.isAfter(upper)) {
      // Deferred — endDate is mutable per REQ-d00129-F. Stop the walk;
      // any subsequent candidates wait for the next invocation
      // (replay or fillBatch tick).
      break;
    }
    // In-window candidate.
    inWindow.add(e);
    lastDecidedSeq = e.sequenceNumber;
  }

  if (inWindow.isEmpty) {
    // No promotions to make. Advance cursor past any permanently-rejected
    // events the walk visited; if the walk stopped at the very first
    // candidate (deferred), do not advance — that event must remain
    // re-evaluable when the upper bound widens.
    if (lastDecidedSeq != null) {
      await backend.writeFillCursorTxn(txn, destination.id, lastDecidedSeq);
    }
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
  // Native destinations (`serializesNatively == true`) consume the
  // library's `esd/batch@1` envelope; replay must mint
  // `BatchEnvelopeMetadata` from the caller's `source` and enqueue via
  // `nativeEnvelope:`, mirroring `fillBatch`'s native branch
  // (REQ-d00152-B). Calling `transform` on a native destination
  // throws by contract.
  // Implements: REQ-d00152-B (replay parity) — historical replay
  //   honors `serializesNatively` symmetrically with `fillBatch` so a
  //   destination registered after events have already landed (e.g., an
  //   audit-mirror destination registered post-bootstrap with
  //   `includeSystemEvents: true`) receives library-built native
  //   envelopes during catch-up.
  if (destination.serializesNatively && source == null) {
    throw ArgumentError(
      'runHistoricalReplay: destination "${destination.id}" declares '
      'serializesNatively == true but no source was supplied; native '
      'batches require a Source to stamp the envelope identity '
      '(REQ-d00152-B+E).',
    );
  }
  var i = 0;
  while (i < inWindow.length) {
    final batch = <StoredEvent>[inWindow[i]];
    i++;
    while (i < inWindow.length &&
        destination.canAddToBatch(batch, inWindow[i])) {
      batch.add(inWindow[i]);
      i++;
    }
    if (destination.serializesNatively) {
      final envelope = BatchEnvelopeMetadata(
        batchFormatVersion: BatchEnvelope.currentBatchFormatVersion,
        batchId: _uuidGen.v4(),
        senderHop: source!.hopId,
        senderIdentifier: source.identifier,
        senderSoftwareVersion: source.softwareVersion,
        sentAt: now,
      );
      await backend.enqueueFifoTxn(
        txn,
        destination.id,
        batch,
        nativeEnvelope: envelope,
      );
    } else {
      final wirePayload = await destination.transform(batch);
      await backend.enqueueFifoTxn(
        txn,
        destination.id,
        batch,
        wirePayload: wirePayload,
      );
    }
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

/// Walk the entire event log and enqueue events whose `client_timestamp`
/// falls in the half-open gap `[newStartDate, oldStartDate)` and that
/// match [destination]'s subscription filter. Used by
/// `DestinationRegistry.setStartDate` when the call moves an
/// already-set `startDate` to an earlier value (REQ-d00129-C
/// monotonic-backward semantics).
///
/// Differs from [runHistoricalReplay] in three ways:
///
/// - Reads the WHOLE event log via `findAllEventsInTxn` (not from
///   `fill_cursor + 1`). The cursor was advanced past these events by
///   prior `fillBatch` / replay invocations under the old startDate; the
///   gap window we are now widening into sits behind the cursor and
///   is invisible to the cursor-based walk.
/// - Filters strictly by `client_timestamp ∈ [newStartDate, oldStartDate)`.
///   Events with `client_timestamp >= oldStartDate` are already in the
///   FIFO (or in flight via the live `fillBatch` path) — re-enqueuing
///   them would duplicate FIFO rows.
/// - Does NOT advance `fill_cursor`. The cursor governs the live
///   `fillBatch` walk; gap replay re-promotes events already past the
///   cursor and SHOULD NOT regress it. Live `fillBatch` continues from
///   wherever the cursor was (past `oldStartDate`'s replayed events).
///
/// Runs inside the [txn] supplied by the caller; does NOT open its own
/// transaction. This matters for serialization: a concurrent `record()`
/// serializes behind the transaction that persists the new schedule and
/// runs gap replay, so it never observes a half-applied gap window.
///
/// No `EntryPromoter` is invoked here — gap replay promotes events from
/// the log into the destination's FIFO, not into a materialized view.
// Implements: REQ-d00129-C — backward movement of startDate triggers a
//   gap replay over [newStartDate, oldStartDate) in the same transaction
//   as the schedule write.
// Implements: REQ-d00130-D — gap replay walks the event log directly
//   (independent of fill_cursor) and uses destination.canAddToBatch and
//   destination.transform so rows are identical in shape to fillBatch's
//   live output.
Future<void> runGapReplay(
  Txn txn,
  Destination destination,
  StorageBackend backend, {
  required DateTime newStartDate,
  required DateTime oldStartDate,
  Source? source,
}) async {
  if (!newStartDate.isBefore(oldStartDate)) {
    // Caller is responsible for the comparison; defensively early-exit.
    return;
  }

  // Native destinations require a Source so replay can mint a library-
  // built BatchEnvelopeMetadata in lieu of calling transform.
  if (destination.serializesNatively && source == null) {
    throw ArgumentError(
      'runGapReplay: destination "${destination.id}" declares '
      'serializesNatively == true but no source was supplied; native '
      'batches require a Source to stamp the envelope identity '
      '(REQ-d00152-B+E).',
    );
  }

  // Walk the entire event log inside this transaction. The cost is
  // bounded by event-log size; backward startDate moves are rare, so
  // a full scan per move is acceptable.
  final all = await backend.findAllEventsInTxn(txn);

  final inGap = <StoredEvent>[];
  for (final e in all) {
    if (!destination.filter.matches(e)) continue;
    if (e.clientTimestamp.isBefore(newStartDate)) continue;
    if (!e.clientTimestamp.isBefore(oldStartDate)) continue;
    inGap.add(e);
  }
  if (inGap.isEmpty) return;

  final now = DateTime.now();
  var i = 0;
  while (i < inGap.length) {
    final batch = <StoredEvent>[inGap[i]];
    i++;
    while (i < inGap.length && destination.canAddToBatch(batch, inGap[i])) {
      batch.add(inGap[i]);
      i++;
    }
    if (destination.serializesNatively) {
      final envelope = BatchEnvelopeMetadata(
        batchFormatVersion: BatchEnvelope.currentBatchFormatVersion,
        batchId: _uuidGen.v4(),
        senderHop: source!.hopId,
        senderIdentifier: source.identifier,
        senderSoftwareVersion: source.softwareVersion,
        sentAt: now,
      );
      await backend.enqueueFifoTxn(
        txn,
        destination.id,
        batch,
        nativeEnvelope: envelope,
      );
    } else {
      final wirePayload = await destination.transform(batch);
      await backend.enqueueFifoTxn(
        txn,
        destination.id,
        batch,
        wirePayload: wirePayload,
      );
    }
  }
  // Deliberately no fill_cursor write: the cursor reflects fillBatch's
  // view of the live tail, which gap replay does not modify.
}
