// Implements: DIARY-DEV-participant-ingest/A — public ingest edge admitting esd/batch@1.
// Implements: DIARY-DEV-participant-ingest/B — bearer patient-token auth before ingest.
// Implements: DIARY-DEV-participant-ingest/C — idempotent, hash-chain-verifying ingest;
//   the receiving node appends its receiver provenance hop (done inside ingestBatch).
import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Build the patient-facing `/ingest` handler over [eventStore]. Dependencies
/// are injected so this module lifts cleanly into a dedicated diary-server node
/// when the edge/core split lands (see design spec section 2).
Handler patientIngestHandler({required EventStore eventStore}) {
  return (Request request) async {
    final payload = verifyPatientAuthHeader(request.headers['authorization']);
    if (payload == null) {
      return Response(401, body: 'invalid or missing patient token');
    }
    final chunks = await request.read().toList();
    final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());

    // Implements: DIARY-DEV-participant-ingest/E — the authenticated participant
    //   must own every participant-prefixed aggregate the batch writes. The JWT
    //   userId IS the participantId. Day-marker aggregates carry the participant
    //   identity as a `{participantId}:{localDate}` aggregate id, so we reject a
    //   batch whose prefix names another participant.
    //
    // Residual: per-event ownership is enforceable ONLY on participant-prefixed
    // (`{pid}:`) aggregates. Epistaxis events use a fresh uuid aggregate id and
    // questionnaire surveys use the portal-assigned instanceId — neither carries
    // a per-event participant identity, and neither can target another
    // participant's aggregate. A leading-colon id (`:foo`) has no participant
    // prefix and is likewise treated as non-prefixed. For those, the sync-channel
    // JWT (verified above) is the trust boundary. This is a documented residual,
    // not a gap.
    final BatchEnvelope env;
    try {
      env = BatchEnvelope.decode(bytes);
    } on IngestDecodeFailure catch (e) {
      // Same malformed-bytes outcome as the ingest path below, for consistency.
      return Response(400, body: 'malformed batch: $e');
    }
    for (final eventMap in env.events) {
      final aggId = eventMap['aggregate_id'] as String?;
      if (aggId != null) {
        final colonIdx = aggId.indexOf(':');
        if (colonIdx > 0) {
          final ownerId = aggId.substring(0, colonIdx);
          if (ownerId != payload.userId) {
            return Response(403,
                body: 'batch contains aggregates not owned by the '
                    'authenticated participant');
          }
        }
        // colonIdx <= 0 (no colon, or leading colon) -> no participant prefix
        // -> non-prefixed -> pass.
      }
    }

    try {
      final result = await eventStore.ingestBatch(bytes,
          wireFormat: BatchEnvelope.wireFormat);
      final ingested = result.events
          .where((e) => e.outcome == IngestOutcome.ingested)
          .length;
      final duplicate = result.events.length - ingested;
      return Response.ok(
        jsonEncode(<String, Object?>{
          'batchId': result.batchId,
          'ingested': ingested,
          'duplicate': duplicate,
        }),
        headers: const {'Content-Type': 'application/json'},
      );
    } on IngestDecodeFailure catch (e) {
      // Unknown wire format or malformed bytes — permanent (4xx, no retry).
      return Response(400, body: 'malformed batch: $e');
    } on IngestChainBroken catch (e) {
      return Response(422, body: 'provenance chain broken: $e');
    } on IngestIdentityMismatch catch (e) {
      return Response(422, body: 'event identity mismatch: $e');
    } on IngestLibFormatVersionAhead catch (e) {
      return Response(422, body: 'lib format version ahead: $e');
    } on IngestEntryTypeVersionAhead catch (e) {
      return Response(422, body: 'entry-type version ahead: $e');
    } catch (e) {
      // Storage / unexpected fault — transient (5xx, destination retries).
      return Response.internalServerError(body: 'ingest failed: $e');
    }
  };
}
