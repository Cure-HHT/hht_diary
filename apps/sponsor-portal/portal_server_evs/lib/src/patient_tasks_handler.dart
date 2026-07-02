// Implements: DIARY-PRD-questionnaire-system/B — serves the participant's active
//   assigned questionnaires from the questionnaire_instance view (replaces the
//   legacy 401).
// Implements: DIARY-PRD-questionnaire-system/C+D — gated on Trial Start; empties
//   when not participating. A *disconnected* participant still receives their
//   tasks (is_disconnected is surfaced for the diary, but does not gate).
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Map a [questionnaire_instance] row's [entryType] to the task status string
/// the diary uses to categorize tasks.
///
/// All non-tombstoned [questionnaire_instance] rows are returned regardless of
/// lifecycle stage — the diary needs `finalized` to mint its device-observed
/// event, and `unlocked` to re-present the task for re-submission.
/// Tombstoned (called-back) instances are absent from the view entirely, so no
/// explicit skip is needed for them.
// Implements: DIARY-GUI-participant-task-list/I+J — the diary needs the
//   submitted/finalized/unlocked status to categorize tasks; finalization
//   removes the task only after the diary records it.
String _statusFor(String entryType) {
  return switch (entryType) {
    'questionnaire_assigned' => 'sent',
    'questionnaire_submission_received' => 'ready_to_review',
    // CUR-1539: the portal lock event is `questionnaire_locked`;
    // `questionnaire_finalized` is its frozen legacy alias (pre-rename logs).
    // The REST wire `status` value stays 'finalized' — older mobile builds in
    // testers' hands read `status: finalized` off /user/tasks.
    'questionnaire_locked' => 'finalized',
    'questionnaire_finalized' => 'finalized',
    'questionnaire_unlocked' => 'unlocked',
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

    // Only not-participating gates the task list. A *disconnected* participant
    // still receives their tasks (is_disconnected is surfaced for the diary,
    // which pauses sync itself but keeps its JWT) — the asymmetry with the
    // not-participating early-return below is deliberate, not an omission.
    //
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
    // Implements: DIARY-GUI-participant-task-list/I+J — ALL non-tombstoned
    //   instances are returned with their real lifecycle status. The diary needs
    //   'finalized' to mint its device-observed questionnaire_finalized event,
    //   and 'unlocked' to re-present the task for re-submission. Tombstoned
    //   (called-back) instances are absent from the questionnaire_instance view
    //   entirely, so no explicit skip is needed for them.
    final instanceRows =
        await eventStore.backend.findViewRows('questionnaire_instance');
    final tasks = <Map<String, Object?>>[];
    for (final r in instanceRows) {
      if (r['participant_id'] != payload.userId) continue;
      tasks.add(<String, Object?>{
        'questionnaire_instance_id': r['aggregateId'],
        'questionnaire_type': r['type'],
        'status': _statusFor(r['entryType'] as String? ?? ''),
        'study_event': r['study_event'],
      });
    }

    // Implements: DIARY-DEV-outgoing-intent-correlation/B
    // Merge participant-facing recall notices as tasks with status 'recalled'.
    final recallRows =
        await eventStore.backend.findViewRows('questionnaire_recall_notice');
    for (final r in recallRows) {
      if (r['participant_id'] != payload.userId) continue;
      tasks.add(<String, Object?>{
        'questionnaire_instance_id': r['instance_id'],
        'questionnaire_type': null,
        'status': 'recalled',
        'study_event': r['study_event'],
      });
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
