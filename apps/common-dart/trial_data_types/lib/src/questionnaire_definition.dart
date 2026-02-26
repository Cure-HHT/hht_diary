// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-CAL-p00047: Hard-Coded Questionnaires

import 'dart:convert';

import 'package:trial_data_types/src/question_category.dart';
import 'package:trial_data_types/src/question_definition.dart';
import 'package:trial_data_types/src/session_config.dart';

/// A preamble page shown before the questionnaire questions.
class PreambleItem {
  const PreambleItem({required this.id, required this.content});

  factory PreambleItem.fromJson(Map<String, dynamic> json) {
    return PreambleItem(
      id: json['id'] as String,
      content: json['content'] as String,
    );
  }

  /// Unique preamble identifier
  final String id;

  /// Preamble text content
  final String content;
}

/// Complete definition of a questionnaire (NOSE HHT or QoL).
///
/// Loaded from the embedded questionnaires.json asset per
/// REQ-CAL-p00047-A: questionnaire definitions are hard-coded.
class QuestionnaireDefinition {
  const QuestionnaireDefinition({
    required this.id,
    required this.name,
    required this.version,
    required this.recallPeriod,
    required this.totalQuestions,
    required this.preamble,
    required this.categories,
    this.sessionConfig,
  });

  factory QuestionnaireDefinition.fromJson(Map<String, dynamic> json) {
    final preambleJson = json['preamble'] as List<dynamic>? ?? [];
    final categoriesJson = json['categories'] as List<dynamic>;
    final sessionConfigJson = json['sessionConfig'] as Map<String, dynamic>?;
    return QuestionnaireDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      recallPeriod: json['recallPeriod'] as String,
      totalQuestions: json['totalQuestions'] as int,
      preamble: preambleJson
          .map((p) => PreambleItem.fromJson(p as Map<String, dynamic>))
          .toList(),
      categories: categoriesJson
          .map((c) => QuestionCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
      sessionConfig: sessionConfigJson != null
          ? SessionConfig.fromJson(sessionConfigJson)
          : null,
    );
  }

  /// Questionnaire identifier (matches QuestionnaireType.value, e.g., "nose_hht")
  final String id;

  /// Display name (e.g., "NOSE HHT")
  final String name;

  /// Version string (e.g., "1.0")
  final String version;

  /// Recall period text (e.g., "2 weeks", "4 weeks")
  final String recallPeriod;

  /// Total number of questions across all categories
  final int totalQuestions;

  /// Preamble pages shown before the questions
  final List<PreambleItem> preamble;

  /// Question categories with response scales and questions
  final List<QuestionCategory> categories;

  /// Session configuration (readiness check, timeout)
  final SessionConfig? sessionConfig;

  /// All questions across all categories in display order
  List<QuestionDefinition> get allQuestions =>
      categories.expand((c) => c.questions).toList();

  /// Find the category that contains a given question
  QuestionCategory? categoryForQuestion(String questionId) {
    for (final category in categories) {
      if (category.questions.any((q) => q.id == questionId)) {
        return category;
      }
    }
    return null;
  }

  /// Load all questionnaire definitions from JSON string.
  ///
  /// The JSON is the content of `assets/data/questionnaires.json`.
  static List<QuestionnaireDefinition> loadAll(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final questionnaires = data['questionnaires'] as List<dynamic>;
    return questionnaires
        .map((q) => QuestionnaireDefinition.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  /// Find a definition by its id from a list of definitions.
  static QuestionnaireDefinition? findById(
    List<QuestionnaireDefinition> definitions,
    String id,
  ) {
    for (final def in definitions) {
      if (def.id == id) return def;
    }
    return null;
  }
}
