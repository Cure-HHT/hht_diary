// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-PRD-questionnaire-versioning (J/K/L version refs)
//
// Cross-wire payload for a finalized questionnaire submission — emitted by the
// diary as a `<id>_survey` / `finalized` event and READ by the portal, so it
// lives in the shared model (anti-drift). Contract frozen by design decision 1d
// / surface D6 (docs/evs-lib-port/diary-event-surface.md):
//
//   - `instance_id`: the portal-minted `questionnaire_assigned` instance id,
//     carried through UNCHANGED for portal-assigned surveys (diary-minted for
//     diary-initiated surveys). The aggregate id of the survey instance.
//   - version refs: `schema_version` / `content_version` / `gui_version`
//     (DIARY-PRD-questionnaire-versioning J/K/L) + optional `translation_version`.
//   - `completed_at`: ISO 8601 submission timestamp.
//   - `flowToken`: the portal-minted correlation token, ECHOED on
//     portal-assigned submissions so the portal can stitch
//     `assigned -> delivered -> received -> submitted` across the FCM hop
//     (surface P5). Absent for diary-initiated surveys. NOT a secret.
//   - `responses`: `question_id -> {value, display_label, normalized_label}`.
//
// Per DIARY-DEV-shared-events-catalog/D the payload carries no OTP / recovery /
// session tokens.
library;

/// One answered question in a submission: the captured [value] plus the
/// participant-facing [displayLabel] and the analysis-facing [normalizedLabel].
/// Labels are optional (free-text / numeric answers may have neither).
class QuestionResponse {
  const QuestionResponse({
    required this.value,
    this.displayLabel,
    this.normalizedLabel,
  });

  /// The raw answer value (string / num / bool / list — whatever the question
  /// schema defines). Kept as `Object?` so the schema, not this type, governs.
  final Object? value;

  /// The label shown to the participant for the chosen [value] (localized).
  final String? displayLabel;

  /// The canonical/coded label used for scoring and analysis.
  final String? normalizedLabel;

  factory QuestionResponse.fromJson(Map<String, Object?> json) {
    return QuestionResponse(
      value: json['value'],
      displayLabel: json['display_label'] as String?,
      normalizedLabel: json['normalized_label'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    if (displayLabel != null) 'display_label': displayLabel,
    if (normalizedLabel != null) 'normalized_label': normalizedLabel,
  };
}

/// Payload for a finalized `<id>_survey` event (decision 1d / surface D6).
class QuestionnaireSubmissionPayload {
  const QuestionnaireSubmissionPayload({
    required this.instanceId,
    required this.questionnaireType,
    required this.schemaVersion,
    required this.contentVersion,
    required this.guiVersion,
    required this.completedAt,
    required this.responses,
    this.translationVersion,
    this.flowToken,
  });

  /// Portal-minted instance id for portal-assigned surveys (carried through
  /// unchanged); diary-minted for diary-initiated surveys.
  final String instanceId;

  /// The questionnaire id (the `<id>` of the `<id>_survey` entry type).
  final String questionnaireType;

  /// Schema version identifier (DIARY-PRD-questionnaire-versioning/J).
  final String schemaVersion;

  /// Content version identifier (DIARY-PRD-questionnaire-versioning/K).
  final String contentVersion;

  /// GUI/presentation version identifier (DIARY-PRD-questionnaire-versioning/L).
  final String guiVersion;

  /// Translation version identifier — present when a non-source-language
  /// translation was shown; absent for the source language.
  final String? translationVersion;

  /// ISO 8601 timestamp at which the participant completed the questionnaire.
  final String completedAt;

  /// Portal correlation token echoed on portal-assigned submissions; null for
  /// diary-initiated surveys. Not a secret.
  final String? flowToken;

  /// `question_id -> QuestionResponse`.
  final Map<String, QuestionResponse> responses;

  factory QuestionnaireSubmissionPayload.fromJson(Map<String, Object?> json) {
    final rawResponses =
        (json['responses'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    return QuestionnaireSubmissionPayload(
      instanceId: json['instance_id']! as String,
      questionnaireType: json['questionnaire_type']! as String,
      schemaVersion: json['schema_version']! as String,
      contentVersion: json['content_version']! as String,
      guiVersion: json['gui_version']! as String,
      translationVersion: json['translation_version'] as String?,
      completedAt: json['completed_at']! as String,
      flowToken: json['flowToken'] as String?,
      responses: <String, QuestionResponse>{
        for (final entry in rawResponses.entries)
          entry.key: QuestionResponse.fromJson(
            (entry.value as Map).cast<String, Object?>(),
          ),
      },
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'instance_id': instanceId,
    'questionnaire_type': questionnaireType,
    'schema_version': schemaVersion,
    'content_version': contentVersion,
    'gui_version': guiVersion,
    if (translationVersion != null) 'translation_version': translationVersion,
    'completed_at': completedAt,
    if (flowToken != null) 'flowToken': flowToken,
    'responses': <String, Object?>{
      for (final entry in responses.entries) entry.key: entry.value.toJson(),
    },
  };
}
