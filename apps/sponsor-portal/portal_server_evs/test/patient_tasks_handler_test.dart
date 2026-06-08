// Verifies: DIARY-PRD-questionnaire-system/B — handler returns one task entry
//   per questionnaire_instance row owned by the authenticated participant.
// Verifies: DIARY-PRD-questionnaire-system/C+D — empty tasks when
//   is_not_participating; trial_started + is_disconnected facts included.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/patient_tasks_handler.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<EventStore> _openStore(String dbName) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

Request _get({String? auth}) => Request(
      'GET',
      Uri.parse('http://localhost/api/v1/user/tasks'),
      headers: {if (auth != null) 'authorization': auth},
    );

/// Seed a participant with a trial-start event so participant_record has a
/// started_at and the participant is actively enrolled.
Future<void> _seedTrialStarted(
  EventStore store, {
  String participantId = 'P-1',
}) async {
  await store.append(
    entryType: 'participant_synced_from_edc',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_synced_from_edc',
    data: <String, Object?>{
      'participant_id': participantId,
      'site_id': 'S-1',
    },
    initiator: const AutomationInitiator(service: 'test'),
  );
  await store.append(
    entryType: 'participant_trial_started',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_trial_started',
    data: <String, Object?>{
      'participant_id': participantId,
      'started_at': '2026-01-01T00:00:00.000Z',
    },
    initiator: const AutomationInitiator(service: 'test'),
  );
}

void main() {
  test('no token -> 401', () async {
    final store = await _openStore('tasks-no-token');
    addTearDown(store.close);
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get());
    expect(res.statusCode, 401);
  });

  test(
      'trial-started participant with one questionnaire_assigned -> 200 with '
      'one task (sent) and is_not_participating == false', () async {
    final store = await _openStore('tasks-one-assigned');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-1',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['is_not_participating'], isFalse);
    expect(body['trial_started'], isTrue);
    expect(body['trial_started_at'], '2026-01-01T00:00:00.000Z');
    expect(body['is_disconnected'], isFalse);

    final tasks = (body['tasks'] as List).cast<Map<String, Object?>>();
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task['questionnaire_instance_id'], 'QI-1');
    expect(task['questionnaire_type'], 'nose_hht');
    expect(task['status'], 'sent');
    expect(task['study_event'], 'Cycle 1 Day 1');
  });

  test(
      'participant_marked_not_participating with an assigned questionnaire -> '
      '200 with empty tasks and is_not_participating == true', () async {
    final store = await _openStore('tasks-not-participating');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-2',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    // Mark participant as not participating — diary should forget JWT.
    await store.append(
      entryType: 'participant_marked_not_participating',
      aggregateType: 'participant',
      aggregateId: 'P-1',
      eventType: 'participant_marked_not_participating',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'mobile_linking_status': 'not_participating',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['is_not_participating'], isTrue);
    expect(body['tasks'], isEmpty);
  });

  test(
      'questionnaire_finalized instance is NOT returned in active tasks '
      '(finalized drops from /user/tasks list)', () async {
    // Verifies: DIARY-BASE-questionnaire-coordinator-workflow/M — once a
    //   questionnaire is finalized it is no longer an active task for the
    //   participant; the handler skips rows whose entryType is
    //   'questionnaire_finalized'.
    final store = await _openStore('tasks-finalized-drops');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    // Assign the questionnaire.
    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-DONE',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    // Finalize the questionnaire — this folds into the row (entryType becomes
    // 'questionnaire_finalized') but the instance is NOT tombstoned.
    await store.append(
      entryType: 'questionnaire_finalized',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-DONE',
      eventType: 'questionnaire_finalized',
      data: const <String, Object?>{
        'participant_id': 'P-1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    // The finalized instance must NOT appear in the active task list.
    expect(body['tasks'], isEmpty);
  });

  test(
      'questionnaire_submission_received instance is NOT returned in active '
      'tasks (submitted -> Ready to Review, drops from /user/tasks)', () async {
    // Verifies: DIARY-BASE-questionnaire-coordinator-workflow/G — once the
    //   participant has submitted (entryType 'questionnaire_submission_received',
    //   status Ready to Review for the coordinator) it is no longer an active
    //   task for the participant; the handler skips it.
    final store = await _openStore('tasks-submitted-drops');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-SUB',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    // Participant submitted: the reactor's dedicated event folds into the row.
    await store.append(
      entryType: 'questionnaire_submission_received',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-SUB',
      eventType: 'questionnaire_submission_received',
      data: const <String, Object?>{
        'completed_at': '2026-02-02T00:00:00.000Z',
        'questionnaire_type': 'nose_hht',
      },
      initiator: const AutomationInitiator(service: 'questionnaire-submission'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    // The submitted instance must NOT appear in the active task list.
    expect(body['tasks'], isEmpty);
  });

  test('disconnected participant still receives tasks; is_disconnected == true',
      () async {
    final store = await _openStore('tasks-disconnected');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-3',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    // Disconnect the participant: the diary pauses sync but keeps its JWT, so
    // the task list is still served (asymmetry with not-participating).
    await store.append(
      entryType: 'participant_disconnected',
      aggregateType: 'participant',
      aggregateId: 'P-1',
      eventType: 'participant_disconnected',
      data: const <String, Object?>{'participant_id': 'P-1'},
      initiator: const AutomationInitiator(service: 'test'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['is_disconnected'], isTrue);
    expect(body['is_not_participating'], isFalse);
    expect((body['tasks'] as List), hasLength(1));
  });
}
