import 'package:collection/collection.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';

/// Inclusive pair of sequence numbers drawn from the events in a batch
/// FIFO row. `firstSeq` is the minimum `sequence_number` across the batch
/// and `lastSeq` is the maximum; for a single-event batch they are equal.
///
/// Declared as a Dart 3 record typedef so callers read the pair positionally
/// (or via the named fields) without needing a dedicated class. Cursor-
/// advancement math in the drain/fill-batch paths uses `lastSeq` as the
/// inclusive upper bound of the batch (REQ-d00128-B).
// Implements: REQ-d00128-B — event_id_range is a (first_seq, last_seq) pair.
typedef EventIdRange = ({int firstSeq, int lastSeq});

/// One row in a destination's FIFO store — a batch of one or more events
/// transformed together into a single wire-ready payload.
///
/// Each row is a transformed copy of a contiguous slice of the event log
/// destined for a specific synchronization target. Rows are appended in
/// strict order on write and are never reordered. `finalStatus` is
/// nullable; `null` means "not-yet-terminal" (drain may attempt the
/// row). Once delivered they are marked `FinalStatus.sent`; on
/// permanent failure they are marked `FinalStatus.wedged`; rows excised
/// by a trail sweep are marked `FinalStatus.tombstoned`. All non-null
/// terminal states are retained forever as send-log / audit records
/// (REQ-d00119-D).
///
/// Phase-4.3 Task 6 migrated this type from a single-event-per-row shape
/// to a batch-per-row shape: `eventIds` is a non-empty `List<String>`,
/// `eventIdRange` is an `(firstSeq, lastSeq)` record, and `wirePayload`
/// is one payload for the whole batch (no per-event payload is stored).
// Implements: REQ-d00119-B+C — carries the documented columns;
// final_status is nullable (null means not-yet-terminal; non-null
// values are one of {sent, wedged, tombstoned}).
// Implements: REQ-d00128-A — eventIds is non-empty; enforced via
// ArgumentError at construction and FormatException on fromJson.
// Implements: REQ-d00128-B — eventIdRange is a (first_seq, last_seq) pair.
// Implements: REQ-d00128-C — wirePayload is one payload covering the
// entire batch.
class FifoEntry {
  FifoEntry({
    required this.entryId,
    required this.eventIds,
    required this.eventIdRange,
    required this.sequenceInQueue,
    required this.wirePayload,
    required this.wireFormat,
    required this.transformVersion,
    required this.enqueuedAt,
    required this.attempts,
    required this.finalStatus,
    required this.sentAt,
  }) {
    // Implements: REQ-d00128-A — reject empty batches at construction.
    // Explicit ArgumentError rather than assert so the invariant is
    // enforced in release builds too, not just debug.
    if (eventIds.isEmpty) {
      throw ArgumentError.value(
        eventIds,
        'eventIds',
        'FifoEntry.eventIds must be non-empty (REQ-d00128-A)',
      );
    }
    // Implements: REQ-d00128-B — event_id_range is drawn from the batch's
    // sequence numbers; the pair MUST be ordered (firstSeq <= lastSeq).
    if (eventIdRange.firstSeq > eventIdRange.lastSeq) {
      throw ArgumentError.value(
        eventIdRange,
        'eventIdRange',
        'eventIdRange.firstSeq (${eventIdRange.firstSeq}) must be '
            '<= lastSeq (${eventIdRange.lastSeq}) (REQ-d00128-B)',
      );
    }
  }

