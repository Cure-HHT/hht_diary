// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//
// Verifies: REQ-p01067-A — categories group questions and a shared scale

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

Map<String, dynamic> _scaleOption(int v, String l) => {'value': v, 'label': l};
Map<String, dynamic> _question(String id, int n, String t) => {
  'id': id,
  'number': n,
  'text': t,
  'required': true,
};

void main() {
  group('QuestionCategory.fromJson', () {
    test('parses NOSE-style category with stem and 3 questions', () {
      final c = QuestionCategory.fromJson({
        'id': 'physical',
        'name': 'Physical',
        'stem': 'How much of a problem...',
        'responseScale': [
          _scaleOption(0, 'No problem'),
          _scaleOption(1, 'Mild'),
          _scaleOption(2, 'Moderate'),
          _scaleOption(3, 'Severe'),
          _scaleOption(4, 'As bad as possible'),
        ],
        'questions': [
          _question('q1', 1, 'Q1'),
          _question('q2', 2, 'Q2'),
          _question('q3', 3, 'Q3'),
        ],
      });

      expect(c.id, 'physical');
      expect(c.name, 'Physical');
      expect(c.stem, 'How much of a problem...');
      expect(c.responseScale, hasLength(5));
      expect(c.questions, hasLength(3));
    });

    test('parses QoL-style category without stem', () {
      final c = QuestionCategory.fromJson({
        'id': 'qol',
        'name': 'HHT Quality of Life',
        'responseScale': [_scaleOption(0, 'Never'), _scaleOption(4, 'Always')],
        'questions': [_question('qol_q1', 1, 'Q1')],
      });

      expect(c.stem, isNull);
      expect(c.questions, hasLength(1));
    });

    test('preserves question order', () {
      final c = QuestionCategory.fromJson({
        'id': 'order',
        'name': 'Order',
        'responseScale': [_scaleOption(0, 'x')],
        'questions': [
          _question('q3', 3, 'three'),
          _question('q1', 1, 'one'),
          _question('q2', 2, 'two'),
        ],
      });

      expect(c.questions.map((q) => q.id).toList(), ['q3', 'q1', 'q2']);
    });
  });
}
