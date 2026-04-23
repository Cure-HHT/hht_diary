import 'dart:convert';
import 'dart:typed_data';

import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/sync/sync_policy.dart';

/// Clock used to decide whether the head entry's backoff has elapsed.
/// Tests pass a fixed-time closure; production passes `null` and picks
/// up `DateTime.now().toUtc()`.
typedef ClockFn = DateTime Function();

/// Drain the head of [destination]'s FIFO: check backoff, call
/// [Destination.send], record the attempt, and route the result into a
/// `sent` or `exhausted` final-status as appropriate. Returns when:
///
/// - the FIFO has no pending rows (`readFifoHead` returns null after
///   skipping `sent` and `exhausted` rows — REQ-d00124-A); or
/// - the pending head's backoff has not elapsed; or
/// - the most recent [Destination.send] returned [SendTransient] below
///   the `maxAttempts` cap (backoff applies on the next drain tick).
///
/// On [SendOk] the head is marked `sent` and the loop advances. On
/// [SendPermanent] or [SendTransient]-at-`maxAttempts` the head is
/// marked `exhausted` and the loop *continues*: `readFifoHead` skips
/// the exhausted row on the next iteration and returns the next pending
/// row in `sequence_in_queue` order (REQ-d00124-D+E). A single drain
/// pass therefore attempts every pending row until one of the terminal
/// conditions above fires.
///
/// Strict FIFO order (REQ-d00124-H): within a single drain pass, rows
/// are attempted in `sequence_in_queue` order. Exhausted rows are
/// skipped in-place — their position in the sequence is preserved for
/// audit purposes, but they do not block later pending rows.
///
/// [policy] is an optional [SyncPolicy] override; when null, the drain
/// loop falls back to [SyncPolicy.defaults] (REQ-d00126-B).
// Implements: REQ-d00124-A+B+C+D+E+F+G+H — strict-FIFO drain with backoff.
// Implements: REQ-d00126-B — optional SyncPolicy? parameter; null falls
// back to SyncPolicy.defaults.
Future<void> drain(
  Destination destination, {
  required StorageBackend backend,
  ClockFn? clock,
  SyncPolicy? policy,
}) async {
  final now = clock ?? () => DateTime.now().toUtc();
  final effective = policy ?? SyncPolicy.defaults;
  while (true) {
    final head = await backend.readFifoHead(destination.id);
    if (head == null) return;

    // Backoff check: only the N-th attempt's timestamp matters; skip if
    // the entry has never been attempted (fresh head).
    if (head.attempts.isNotEmpty) {
      final backoff = effective.backoffFor(head.attempts.length);
      final nextAllowed = head.attempts.last.attemptedAt.add(backoff);
      if (now().isBefore(nextAllowed)) return;
    }

    // Reconstruct a WirePayload from the FifoEntry's stored fields. The
    // stored `wire_payload` is a Map (structured JSON); we re-encode to
    // bytes for destinations that consume byte payloads. JSON encoding is
    // deterministic for Maps with stable key order.
    final payload = WirePayload(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(head.wirePayload))),
      contentType: head.wireFormat,
      transformVersion: head.transformVersion,
    );

    // Call the destination. Categorize any thrown error as SendTransient —
    // the drain-loop contract does not distinguish between a thrown
    // exception and an explicit SendTransient return: both mean "try
    // again later".
    SendResult result;
    try {
      result = await destination.send(payload);
    } catch (error, stack) {
      result = SendTransient(error: 'uncaught exception: $error\n$stack');
    }

    // REQ-d00124-G: always record the attempt, regardless of outcome.
    final attempt = _attemptFromResult(result, now());
    await backend.appendAttempt(destination.id, head.entryId, attempt);

    // Route the outcome.
    // Implements: REQ-d00124-D+E — exhausting the head row (SendPermanent
    // or SendTransient-at-maxAttempts) marks it final and CONTINUES to
    // the next pending row; readFifoHead (REQ-d00124-A) skips exhausted
    // rows on the next iteration, so drain advances through the FIFO in
    // sequence_in_queue order rather than wedging on an exhausted head.
    switch (result) {
      case SendOk():
        await backend.markFinal(destination.id, head.entryId, FinalStatus.sent);
        continue;
      case SendPermanent():
        await backend.markFinal(
          destination.id,
          head.entryId,
          FinalStatus.wedged,
        );
        continue;
      case SendTransient():
        // head.attempts.length is the count BEFORE this attempt was
        // appended. After appendAttempt, the entry has attempts.length+1.
        // The spec: "attempts.length + 1 >= maxAttempts -> wedged".
        if (head.attempts.length + 1 >= effective.maxAttempts) {
          await backend.markFinal(
            destination.id,
            head.entryId,
            FinalStatus.wedged,
          );
          continue;
        }
        // Below the attempt cap: backoff applies on the next drain tick.
        return;
    }
  }
}

AttemptResult _attemptFromResult(SendResult result, DateTime attemptedAt) {
  switch (result) {
    case SendOk():
      return AttemptResult(attemptedAt: attemptedAt, outcome: 'ok');
    case SendTransient(:final error, :final httpStatus):
      return AttemptResult(
        attemptedAt: attemptedAt,
        outcome: 'transient',
        errorMessage: error,
        httpStatus: httpStatus,
      );
    case SendPermanent(:final error):
      return AttemptResult(
        attemptedAt: attemptedAt,
        outcome: 'permanent',
        errorMessage: error,
      );
  }
}
