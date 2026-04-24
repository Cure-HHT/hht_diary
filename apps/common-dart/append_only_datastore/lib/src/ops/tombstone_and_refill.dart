import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';

/// Recover a FIFO wedged at its head — or preemptively declare a
/// still-pending head undeliverable — by archiving the head row as a
/// tombstone, clearing the pending trail, and rewinding `fill_cursor`
/// so the next `fillBatch` rebuilds the events into fresh bundles.
///
/// The sole operator recovery primitive for the drain loop; the only
/// code path by which a FIFO row reaches `final_status == tombstoned`.
///
/// Preconditions (REQ-d00144-A), checked BEFORE opening the transaction
/// so a mis-call does not hold a write lock:
/// - The row identified by [fifoRowId] on [destinationId] SHALL exist.
/// - The row SHALL be the current head of the destination's FIFO
///   (i.e., `readFifoHead(destinationId)` returns this row). Its
///   `final_status` is therefore either `null` (pre-terminal) or
///   `FinalStatus.wedged` (blocking terminal); a `sent` or
///   `tombstoned` target, or a non-head target, is rejected with
///   `ArgumentError`.
///
/// Cascade inside one `StorageBackend.transaction` (REQ-d00144-B+C+D):
/// - Target row flips to `FinalStatus.tombstoned`; `attempts[]` and all
///   other fields preserved.
/// - Every row whose `sequence_in_queue > target.sequence_in_queue` AND
///   whose `final_status IS null` is deleted from the FIFO store.
/// - `fill_cursor_<destinationId>` is rewound to
///   `target.event_id_range.first_seq - 1`.
///
/// Returns a [TombstoneAndRefillResult] (REQ-d00144-E).
Future<TombstoneAndRefillResult> tombstoneAndRefill(
  String destinationId,
  String fifoRowId, {
  required StorageBackend backend,
}) async {
  // REQ-d00144-A: pre-transaction precondition checks. readFifoHead
  // returns the first row whose final_status is null or wedged; sent
  // and tombstoned rows are skipped. So if the caller's target is the
  // head, it is automatically in {null, wedged}; if it is anything else
  // (does not exist, sent, tombstoned, or simply not-the-head), the
  // returned head will differ from fifoRowId and we reject.
  // Implements: REQ-d00144-A — head-only + existence preconditions,
  // checked pre-transaction so ArgumentError does not hold a write lock.
  final head = await backend.readFifoHead(destinationId);
  if (head == null || head.entryId != fifoRowId) {
    throw ArgumentError.value(
      fifoRowId,
      'fifoRowId',
      'tombstoneAndRefill($destinationId, $fifoRowId): target is not '
          'the current head of the FIFO. readFifoHead returned '
          '${head?.entryId}. (REQ-d00144-A)',
    );
  }
  // head.finalStatus is null or wedged here (readFifoHead contract).

  final targetFirstSeq = head.eventIdRange.firstSeq;
  final targetSeqInQueue = head.sequenceInQueue;

  return backend.transaction((txn) async {
    // Implements: REQ-d00144-B — wedged|null -> tombstoned; attempts[]
    // preserved (delegated to backend.setFinalStatusTxn).
    await backend.setFinalStatusTxn(
      txn,
      destinationId,
      fifoRowId,
      FinalStatus.tombstoned,
    );
    // Implements: REQ-d00144-C — trail null rows deleted.
    final deletedTrailCount = await backend
        .deleteNullRowsAfterSequenceInQueueTxn(
          txn,
          destinationId,
          targetSeqInQueue,
        );
    // Implements: REQ-d00144-D — fill_cursor rewind to
    // target.event_id_range.first_seq - 1.
    final rewoundTo = targetFirstSeq - 1;
    await backend.writeFillCursorTxn(txn, destinationId, rewoundTo);
    // Implements: REQ-d00144-E — return the operator-visible counts.
    return TombstoneAndRefillResult(
      targetRowId: fifoRowId,
      deletedTrailCount: deletedTrailCount,
      rewoundTo: rewoundTo,
    );
  });
}
