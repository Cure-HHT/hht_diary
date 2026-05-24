// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//
// Verifies: REQ-p01067-B / REQ-p01068-B — response scale parses 0-4 with labels

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('ResponseScaleOption.fromJson', () {
    test('parses required fields', () {
      final o = ResponseScaleOption.fromJson({
        'value': 0,
        'label': 'No problem',
      });
      expect(o.value, 0);
      expect(o.label, 'No problem');
    });

    test('parses full 0-4 scale', () {
      final scale = [
        {'value': 0, 'label': 'No problem'},
        {'value': 1, 'label': 'Very mild problem'},
        {'value': 2, 'label': 'Moderate problem'},
        {'value': 3, 'label': 'Severe problem'},
        {'value': 4, 'label': 'As bad as possible'},
      ].map(ResponseScaleOption.fromJson).toList();

      expect(scale, hasLength(5));
      expect(scale.map((o) => o.value), [0, 1, 2, 3, 4]);
      expect(scale.map((o) => o.label).toSet(), hasLength(5));
    });

    test('throws when value missing', () {
      expect(
        () => ResponseScaleOption.fromJson({'label': 'x'}),
        throwsA(anyOf(isA<TypeError>(), isA<NoSuchMethodError>())),
      );
    });

    test('throws when label missing', () {
      expect(
        () => ResponseScaleOption.fromJson({'value': 0}),
        throwsA(anyOf(isA<TypeError>(), isA<NoSuchMethodError>())),
      );
    });
  });
}
