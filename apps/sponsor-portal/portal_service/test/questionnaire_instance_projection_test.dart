// Verifies: DIARY-PRD-questionnaire-system/B — the questionnaire_instance view
//   tracks Completion Status per instance; lifecycle events fold into the row.
// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/D — Call Back
//   (questionnaire_called_back) tombstones the instance row so the card resets
//   to Not Sent by absence.
// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/M — finalized instance
//   row carries latest entryType == 'questionnaire_finalized'.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('questionnaire_assigned folds into a per-instance row', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('qi-1');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    addTearDown(store.close);

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

    final rows = await store.backend.findViewRows('questionnaire_instance');
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['aggregateId'], 'QI-1');
    expect(row['entryType'], 'questionnaire_assigned');
    expect(row['participant_id'], 'P-1');
    expect(row['type'], 'nose_hht');
    expect(row['study_event'], 'Cycle 1 Day 1');
  });

  test(
    'questionnaire_called_back tombstones the instance row (Call Back = retract)',
    () async {
      // Verifies: DIARY-BASE-questionnaire-coordinator-workflow/D — the
      //   questionnaire_called_back event removes the row; absence = Not Sent.
      final db = await newDatabaseFactoryMemory().openDatabase('qi-2');
      final backend = SembastBackend(database: db);
      final store = await openPortalEventStore(backend: backend);
      addTearDown(store.close);

      await store.append(
        entryType: 'questionnaire_assigned',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-CB',
        eventType: 'questionnaire_assigned',
        data: const <String, Object?>{
          'participant_id': 'P-2',
          'type': 'nose_hht',
          'study_event': 'Cycle 1 Day 1',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      // Confirm the row exists before the tombstone.
      final before = await store.backend.findViewRows('questionnaire_instance');
      expect(before.where((r) => r['aggregateId'] == 'QI-CB'), hasLength(1));

      await store.append(
        entryType: 'questionnaire_called_back',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-CB',
        eventType: 'questionnaire_called_back',
        data: const <String, Object?>{'participant_id': 'P-2'},
        initiator: const UserInitiator('coordinator-1'),
      );

      // After Call Back the row must be gone — card resets to Not Sent by absence.
      final after = await store.backend.findViewRows('questionnaire_instance');
      expect(after.where((r) => r['aggregateId'] == 'QI-CB'), isEmpty);
    },
  );

  test(
    'questionnaire_finalized folds into the instance row with updated entryType',
    () async {
      // Verifies: DIARY-BASE-questionnaire-coordinator-workflow/M — finalized
      //   instance reflects entryType == 'questionnaire_finalized'.
      final db = await newDatabaseFactoryMemory().openDatabase('qi-3');
      final backend = SembastBackend(database: db);
      final store = await openPortalEventStore(backend: backend);
      addTearDown(store.close);

      await store.append(
        entryType: 'questionnaire_assigned',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-FIN',
        eventType: 'questionnaire_assigned',
        data: const <String, Object?>{
          'participant_id': 'P-3',
          'type': 'nose_hht',
          'study_event': 'Cycle 1 Day 1',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      await store.append(
        entryType: 'questionnaire_finalized',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-FIN',
        eventType: 'questionnaire_finalized',
        data: const <String, Object?>{
          'participant_id': 'P-3',
          'cycle': 'Cycle 1 Day 1',
          'end_event': null,
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      final rows = await store.backend.findViewRows('questionnaire_instance');
      final row = rows.singleWhere((r) => r['aggregateId'] == 'QI-FIN');
      expect(row['entryType'], 'questionnaire_finalized');
      expect(row['participant_id'], 'P-3');
      // A non-terminal cycle finalize: end_event folds in absent/null.
      expect(row['end_event'], isNull);
      // Verifies: REQ-CAL-p00023/T — the intrinsic `updatedAt` fold stamp is on
      //   the finalized row; for a finalized instance this IS the finalization
      //   time the Manage Questionnaires modal reads as `finalizedAt`.
      expect(row['updatedAt'], isA<String>());
      expect(DateTime.tryParse(row['updatedAt']! as String), isNotNull);
    },
  );

  test(
    'questionnaire_finalized with a terminal end_event folds end_event onto the row',
    () async {
      // Verifies: DIARY-BASE-questionnaire-finalization/E — a terminal close
      //   (End of Treatment / End of Study) records `end_event` on the instance
      //   row so the card renders Closed; the key-wise merge carries it forward.
      final db = await newDatabaseFactoryMemory().openDatabase('qi-term');
      final backend = SembastBackend(database: db);
      final store = await openPortalEventStore(backend: backend);
      addTearDown(store.close);

      await store.append(
        entryType: 'questionnaire_assigned',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-TERM',
        eventType: 'questionnaire_assigned',
        data: const <String, Object?>{
          'participant_id': 'P-5',
          'type': 'nose_hht',
          'study_event': 'Cycle 3 Day 1',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      await store.append(
        entryType: 'questionnaire_finalized',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-TERM',
        eventType: 'questionnaire_finalized',
        data: const <String, Object?>{
          'participant_id': 'P-5',
          'cycle': 'Cycle 3 Day 1',
          'end_event': 'end_of_treatment',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      final rows = await store.backend.findViewRows('questionnaire_instance');
      final row = rows.singleWhere((r) => r['aggregateId'] == 'QI-TERM');
      expect(row['entryType'], 'questionnaire_finalized');
      expect(row['end_event'], 'end_of_treatment');
      expect(row['cycle'], 'Cycle 3 Day 1');
      // The assigned-row fields are preserved through the key-wise merge.
      expect(row['type'], 'nose_hht');
    },
  );

  test('questionnaire_submission_received folds onto an assigned row '
      '(latest entryType drives Ready to Review)', () async {
    // Verifies: DIARY-BASE-questionnaire-coordinator-workflow/G — a participant
    //   submission (questionnaire_submission_received) folds into the existing
    //   assigned instance row; the latest entryType becomes
    //   'questionnaire_submission_received', from which the client derives
    //   Ready to Review.
    final db = await newDatabaseFactoryMemory().openDatabase('qi-sub');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    addTearDown(store.close);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-SUB',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-4',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

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

    final rows = await store.backend.findViewRows('questionnaire_instance');
    final row = rows.singleWhere((r) => r['aggregateId'] == 'QI-SUB');
    expect(row['entryType'], 'questionnaire_submission_received');
    // The assigned-row fields are preserved through the key-wise merge.
    expect(row['participant_id'], 'P-4');
    expect(row['type'], 'nose_hht');
    expect(row['study_event'], 'Cycle 1 Day 1');
  });

  test(
    'questionnaire_unlocked folds into the instance row with updated entryType',
    () async {
      // Verifies: DIARY-GUI-participant-task-list/J — after assigned →
      //   submission_received → finalized → unlocked, the instance row reflects
      //   entryType == 'questionnaire_unlocked' so the diary re-presents the
      //   task for re-submission.
      final db = await newDatabaseFactoryMemory().openDatabase('qi-unlock');
      final backend = SembastBackend(database: db);
      final store = await openPortalEventStore(backend: backend);
      addTearDown(store.close);

      await store.append(
        entryType: 'questionnaire_assigned',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-UNLOCK',
        eventType: 'questionnaire_assigned',
        data: const <String, Object?>{
          'participant_id': 'P-6',
          'type': 'nose_hht',
          'study_event': 'Cycle 1 Day 1',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      await store.append(
        entryType: 'questionnaire_submission_received',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-UNLOCK',
        eventType: 'questionnaire_submission_received',
        data: const <String, Object?>{
          'completed_at': '2026-02-02T00:00:00.000Z',
          'questionnaire_type': 'nose_hht',
        },
        initiator: const AutomationInitiator(
          service: 'questionnaire-submission',
        ),
      );

      await store.append(
        entryType: 'questionnaire_finalized',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-UNLOCK',
        eventType: 'questionnaire_finalized',
        data: const <String, Object?>{
          'participant_id': 'P-6',
          'cycle': 'Cycle 1 Day 1',
          'end_event': null,
        },
        initiator: const UserInitiator('coordinator-1'),
      );

      await store.append(
        entryType: 'questionnaire_unlocked',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-UNLOCK',
        eventType: 'questionnaire_unlocked',
        data: const <String, Object?>{'participant_id': 'P-6'},
        initiator: const UserInitiator('coordinator-1'),
      );

      final rows = await store.backend.findViewRows('questionnaire_instance');
      final row = rows.singleWhere((r) => r['aggregateId'] == 'QI-UNLOCK');
      expect(row['entryType'], 'questionnaire_unlocked');
      // The assigned-row fields are preserved through the key-wise merge.
      expect(row['participant_id'], 'P-6');
      expect(row['type'], 'nose_hht');
      expect(row['study_event'], 'Cycle 1 Day 1');
    },
  );
}
