// IMPLEMENTS REQUIREMENTS:
//   REQ-p01071: QoL Questionnaire UI

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('renders plain text segment', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        const RichTextQuestion(segments: [TextSegment(text: 'Hello world')]),
      ),
    );

    expect(find.byType(RichText), findsOneWidget);
    // The text should be present (rendered via RichText)
    final richText = tester.widget<RichText>(find.byType(RichText));
    final textSpan = richText.text as TextSpan;
    expect(textSpan.children, hasLength(1));
    expect((textSpan.children![0] as TextSpan).text, 'Hello world');
  });

  testWidgets('renders bold_italic segment', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        const RichTextQuestion(
          segments: [
            TextSegment(text: 'normal '),
            TextSegment(text: 'emphasized', emphasis: TextEmphasis.boldItalic),
          ],
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final textSpan = richText.text as TextSpan;
    expect(textSpan.children, hasLength(2));

    final emphasisSpan = textSpan.children![1] as TextSpan;
    expect(emphasisSpan.style?.fontWeight, FontWeight.bold);
    expect(emphasisSpan.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('renders bold_italic_underline segment', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        const RichTextQuestion(
          segments: [
            TextSegment(
              text: 'underlined',
              emphasis: TextEmphasis.boldItalicUnderline,
            ),
          ],
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final textSpan = richText.text as TextSpan;
    final span = textSpan.children![0] as TextSpan;
    expect(span.style?.fontWeight, FontWeight.bold);
    expect(span.style?.fontStyle, FontStyle.italic);
    expect(span.style?.decoration, TextDecoration.underline);
  });
}
