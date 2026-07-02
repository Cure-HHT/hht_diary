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
      'questionnaire_submission_received instance IS returned with '
      'status=ready_to_review (diary needs to see it for categorization)',
      () async {
    // Verifies: DIARY-GUI-participant-task-list/I — the diary needs
    //   ready_to_review status to categorize the task; the handler must include
    //   it, not skip it.
    final store = await _openStore('tasks-submitted-ready-to-review');
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
    final tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks, hasLength(1));
    expect(tasks.single['questionnaire_instance_id'], 'QI-SUB');
    expect(tasks.single['status'], 'ready_to_review');
  });

  test(
      'locked questionnaire_instance IS returned with status=finalized '
      '(diary mints device-observed event on seeing this status)', () async {
    // Verifies: DIARY-GUI-participant-task-list/I+J — the diary needs the
    //   finalized status to mint the device-observed questionnaire_finalized
    //   event; the handler must include it, not skip it.
    // CUR-1539: the portal event is `questionnaire_locked`, but the REST wire
    //   `status` value stays 'finalized' (mobile compatibility contract).
    final store = await _openStore('tasks-locked-surfaced');
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

    // Lock the questionnaire — this folds into the row (entryType becomes
    // 'questionnaire_locked') but the instance is NOT tombstoned.
    await store.append(
      entryType: 'questionnaire_locked',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-DONE',
      eventType: 'questionnaire_locked',
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
    final tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks, hasLength(1));
    expect(tasks.single['questionnaire_instance_id'], 'QI-DONE');
    expect(tasks.single['status'], 'finalized');
  });

  test(
      'legacy questionnaire_finalized row (pre-CUR-1539 logs) still maps to '
      'status=finalized on the wire', () async {
    // CUR-1539: `questionnaire_finalized` is the frozen legacy alias of
    // `questionnaire_locked`; rows folded from pre-rename event logs must keep
    // producing the unchanged REST wire status 'finalized'.
    final store = await _openStore('tasks-legacy-finalized-surfaced');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-LEGACY',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );
    await store.append(
      entryType: 'questionnaire_finalized',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-LEGACY',
      eventType: 'questionnaire_finalized',
      data: const <String, Object?>{'participant_id': 'P-1'},
      initiator: const UserInitiator('coordinator-1'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks, hasLength(1));
    expect(tasks.single['questionnaire_instance_id'], 'QI-LEGACY');
    expect(tasks.single['status'], 'finalized');
  });

  test(
      'unlocked questionnaire_instance IS returned with status=unlocked '
      '(diary needs to re-present the task for re-submission)', () async {
    // Verifies: DIARY-GUI-participant-task-list/J — the diary needs the
    //   unlocked status to re-present the task for re-submission.
    final store = await _openStore('tasks-unlocked-surfaced');
    addTearDown(store.close);
    await _seedTrialStarted(store);

    // Assign → finalize → unlock lifecycle.
    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-UNL',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );
    await store.append(
      entryType: 'questionnaire_submission_received',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-UNL',
      eventType: 'questionnaire_submission_received',
      data: const <String, Object?>{
        'completed_at': '2026-02-02T00:00:00.000Z',
        'questionnaire_type': 'nose_hht',
      },
      initiator: const AutomationInitiator(service: 'questionnaire-submission'),
    );
    await store.append(
      entryType: 'questionnaire_locked',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-UNL',
      eventType: 'questionnaire_locked',
      data: const <String, Object?>{'participant_id': 'P-1'},
      initiator: const UserInitiator('coordinator-1'),
    );
    await store.append(
      entryType: 'questionnaire_unlocked',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-UNL',
      eventType: 'questionnaire_unlocked',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'reason': 'data entry error',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final handler = patientTasksHandler(eventStore: store);

    final res = await handler(_get(auth: 'Bearer $token'));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks, hasLength(1));
    expect(tasks.single['questionnaire_instance_id'], 'QI-UNL');
    expect(tasks.single['status'], 'unlocked');
  });

  // Verifies: DIARY-DEV-outgoing-intent-correlation/B (polling backstop surfaces the recall)
  test('recall notice surfaces as a task with status recalled', () async {
    final store = await _openStore('tasks-recall.db');
    await _seedTrialStarted(store, participantId: 'P-1');
    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    await store.append(
      entryType: 'questionnaire_recall_notice',
      aggregateType: 'questionnaire_recall_notice',
      aggregateId: 'P-1:recall:QI-9',
      eventType: 'questionnaire_recall_notice',
      data: <String, Object?>{
        'participant_id': 'P-1',
        'instance_id': 'QI-9',
        'study_event': 'Cycle 4 Day 1',
        'recalled_at': '2026-06-20T00:00:00Z',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );
    final handler = patientTasksHandler(eventStore: store);
    final res = await handler(_get(auth: 'Bearer $token'));
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final tasks = (body['tasks'] as List).cast<Map<String, Object?>>();
    final recalled = tasks.where((t) => t['status'] == 'recalled').toList();
    expect(recalled.single['questionnaire_instance_id'], 'QI-9');
    await store.close();
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
