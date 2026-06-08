// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/C
// Verifies: DIARY-BASE-questionnaire-cycle-tracking/D+K
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  // sc-1 is seeded by the local convenience seed as StudyCoordinator @ site-1,
  // which holds portal.questionnaire.send (the ACT-QST-001 permission). The
  // handler dispatches under this principal; the site scope is resolved from
  // user_role_scopes at dispatch time, so siteId must be site-1 for the
  // site-scoped permission to authorize.
  final coordinator = Principal.user(
    userId: 'sc-1',
    roles: const {'StudyCoordinator'},
    activeRole: 'StudyCoordinator',
  );

  test(
      'first send (no prior instances) -> 200 and one questionnaire_assigned '
      'row with study_event == "Cycle 1 Day 1"', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('send-first.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    final resp = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-001',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(resp.statusCode, 200);
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    expect(body['studyEvent'], 'Cycle 1 Day 1');
    expect(body['instanceId'], isA<String>());

    final rows =
        await boot.eventStore.backend.findViewRows('questionnaire_instance');
    final mine = rows
        .where((r) =>
            r['participant_id'] == 'P-001' && r['type'] == 'symptom-diary')
        .toList();
    expect(mine, hasLength(1));
    expect(mine.single['entryType'], 'questionnaire_assigned');
    expect(mine.single['study_event'], 'Cycle 1 Day 1');
  });

  test(
      'second send while the first is still open (not finalized) -> 409 '
      '(duplicate-open guard)', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('send-dup.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    final first = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-002',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(first.statusCode, 200);

    final second = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-002',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(second.statusCode, 409);
    final body =
        jsonDecode(await second.readAsString()) as Map<String, Object?>;
    expect(body['error'], isA<String>());
  });

  test(
      'after the first instance is finalized, the next send -> 200 with '
      'study_event == "Cycle 2 Day 1"', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('send-next.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    final first = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-003',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(first.statusCode, 200);
    final firstBody =
        jsonDecode(await first.readAsString()) as Map<String, Object?>;
    final firstInstanceId = firstBody['instanceId'] as String;

    // Finalize the first instance directly (append questionnaire_finalized under
    // its aggregate id). The AggregateProjectionSpec key-wise merge overwrites
    // entryType to questionnaire_finalized while preserving study_event from the
    // assign event, so computeNextCycle sees one finalized Cycle 1 row.
    await boot.eventStore.append(
      entryType: 'questionnaire_finalized',
      aggregateType: 'questionnaire_instance',
      aggregateId: firstInstanceId,
      eventType: 'questionnaire_finalized',
      data: const <String, Object?>{'finalized_by': 'sc-1'},
      initiator: const AutomationInitiator(service: 'test-seed'),
    );

    final next = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-003',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(next.statusCode, 200);
    final nextBody =
        jsonDecode(await next.readAsString()) as Map<String, Object?>;
    expect(nextBody['studyEvent'], 'Cycle 2 Day 1');
  });
}
