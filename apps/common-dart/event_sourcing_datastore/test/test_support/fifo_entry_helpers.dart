import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Build a `FifoEntry` for the common single-event batch case without
/// forcing every call-site to spell out `eventIds: [id]` and
/// `eventIdRange: (firstSeq: n, lastSeq: n)`.
///
/// This helper exists for tests that pre-date Phase 4.3 Task 6's
/// single-event → batch-per-row migration. The batch shape (REQ-d00128-A
/// + B) makes `eventIds` and `eventIdRange` required on `FifoEntry`;
/// wrapping a scalar `eventId` + `sequenceNumber` into both fields here
/// keeps per-call churn minimal.
// Implements: REQ-d00128-A+B — construct a valid batch-shape FifoEntry
// from a single event's id and sequence_number.
/// Build a minimal `StoredEvent` fixture with the given id and sequence
/// number. Tests that need a batch input to `StorageBackend.enqueueFifo`
/// construct one via `[storedEventFixture(...)]`.
StoredEvent storedEventFixture({
  required String eventId,
  required int sequenceNumber,
  String aggregateId = 'agg-1',
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
}) => StoredEvent(
  key: 0,
  eventId: eventId,
  aggregateId: aggregateId,
  aggregateType: 'DiaryEntry',
  entryType: entryType,
  entryTypeVersion: 1,
  libFormatVersion: 1,
  eventType: eventType,
  sequenceNumber: sequenceNumber,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  initiator: const UserInitiator('u'),
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash-$eventId',
);

/// Build a `WirePayload` whose bytes encode [payload] as JSON. The
/// standalone `SembastBackend.enqueueFifo` requires a JSON-object
/// payload so it can persist the decoded map into the FIFO row.
WirePayload wirePayloadJson(
  Map<String, Object?> payload, {
  String contentType = 'json-v1',
  String? transformVersion = 'json-v1',
}) => WirePayload(
  bytes: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
  contentType: contentType,
  transformVersion: transformVersion,
);

/// Convenience: enqueue a single-event batch through the new batch-aware
/// `StorageBackend.enqueueFifo`. Wraps [eventId] + [sequenceNumber] in a
/// one-element batch and a JSON-encoded wire payload; returns the
/// persisted `FifoEntry`. Used by tests that pre-date the batch-per-row
/// migration where every FIFO row in the suite was a single event.
Future<FifoEntry> enqueueSingle(
  StorageBackend backend,
  String destinationId, {
  required String eventId,
  int sequenceNumber = 1,
  Map<String, Object?>? wirePayload,
  String wireFormat = 'json-v1',
  String? transformVersion = 'json-v1',
}) => backend.enqueueFifo(
  destinationId,
  [storedEventFixture(eventId: eventId, sequenceNumber: sequenceNumber)],
  wirePayload: wirePayloadJson(
    wirePayload ?? const <String, Object?>{'ok': true},
    contentType: wireFormat,
    transformVersion: transformVersion,
  ),
);

FifoEntry singleEventFifoEntry({
  required String entryId,
  required String eventId,
  required int sequenceNumber,
  required int sequenceInQueue,
  Map<String, Object?>? wirePayload,
  String wireFormat = 'json-v1',
  String? transformVersion,
  DateTime? enqueuedAt,
  List<AttemptResult>? attempts,
  FinalStatus? finalStatus,
  DateTime? sentAt,
}) => FifoEntry(
  entryId: entryId,
  eventIds: [eventId],
  eventIdRange: (firstSeq: sequenceNumber, lastSeq: sequenceNumber),
  sequenceInQueue: sequenceInQueue,
  wirePayload: wirePayload ?? const {'ok': true},
  wireFormat: wireFormat,
  transformVersion: transformVersion,
  enqueuedAt: enqueuedAt ?? DateTime.utc(2026, 4, 22),
  attempts: attempts ?? const [],
  finalStatus: finalStatus,
  sentAt: sentAt,
);
