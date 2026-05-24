// IMPLEMENTS REQUIREMENTS:
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-p01071: QoL Questionnaire UI
//
// Verifies: REQ-p01071-A — text segments parse with their emphasis style

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('TextEmphasis.fromValue', () {
    test('returns boldItalic for "bold_italic"', () {
      expect(TextEmphasis.fromValue('bold_italic'), TextEmphasis.boldItalic);
    });

    test('returns boldItalicUnderline for "bold_italic_underline"', () {
      expect(
        TextEmphasis.fromValue('bold_italic_underline'),
        TextEmphasis.boldItalicUnderline,
      );
    });

    test('returns none for null', () {
      expect(TextEmphasis.fromValue(null), TextEmphasis.none);
    });

    test('returns none for unknown values', () {
      expect(TextEmphasis.fromValue('italic'), TextEmphasis.none);
      expect(TextEmphasis.fromValue(''), TextEmphasis.none);
      expect(TextEmphasis.fromValue('garbage'), TextEmphasis.none);
    });

    test('exactly 3 enum values exist (drift guard)', () {
      expect(TextEmphasis.values, hasLength(3));
    });
  });

  group('TextSegment.fromJson', () {
    test('plain segment with no emphasis', () {
      final s = TextSegment.fromJson({'text': 'hello'});
      expect(s.text, 'hello');
      expect(s.emphasis, TextEmphasis.none);
      expect(s.hasEmphasis, isFalse);
    });

    test('segment with explicit none emphasis', () {
      final s = TextSegment.fromJson({'text': 'plain', 'emphasis': null});
      expect(s.emphasis, TextEmphasis.none);
    });

    test('segment with boldItalic', () {
      final s = TextSegment.fromJson({'text': 'em', 'emphasis': 'bold_italic'});
      expect(s.emphasis, TextEmphasis.boldItalic);
      expect(s.hasEmphasis, isTrue);
    });

    test('segment with boldItalicUnderline', () {
      final s = TextSegment.fromJson({
        'text': 'em',
        'emphasis': 'bold_italic_underline',
      });
      expect(s.emphasis, TextEmphasis.boldItalicUnderline);
      expect(s.hasEmphasis, isTrue);
    });

    test('throws when text is missing', () {
      expect(
        () => TextSegment.fromJson(<String, dynamic>{}),
        throwsA(anyOf(isA<TypeError>(), isA<NoSuchMethodError>())),
      );
    });

    test('preserves unicode and whitespace', () {
      final s = TextSegment.fromJson({
        'text': '  café  \n🚀',
        'emphasis': 'bold_italic',
      });
      expect(s.text, '  café  \n🚀');
    });
  });
}
