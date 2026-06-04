// Implements: DIARY-PRD-questionnaire-system/C — exposes the Trial-Start fact the
//   diary gates Diary Data Synchronization on. The diary polls this to learn the
//   trial-start watermark (DIARY-DEV-native-outbound-sync/C) and its current
//   linking status; before Trial Start the diary keeps entries local.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Build the patient-facing `GET /api/v1/user/state` handler over [eventStore].
/// Authenticated by the participant bearer token minted at `/link`; returns the
/// participant's trial-start watermark + linking status. Seam-isolated like
/// `/ingest` for the deferred edge/core split.
Handler patientStateHandler({required EventStore eventStore}) {
  return (Request request) async {
    final payload = verifyPatientAuthHeader(request.headers['authorization']);
    if (payload == null) {
      return Response(401, body: 'invalid or missing patient token');
    }

    // participant_record folds participant_trial_started (carrying `started_at`)
    // alongside the linking-lifecycle status. The JWT's userId IS the
    // participantId (DIARY-DEV-participant-ingest/D).
    final rows = await eventStore.backend.findViewRows('participant_record');
    Map<String, dynamic>? rec;
    for (final r in rows) {
      if (r['participant_id'] == payload.userId ||
          r['aggregateId'] == payload.userId) {
        rec = r;
        break;
      }
    }

    final trialStartedAt = rec?['started_at'] as String?;
    final status = rec?['mobile_linking_status'] as String?;
    return Response.ok(
      jsonEncode(<String, Object?>{
        'trial_started': trialStartedAt != null,
        if (trialStartedAt != null) 'trial_started_at': trialStartedAt,
        if (status != null) 'mobile_linking_status': status,
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  };
}