  /// Decode from snake_case JSON. `wirePayload`, `attempts`, and
  /// `eventIds` are wrapped unmodifiable so downstream callers cannot
  /// mutate the record in place. Throws [FormatException] on missing
  /// or wrong-typed fields, or when `event_ids` is empty (REQ-d00128-A).
  factory FifoEntry.fromJson(Map<String, Object?> json) {
    final entryId = json['entry_id'];
    if (entryId is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "entry_id"',
      );
    }
    final eventIdsRaw = json['event_ids'];
    if (eventIdsRaw is! List) {
      throw const FormatException('FifoEntry: missing or non-List "event_ids"');
    }
    if (eventIdsRaw.isEmpty) {
      throw const FormatException(
        'FifoEntry: "event_ids" must be non-empty (REQ-d00128-A)',
      );
    }
    final eventIds = <String>[];
    for (final e in eventIdsRaw) {
      if (e is! String) {
        throw const FormatException(
          'FifoEntry: every element of "event_ids" must be a String',
        );
      }
      eventIds.add(e);
    }
    final eventIdRangeRaw = json['event_id_range'];
    if (eventIdRangeRaw is! Map) {
      throw const FormatException(
        'FifoEntry: missing or non-Map "event_id_range"',
      );
    }
    final firstSeq = eventIdRangeRaw['first_seq'];
    if (firstSeq is! int) {
      throw const FormatException(
        'FifoEntry: "event_id_range.first_seq" must be an int',
      );
    }
    final lastSeq = eventIdRangeRaw['last_seq'];
    if (lastSeq is! int) {
      throw const FormatException(
        'FifoEntry: "event_id_range.last_seq" must be an int',
      );
    }
    final seqInQueue = json['sequence_in_queue'];
    if (seqInQueue is! int) {
      throw const FormatException(
        'FifoEntry: missing or non-int "sequence_in_queue"',
      );
    }
    final wirePayloadRaw = json['wire_payload'];
    if (wirePayloadRaw is! Map) {
      throw const FormatException(
        'FifoEntry: missing or non-Map "wire_payload"',
      );
    }
    final wireFormat = json['wire_format'];
    if (wireFormat is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "wire_format"',
      );
    }
    final transformVersionRaw = json['transform_version'];
    if (transformVersionRaw != null && transformVersionRaw is! String) {
      throw const FormatException(
        'FifoEntry: "transform_version" must be a String when present',
      );
    }
    final enqueuedAtRaw = json['enqueued_at'];
    if (enqueuedAtRaw is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "enqueued_at"',
      );
    }
    final attemptsRaw = json['attempts'];
    if (attemptsRaw is! List) {
      throw const FormatException('FifoEntry: missing or non-List "attempts"');
    }
    final finalStatusRaw = json['final_status'];
    if (finalStatusRaw != null && finalStatusRaw is! String) {
      throw const FormatException(
        'FifoEntry: "final_status" must be a String or null',
      );
    }
    final finalStatus = finalStatusRaw == null
        ? null
        : FinalStatus.fromJson(finalStatusRaw as String);
    final sentAtRaw = json['sent_at'];
    if (sentAtRaw != null && sentAtRaw is! String) {
      throw const FormatException(
        'FifoEntry: "sent_at" must be a String when present',
      );
    }

    final attempts = List<AttemptResult>.unmodifiable(
      attemptsRaw.map(
        (e) => AttemptResult.fromJson(Map<String, Object?>.from(e as Map)),
      ),
    );
    return FifoEntry(
      entryId: entryId,
      eventIds: List<String>.unmodifiable(eventIds),
      eventIdRange: (firstSeq: firstSeq, lastSeq: lastSeq),
      sequenceInQueue: seqInQueue,
      wirePayload: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(wirePayloadRaw),
      ),
      wireFormat: wireFormat,
      transformVersion: transformVersionRaw as String?,
      enqueuedAt: DateTime.parse(enqueuedAtRaw),
      attempts: attempts,
      finalStatus: finalStatus,
      sentAt: sentAtRaw == null ? null : DateTime.parse(sentAtRaw as String),
    );
  }

  /// Stable per-row identifier used by `markFinal`, `appendAttempt`,
  /// `tombstoneAndRefill`, and operator diagnostics. Generated as a v4
  /// UUID at enqueue time and never reused across rows; two FIFO rows
  /// (of any `final_status`, including tombstoned archive rows) never
  /// share an `entryId`. The identifier has no relationship to the
  /// events the row carries — callers that need to correlate against
  /// events should use `eventIds` or `eventIdRange` instead.
  final String entryId;

  /// Event_ids of every event included in this batch row, in the order they
  /// were batched. Always non-empty (REQ-d00128-A) — enforced at
  /// construction and rechecked on `fromJson`. Preserved for audit and for
  /// idempotent redelivery.
  // Implements: REQ-d00128-A — non-empty list identifying every event in
  // the batch.
  final List<String> eventIds;

  /// Inclusive `(first_seq, last_seq)` pair drawn from the sequence_numbers
  /// of the events in this batch. Used for cursor advancement math in the
  /// drain and fill-batch paths — `lastSeq` is the upper bound of the batch
  /// on the event log. For a single-event batch, `firstSeq == lastSeq`.
  // Implements: REQ-d00128-B — (first_seq, last_seq) pair for cursor math.
  final EventIdRange eventIdRange;

  /// Insertion-order position in this FIFO; monotonic per destination.
  final int sequenceInQueue;

  /// Transformed wire payload ready to hand to `destination.send()`. One
  /// payload covers every event in the batch (REQ-d00128-C); per-event
  /// wire payloads are NOT stored.
  // Implements: REQ-d00128-C — one payload per batch row.
  final Map<String, Object?> wirePayload;

  /// Wire-format discriminator (e.g., `"json-v1"`, `"fhir-r4"`).
  final String wireFormat;

  /// Version of the transform that produced `wirePayload`; null for
  /// pass-through (identity transform).
  final String? transformVersion;

  /// When the entry was appended to the FIFO (equal to the enclosing
  /// write transaction commit instant for all practical purposes).
  final DateTime enqueuedAt;

  /// Historical send attempts; grows, never shrinks; retained forever per
  /// REQ-d00119-D.
  final List<AttemptResult> attempts;

  /// Terminal state of this entry. `null` on enqueue and while the row is
  /// still a drain candidate; moves to `sent`, `wedged`, or `tombstoned`
  /// on a terminal transition. Non-null terminal values are retained
  /// forever as audit records (REQ-d00119-D).
  final FinalStatus? finalStatus;

  /// When the entry was marked `sent`; null while pre-terminal, wedged,
  /// or tombstoned.
  final DateTime? sentAt;

  /// Encode to snake_case JSON. Optional fields emit explicit null.
  Map<String, Object?> toJson() => <String, Object?>{
    'entry_id': entryId,
    'event_ids': eventIds,
    'event_id_range': <String, Object?>{
      'first_seq': eventIdRange.firstSeq,
      'last_seq': eventIdRange.lastSeq,
    },
    'sequence_in_queue': sequenceInQueue,
    'wire_payload': wirePayload,
    'wire_format': wireFormat,
    'transform_version': transformVersion,
    'enqueued_at': enqueuedAt.toIso8601String(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'final_status': finalStatus?.toJson(),
    'sent_at': sentAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FifoEntry &&
          entryId == other.entryId &&
          const ListEquality<String>().equals(eventIds, other.eventIds) &&
          eventIdRange == other.eventIdRange &&
          sequenceInQueue == other.sequenceInQueue &&
          _deepEquals.equals(wirePayload, other.wirePayload) &&
          wireFormat == other.wireFormat &&
          transformVersion == other.transformVersion &&
          enqueuedAt == other.enqueuedAt &&
          const ListEquality<AttemptResult>().equals(
            attempts,
            other.attempts,
          ) &&
          finalStatus == other.finalStatus &&
          sentAt == other.sentAt;

  @override
  int get hashCode => Object.hash(
    entryId,
    const ListEquality<String>().hash(eventIds),
    eventIdRange,
    sequenceInQueue,
    _deepEquals.hash(wirePayload),
    wireFormat,
    transformVersion,
    enqueuedAt,
    const ListEquality<AttemptResult>().hash(attempts),
    finalStatus,
    sentAt,
  );

  @override
  String toString() =>
      'FifoEntry(entryId: $entryId, eventIds: $eventIds, '
      'eventIdRange: (firstSeq: ${eventIdRange.firstSeq}, '
      'lastSeq: ${eventIdRange.lastSeq}), '
      'sequenceInQueue: $sequenceInQueue, wireFormat: $wireFormat, '
      'finalStatus: $finalStatus, attempts: ${attempts.length})';
}

const DeepCollectionEquality _deepEquals = DeepCollectionEquality();
