// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S
import 'package:clinical_diary/read/questionnaire_status_projection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a view row map the same way the library produces them:
/// top-level [aggregateId] and [entryType] keys (stamped by AggregateFold)
/// plus whatever [data] the event payload contributed.
Map<String, Object?> _viewRow({
  required String aggregateId,
  required String entryType,
  Map<String, Object?> data = const {},
}) {
  return {'aggregateId': aggregateId, 'entryType': entryType, ...data};
}

void main() {
  group('QuestionnaireStatusRow.fromViewRow', () {
    test('questionnaire_finalized folds to isFinalized row', () {
      final row = QuestionnaireStatusRow.fromViewRow(
        _viewRow(
          aggregateId: 'i1',
          entryType: 'questionnaire_finalized',
          data: const {'source': 'portal-state-sync'},
        ),
      );
      expect(row.instanceId, 'i1');
      expect(row.isFinalized, isTrue);
      expect(row.isUnlocked, isFalse);
    });

    test('questionnaire_unlocked folds to isUnlocked row', () {
      final row = QuestionnaireStatusRow.fromViewRow(
        _viewRow(
          aggregateId: 'i2',
          entryType: 'questionnaire_unlocked',
          data: const {},
        ),
      );
      expect(row.instanceId, 'i2');
      expect(row.isFinalized, isFalse);
      expect(row.isUnlocked, isTrue);
    });
  });

  group('questionnaireStatusProjection spec', () {
    test('view name matches constant', () {
      expect(
        questionnaireStatusProjection.viewName,
        questionnaireStatusViewName,
      );
    });

    test('interest covers questionnaire_instance aggregate type', () {
      expect(
        questionnaireStatusProjection.interest.aggregateTypes,
        contains(questionnaireInstanceAggregateType),
      );
    });

    test(
      'interest covers questionnaire_finalized and questionnaire_unlocked',
      () {
        final eventTypes = questionnaireStatusProjection.interest.eventTypes;
        expect(eventTypes, contains('questionnaire_finalized'));
        expect(eventTypes, contains('questionnaire_unlocked'));
      },
    );
  });
}
