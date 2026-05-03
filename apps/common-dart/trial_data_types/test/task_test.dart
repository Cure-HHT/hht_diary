// Verifies: REQ-CAL-p00081 (task model), REQ-CAL-p00080 (study_event round-trip)

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('Task.fromFcmData', () {
    test('parses study_event into subtitle when no explicit subtitle', () {
      final task = Task.fromFcmData({
        'questionnaire_instance_id': 'inst-123',
        'questionnaire_type': 'nose_hht',
        'study_event': 'Cycle 2 Day 1',
      });

      expect(task.studyEvent, 'Cycle 2 Day 1');
      expect(task.subtitle, 'Cycle 2 Day 1');
      expect(task.questionnaireType, QuestionnaireType.noseHht);
      expect(task.id, 'inst-123');
    });

    test('explicit subtitle takes precedence over study_event', () {
      final task = Task.fromFcmData({
        'questionnaire_instance_id': 'inst-123',
        'questionnaire_type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
        'subtitle': 'Due today',
      });

      expect(task.subtitle, 'Due today');
      expect(task.studyEvent, 'Cycle 1 Day 1');
    });

    test('study_event absent leaves field null', () {
      final task = Task.fromFcmData({
        'questionnaire_instance_id': 'inst-123',
        'questionnaire_type': 'nose_hht',
      });

      expect(task.studyEvent, isNull);
      expect(task.subtitle, isNull);
    });
  });

  group('Task JSON round-trip', () {
    test('preserves study_event through toJson/fromJson', () {
      final original = Task.fromFcmData({
        'questionnaire_instance_id': 'inst-456',
        'questionnaire_type': 'qol',
        'study_event': 'Cycle 3 Day 1',
      });

      final round = Task.fromJson(original.toJson());

      expect(round.studyEvent, 'Cycle 3 Day 1');
      expect(round.subtitle, 'Cycle 3 Day 1');
      expect(round.id, original.id);
      expect(round.questionnaireType, original.questionnaireType);
    });
  });
}
