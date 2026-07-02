/// Text emphasis styles for rich question text.
///
/// Used in QoL questionnaire questions where key phrases need visual emphasis.
// Implements: DIARY-PRD-questionnaire-hht-qol/E — emphasized key phrases in QoL questions
enum TextEmphasis {
  /// No emphasis — plain text
  none,

  /// Bold and italic emphasis
  boldItalic,

  /// Bold, italic, and underline emphasis
  boldItalicUnderline;

  /// Parse from JSON string value.
  static TextEmphasis fromValue(String? value) {
    return switch (value) {
      'bold_italic' => TextEmphasis.boldItalic,
      'bold_italic_underline' => TextEmphasis.boldItalicUnderline,
      _ => TextEmphasis.none,
    };
  }
}

/// A segment of question text with optional emphasis.
///
/// QoL questions use segments to highlight key phrases
/// like "been interrupted" or "avoided social activities".
// Implements: DIARY-PRD-questionnaire-hht-qol/E — segmented emphasis for QoL key phrases
class TextSegment {
  const TextSegment({required this.text, this.emphasis = TextEmphasis.none});

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      text: json['text'] as String,
      emphasis: TextEmphasis.fromValue(json['emphasis'] as String?),
    );
  }

  /// The text content of this segment
  final String text;

  /// Emphasis style applied to this segment
  final TextEmphasis emphasis;

  /// Whether this segment has any emphasis
  bool get hasEmphasis => emphasis != TextEmphasis.none;
}
