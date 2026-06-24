// Verifies: DIARY-DEV-inbound-event-on-receipt/C — acknowledgeRecall emits
//   the ack event (outbound), the local recall-view tombstone, and (when a
//   local survey exists) the portal-withdrawn survey tombstone. When the
//   survey tombstone dispatch is denied, acknowledgeRecall still completes
//   (ack + clear intact) and emits a durable diagnostic event.
// Verifies: DIARY-DEV-outgoing-intent-correlation/D — the outbound ack carries
//   instance_id + participant_id so the portal can correlate back to the
//   recall-notice aggregate.
import 'package:clinical_diary/actions/acknowledge_recall_action.dart';
import 'package:clinical_diary/read/questionnaire_recall_projection.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/services/recall_acknowledger.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart'
    show ActionSubmitter, LocalScope, LocalViewSource;
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Test helper: an ActionSubmitter that delegates to a real submitter for
// every action EXCEPT 'delete_entry', which it returns as denied.
// ---------------------------------------------------------------------------
class _DeleteEntryDenyingSubmitter implements ActionSubmitter {
  _DeleteEntryDenyingSubmitter(this._real);
  final ActionSubmitter _real;

  @override
  Future<DispatchResult<Object?>> submit(ActionSubmission submission) {
    if (submission.actionName == 'delete_entry') {
      return Future.value(
        const DispatchResult<Object?>.authorizationDenied(
          Permission('diary.delete_entry'),
        ),
      );
    }
    return _real.submit(submission);
  }
}

/// Boot a fresh in-memory diary scope for the test.
Future<DiaryScopeRuntime> _boot({
  List<EntryTypeDefinition> extraEntryTypes = const [],
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'recall-ack-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-ack',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
    extraEntryTypes: extraEntryTypes,
  );
}

/// A minimal `<id>_survey` entry type def, mirroring what main.dart registers.
EntryTypeDefinition _surveyType(String questionnaireId) => EntryTypeDefinition(
  id: '${questionnaireId}_survey',
  registeredVersion: 1,
  name: questionnaireId,
);

/// Raw input for a minimal `submit_questionnaire` dispatch.
Map<String, Object?> _submitRaw({
  String instanceId = 'QI1',
  String type = 'qol',
}) => <String, Object?>{
  'instance_id': instanceId,
  'questionnaire_type': type,
  'schema_version': '1.0.0',
  'content_version': '1.0.0',
  'gui_version': '1.0.0',
  'completed_at': '2026-06-20T08:30:00.000Z',
  'responses': <String, Object?>{
    'q1': <String, Object?>{
      'value': 1,
      'display_label': 'Yes',
      'normalized_label': '1',
    },
  },
};

