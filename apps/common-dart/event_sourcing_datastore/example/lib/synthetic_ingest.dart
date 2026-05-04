import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:uuid/uuid.dart';

/// Helper for the "Ingest sample batch" demo button on `top_action_bar.dart`.
///
/// Builds a minimal, well-formed `esd/batch@1` envelope carrying ONE
/// synthetic event that pretends to come from a different device
/// (`remote-mobile-1`). The resulting envelope is fed to
/// `EventStore.ingestBatch`, which stamps a receiver `ProvenanceEntry`
/// (with `origin_sequence_number` carrying the wire-supplied seq) and
/// reassigns a fresh local `sequence_number` per REQ-d00145-E.
///
/// **Single-event-per-batch by design.** Plan 4.15 Task 5 Risk 2: the
/// `EventStore.ingestBatch` Chain 1 verifier walks every provenance entry
/// from index `len-1` down to (exclusive) index `0`, recomputing each
/// receiver hop's `arrival_hash`. With a single origin entry the loop
/// never executes, so chain-1 trivially passes — the synthetic event's
/// `event_hash` need not match a real canonical hash. A multi-event
/// batch would also pass (each event's chain is verified independently),
/// but staying at one event keeps the helper self-contained: no need to
/// import `package:crypto` / `canonical_json_jcs` from the example,
/// avoiding a `depend_on_referenced_packages` lint failure.
///
/// The receiver-side `_appendReceiverProvenance` recomputes a real
/// canonical hash for the stored event; the synthetic placeholder hash
/// only ever lives on the receiver provenance entry's `arrival_hash`
/// field (REQ-d00115-G), where its role is documentary, not verifying.
class SyntheticBatchBuilder {
  SyntheticBatchBuilder({
    this.senderHop = 'remote-mobile-1',
    this.senderIdentifier = 'remote-device-uuid-demo',
    this.senderSoftwareVersion = 'remote-diary@1.0.0',
  });

  final String senderHop;
  final String senderIdentifier;
  final String senderSoftwareVersion;

  static const _uuid = Uuid();

  /// Construct a one-event `BatchEnvelope` ready for
  /// `eventStore.ingestBatch(envelope.encode(), wireFormat: 'esd/batch@1')`.
  ///
  /// The synthetic event is shaped like a "demo_note" finalized append on
  /// the originator: a single origin `ProvenanceEntry` with
  /// `received_at = now` and the sender's identifier/software_version,
  /// `sequence_number = originSequenceNumber` (defaults to 1001 — high
  /// enough to be visually distinguishable from local sequence numbers
  /// in the demo), and a deterministic-looking placeholder `event_hash`.
  BatchEnvelope buildSingleEventBatch({
    int originSequenceNumber = 1001,
    String aggregateId = 'remote-aggregate-1',
    String entryType = 'demo_note',
    String aggregateType = 'DiaryEntry',
    String userId = 'remote-user-1',
    Map<String, Object?>? answers,
  }) {
    final now = DateTime.now().toUtc();
    // Build the origin provenance entry as raw JSON. The library
    // re-exports `BatchContext` but not `ProvenanceEntry`; rather than
    // pull `package:provenance` in as a direct dep on the example
    // (just to round-trip a five-field map), the helper writes the
    // snake_case shape inline. `ProvenanceEntry.fromJson` (called
    // inside `ingestBatch`) parses this back.
    final originEntry = <String, Object?>{
      'hop': senderHop,
      'received_at': now.toIso8601String(),
      'identifier': senderIdentifier,
      'software_version': senderSoftwareVersion,
    };
    final eventId = _uuid.v4();
    final eventMap = <String, Object?>{
      'event_id': eventId,
      'aggregate_id': aggregateId,
      'aggregate_type': aggregateType,
      'entry_type': entryType,
      'entry_type_version': 1,
      'lib_format_version': StoredEvent.currentLibFormatVersion,
      'event_type': 'finalized',
      'sequence_number': originSequenceNumber,
      'data': <String, Object?>{
        'answers':
            answers ??
            <String, Object?>{
              'title': 'remote note',
              'body': 'ingested from $senderHop at ${now.toIso8601String()}',
              'date': now.toIso8601String(),
            },
      },
      'metadata': <String, Object?>{
        'change_reason': 'initial',
        'provenance': <Map<String, Object?>>[originEntry],
      },
      'initiator': UserInitiator(userId).toJson(),
      'flow_token': null,
      'client_timestamp': now.toIso8601String(),
      // Placeholder; the receiver only reads this field to stamp it as
      // `arrival_hash` on its own provenance entry. Chain 1 verification
      // never recomputes a hash at the origin position (loop walks from
      // `len-1` down to but not including `0`), so a non-canonical value
      // here is harmless for the demo.
      'event_hash': 'synthetic-origin-hash-$eventId',
      'previous_event_hash': null,
    };
    return BatchEnvelope(
      batchFormatVersion: BatchEnvelope.currentBatchFormatVersion,
      batchId: 'demo-ingest-${now.millisecondsSinceEpoch}',
      senderHop: senderHop,
      senderIdentifier: senderIdentifier,
      senderSoftwareVersion: senderSoftwareVersion,
      sentAt: now,
      events: <Map<String, Object?>>[eventMap],
    );
  }
}
