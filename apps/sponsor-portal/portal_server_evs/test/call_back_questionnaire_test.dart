// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/D+E
// Verifies: DIARY-BASE-questionnaire-manage-modal/F+G
//
// End-to-end at the dispatcher/projection level: a Call Back (ACT-QST-002)
// dispatched over the same generic path that POST /actions uses tombstones the
// questionnaire_instance row, so the instance disappears from the
// questionnaire_instance view AND from the participant's /user/tasks list.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_server_evs/src/patient_tasks_handler.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // sc-1 is seeded by the local convenience seed as StudyCoordinator @ site-1.
  // The seeded StudyCoordinator role holds both portal.questionnaire.send
  // (ACT-QST-001) and portal.questionnaire.call_back (ACT-QST-002), scoped to
  // site-1, so both dispatches authorize when siteId == 'site-1'.
  final coordinator = Principal.user(
    userId: 'sc-1',
    roles: const {'StudyCoordinator'},
    activeRole: 'StudyCoordinator',
  );

  // The recall tombstone is applied by an async reactor (RecallReactor), so the
  // dispatcher returns before the projected view/tasks settle. Poll until the
  // condition holds instead of reading once immediately (fixes a CI flake).
  Future<void> eventually(
    Future<bool> Function() condition, {
    required String reason,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for: $reason');
  }

  test(
      'Call Back (ACT-QST-002) over the generic dispatcher tombstones the '
      'instance: gone from questionnaire_instance view and from /user/tasks',
      () async {
    final db = await newDatabaseFactoryMemory().openDatabase('call-back.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    const participantId = 'P-CB1';

    // Seed a participant record (trial-started) so /user/tasks has a record to
    // read; the participant is actively enrolled.
    await boot.eventStore.append(
      entryType: 'participant_synced_from_edc',
      aggregateType: 'participant',
      aggregateId: participantId,
      eventType: 'participant_synced_from_edc',
      data: const <String, Object?>{
        'participant_id': participantId,
        'site_id': 'site-1',
      },
      initiator: const AutomationInitiator(service: 'test-seed'),
    );
    await boot.eventStore.append(
      entryType: 'participant_trial_started',
      aggregateType: 'participant',
      aggregateId: participantId,
      eventType: 'participant_trial_started',
      data: const <String, Object?>{
        'participant_id': participantId,
        'started_at': '2026-01-01T00:00:00.000Z',
      },
      initiator: const AutomationInitiator(service: 'test-seed'),
    );

    // 1) Send a questionnaire to create an assigned instance.
    final sendResp = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': participantId,
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(sendResp.statusCode, 200);
    final sendBody =
        jsonDecode(await sendResp.readAsString()) as Map<String, Object?>;
    final instanceId = sendBody['instanceId'] as String;

    // 2) The questionnaire_instance view has exactly one assigned row for this
    //    participant + type.
    final beforeRows =
        await boot.eventStore.backend.findViewRows('questionnaire_instance');
    final beforeMine = beforeRows
        .where((r) =>
            r['participant_id'] == participantId &&
            r['type'] == 'symptom-diary')
        .toList();
    expect(beforeMine, hasLength(1));
    expect(beforeMine.single['entryType'], 'questionnaire_assigned');
    expect(beforeMine.single['aggregateId'], instanceId);

    // The participant's /user/tasks lists the assigned questionnaire.
    final tasksHandler = patientTasksHandler(eventStore: boot.eventStore);
    final token = createPatientJwt(authCode: 'ac', userId: participantId);
    Future<List<Map<String, Object?>>> readTasks() async {
      final res = await tasksHandler(Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/tasks'),
        headers: {'authorization': 'Bearer $token'},
      ));
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      return (body['tasks'] as List).cast<Map<String, Object?>>();
    }

    final tasksBefore = await readTasks();
    expect(tasksBefore, hasLength(1));
    expect(tasksBefore.single['questionnaire_instance_id'], instanceId);

    // 3) Dispatch ACT-QST-002 (Call Back) via the SAME generic dispatcher path
    //    that POST /actions uses — mirrors the send_questionnaire_handler
    //    ActionSubmission / ActionContext shape exactly.
    final callBack = await boot.dispatcher.dispatch(
      ActionSubmission(
        actionName: 'ACT-QST-002',
        rawInput: <String, Object?>{
          'siteId': 'site-1',
          'instanceId': instanceId,
          'reason': 'recalled in error',
        },
        idempotencyKey: 'callback:$instanceId',
      ),
      ActionContext(
        principal: coordinator,
        security: const SecurityDetails(),
        requestStartedAt: DateTime.now().toUtc(),
      ),
    );
    expect(callBack, isA<DispatchSuccess>());

    // 4) The questionnaire_instance row is tombstoned — gone from the view
    //    (applied by the async RecallReactor, so poll until it settles).
    await eventually(
      () async {
        final rows = await boot.eventStore.backend
            .findViewRows('questionnaire_instance');
        return rows.where((r) => r['aggregateId'] == instanceId).isEmpty;
      },
      reason: 'questionnaire_instance row to be tombstoned after Call Back',
    );

    // 5) The participant's /user/tasks no longer returns the questionnaire.
    await eventually(
      () async => (await readTasks()).isEmpty,
      reason: '/user/tasks to drop the recalled questionnaire',
    );
  });
}
