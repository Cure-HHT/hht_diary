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

/// Thrown by `EventStore.ingestBatch` when an incoming event's
/// `lib_format_version` exceeds the receiver's `StoredEvent.currentLibFormatVersion`.
/// The receiver cannot interpret the event's storage shape; the entire batch
/// is rolled back. Operator action: upgrade the receiver lib.
// Implements: REQ-d00145-L.
class IngestLibFormatVersionAhead implements Exception {
  const IngestLibFormatVersionAhead({
    required this.eventId,
    required this.wireVersion,
    required this.receiverVersion,
  });
  final String eventId;
  final int wireVersion;
  final int receiverVersion;
  @override
  String toString() =>
      'IngestLibFormatVersionAhead(event_id: $eventId, '
      'wire: $wireVersion, receiver: $receiverVersion)';
}

/// Thrown by `EventStore.ingestBatch` when an incoming event's
/// `entry_type_version` exceeds `EntryTypeDefinition.registered_version` for
/// its `entry_type` in the receiver's registry. Operator action: upgrade
/// the receiver's entry-type registry to register the new version.
// Implements: REQ-d00145-M.
class IngestEntryTypeVersionAhead implements Exception {
  const IngestEntryTypeVersionAhead({
    required this.eventId,
    required this.entryType,
    required this.wireVersion,
    required this.receiverVersion,
  });
  final String eventId;
  final String entryType;
  final int wireVersion;
  final int receiverVersion;
  @override
  String toString() =>
      'IngestEntryTypeVersionAhead(event_id: $eventId, entry_type: $entryType, '
      'wire: $wireVersion, receiver: $receiverVersion)';
}
