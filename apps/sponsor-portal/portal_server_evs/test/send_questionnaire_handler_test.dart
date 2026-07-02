// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/C
// Verifies: DIARY-BASE-questionnaire-cycle-tracking/D+K
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

/// Start [participantId]'s trial so it becomes trial-ACTIVE (sendable). Appends
/// `participant_trial_started` (carrying `started_at`) the same way the portal's
/// Start Trial action does; the participant_record fold then reports the
/// participant as trial-active. Required before a questionnaire may be sent —
/// the seed participants arrive from the EDC inactive (synced-from-EDC), and the
/// send endpoint now rejects sends to a non-active participant.
Future<void> _startTrial(EventStore eventStore, String participantId) async {
  await eventStore.append(
    entryType: 'participant_trial_started',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_trial_started',
    data: const <String, Object?>{'started_at': '2026-01-01T00:00:00.000Z'},
    initiator: const AutomationInitiator(service: 'test-seed'),
  );
}

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
    await _startTrial(boot.eventStore, 'P-001');

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
    await _startTrial(boot.eventStore, 'P-002');

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
    await _startTrial(boot.eventStore, 'P-003');

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

    // Lock the first instance directly (append questionnaire_locked under
    // its aggregate id). The AggregateProjectionSpec key-wise merge overwrites
    // entryType to questionnaire_locked while preserving study_event from the
    // assign event, so computeNextCycle sees one locked Cycle 1 row.
    await boot.eventStore.append(
      entryType: 'questionnaire_locked',
      aggregateType: 'questionnaire_instance',
      aggregateId: firstInstanceId,
      eventType: 'questionnaire_locked',
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

  test(
      'a whitespace-only studyEvent is normalized to null -> auto cycle, not an '
      'empty study_event written to the instance', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('send-whitespace.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);
    await _startTrial(boot.eventStore, 'P-001');

    final resp = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-001',
        'questionnaireType': 'symptom-diary',
        'studyEvent': '   ',
      },
    );
    expect(resp.statusCode, 200);
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    // Treated as if no studyEvent were supplied -> auto-computed first cycle.
    expect(body['studyEvent'], 'Cycle 1 Day 1');

    final rows =
        await boot.eventStore.backend.findViewRows('questionnaire_instance');
    final mine = rows
        .where((r) =>
            r['participant_id'] == 'P-001' && r['type'] == 'symptom-diary')
        .toList();
    expect(mine, hasLength(1));
    expect(mine.single['study_event'], 'Cycle 1 Day 1');
  });

  // Verifies: DIARY-PRD-questionnaire-system/C+D — Diary Data Synchronization is
  // active only between Trial Start (C) and disconnect/not-participating (D); a
  // questionnaire may only be sent within that window. Pre-Trial-Start: rejected.
  test(
      'send to a participant whose trial has NOT started -> 409 and no '
      'questionnaire_assigned event', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('send-inactive.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);
    // P-001 is seeded from the EDC (synced-from-EDC) and is INACTIVE: no trial
    // started. We deliberately do NOT call _startTrial.

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

    expect(resp.statusCode, 409);
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    expect(body['error'], isA<String>());
    expect((body['error'] as String).toLowerCase(), contains('trial'));

    // No instance was minted.
    final rows =
        await boot.eventStore.backend.findViewRows('questionnaire_instance');
    final mine = rows
        .where((r) =>
            r['participant_id'] == 'P-001' && r['type'] == 'symptom-diary')
        .toList();
    expect(mine, isEmpty);
  });

  // Verifies: DIARY-PRD-questionnaire-system/D — synchronization deactivates on
  // disconnect, so a started-then-disconnected participant is outside the active
  // window and is not sendable even though started_at remains set.
  test(
      'send to a participant who started the trial but is now disconnected -> '
      '409', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('send-disconnected.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);
    await _startTrial(boot.eventStore, 'P-002');
    // Then disconnect: the latest lifecycle entryType is no longer a
    // connected/active state, so the participant is not sendable even though
    // started_at remains set.
    await boot.eventStore.append(
      entryType: 'participant_disconnected',
      aggregateType: 'participant',
      aggregateId: 'P-002',
      eventType: 'participant_disconnected',
      data: const <String, Object?>{'reason': 'test'},
      initiator: const AutomationInitiator(service: 'test-seed'),
    );

    final resp = await respondToSend(
      boot.eventStore,
      boot.dispatcher,
      coordinator,
      <String, Object?>{
        'siteId': 'site-1',
        'participantId': 'P-002',
        'questionnaireType': 'symptom-diary',
      },
    );
    expect(resp.statusCode, 409);
  });

  group('participantTrialActive (pure gate)', () {
    test('inactive (synced from EDC, no started_at) -> false', () {
      expect(
        participantTrialActive(
            entryType: 'participant_synced_from_edc', startedAt: null),
        isFalse,
      );
    });
    test('linked but awaiting start (no started_at) -> false', () {
      expect(
        participantTrialActive(
            entryType: 'participant_linking_code_used', startedAt: null),
        isFalse,
      );
    });
    test('trial started -> true', () {
      expect(
        participantTrialActive(
            entryType: 'participant_trial_started', startedAt: '2026-01-01'),
        isTrue,
      );
    });
    test('re-linked after trial start (started_at preserved) -> true', () {
      expect(
        participantTrialActive(
            entryType: 'participant_linking_code_used',
            startedAt: '2026-01-01'),
        isTrue,
      );
    });
    test('disconnected after start -> false', () {
      expect(
        participantTrialActive(
            entryType: 'participant_disconnected', startedAt: '2026-01-01'),
        isFalse,
      );
    });
    test('not participating after start -> false', () {
      expect(
        participantTrialActive(
            entryType: 'participant_marked_not_participating',
            startedAt: '2026-01-01'),
        isFalse,
      );
    });
  });
}