void main() {
  // --------------------------------------------------------------------------
  // Case 1: local survey EXISTS — ack + recall-clear + survey tombstone.
  // --------------------------------------------------------------------------
  test(
    'acknowledgeRecall emits ack(finalized), recall tombstone, and '
    'survey portal-withdrawn tombstone when local survey is present',
    () async {
      final rt = await _boot(extraEntryTypes: [_surveyType('qol')]);

      // Seed a device-local recall row for QI1.
      await rt.scope.actionSubmitter.submit(
        const ActionSubmission(
          actionName: 'record_questionnaire_recalled',
          rawInput: {'instance_id': 'QI1', 'study_event': 'Cycle 4 Day 1'},
        ),
      );

      // Seed a submitted local survey for QI1.
      await rt.scope.actionSubmitter.submit(
        ActionSubmission(
          actionName: 'submit_questionnaire',
          rawInput: _submitRaw(),
        ),
      );

      // Act.
      await acknowledgeRecall(rt, 'QI1');

      // Inspect all events in the store.
      final all = await rt.bundle.eventStore.backend
          .readEventsReverse()
          .toList();

      // 1. Outbound ack event is present with eventType `finalized`.
      expect(
        all.any(
          (e) =>
              e.entryType == 'questionnaire_recall_acked' &&
              e.eventType == 'finalized' &&
              e.aggregateType == questionnaireRecallNoticeAggregateType &&
              (e.data['instance_id'] as String?) == 'QI1' &&
              (e.data['participant_id'] as String?) == 'P-test',
        ),
        isTrue,
        reason: 'expected questionnaire_recall_acked / finalized event',
      );

      // 2. Local recall tombstone.
      expect(
        all.any(
          (e) =>
              e.aggregateType == questionnaireRecallLocalAggregateType &&
              e.aggregateId == 'QI1' &&
              e.eventType == 'tombstone',
        ),
        isTrue,
        reason: 'expected questionnaire_recall_local tombstone',
      );

      // 3. DiaryEntry tombstone with changeReason portal-withdrawn.
      expect(
        all.any(
          (e) =>
              e.aggregateType == diaryEntryAggregateType &&
              e.aggregateId == 'QI1' &&
              e.eventType == 'tombstone' &&
              e.data['changeReason'] == DiaryChangeReason.portalWithdrawn.wire,
        ),
        isTrue,
        reason:
            'expected DiaryEntry tombstone with changeReason portal-withdrawn',
      );

      await rt.dispose();
    },
  );

  // --------------------------------------------------------------------------
  // Case 2: NO local survey — ack + recall-clear only, no crash.
  // --------------------------------------------------------------------------
  test('acknowledgeRecall emits ack(finalized) and recall tombstone even when '
      'no local survey exists', () async {
    final rt = await _boot();

    // Seed only the device-local recall row (no survey submitted).
    await rt.scope.actionSubmitter.submit(
      const ActionSubmission(
        actionName: 'record_questionnaire_recalled',
        rawInput: {'instance_id': 'QI2', 'study_event': 'Screening'},
      ),
    );

    // Act — must NOT crash even though there is no local survey.
    await acknowledgeRecall(rt, 'QI2');

    final all = await rt.bundle.eventStore.backend.readEventsReverse().toList();

    // 1. Ack event present.
    expect(
      all.any(
        (e) =>
            e.entryType == 'questionnaire_recall_acked' &&
            e.eventType == 'finalized',
      ),
      isTrue,
      reason: 'expected questionnaire_recall_acked / finalized event',
    );

    // 2. Recall tombstone present.
    expect(
      all.any(
        (e) =>
            e.aggregateType == questionnaireRecallLocalAggregateType &&
            e.aggregateId == 'QI2' &&
            e.eventType == 'tombstone',
      ),
      isTrue,
      reason: 'expected questionnaire_recall_local tombstone',
    );

    // 3. NO DiaryEntry tombstone (no survey to remove).
    expect(
      all.any(
        (e) =>
            e.aggregateType == diaryEntryAggregateType &&
            e.eventType == 'tombstone',
      ),
      isFalse,
      reason: 'expected no DiaryEntry tombstone when no local survey exists',
    );

    await rt.dispose();
  });

  // --------------------------------------------------------------------------
  // Case 3: delete_entry DENIED — ack + recall-clear still emitted, and a
  // durable diagnostic event is recorded (ALCOA+ gap closed).
  // --------------------------------------------------------------------------
  test('acknowledgeRecall still completes and records a diagnostic event when '
      'delete_entry is denied', () async {
    // Boot a real scope so actions and event store are wired up.
    final rt = await _boot(extraEntryTypes: [_surveyType('qol')]);

    // Seed a device-local recall row for QI3.
    await rt.scope.actionSubmitter.submit(
      const ActionSubmission(
        actionName: 'record_questionnaire_recalled',
        rawInput: {'instance_id': 'QI3', 'study_event': 'Screening'},
      ),
    );

    // Seed a submitted local survey so delete_entry will be attempted.
    await rt.scope.actionSubmitter.submit(
      ActionSubmission(
        actionName: 'submit_questionnaire',
        rawInput: _submitRaw(instanceId: 'QI3'),
      ),
    );

    // Build a replacement scope whose submitter denies delete_entry.
    final denyingScope = LocalScope(
      authSession: rt.authSession,
      actionSubmitter: _DeleteEntryDenyingSubmitter(rt.scope.actionSubmitter),
      viewSource: LocalViewSource(eventStore: rt.bundle.eventStore),
      permissionSource: rt.permissionSource,
    );
    final interceptedRt = DiaryScopeRuntime(
      scope: denyingScope,
      bundle: rt.bundle,
      authSession: rt.authSession,
      permissionSource: rt.permissionSource,
    );

    // Act — must NOT throw even though delete_entry is denied.
    await acknowledgeRecall(interceptedRt, 'QI3');

    final all = await rt.bundle.eventStore.backend.readEventsReverse().toList();

    // 1. Ack event still emitted.
    expect(
      all.any(
        (e) =>
            e.entryType == 'questionnaire_recall_acked' &&
            e.eventType == 'finalized' &&
            (e.data['instance_id'] as String?) == 'QI3',
      ),
      isTrue,
      reason:
          'expected questionnaire_recall_acked / finalized even on denied delete',
    );

    // 2. Recall tombstone still emitted.
    expect(
      all.any(
        (e) =>
            e.aggregateType == questionnaireRecallLocalAggregateType &&
            e.aggregateId == 'QI3' &&
            e.eventType == 'tombstone',
      ),
      isTrue,
      reason:
          'expected questionnaire_recall_local tombstone even on denied delete',
    );

    // 3. No survey tombstone (delete_entry was denied).
    expect(
      all.any(
        (e) =>
            e.aggregateType == diaryEntryAggregateType &&
            e.aggregateId == 'QI3' &&
            e.eventType == 'tombstone',
      ),
      isFalse,
      reason: 'expected no DiaryEntry tombstone when delete_entry denied',
    );

    // 4. Durable diagnostic event recorded (ALCOA+ observable failure).
    expect(
      all.any(
        (e) =>
            e.entryType == 'recall_survey_tombstone_failed' &&
            e.aggregateId == 'QI3' &&
            (e.data['instance_id'] as String?) == 'QI3',
      ),
      isTrue,
      reason:
          'expected recall_survey_tombstone_failed diagnostic event when '
          'delete_entry is denied',
    );

    await rt.dispose();
  });

  // --------------------------------------------------------------------------
  // AcknowledgeRecallAction unit test.
  // --------------------------------------------------------------------------
  test('AcknowledgeRecallAction emits correct event draft', () async {
    const action = AcknowledgeRecallAction();
    expect(action.name, 'acknowledge_recall');

    final input = action.parseInput(<String, Object?>{
      'instance_id': 'QI3',
      'participant_id': 'P-x',
      'flow_token': 'tok-abc',
    });
    action.validate(input);

    final result = await action.execute(
      input,
      ActionContext(
        principal: UserPrincipal(
          userId: 'P-x',
          roles: const {'participant'},
          activeRole: 'participant',
        ),
        security: const SecurityDetails(),
        requestStartedAt: DateTime.utc(2026, 6, 20),
      ),
    );
    final draft = result.events.single;
    expect(draft.aggregateType, questionnaireRecallNoticeAggregateType);
    expect(draft.aggregateId, 'P-x:recall:QI3');
    expect(draft.entryType, 'questionnaire_recall_acked');
    expect(draft.eventType, 'finalized');
    expect(draft.data['instance_id'], 'QI3');
    expect(draft.data['participant_id'], 'P-x');
    expect(draft.data['flow_token'], 'tok-abc');
    expect(draft.data['acked_at'], isA<String>());
  });

  test('AcknowledgeRecallAction validate rejects missing instance_id', () {
    const action = AcknowledgeRecallAction();
    final input = action.parseInput(<String, Object?>{'participant_id': 'P-x'});
    expect(() => action.validate(input), throwsArgumentError);
  });

  test('AcknowledgeRecallAction validate rejects missing participant_id', () {
    const action = AcknowledgeRecallAction();
    final input = action.parseInput(<String, Object?>{'instance_id': 'QI3'});
    expect(() => action.validate(input), throwsArgumentError);
  });
}
