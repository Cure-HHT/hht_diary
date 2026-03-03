// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-CAL-p00047: Hard-Coded Questionnaires

import 'dart:io';

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  late List<QuestionnaireDefinition> definitions;

  setUpAll(() {
    final jsonString = File(
      'assets/data/questionnaires.json',
    ).readAsStringSync();
    definitions = QuestionnaireDefinition.loadAll(jsonString);
  });

  group('QuestionnaireDefinition.loadAll', () {
    test('loads two questionnaire definitions', () {
      expect(definitions, hasLength(2));
    });

    test('definitions have correct ids', () {
      expect(definitions[0].id, 'nose_hht');
      expect(definitions[1].id, 'hht_qol');
    });
  });

  group('NOSE HHT definition', () {
    late QuestionnaireDefinition noseHht;

    setUp(() {
      noseHht = definitions.firstWhere((d) => d.id == 'nose_hht');
    });

    test('has correct metadata', () {
      expect(noseHht.name, 'NOSE HHT');
      expect(noseHht.version, '1.0');
      expect(noseHht.recallPeriod, '2 weeks');
      expect(noseHht.totalQuestions, 29);
    });

    test('has 3 preamble items', () {
      expect(noseHht.preamble, hasLength(3));
      expect(noseHht.preamble[0].id, 'nose_preamble_1');
      expect(noseHht.preamble[0].content, contains('Nasal Outcome Score'));
    });

    test('has 3 categories', () {
      expect(noseHht.categories, hasLength(3));
      expect(noseHht.categories[0].id, 'physical');
      expect(noseHht.categories[1].id, 'functional');
      expect(noseHht.categories[2].id, 'emotional');
    });

    test('categories have correct question counts', () {
      expect(noseHht.categories[0].questions, hasLength(6));
      expect(noseHht.categories[1].questions, hasLength(14));
      expect(noseHht.categories[2].questions, hasLength(9));
    });

    test('allQuestions returns 29 questions', () {
      expect(noseHht.allQuestions, hasLength(29));
    });

    test('questions have sequential numbers 1-29', () {
      final numbers = noseHht.allQuestions.map((q) => q.number).toList();
      expect(numbers, List.generate(29, (i) => i + 1));
    });

    test('physical category has correct response scale', () {
      final physical = noseHht.categories[0];
      expect(physical.responseScale, hasLength(5));
      expect(physical.responseScale[0].value, 0);
      expect(physical.responseScale[0].label, 'No problem');
      expect(physical.responseScale[4].value, 4);
      expect(physical.responseScale[4].label, 'As bad as possible');
    });

    test('physical category has stem text', () {
      expect(noseHht.categories[0].stem, contains('Please rate how severe'));
    });

    test('questions have no segments (plain text)', () {
      for (final q in noseHht.allQuestions) {
        expect(q.hasSegments, isFalse);
      }
    });

    test('session config is present', () {
      expect(noseHht.sessionConfig, isNotNull);
      expect(noseHht.sessionConfig!.readinessCheck, isTrue);
      expect(noseHht.sessionConfig!.estimatedMinutes, '10-12');
      expect(noseHht.sessionConfig!.sessionTimeoutMinutes, 30);
    });

    test('categoryForQuestion finds correct category', () {
      final cat = noseHht.categoryForQuestion('nose_physical_1');
      expect(cat, isNotNull);
      expect(cat!.id, 'physical');

      final cat2 = noseHht.categoryForQuestion('nose_emotional_5');
      expect(cat2, isNotNull);
      expect(cat2!.id, 'emotional');
    });

    test('categoryForQuestion returns null for unknown id', () {
      expect(noseHht.categoryForQuestion('unknown_q'), isNull);
    });
  });

  group('QoL definition', () {
    late QuestionnaireDefinition qol;

    setUp(() {
      qol = definitions.firstWhere((d) => d.id == 'hht_qol');
    });

    test('has correct metadata', () {
      expect(qol.name, 'Quality of Life Survey');
      expect(qol.version, '1.0');
      expect(qol.recallPeriod, '4 weeks');
      expect(qol.totalQuestions, 4);
    });

    test('has 4 preamble items', () {
      expect(qol.preamble, hasLength(4));
    });

    test('has 1 category', () {
      expect(qol.categories, hasLength(1));
      expect(qol.categories[0].name, 'HHT Quality of Life');
    });

    test('category stem is null', () {
      expect(qol.categories[0].stem, isNull);
    });

    test('has frequency response scale', () {
      final scale = qol.categories[0].responseScale;
      expect(scale, hasLength(5));
      expect(scale[0].label, 'Never');
      expect(scale[4].label, 'Always');
    });

    test('questions have segments for rich text', () {
      for (final q in qol.allQuestions) {
        expect(q.hasSegments, isTrue);
      }
    });

    test('QoL Q4 has bold_italic_underline emphasis', () {
      final q4 = qol.allQuestions.last;
      expect(q4.id, 'qol_q4');
      final underlineSegment = q4.segments!.firstWhere(
        (s) => s.emphasis == TextEmphasis.boldItalicUnderline,
      );
      expect(underlineSegment.text, 'other than nosebleeds');
    });

    test('QoL Q1 has bold_italic emphasis segment', () {
      final q1 = qol.allQuestions.first;
      final emphasisSegment = q1.segments!.firstWhere(
        (s) => s.emphasis == TextEmphasis.boldItalic,
      );
      expect(emphasisSegment.text, 'been interrupted by a nose bleed?');
    });
  });

  group('QuestionnaireDefinition.findById', () {
    test('finds by id', () {
      final found = QuestionnaireDefinition.findById(definitions, 'nose_hht');
      expect(found, isNotNull);
      expect(found!.name, 'NOSE HHT');
    });

    test('returns null for unknown id', () {
      final found = QuestionnaireDefinition.findById(definitions, 'unknown');
      expect(found, isNull);
    });
  });

  group('QuestionResponse', () {
    test('serializes to JSON', () {
      const response = QuestionResponse(
        questionId: 'nose_physical_1',
        value: 2,
        displayLabel: 'Moderate problem',
        normalizedLabel: '2',
      );
      final json = response.toJson();
      expect(json['question_id'], 'nose_physical_1');
      expect(json['value'], 2);
      expect(json['display_label'], 'Moderate problem');
    });

    test('deserializes from JSON', () {
      final response = QuestionResponse.fromJson({
        'question_id': 'qol_q1',
        'value': 3,
        'display_label': 'Often',
        'normalized_label': '3',
      });
      expect(response.questionId, 'qol_q1');
      expect(response.value, 3);
    });
  });

  group('QuestionnaireSubmission', () {
    test('serializes to JSON', () {
      final submission = QuestionnaireSubmission(
        instanceId: 'test-uuid',
        questionnaireType: 'nose_hht',
        version: '1.0',
        responses: const [
          QuestionResponse(
            questionId: 'nose_physical_1',
            value: 2,
            displayLabel: 'Moderate problem',
            normalizedLabel: '2',
          ),
        ],
        completedAt: DateTime.utc(2026, 2, 24, 12, 0),
      );
      final json = submission.toJson();
      expect(json['instance_id'], 'test-uuid');
      expect(json['questionnaire_type'], 'nose_hht');
      expect(json['version'], '1.0');
      expect(json['responses'], hasLength(1));
      expect(json['completed_at'], '2026-02-24T12:00:00.000Z');
    });
  });

  group('TextSegment', () {
    test('parses no emphasis', () {
      final segment = TextSegment.fromJson({'text': 'hello'});
      expect(segment.text, 'hello');
      expect(segment.emphasis, TextEmphasis.none);
      expect(segment.hasEmphasis, isFalse);
    });

    test('parses bold_italic', () {
      final segment = TextSegment.fromJson({
        'text': 'important',
        'emphasis': 'bold_italic',
      });
      expect(segment.emphasis, TextEmphasis.boldItalic);
      expect(segment.hasEmphasis, isTrue);
    });

    test('parses bold_italic_underline', () {
      final segment = TextSegment.fromJson({
        'text': 'critical',
        'emphasis': 'bold_italic_underline',
      });
      expect(segment.emphasis, TextEmphasis.boldItalicUnderline);
    });
  });

  group('SessionConfig', () {
    test('parses from JSON', () {
      final config = SessionConfig.fromJson({
        'readinessCheck': true,
        'readinessMessage': 'Get ready',
        'estimatedMinutes': '5-10',
        'sessionTimeoutMinutes': 30,
        'timeoutWarningMinutes': 5,
      });
      expect(config.readinessCheck, isTrue);
      expect(config.readinessMessage, 'Get ready');
      expect(config.estimatedMinutes, '5-10');
      expect(config.sessionTimeoutMinutes, 30);
      expect(config.timeoutWarningMinutes, 5);
    });

    test('uses defaults for missing fields', () {
      final config = SessionConfig.fromJson(<String, dynamic>{});
      expect(config.readinessCheck, isTrue);
      expect(config.sessionTimeoutMinutes, 30);
    });
  });
}
