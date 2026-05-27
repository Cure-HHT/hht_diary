// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//
// Verifies: REQ-p01070-A / REQ-p01071-A — questions deserialise with optional
//           rich-text segments and a default required=true

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('QuestionDefinition.fromJson', () {
    test('parses minimal NOSE-style question', () {
      final q = QuestionDefinition.fromJson({
        'id': 'nose_physical_1',
        'number': 1,
        'text': 'How much of a problem was your blocked nose?',
        'required': true,
      });

      expect(q.id, 'nose_physical_1');
      expect(q.number, 1);
      expect(q.text, startsWith('How much of a problem'));
      expect(q.required, isTrue);
      expect(q.hasSegments, isFalse);
      expect(q.segments, isNull);
    });

    test('defaults required to true when omitted', () {
      final q = QuestionDefinition.fromJson({
        'id': 'q1',
        'number': 1,
        'text': 'plain',
      });
      expect(q.required, isTrue);
    });

    test('respects required=false', () {
      final q = QuestionDefinition.fromJson({
        'id': 'q1',
        'number': 1,
        'text': 'optional',
        'required': false,
      });
      expect(q.required, isFalse);
    });

    test('parses QoL question with rich segments', () {
      final q = QuestionDefinition.fromJson({
        'id': 'qol_q1',
        'number': 1,
        'text': 'How often have you been interrupted by nosebleeds?',
        'required': true,
        'segments': [
          {'text': 'How often have you '},
          {'text': 'been interrupted', 'emphasis': 'bold_italic'},
          {'text': ' by nosebleeds?'},
        ],
      });

      expect(q.hasSegments, isTrue);
      expect(q.segments, hasLength(3));
      expect(q.segments![1].emphasis, TextEmphasis.boldItalic);
    });

    test('treats empty segments list as no segments', () {
      final q = QuestionDefinition.fromJson({
        'id': 'q1',
        'number': 1,
        'text': 'plain',
        'segments': <dynamic>[],
      });
      expect(q.hasSegments, isFalse);
    });
  });
}
