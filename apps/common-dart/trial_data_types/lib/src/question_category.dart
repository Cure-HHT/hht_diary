// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

import 'package:trial_data_types/src/question_definition.dart';
import 'package:trial_data_types/src/response_scale_option.dart';

/// A category grouping related questions with a shared response scale.
///
/// NOSE HHT has 3 categories (Physical, Functional, Emotional).
/// QoL has 1 category (HHT Quality of Life).
/// Each category has its own stem text and response labels.
class QuestionCategory {
  const QuestionCategory({
    required this.id,
    required this.name,
    required this.responseScale,
    required this.questions,
    this.stem,
  });

  factory QuestionCategory.fromJson(Map<String, dynamic> json) {
    final scaleJson = json['responseScale'] as List<dynamic>;
    final questionsJson = json['questions'] as List<dynamic>;
    return QuestionCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      stem: json['stem'] as String?,
      responseScale: scaleJson
          .map((s) => ResponseScaleOption.fromJson(s as Map<String, dynamic>))
          .toList(),
      questions: questionsJson
          .map((q) => QuestionDefinition.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Unique category identifier (e.g., "physical", "functional", "emotional")
  final String id;

  /// Display name (e.g., "Physical", "Functional", "Emotional")
  final String name;

  /// Stem text displayed at the top of the category (null for QoL)
  final String? stem;

  /// Response scale options (0-4) with labels specific to this category
  final List<ResponseScaleOption> responseScale;

  /// Questions in this category, in display order
  final List<QuestionDefinition> questions;
}
