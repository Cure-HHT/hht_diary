// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00047: Hard-Coded Questionnaires
//   REQ-p01065: Clinical Questionnaire System

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  test('exactly 3 types (drift guard)', () {
    expect(QuestionnaireType.values, hasLength(3));
  });

  test('wire values match expected vocabulary', () {
    expect(QuestionnaireType.eq.value, 'eq');
    expect(QuestionnaireType.noseHht.value, 'nose_hht');
    expect(QuestionnaireType.qol.value, 'qol');
  });

  group('fromValue', () {
    for (final t in QuestionnaireType.values) {
      test('round-trips ${t.value}', () {
        expect(QuestionnaireType.fromValue(t.value), t);
      });
    }

    test('throws on unknown', () {
      expect(
        () => QuestionnaireType.fromValue('phq9'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty', () {
      expect(
        () => QuestionnaireType.fromValue(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('all display names non-empty and unique', () {
    final names = QuestionnaireType.values.map((t) => t.displayName).toSet();
    expect(names, hasLength(QuestionnaireType.values.length));
    for (final n in names) {
      expect(n.trim(), isNotEmpty);
    }
  });
}
