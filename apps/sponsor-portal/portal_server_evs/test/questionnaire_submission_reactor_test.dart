// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/G — a diary
//   `<id>_survey` `finalized` event whose aggregateId == the questionnaire
//   instance id drives the instance to Ready to Review (via the dedicated
//   questionnaire_submission_received event the reactor emits), while non-survey
//   diary entries, surveys with no portal instance, and already-finalized
//   instances are ignored.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  // Reactors are async fire-and-forget; give the subscription room to process
  // the appended diary event before asserting on the projected view.
  Future<void> drain() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> appendAssignedInstance(
    EventStore store, {
    required String instanceId,
    required String participantId,
    String type = 'nose_hht',
  }) =>
      store.append(
        entryType: 'questionnaire_assigned',
        aggregateType: 'questionnaire_instance',
        aggregateId: instanceId,
        eventType: 'questionnaire_assigned',
        data: <String, Object?>{
          'participant_id': participantId,
          'type': type,
          'study_event': 'Cycle 1 Day 1',
        },
        initiator: const UserInitiator('coordinator-1'),
      );

  // The diary's `<id>_survey` entry types are registered dynamically on the
  // portal store as they arrive over /ingest (the wire envelope carries the
  // definition). In this focused unit test we append the survey finalized event
  // directly, so register the type on the store first (idempotently), mirroring
  // what ingestBatch does in production.
  Future<void> appendDiaryFinalized(
    EventStore store, {
    required String aggregateId,
    required String entryType,
    String questionnaireType = 'nose_hht',
  }) {
    if (!store.entryTypes.isRegistered(entryType)) {
      store.entryTypes.register(
        EntryTypeDefinition(
            id: entryType, registeredVersion: 1, name: entryType),
      );
    }
    return store.append(
      entryType: entryType,
      aggregateType: diaryEntryAggregateType,
      aggregateId: aggregateId,
      eventType: 'finalized',
      data: <String, Object?>{
        'instance_id': aggregateId,
        'questionnaire_type': questionnaireType,
        'completed_at': '2026-02-02T00:00:00.000Z',
        'responses': const <String, Object?>{},
      },
      initiator: const AutomationInitiator(service: 'diary'),
    );
  }

  Future<Map<String, Object?>?> instanceRow(
    EventStore store,
    String instanceId,
  ) async {
    final rows = await store.backend.findViewRows('questionnaire_instance');
    for (final r in rows) {
      if (r['aggregateId'] == instanceId) return r;
    }
    return null;
  }

  test(
    'survey finalized for a live assigned instance -> reactor emits '
    'questionnaire_submission_received; row folds to that entryType',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('qsr-a');
      final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db),
        raveClient: DevSeedRaveClient(),
      );
      addTearDown(boot.dispose);

      await appendAssignedInstance(
        boot.eventStore,
        instanceId: 'QI-A',
        participantId: 'P-A',
      );
      await drain();

      await appendDiaryFinalized(
        boot.eventStore,
        aggregateId: 'QI-A',
        entryType: 'nose_hht_survey',
      );
      await drain();

      final row = await instanceRow(boot.eventStore, 'QI-A');
      expect(row, isNotNull);
      expect(row!['entryType'], 'questionnaire_submission_received');
      expect(row['participant_id'], 'P-A');
    },
  );

  test(
    'non-survey diary finalized (epistaxis) -> no emission, no phantom row',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('qsr-b');
      final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db),
        raveClient: DevSeedRaveClient(),
      );
      addTearDown(boot.dispose);

      // No assigned instance for this aggregateId; an epistaxis finalized event
      // must not produce a questionnaire_submission_received nor any row.
      await appendDiaryFinalized(
        boot.eventStore,
        aggregateId: 'EPI-1',
        entryType: 'epistaxis',
      );
      await drain();

      final row = await instanceRow(boot.eventStore, 'EPI-1');
      expect(row, isNull);
    },
  );

  test(
    'survey finalized with no questionnaire_instance row -> no emission, '
    'no phantom row',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('qsr-c');
      final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db),
        raveClient: DevSeedRaveClient(),
      );
      addTearDown(boot.dispose);

      // A survey whose instance was never assigned by the portal (or was
      // called-back/tombstoned): the guard must NOT create a phantom row.
      await appendDiaryFinalized(
        boot.eventStore,
        aggregateId: 'QI-ORPHAN',
        entryType: 'nose_hht_survey',
      );
      await drain();

      final row = await instanceRow(boot.eventStore, 'QI-ORPHAN');
      expect(row, isNull);
    },
  );

  test(
    'idempotency / no-regression: a survey finalized does NOT revert an '
    'already-finalized (Closed) instance',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('qsr-d');
      final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db),
        raveClient: DevSeedRaveClient(),
      );
      addTearDown(boot.dispose);

      await appendAssignedInstance(
        boot.eventStore,
        instanceId: 'QI-D',
        participantId: 'P-D',
      );
      // Coordinator has already locked (Closed). CUR-1539: the reactor also
      // guards on the frozen legacy alias 'questionnaire_finalized'.
      await boot.eventStore.append(
        entryType: 'questionnaire_locked',
        aggregateType: 'questionnaire_instance',
        aggregateId: 'QI-D',
        eventType: 'questionnaire_locked',
        data: const <String, Object?>{'participant_id': 'P-D'},
        initiator: const UserInitiator('coordinator-1'),
      );
      await drain();

      // A late diary survey finalized arrives for the same instance.
      await appendDiaryFinalized(
        boot.eventStore,
        aggregateId: 'QI-D',
        entryType: 'nose_hht_survey',
      );
      await drain();

      // The instance must remain Closed — not reverted to Ready to Review.
      final row = await instanceRow(boot.eventStore, 'QI-D');
      expect(row, isNotNull);
      expect(row!['entryType'], 'questionnaire_locked');
    },
  );
}
