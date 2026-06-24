// Verifies: DIARY-DEV-inbound-event-on-receipt/B (received recall recorded as a local event/view)
import 'package:clinical_diary/actions/record_questionnaire_recalled_action.dart';
import 'package:clinical_diary/read/questionnaire_recall_projection.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'record_questionnaire_recalled inserts a row in questionnaire_recall view',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'recall-local.db',
      );
      final rt = await bootstrapDiaryScope(
        backend: SembastBackend(database: db),
        deviceId: 'DEV',
        softwareVersion: 'test',
        localUserId: 'P-test',
      );
      await rt.scope.actionSubmitter.submit(
        const ActionSubmission(
          actionName: 'record_questionnaire_recalled',
          rawInput: {'instance_id': 'QI1', 'study_event': 'Cycle 4 Day 1'},
        ),
      );
      final rows = await rt.bundle.eventStore.backend.findViewRows(
        questionnaireRecallViewName,
      );
      expect(rows.where((r) => r['aggregateId'] == 'QI1'), hasLength(1));
      await rt.dispose();
    },
  );

  test('QuestionnaireRecallRow.fromViewRow maps instanceId and studyEvent', () {
    final row = QuestionnaireRecallRow.fromViewRow(<String, Object?>{
      'aggregateId': 'QI2',
      'instance_id': 'QI2',
      'study_event': 'Cycle 1 Day 1',
    });
    expect(row.instanceId, 'QI2');
    expect(row.studyEvent, 'Cycle 1 Day 1');
  });

  test(
    'RecordQuestionnaireRecalledAction emits the correct event draft',
    () async {
      const action = RecordQuestionnaireRecalledAction();
      expect(action.name, 'record_questionnaire_recalled');
      final input = action.parseInput(<String, Object?>{
        'instance_id': 'QI3',
        'study_event': 'Screening',
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
      expect(draft.aggregateType, questionnaireRecallLocalAggregateType);
      expect(draft.aggregateId, 'QI3');
      expect(draft.entryType, 'questionnaire_recalled');
      expect(draft.eventType, 'finalized');
      expect(draft.data['instance_id'], 'QI3');
      expect(draft.data['study_event'], 'Screening');
      expect(result.result, 'QI3');
    },
  );

  test('validate rejects missing instance_id', () {
    const action = RecordQuestionnaireRecalledAction();
    final input = action.parseInput(<String, Object?>{});
    expect(() => action.validate(input), throwsArgumentError);
  });
}
