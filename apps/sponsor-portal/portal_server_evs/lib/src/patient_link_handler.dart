// Implements: DIARY-DEV-participant-link-issuance/A+B+C+D — public `/link` edge:
//   validates a coordinator-issued linking code, mints a participant-identity
//   JWT, and atomically consumes the code (appends participant_linking_code_used
//   in the same transaction as the validation read, so single-use is atomic).
//   Reads participant_record + sites_index only to build the response; the
//   relink/device gate (B2) and /ingest ownership (B3) are layered on later.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Outcome of the in-transaction validate+consume step. On success carries the
/// minted [jwt] plus the response fields; on failure carries the HTTP
/// [statusCode] + a short [message] (and no consume event was appended).
class _LinkOutcome {
  _LinkOutcome.failure(this.statusCode, this.message)
      : success = false,
        jwt = null,
        participantId = null,
        siteId = null,
        siteName = null,
        siteNumber = null;

  _LinkOutcome.success({
    required this.jwt,
    required this.participantId,
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
  })  : success = true,
        statusCode = 200,
        message = null;

  final bool success;
  final int statusCode;
  final String? message;
  final String? jwt;
  final String? participantId;
  final String? siteId;
  final String? siteName;
  final String? siteNumber;
}

/// Build the patient-facing `/link` handler over [eventStore]. Dependencies are
/// injected so this module lifts cleanly into a dedicated diary-server node when
/// the edge/core split lands (mirrors [patientIngestHandler]).
Handler patientLinkHandler({required EventStore eventStore}) {
  return (Request request) async {
    // 1. Parse the body; reject unparseable JSON or a missing/blank code.
    final String rawCode;
    final String? appUuid;
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map) return Response(400, body: 'malformed request body');
      final code = decoded['code'];
      if (code is! String || code.trim().isEmpty) {
        return Response(400, body: 'missing linking code');
      }
      rawCode = code;
      final uuid = decoded['appUuid'];
      appUuid = uuid is String ? uuid : null;
    } catch (_) {
      return Response(400, body: 'malformed request body');
    }

    // 2. Normalize: strip the display dash/spaces; stored codes are uppercase.
    final normalizedCode =
        rawCode.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalizedCode.isEmpty) {
      return Response(400, body: 'missing linking code');
    }

    // 3. Validate + consume atomically inside one transaction. The decision
    //    (status + response fields) is returned OUT of the body; the
    //    consume append happens ONLY on the success path.
    final outcome = await eventStore.runTransaction<_LinkOutcome>(
      (txn, collector) async {
        final backend = eventStore.backend;

        // 3a. Look up the code. `where:` filtering is unreliable for arbitrary
        //     view columns across backends, so read all rows + filter in Dart.
        final codeRows = await backend.findViewRowsInTxn(txn, 'linking_codes');
        Map<String, dynamic>? codeRow;
        for (final row in codeRows) {
          if (row['linking_code'] == normalizedCode) {
            codeRow = row;
            break;
          }
        }
        if (codeRow == null) {
          return _LinkOutcome.failure(400, 'invalid or unknown code');
        }

        final status = codeRow['status'];
        if (status == 'used') {
          return _LinkOutcome.failure(409, 'code already used');
        }
        if (status == 'revoked') {
          return _LinkOutcome.failure(410, 'code revoked');
        }

        // Active but expired -> 410.
        final expiresRaw = codeRow['expires_at'];
        if (expiresRaw is String) {
          final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
          if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
            return _LinkOutcome.failure(410, 'code expired');
          }
        }

        // 3b. Active + unexpired: continue.
        final participantId = codeRow['participant_id'] as String;
        final siteId = codeRow['site_id'] as String?;

        // 3c. Read site info for the response (participant_record is read for
        //     B2's relink gate later; not needed for the B1 response itself).
        String? siteName;
        String? siteNumber;
        if (siteId != null) {
          final siteRows = await backend.findViewRowsInTxn(txn, 'sites_index');
          for (final row in siteRows) {
            if (row['site_id'] == siteId) {
              siteName = row['site_name'] as String?;
              siteNumber = row['site_number'] as String?;
              break;
            }
          }
        }

        // 3d. Mint the participant-identity JWT.
        final jwt = createPatientJwt(
          authCode: normalizedCode,
          userId: participantId,
        );

        // 3e. Consume the code: append participant_linking_code_used. This both
        //     marks linking_codes[code].status='used' (atomic single-use) and
        //     merges mobile_linking_status/app_uuid into participant_record.
        await eventStore.appendInTxn(
          txn,
          entryType: 'participant_linking_code_used',
          aggregateId: participantId,
          aggregateType: 'participant',
          eventType: 'participant_linking_code_used',
          data: <String, Object?>{
            'linking_code': normalizedCode,
            'participant_id': participantId,
            'app_uuid': appUuid,
            'used_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'used',
            'mobile_linking_status': 'connected',
          },
          initiator: const AutomationInitiator(service: 'patient-link'),
          flowToken: null,
          metadata: null,
          security: null,
          checkpointReason: null,
          changeReason: null,
          dedupeByContent: false,
          collector: collector,
        );

        return _LinkOutcome.success(
          jwt: jwt,
          participantId: participantId,
          siteId: siteId,
          siteName: siteName,
          siteNumber: siteNumber,
        );
      },
    );

    // 4. Map the outcome to an HTTP response.
    if (!outcome.success) {
      return Response(outcome.statusCode, body: outcome.message);
    }
    final participantId = outcome.participantId;
    return Response.ok(
      jsonEncode(<String, Object?>{
        'success': true,
        'jwt': outcome.jwt,
        'userId': participantId,
        'participantId': participantId,
        'linkingCode': normalizedCode,
        'siteId': outcome.siteId,
        'siteName': outcome.siteName,
        'siteNumber': outcome.siteNumber,
        'studyParticipantId': participantId,
        'sitePhoneNumber': null,
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  };
}
