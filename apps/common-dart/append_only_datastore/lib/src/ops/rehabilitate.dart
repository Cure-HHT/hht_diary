import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';

/// Flip a single exhausted FIFO row back to `pending` so the drain loop
/// re-attempts delivery on the next `syncCycle` tick. The lighter-weight
/// counterpart to `unjamDestination`: no rows are deleted, no cursor is
/// rewound, and the destination does NOT need to be deactivated first
/// (REQ-d00132-D) — a concurrent drain that reads the row right after
/// rehab simply sees a newly-pending row, which is the intended outcome.
///
/// The typical use case is a destination-side fix: the server's endpoint
/// was returning 5xx, the operator has patched it, and the exhausted
/// rows from before the fix should drain through unchanged rather than
/// being re-built by `fillBatch` (which would re-pack them into new
/// `event_id_range`s and risk duplicate delivery of the already-
/// successfully-delivered `sent` prefix).
///
/// Preconditions (REQ-d00132-A), checked BEFORE opening the transaction
/// so a mis-call does not hold a write lock across the ArgumentError
/// path:
/// - the row identified by [fifoRowId] on [destinationId] SHALL exist;
/// - the row's `final_status` SHALL be `exhausted`.
///
/// On success:
/// - `final_status` is set to `pending` (REQ-d00132-B);
/// - `attempts[]` is preserved unchanged (REQ-d00132-B).
// Implements: REQ-d00132-A — existence / status preconditions, checked
// pre-transaction so the ArgumentError path does not hold a write lock.
// Implements: REQ-d00132-B — exhausted -> pending flip; attempts[]
// preserved (delegated to backend.setFinalStatusTxn).
// Implements: REQ-d00132-D — permitted on an active destination (no
// schedule / endDate check, unlike unjamDestination).
Future<void> rehabilitateExhaustedRow(
  String destinationId,
  String fifoRowId, {
  required StorageBackend backend,
}) async {
  final row = await backend.readFifoRow(destinationId, fifoRowId);
  if (row == null) {
    throw ArgumentError.value(
      fifoRowId,
      'fifoRowId',
      'rehabilitateExhaustedRow($destinationId, $fifoRowId): FIFO row '
          'not found on destination. (REQ-d00132-A)',
    );
  }
  if (row.finalStatus != FinalStatus.exhausted) {
    throw ArgumentError.value(
      fifoRowId,
      'fifoRowId',
      'rehabilitateExhaustedRow($destinationId, $fifoRowId): row is '
          '${row.finalStatus.toJson()}, not exhausted; only exhausted '
          'rows can be rehabilitated. (REQ-d00132-A)',
    );
  }
  await backend.transaction(
    (txn) => backend.setFinalStatusTxn(
      txn,
      destinationId,
      fifoRowId,
      FinalStatus.pending,
    ),
  );
}

/// Flip every `exhausted` row on [destinationId] back to `pending` and
/// return the count of rows flipped. Same semantics per-row as
/// [rehabilitateExhaustedRow]: `attempts[]` preserved, no rows deleted,
/// no cursor touched, no deactivation precondition.
///
/// When no exhausted row exists, returns `0` without opening a
/// transaction. Otherwise every flip runs in a single transaction so the
/// rehabilitation commits atomically and rolls back together on error.
/// The enumeration is read BEFORE the transaction opens; this is safe
/// because a concurrent writer cannot transition `exhausted -> anything`
/// (the one-way rule in [StorageBackend.markFinal] rejects retransition)
/// — the snapshot is stable by construction.
// Implements: REQ-d00132-C — flip every exhausted row to pending in one
// transaction; returns count. Short-circuits before opening a
// transaction when no exhausted row exists.
// Implements: REQ-d00132-D — permitted on an active destination.
Future<int> rehabilitateAllExhausted(
  String destinationId, {
  required StorageBackend backend,
}) async {
  final exhausted = await backend.exhaustedRowsOf(destinationId);
  if (exhausted.isEmpty) return 0;
  await backend.transaction((txn) async {
    for (final row in exhausted) {
      await backend.setFinalStatusTxn(
        txn,
        destinationId,
        row.entryId,
        FinalStatus.pending,
      );
    }
  });
  return exhausted.length;
}
