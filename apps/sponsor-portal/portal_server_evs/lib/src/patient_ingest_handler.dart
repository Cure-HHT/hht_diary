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
    if (verifyPatientAuthHeader(request.headers['authorization']) == null) {
      return Response(401, body: 'invalid or missing patient token');
    }
    final chunks = await request.read().toList();
    final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());
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
