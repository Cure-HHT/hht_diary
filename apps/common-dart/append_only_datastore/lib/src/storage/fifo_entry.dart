import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:collection/collection.dart';

/// One row in a destination's FIFO store.
///
/// Each entry is a transformed, wire-ready copy of an event destined for
/// a specific synchronization target. Entries are enqueued in strict order
/// on write and are never reordered. Once delivered they are marked
/// `FinalStatus.sent` but retained as send-log records; on permanent
/// failure they are marked `FinalStatus.exhausted` and the FIFO head
/// wedges (drain loop stops for this destination until the entry is
/// resolved by operator action).
// Implements: REQ-d00119-B+C — carries the ten documented columns;
// final_status typed to the three legal values (pending|sent|exhausted).
class FifoEntry {
  const FifoEntry({
    required this.entryId,
    required this.eventId,
    required this.sequenceInQueue,
    required this.wirePayload,
    required this.wireFormat,
    required this.transformVersion,
    required this.enqueuedAt,
    required this.attempts,
    required this.finalStatus,
    required this.sentAt,
  });

  /// Decode from snake_case JSON. `wirePayload` and `attempts` are wrapped
  /// unmodifiable so downstream callers cannot mutate the record in place.
  /// Throws [FormatException] on missing or wrong-typed fields.
  factory FifoEntry.fromJson(Map<String, Object?> json) {
    final entryId = json['entry_id'];
    if (entryId is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "entry_id"',
      );
    }
    final eventId = json['event_id'];
    if (eventId is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "event_id"',
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
    if (finalStatusRaw is! String) {
      throw const FormatException(
        'FifoEntry: missing or non-string "final_status"',
      );
    }
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
      eventId: eventId,
      sequenceInQueue: seqInQueue,
      wirePayload: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(wirePayloadRaw),
      ),
      wireFormat: wireFormat,
      transformVersion: transformVersionRaw as String?,
      enqueuedAt: DateTime.parse(enqueuedAtRaw),
      attempts: attempts,
      finalStatus: FinalStatus.fromJson(finalStatusRaw),
      sentAt: sentAtRaw == null ? null : DateTime.parse(sentAtRaw as String),
    );
  }

  /// The aggregate_id of the originating entry. Used for operator diagnostics
  /// and to correlate a FIFO row back to its diary_entries view row.
  final String entryId;

  /// Event_id of the event that produced this FIFO row. Preserved for
  /// audit and for idempotent redelivery.
  final String eventId;

  /// Insertion-order position in this FIFO; monotonic per destination.
  final int sequenceInQueue;

  /// Transformed wire payload ready to hand to `destination.send()`.
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

  /// Terminal state of this entry. On enqueue `pending`; moves to `sent` or
  /// `exhausted` on terminal drain-loop decision.
  final FinalStatus finalStatus;

  /// When the entry was marked `sent`; null while pending or exhausted.
  final DateTime? sentAt;

  /// Encode to snake_case JSON. Optional fields emit explicit null.
  Map<String, Object?> toJson() => <String, Object?>{
    'entry_id': entryId,
    'event_id': eventId,
    'sequence_in_queue': sequenceInQueue,
    'wire_payload': wirePayload,
    'wire_format': wireFormat,
    'transform_version': transformVersion,
    'enqueued_at': enqueuedAt.toIso8601String(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'final_status': finalStatus.toJson(),
    'sent_at': sentAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FifoEntry &&
          entryId == other.entryId &&
          eventId == other.eventId &&
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
    eventId,
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
      'FifoEntry(entryId: $entryId, eventId: $eventId, '
      'sequenceInQueue: $sequenceInQueue, wireFormat: $wireFormat, '
      'finalStatus: $finalStatus, attempts: ${attempts.length})';
}

const DeepCollectionEquality _deepEquals = DeepCollectionEquality();
