/// Thrown by `EventStore.ingestBatch` / `ingestEvent` / `BatchEnvelope.decode`
/// when the input bytes cannot be parsed as a well-formed `esd/batch@1`
/// envelope (malformed JSON, wrong shape, unsupported format version,
/// missing required fields).
// Implements: REQ-d00145-B.
class IngestDecodeFailure implements Exception {
  const IngestDecodeFailure(this.message);
  final String message;
  @override
  String toString() => 'IngestDecodeFailure: $message';
}

/// Thrown by `ingestBatch` / `ingestEvent` when an incoming event's Chain 1
/// does not verify — some hop's `arrival_hash` does not match the hash the
/// prior state would produce.
// Implements: REQ-d00145-C.
class IngestChainBroken implements Exception {
  const IngestChainBroken({
    required this.eventId,
    required this.hopIndex,
    required this.expectedHash,
    required this.actualHash,
  });
  final String eventId;
  final int hopIndex;
  final String expectedHash;
  final String actualHash;
  @override
  String toString() =>
      'IngestChainBroken(eventId: $eventId, hopIndex: $hopIndex, '
      'expected: $expectedHash, actual: $actualHash)';
}

/// Thrown by `ingestBatch` / `ingestEvent` when an incoming event's
/// `event_id` matches an already-stored event but the incoming wire
/// `event_hash` differs from the stored copy's
/// `provenance[thisHop].arrival_hash` (i.e., the two copies are NOT
/// byte-identical).
// Implements: REQ-d00145-D.
class IngestIdentityMismatch implements Exception {
  const IngestIdentityMismatch({
    required this.eventId,
    required this.incomingHash,
    required this.storedArrivalHash,
  });
  final String eventId;
  final String incomingHash;
  final String storedArrivalHash;
  @override
  String toString() =>
      'IngestIdentityMismatch(eventId: $eventId, incoming: $incomingHash, '
      'storedArrival: $storedArrivalHash)';
}
