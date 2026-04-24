import 'dart:async';
import 'dart:io';

import 'package:sembast/sembast.dart';

/// Storage-layer failure taxonomy. Callers that catch exceptions from the
/// backend, materializer, or event-append path can run the raw error through
/// the classifier (Phase 4.5 Task 4) and then switch on the returned variant
/// to decide whether to retry, surface to the user, or quarantine.
///
/// The three variants correspond to disjoint recovery strategies:
/// * `StorageTransientException` — retryable (lock contention, timeout).
/// * `StoragePermanentException` — non-retryable but data intact (permission
///   denied, closed state, bad argument); requires caller / operator action.
/// * `StorageCorruptException` — data-integrity violated (decode failure,
///   hash-chain mismatch); requires intervention and usually a rebuild.
// Implements: REQ-d00143-A — sealed Dart 3 class with exactly three
// subclasses; exhaustive pattern-matching enforced at compile time.
sealed class StorageException implements Exception {
  const StorageException(this.message, this.cause, this.stackTrace);

  final String message;

  // Implements: REQ-d00143-G — preserve the original cause and stackTrace for
  // diagnostic traceability.
  final Object cause;
  final StackTrace stackTrace;
}

/// Transient / retryable storage failure. A caller may safely retry the
/// operation after a backoff.
class StorageTransientException extends StorageException {
  const StorageTransientException(super.message, super.cause, super.stackTrace);

  @override
  String toString() => 'StorageTransientException: $message (cause: $cause)';
}

/// Permanent / non-retryable storage failure. The underlying data is intact
/// but the operation cannot succeed without caller or operator intervention.
class StoragePermanentException extends StorageException {
  const StoragePermanentException(super.message, super.cause, super.stackTrace);

  @override
  String toString() => 'StoragePermanentException: $message (cause: $cause)';
}

/// Data-corruption storage failure. The on-disk bytes no longer match the
/// expected shape (JSON decode failure, hash-chain break, schema mismatch);
/// recovery usually requires a rebuild or restoration from a clean source.
class StorageCorruptException extends StorageException {
  const StorageCorruptException(super.message, super.cause, super.stackTrace);

  @override
  String toString() => 'StorageCorruptException: $message (cause: $cause)';
}

/// Classify a caught error from the storage layer into one of the three
/// [StorageException] buckets. Pure function: never throws, always returns.
///
/// Callers pass the raw `error` and `stack` from a `try`/`catch` and then
/// pattern-match the result to decide whether to retry, quarantine, or
/// surface. No call sites wire this classifier in Phase 4.5 — consumers land
/// in Phase 4.6 (or later) under the same REQ-d00143 umbrella.
///
/// Mapping today:
/// * `dart:async` `TimeoutException` → transient
/// * `dart:core` `FormatException`, sembast `DatabaseException.errInvalidCodec`
///   → corrupt (event-data decode / hash-chain break / codec-decode failure
///   that is indistinguishable from on-disk corruption)
/// * `dart:io` `FileSystemException`, `StateError`, `ArgumentError`, sembast
///   `DatabaseException` lifecycle codes (`errBadParam`,
///   `errDatabaseNotFound`, `errDatabaseClosed`) → permanent
/// * anything else → permanent (conservative fallback per REQ-d00143-F — a
///   retry loop on unknown errors is worse than failing loudly)
// Implements: REQ-d00143-B — public classifier returning StorageException
// for any input; never throws.
// Implements: REQ-d00143-C — TimeoutException and backend-raised transient
// signals classify as StorageTransientException.
// Implements: REQ-d00143-D — FormatException (JSON decode / hash-chain
// break) and sembast DatabaseException.errInvalidCodec classify as
// StorageCorruptException.
// Implements: REQ-d00143-E — dart:io FileSystemException, StateError,
// ArgumentError, and sembast DatabaseException lifecycle codes
// (errBadParam, errDatabaseNotFound, errDatabaseClosed) classify as
// StoragePermanentException.
// Implements: REQ-d00143-F — unrecognized input conservatively classifies
// as StoragePermanentException (never transient).
// Implements: REQ-d00143-G — classifier forwards the original cause and
// stackTrace to the returned exception.
StorageException classifyStorageException(Object error, StackTrace stack) {
  return switch (error) {
    final TimeoutException e => StorageTransientException(
      e.message ?? 'timeout',
      e,
      stack,
    ),
    final FormatException e => StorageCorruptException(e.message, e, stack),
    final FileSystemException e => StoragePermanentException(
      e.message,
      e,
      stack,
    ),
    // Sembast errInvalidCodec — on-disk bytes cannot be decoded with the
    // configured codec. This is caller-visible indistinguishable from
    // genuine corruption (we cannot tell "wrong codec configured" from
    // "bytes damaged" at this layer), so classify as corrupt and let the
    // caller's corruption-handler decide whether to rebuild or surface to
    // an operator.
    final DatabaseException e
        when e.code == DatabaseException.errInvalidCodec =>
      StorageCorruptException('[${e.code}] ${e.message}', e, stack),
    // Remaining sembast codes (errBadParam, errDatabaseNotFound,
    // errDatabaseClosed) are operational / lifecycle errors — data intact,
    // caller or operator action required. Sembast handles lock contention
    // internally and does not surface it as a DatabaseException, so no
    // codes map to transient.
    final DatabaseException e => StoragePermanentException(
      '[${e.code}] ${e.message}',
      e,
      stack,
    ),
    final StateError e => StoragePermanentException(e.message, e, stack),
    final ArgumentError e => StoragePermanentException(
      (e.message ?? 'invalid argument').toString(),
      e,
      stack,
    ),
    _ => StoragePermanentException(error.toString(), error, stack),
  };
}
