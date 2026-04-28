// Verifies: REQ-d00115, REQ-d00116, REQ-d00128

import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
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
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<EntryTypeDefinition>> loadWithJson(String jsonString) =>
      loadClinicalDiaryEntryTypes(jsonLoader: () async => jsonString);

  // ---------------------------------------------------------------------------
  // Static nosebleed types
  // ---------------------------------------------------------------------------

  group('static nosebleed entry types', () {
    late List<EntryTypeDefinition> types;

    setUp(() async {
      types = await loadWithJson(_fixtureJson);
    });

    test('epistaxis_event is present with correct shape', () {
      final t = types.firstWhere((e) => e.id == 'epistaxis_event');
      expect(t.widgetId, 'epistaxis_form_v1');
      expect(t.widgetConfig, <String, Object?>{});
      expect(t.effectiveDatePath, 'startTime');
      expect(t.registeredVersion, 1);
      expect(t.name, 'Nosebleed');
    });

    test('no_epistaxis_event is present with correct shape', () {
      final t = types.firstWhere((e) => e.id == 'no_epistaxis_event');
      expect(t.widgetId, 'epistaxis_form_v1');
      expect(t.widgetConfig, <String, Object?>{'variant': 'no_epistaxis'});
      expect(t.effectiveDatePath, 'date');
      expect(t.registeredVersion, 1);
      expect(t.name, 'No Nosebleeds');
    });

    test('unknown_day_event is present with correct shape', () {
      final t = types.firstWhere((e) => e.id == 'unknown_day_event');
      expect(t.widgetId, 'epistaxis_form_v1');
      expect(t.widgetConfig, <String, Object?>{'variant': 'unknown_day'});
      expect(t.effectiveDatePath, 'date');
      expect(t.registeredVersion, 1);
      expect(t.name, 'Unknown Day');
    });
  });

  // ---------------------------------------------------------------------------
  // Survey entry types — data-driven from JSON
  // ---------------------------------------------------------------------------

  group('survey entry types', () {
    test('one survey type is produced per questionnaire in the JSON', () async {
      // Two-questionnaire fixture -> exactly 2 survey types
      final types = await loadWithJson(_fixtureJsonTwo);
      final surveys = types
          .where((e) => e.widgetId == 'survey_renderer_v1')
          .toList();
      expect(surveys.length, 2);
    });

    test('survey id is questionnaire id + _survey suffix', () async {
      final types = await loadWithJson(_fixtureJson);
      final survey = types.firstWhere((e) => e.id == 'test_q_survey');
      expect(survey.widgetId, 'survey_renderer_v1');
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

    test(
      'survey effectiveDatePath is null (falls back to client_timestamp)',
      () async {
        final types = await loadWithJson(_fixtureJson);
        final survey = types.firstWhere((e) => e.id == 'test_q_survey');
        expect(survey.effectiveDatePath, isNull);
      },
    );

    test(
      'widgetConfig carries the full questionnaire structure (has categories key)',
      () async {
        final types = await loadWithJson(_fixtureJson);
        final survey = types.firstWhere((e) => e.id == 'test_q_survey');
        expect(
          survey.widgetConfig,
          containsPair('categories', isA<List<dynamic>>()),
        );
      },
    );

    test('widgetConfig carries questionnaire id', () async {
      final types = await loadWithJson(_fixtureJson);
      final survey = types.firstWhere((e) => e.id == 'test_q_survey');
      expect(survey.widgetConfig['id'], 'test_q');
    });
  });

  // ---------------------------------------------------------------------------
  // Data-driven: adding a new questionnaire yields a new entry type (no Dart change)
  // ---------------------------------------------------------------------------

  group('data-driven: JSON-only addition produces a new entry type', () {
    test(
      'single fixture questionnaire produces exactly 1 survey type',
      () async {
        final types = await loadWithJson(_fixtureJson);
        final surveys = types
            .where((e) => e.widgetId == 'survey_renderer_v1')
            .toList();
        expect(surveys.length, 1);
        expect(surveys.first.id, 'test_q_survey');
      },
    );

    test(
      'two fixture questionnaires produce 2 survey types (no hardcoding)',
      () async {
        final types = await loadWithJson(_fixtureJsonTwo);
        final surveyIds = types
            .where((e) => e.widgetId == 'survey_renderer_v1')
            .map((e) => e.id)
            .toSet();
        expect(surveyIds, containsAll(['alpha_q_survey', 'beta_q_survey']));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // All ids are unique
  // ---------------------------------------------------------------------------

  group('uniqueness', () {
    test(
      'all entry-type ids are unique across nosebleed + survey sets',
      () async {
        final types = await loadWithJson(_fixtureJsonTwo);
        final ids = types.map((e) => e.id).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'Duplicate ids found: $ids',
        );
      },
    );
  });
}
