// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//
// Verifies: REQ-CAL-p00081-B — tasks ordered by priority (1 = highest)
// Verifies: REQ-CAL-p00081-C — display priority is stable

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  test('exactly 5 task types (drift guard)', () {
    expect(TaskType.values, hasLength(5));
  });

  test('priorities are within documented range (1..4)', () {
    for (final t in TaskType.values) {
      expect(t.priority, inInclusiveRange(1, 4));
    }
  });

  test(
    'priority-1 group contains questionnaire AND cancelledQuestionnaire',
    () {
      final p1 = TaskType.values.where((t) => t.priority == 1).toSet();
      expect(
        p1,
        containsAll([TaskType.questionnaire, TaskType.cancelledQuestionnaire]),
      );
    },
  );

  test('strict priority order for non-tied types', () {
    expect(TaskType.incompleteRecord.priority, 2);
    expect(TaskType.yesterdayReminder.priority, 3);
    expect(TaskType.missingDays.priority, 4);
  });

  group('fromValue', () {
    for (final t in TaskType.values) {
      test('round-trips ${t.value}', () {
        expect(TaskType.fromValue(t.value), t);
      });
    }

    test('throws on unknown', () {
      expect(
        () => TaskType.fromValue('reminder'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
