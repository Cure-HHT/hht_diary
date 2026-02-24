// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-CAL-p00047: Hard-Coded Questionnaires
//   REQ-d00113: Deleted Questionnaire Submission Handling
//
// Service for loading questionnaire definitions and submitting responses.

import 'dart:convert';

import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:eq/eq.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:trial_data_types/trial_data_types.dart';

/// Service for managing questionnaire definitions and submission.
///
/// Per REQ-CAL-p00047: Questionnaire definitions are loaded from the
/// embedded JSON asset. Submission is handled via the diary server API.
class QuestionnaireService {
  QuestionnaireService({
    required this.enrollmentService,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final EnrollmentService enrollmentService;
  final http.Client _httpClient;

  List<QuestionnaireDefinition>? _definitions;

  /// Load and cache questionnaire definitions from the bundled JSON asset.
  Future<List<QuestionnaireDefinition>> loadDefinitions() async {
    if (_definitions != null) return _definitions!;

    final jsonString = await rootBundle.loadString(
      'packages/trial_data_types/assets/data/questionnaires.json',
    );
    _definitions = QuestionnaireDefinition.loadAll(jsonString);
    return _definitions!;
  }

  /// Get a specific questionnaire definition by type.
  ///
  /// Maps QuestionnaireType enum values to JSON definition IDs:
  /// - noseHht -> "nose_hht"
  /// - qol -> "hht_qol"
  Future<QuestionnaireDefinition?> getDefinition(QuestionnaireType type) async {
    final definitions = await loadDefinitions();
    final id = switch (type) {
      QuestionnaireType.noseHht => 'nose_hht',
      QuestionnaireType.qol => 'hht_qol',
      QuestionnaireType.eq => 'eq',
    };
    return QuestionnaireDefinition.findById(definitions, id);
  }

  /// Submit questionnaire responses to the diary server.
  ///
  /// Returns a SubmitResult indicating success, failure, or deleted status.
  /// REQ-d00113: Handles 409 questionnaire_deleted error gracefully.
  Future<SubmitResult> submitResponses(
    QuestionnaireSubmission submission,
  ) async {
    try {
      final jwt = await enrollmentService.getJwtToken();
      if (jwt == null) {
        return const SubmitResult(success: false, error: 'Not authenticated');
      }

      final backendUrl = await enrollmentService.getBackendUrl();
      if (backendUrl == null) {
        return const SubmitResult(success: false, error: 'Not enrolled');
      }

      final url =
          '$backendUrl/api/v1/user/questionnaires/${submission.instanceId}/submit';

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(submission.toJson()),
      );

      if (response.statusCode == 200) {
        return const SubmitResult(success: true);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as String? ?? 'Unknown error';

      // REQ-d00113: Handle deleted questionnaire
      if (response.statusCode == 409 && error == 'questionnaire_deleted') {
        return const SubmitResult(
          success: false,
          isDeleted: true,
          error: 'This questionnaire has been withdrawn by your investigator.',
        );
      }

      return SubmitResult(success: false, error: error);
    } catch (e) {
      debugPrint('[QuestionnaireService] Submit error: $e');
      return const SubmitResult(
        success: false,
        error: 'Failed to submit. Please check your connection and try again.',
      );
    }
  }
}
