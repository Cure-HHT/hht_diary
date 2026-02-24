// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

import 'package:trial_data_types/src/text_segment.dart';

/// Definition of a single question within a questionnaire.
///
/// Questions are displayed one at a time per REQ-p01070-A / REQ-p01071-A.
/// QoL questions include rich text segments for emphasis.
class QuestionDefinition {
  const QuestionDefinition({
    required this.id,
    required this.number,
    required this.text,
    required this.required,
    this.segments,
  });

  factory QuestionDefinition.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List<dynamic>?;
    return QuestionDefinition(
      id: json['id'] as String,
      number: json['number'] as int,
      text: json['text'] as String,
      required: json['required'] as bool? ?? true,
      segments: segmentsJson
          ?.map((s) => TextSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Unique question identifier (e.g., "nose_physical_1", "qol_q1")
  final String id;

  /// Display number (1-based)
  final int number;

  /// Plain text of the question
  final String text;

  /// Whether an answer is required to submit
  final bool required;

  /// Rich text segments with emphasis (QoL questions only).
  /// When present, these should be used for display instead of [text].
  final List<TextSegment>? segments;

  /// Whether this question uses rich text segments
  bool get hasSegments => segments != null && segments!.isNotEmpty;
}
