// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

/// A patient's response to a single question.
class QuestionResponse {
  const QuestionResponse({
    required this.questionId,
    required this.value,
    required this.displayLabel,
    required this.normalizedLabel,
  });

  factory QuestionResponse.fromJson(Map<String, dynamic> json) {
    return QuestionResponse(
      questionId: json['question_id'] as String,
      value: json['value'] as int,
      displayLabel: json['display_label'] as String,
      normalizedLabel: json['normalized_label'] as String,
    );
  }

  /// The question this response is for
  final String questionId;

  /// Numeric value (0-4)
  final int value;

  /// Display label from the response scale (e.g., "Moderate problem")
  final String displayLabel;

  /// Normalized label across questionnaires (e.g., "0", "1", "2", "3", "4")
  final String normalizedLabel;

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'value': value,
      'display_label': displayLabel,
      'normalized_label': normalizedLabel,
    };
  }
}

/// Complete submission of a questionnaire with all responses.
class QuestionnaireSubmission {
  const QuestionnaireSubmission({
    required this.instanceId,
    required this.questionnaireType,
    required this.version,
    required this.responses,
    required this.completedAt,
  });

  /// The questionnaire instance ID (from the task)
  final String instanceId;

  /// Questionnaire type identifier (e.g., "nose_hht", "qol")
  final String questionnaireType;

  /// Version of the questionnaire definition
  final String version;

  /// All question responses
  final List<QuestionResponse> responses;

  /// When the patient completed the questionnaire
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return {
      'instance_id': instanceId,
      'questionnaire_type': questionnaireType,
      'version': version,
      'responses': responses.map((r) => r.toJson()).toList(),
      'completed_at': completedAt.toIso8601String(),
    };
  }
}
