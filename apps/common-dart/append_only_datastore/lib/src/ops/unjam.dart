import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';

/// Repair a wedged destination: delete every pending FIFO row, preserve
/// every `sent` and `exhausted` row (audit trail), and rewind
/// `fill_cursor` to the last successfully-delivered event's
/// `event_id_range.last_seq` (or `-1` when no `sent` row exists).
///
/// Precondition: the destination MUST be deactivated first. An "active"
/// destination — `endDate == null` or `endDate > now()` — is rejected
/// with `StateError` rather than unjammed under a live drain loop
/// (REQ-d00131-A). Deactivate via `DestinationRegistry.deactivateDestination`
/// (which sets `endDate = now()`) or `DestinationRegistry.setEndDate(id,
/// past-instant)` before calling this function. The `markFinal` /
/// `appendAttempt` no-op-on-missing-target tolerance (REQ-d00127) closes
/// the narrower race for a drain call that was already mid-flight when
/// deactivation landed.
///
/// All mutations run inside one `StorageBackend.transaction`:
/// - delete pending rows (REQ-d00131-B);
/// - preserve sent + exhausted rows (REQ-d00131-C, by omission from the
///   delete filter);
/// - rewind `fill_cursor` to `max(event_id_range.last_seq where
///   final_status == sent)`, or `-1` when no such row exists
///   (REQ-d00131-D).
///
/// Returns an [UnjamResult] carrying the count of deleted pending rows
/// and the rewind target (REQ-d00131-E).
// Implements: REQ-d00131-A — deactivation precondition, checked before
// opening the transaction so a mis-call does not hold a write lock.
// Implements: REQ-d00131-B+C+D+E — transactional delete / preserve /
// rewind / return result.
Future<UnjamResult> unjamDestination(
  String destinationId, {
  required DestinationRegistry registry,
  required StorageBackend backend,
}) async {
  final schedule = await registry.scheduleOf(destinationId);
  final now = DateTime.now();
  // "Active" under REQ-d00131-A: endDate is null (never ends) OR
  // endDate is strictly after now(). A destination whose endDate has
  // elapsed (<= now) is deactivated and unjam-safe.
  if (schedule.endDate == null || schedule.endDate!.isAfter(now)) {
    throw StateError(
      'unjamDestination($destinationId): destination must be deactivated '
      'first (endDate must be <= now); current endDate is '
      '${schedule.endDate}. Call registry.deactivateDestination or '
      'registry.setEndDate with a past date before unjamming. '
      '(REQ-d00131-A)',
    );
  }

  return backend.transaction((txn) async {
    // REQ-d00131-B: delete every pending row. Exhausted and sent rows
    // are preserved implicitly because the filter inside
    // `deletePendingRowsTxn` pins `final_status == pending` — this is
    // also the REQ-d00131-C audit-trail preservation.
    final deletedPending = await backend.deletePendingRowsTxn(
      txn,
      destinationId,
    );
    // REQ-d00131-D: rewind target is max(event_id_range.last_seq) across
    // sent rows; when no sent row exists we fall back to -1 (the
    // pre-start sentinel per REQ-d00128-G / REQ-d00131-D).
    final lastSentSeq = await backend.maxSentSequenceTxn(txn, destinationId);
    final rewoundTo = lastSentSeq ?? -1;
    await backend.writeFillCursorTxn(txn, destinationId, rewoundTo);
    // REQ-d00131-E: return both operator-visible counts.
    return UnjamResult(deletedPending: deletedPending, rewoundTo: rewoundTo);
  });
}
