// Implements: DIARY-PRD-questionnaire-system/B — serves the participant's active
//   assigned questionnaires from the questionnaire_instance view (replaces the
//   legacy 401).
// Implements: DIARY-PRD-questionnaire-system/C+D — gated on Trial Start; empties
//   when disconnected / not participating.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Map a [questionnaire_instance] row's [entryType] to the task status string
/// the diary displays. Phase 1 only sees `questionnaire_assigned`; the switch
/// is intentionally open for future lifecycle entry types.
String _statusFor(String entryType) {
  return switch (entryType) {
    'questionnaire_assigned' => 'sent',
    _ => 'sent',
  };
}

/// Build the patient-facing `GET /api/v1/user/tasks` handler over [eventStore].
/// Authenticated by the participant bearer token minted at `/link`; returns the
/// participant's active assigned questionnaires plus the trial-start / lifecycle
/// facts the diary needs to decide whether to act on the tasks.
Handler patientTasksHandler({required EventStore eventStore}) {
  return (Request request) async {
    final payload = verifyPatientAuthHeader(request.headers['authorization']);
    if (payload == null) {
      return Response(401, body: 'invalid or missing patient token');
    }

    // Read participant_record for trial-start watermark + lifecycle status.
    // The JWT's userId IS the participantId (DIARY-DEV-participant-ingest/D).
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
    final entryType = rec?['entryType'] as String?;
    final isDisconnected = entryType == 'participant_disconnected';
    // Implements: DIARY-PRD-questionnaire-system/C+D
    final isNotParticipating =
        entryType == 'participant_marked_not_participating';

    // When the participant is no longer in the trial the diary must forget its
    // JWT; return an empty task list so the diary does exactly that.
    if (isNotParticipating) {
      return Response.ok(
        jsonEncode(<String, Object?>{
          'tasks': const <Object?>[],
          'trial_started': trialStartedAt != null,
          if (trialStartedAt != null) 'trial_started_at': trialStartedAt,
          'is_disconnected': isDisconnected,
          'is_not_participating': true,
        }),
        headers: const {'Content-Type': 'application/json'},
      );
    }

    // Read questionnaire_instance and filter to this participant's rows.
    // Implements: DIARY-PRD-questionnaire-system/B
    final instanceRows =
        await eventStore.backend.findViewRows('questionnaire_instance');
    final tasks = <Map<String, Object?>>[];
    for (final r in instanceRows) {
      if (r['participant_id'] == payload.userId) {
        tasks.add(<String, Object?>{
          'questionnaire_instance_id': r['aggregateId'],
          'questionnaire_type': r['type'],
          'status': _statusFor(r['entryType'] as String? ?? ''),
          'study_event': r['study_event'],
        });
      }
    }

    return Response.ok(
      jsonEncode(<String, Object?>{
        'tasks': tasks,
        'trial_started': trialStartedAt != null,
        if (trialStartedAt != null) 'trial_started_at': trialStartedAt,
        'is_disconnected': isDisconnected,
        'is_not_participating': false,
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  };
}
