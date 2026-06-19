// POST /admin/questionnaire/send — server-side send-orchestration for the
// "Send Now" / "Start Next Cycle" coordinator action.
//
// EVS actions cannot read projections mid-execute (the dispatcher's stages run
// against a snapshot, and an action's execute() may not query views), so the
// next-cycle decision is made HERE, in server code that can read the
// questionnaire_instance view + the cycle-tracking settings. Once the cycle is
// resolved, this handler dispatches the existing ACT-QST-001 action in-process
// via the ActionDispatcher, mints the instance id, and maps the dispatch
// outcome to an HTTP response.
//
// Mounted under /admin/ so the nginx reverse proxy forwards it to the dart
// backend (a bare /debug/ or other prefix is served the SPA instead).
import 'dart:convert';
import 'dart:math';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'next_cycle.dart';
import 'portal_settings.dart';

/// Mints an instance id for a new questionnaire send. No `uuid` dependency is
/// declared, so this composes a UUID-v4-shaped string from a cryptographically
/// secure RNG. Collision probability is negligible and each send is a distinct
/// aggregate, so a fresh id per call is correct.
String _mintInstanceId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // RFC 4122 version 4 + variant bits.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) => [
        for (var i = start; i < end; i++)
          bytes[i].toRadixString(16).padLeft(2, '0'),
      ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Whether a participant in this lifecycle state may be SENT a questionnaire.
///
/// A questionnaire may only be sent to a trial-ACTIVE participant — one whose
/// trial has been started. The portal UI already enforces this: it offers the
/// "Manage Questionnaires" surface (the only path to a send) ONLY for a
/// trial-active participant (`portal_ui_evs` `participant_status.dart`
/// `primaryActionFor`: `linkedAwaitingStart -> Start Trial`,
/// `trialActive -> Manage Questionnaires`). This endpoint MUST enforce the same
/// precondition independently — the UI cannot be the only gate, or a direct API
/// call can send to a participant who is still inactive (just synced from the
/// EDC) or "Linked – Awaiting Start".
///
/// Trial-active mirrors `effectiveParticipantStatus(entryType, trialStarted:
/// startedAt != null) == ParticipantStatus.trialActive`: the trial has started
/// (`started_at` is set on `participant_record`, preserved across a
/// not-participating -> reactivate -> re-link cycle by the key-wise-merge fold)
/// AND the participant is currently connected/active — i.e. the latest lifecycle
/// `entryType` is `participant_trial_started`, or a post-start re-link
/// (`participant_linking_code_used` / `participant_linked`). A participant who
/// is disconnected, marked not-participating, pending a re-link, or never
/// trial-started is NOT sendable.
///
/// This is the send-side dual of the Diary Data Synchronization gate:
/// `DIARY-PRD-questionnaire-system/C` activates synchronization upon Trial Start
/// and `/D` deactivates it on disconnect / not-participating. A questionnaire
/// sent while synchronization is inactive (pre-Trial-Start, disconnected, or
/// not-participating) could never have its response promoted to the Sponsor
/// portal / Rave EDC, so the send must be gated on the same trial-active window.
///
/// Implements: DIARY-PRD-questionnaire-system/C+D
bool participantTrialActive({String? entryType, String? startedAt}) {
  if (startedAt == null) return false;
  return switch (entryType) {
    'participant_trial_started' ||
    'participant_linking_code_used' ||
    'participant_linked' =>
      true,
    _ => false,
  };
}

