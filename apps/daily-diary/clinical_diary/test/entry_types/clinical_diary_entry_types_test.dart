import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal valid questionnaires.json payload used for the data-driven seam test.
const _fixtureJson = '''
{
  "questionnaires": [
    {
      "id": "test_q",
      "name": "Test Questionnaire",
      "version": "1.0",
      "recallPeriod": "1 week",
      "totalQuestions": 1,
      "categories": [
        {
          "id": "cat1",
          "name": "Category 1",
          "stem": null,
          "responseScale": [{"value": 0, "label": "No"}],
          "questions": [
            {"id": "q1", "number": 1, "text": "Question?", "required": true}
          ]
        }
      ]
    }
  ]
}
''';

// Two-questionnaire fixture to verify every entry in the JSON produces an entry type.
const _fixtureJsonTwo = '''
{
  "questionnaires": [
    {
      "id": "alpha_q",
      "name": "Alpha Questionnaire",
      "version": "1.0",
      "recallPeriod": "2 weeks",
      "totalQuestions": 1,
      "categories": [
        {
          "id": "cat1",
          "name": "Category",
          "stem": null,
          "responseScale": [{"value": 0, "label": "No"}],
          "questions": [
            {"id": "q1", "number": 1, "text": "Q?", "required": true}
          ]
        }
      ]
    },
    {
      "id": "beta_q",
      "name": "Beta Questionnaire",
      "version": "1.0",
      "recallPeriod": "4 weeks",
      "totalQuestions": 1,
      "categories": [
        {
          "id": "cat1",
          "name": "Category",
          "stem": null,
          "responseScale": [{"value": 0, "label": "No"}],
          "questions": [
            {"id": "q1", "number": 1, "text": "Q?", "required": true}
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  Future<List<EntryTypeDefinition>> loadWithJson(String jsonString) =>
      loadSurveyEntryTypes(jsonLoader: () async => jsonString);

  // ---------------------------------------------------------------------------
  // Survey entry types — data-driven from JSON
  // ---------------------------------------------------------------------------

  // Verifies: DIARY-DEV-shared-events-catalog/A
  group('survey entry types', () {
    test('one survey type is produced per questionnaire in the JSON', () async {
      // Two-questionnaire fixture -> exactly 2 survey types
      final types = await loadWithJson(_fixtureJsonTwo);
      expect(types.length, 2);
    });

    test('survey id is questionnaire id + _survey suffix', () async {
      final types = await loadWithJson(_fixtureJson);
      final survey = types.firstWhere((e) => e.id == 'test_q_survey');
      expect(survey.id, 'test_q_survey');
    });

    test('survey name matches questionnaire name', () async {
      final types = await loadWithJson(_fixtureJson);
      final survey = types.firstWhere((e) => e.id == 'test_q_survey');
      expect(survey.name, 'Test Questionnaire');
    });

    test('survey registeredVersion is 1', () async {
      final types = await loadWithJson(_fixtureJson);
      final survey = types.firstWhere((e) => e.id == 'test_q_survey');
      expect(survey.registeredVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Data-driven: adding a new questionnaire yields a new entry type (no Dart change)
  // ---------------------------------------------------------------------------

  // Verifies: DIARY-DEV-shared-events-catalog/A
  group('data-driven: JSON-only addition produces a new entry type', () {
    test(
      'single fixture questionnaire produces exactly 1 survey type',
      () async {
        final types = await loadWithJson(_fixtureJson);
        expect(types.length, 1);
        expect(types.first.id, 'test_q_survey');
      },
    );

    test(
      'two fixture questionnaires produce 2 survey types (no hardcoding)',
      () async {
        final types = await loadWithJson(_fixtureJsonTwo);
        final surveyIds = types.map((e) => e.id).toSet();
        expect(surveyIds, containsAll(['alpha_q_survey', 'beta_q_survey']));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // All ids are unique
  // ---------------------------------------------------------------------------

  // Verifies: DIARY-DEV-shared-events-catalog/A
  group('uniqueness', () {
    test('all survey entry-type ids are unique', () async {
      final types = await loadWithJson(_fixtureJsonTwo);
      final ids = types.map((e) => e.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Duplicate ids found: $ids',
      );
    });
  });
}
