// IMPLEMENTS REQUIREMENTS:
//   REQ-p01071: QoL Questionnaire UI

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Renders a question with rich text segments (bold, italic, underline).
///
/// Used for QoL questions that have emphasis on key phrases
/// per REQ-p01071-A.
class RichTextQuestion extends StatelessWidget {
  const RichTextQuestion({required this.segments, this.style, super.key});

  /// Text segments with optional emphasis
  final List<TextSegment> segments;

  /// Base text style (emphasis is applied on top of this)
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge!;
    return RichText(
      text: TextSpan(
        children: segments.map((segment) {
          return TextSpan(
            text: segment.text,
            style: _styleForEmphasis(baseStyle, segment.emphasis),
          );
        }).toList(),
      ),
    );
  }

  TextStyle _styleForEmphasis(TextStyle base, TextEmphasis emphasis) {
    return switch (emphasis) {
      TextEmphasis.none => base,
      TextEmphasis.boldItalic => base.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
      TextEmphasis.boldItalicUnderline => base.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      ),
    };
  }
}
