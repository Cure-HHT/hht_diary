/// Reason a single chain link failed verification.
enum ChainFailureKind {
  /// `provenance[k].arrival_hash` did not equal the recomputed hash at hop k.
  arrivalHashMismatch,

  /// `provenance[thisHop].previous_ingest_hash` did not equal the stored
  /// `event_hash` of the prior event in Chain 2.
  previousIngestHashMismatch,

  /// An expected provenance entry was missing (e.g., empty provenance on a
  /// non-origin event).
  provenanceMissing,
}

/// A single broken link encountered during a chain walk.
class ChainFailure {
  const ChainFailure({
    required this.position,
    required this.kind,
    required this.expectedHash,
    required this.actualHash,
  });

  /// For Chain 1: the `provenance[]` index of the failing hop.
  /// For Chain 2: the `ingest_sequence_number` of the failing event.
  final int position;
  final ChainFailureKind kind;
  final String expectedHash;
  final String actualHash;
}

/// Non-throwing verdict returned by `verifyEventChain` / `verifyIngestChain`.
// Implements: REQ-d00146-B+C.
class ChainVerdict {
  const ChainVerdict({required this.ok, required this.failures});
  final bool ok;
  final List<ChainFailure> failures;

  static const ChainVerdict valid = ChainVerdict(
    ok: true,
    failures: <ChainFailure>[],
  );
}