/// Core send-orchestration logic, testable without the HTTP/auth wrapper.
///
/// Reads the questionnaire_instance view rows for `(participantId,
/// questionnaireType)` (tombstoned/called-back instances are already absent
/// from the view), reads the cycle-tracking settings, computes the next cycle,
/// and either rejects (409/422) or dispatches ACT-QST-001 (200/403).
///
/// [body] is the parsed JSON: `{siteId, participantId, questionnaireType,
/// studyEvent?}`.
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
// Implements: DIARY-BASE-questionnaire-cycle-tracking/D+K
Future<Response> respondToSend(
  EventStore eventStore,
  ActionDispatcher dispatcher,
  Principal principal,
  Map<String, Object?> body,
) async {
  final siteId = body['siteId'];
  final participantId = body['participantId'];
  final questionnaireType = body['questionnaireType'];
  final requestedStudyEvent = body['studyEvent'];
  if (siteId is! String ||
      siteId.isEmpty ||
      participantId is! String ||
      participantId.isEmpty ||
      questionnaireType is! String ||
      questionnaireType.isEmpty) {
    return Response(
      400,
      body: jsonEncode(<String, Object?>{
        'error':
            'expects {siteId, participantId, questionnaireType}: non-empty String',
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  }
  if (requestedStudyEvent != null && requestedStudyEvent is! String) {
    return Response(
      400,
      body: jsonEncode(<String, Object?>{
        'error': 'studyEvent must be a String when present'
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  }
  // Normalize a whitespace-only studyEvent to null so it is not treated as an
  // explicit cycle selection — otherwise `{studyEvent: " "}` would be written to
  // the instance as an empty/whitespace study_event.
  final trimmedStudyEvent = (requestedStudyEvent as String?)?.trim();
  final effectiveStudyEvent =
      (trimmedStudyEvent == null || trimmedStudyEvent.isEmpty)
          ? null
          : trimmedStudyEvent;

  final backend = eventStore.backend;

  // Precondition: only a trial-ACTIVE participant may be sent a questionnaire
  // (the UI gates this; the endpoint must too — see [participantTrialActive]).
  // participant_record folds the latest lifecycle entryType + the preserved
  // started_at; match on participant_id/aggregateId the same way
  // patient_state_handler does.
  // Implements: DIARY-PRD-questionnaire-system/C+D
  final participantRows = await backend.findViewRows('participant_record');
  Map<String, Object?>? participantRec;
  for (final r in participantRows) {
    if (r['participant_id'] == participantId ||
        r['aggregateId'] == participantId) {
      participantRec = r;
      break;
    }
  }
  if (!participantTrialActive(
    entryType: participantRec?['entryType'] as String?,
    startedAt: participantRec?['started_at'] as String?,
  )) {
    return Response(
      409,
      body: jsonEncode(<String, Object?>{
        'error': 'participant trial is not active; start the participant\'s '
            'trial before sending a questionnaire',
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  }

  // Read this participant's non-tombstoned instances of this type. Call-back
  // (tombstone) rows are already removed from the view by the projection spec.
  final allRows = await backend.findViewRows('questionnaire_instance');
  final existing = <Map<String, Object?>>[
    for (final r in allRows)
      if (r['participant_id'] == participantId &&
          r['type'] == questionnaireType)
        r,
  ];

  final cycleTracking = await cycleTrackingEnabled(backend);
  final requireInitial = await requireInitialCycleSelection(backend);

  final decision = computeNextCycle(
    existing: existing,
    cycleTrackingEnabled: cycleTracking,
    requireInitialCycleSelection: requireInitial,
    requestedStudyEvent: effectiveStudyEvent,
  );

  switch (decision) {
    case NextCycleBlocked(:final reason):
      return Response(
        409,
        body: jsonEncode(<String, Object?>{'error': reason}),
        headers: const {'Content-Type': 'application/json'},
      );
    case NextCycleNeedsSelection():
      return Response(
        422,
        body: jsonEncode(
            <String, Object?>{'error': 'needs_initial_cycle_selection'}),
        headers: const {'Content-Type': 'application/json'},
      );
    case NextCycleAuto(:final studyEvent):
      final instanceId = _mintInstanceId();
      final result = await dispatcher.dispatch(
        ActionSubmission(
          actionName: 'ACT-QST-001',
          rawInput: <String, Object?>{
            'siteId': siteId,
            'instanceId': instanceId,
            'participantId': participantId,
            'questionnaireType': questionnaireType,
            if (studyEvent != null) 'studyEvent': studyEvent,
          },
          idempotencyKey: 'send:$instanceId',
        ),
        ActionContext(
          principal: principal,
          security: const SecurityDetails(),
          requestStartedAt: DateTime.now().toUtc(),
        ),
      );
      switch (result) {
        case DispatchSuccess():
          return Response.ok(
            jsonEncode(<String, Object?>{
              'instanceId': instanceId,
              'studyEvent': studyEvent,
            }),
            headers: const {'Content-Type': 'application/json'},
          );
        case DispatchAuthorizationDenied():
          return Response.forbidden(
            jsonEncode(<String, Object?>{
              'error': 'not authorized to send for this site'
            }),
            headers: const {'Content-Type': 'application/json'},
          );
        default:
          return Response(
            500,
            body: jsonEncode(<String, Object?>{
              'error': 'send dispatch failed: ${result.runtimeType}',
            }),
            headers: const {'Content-Type': 'application/json'},
          );
      }
  }
}
