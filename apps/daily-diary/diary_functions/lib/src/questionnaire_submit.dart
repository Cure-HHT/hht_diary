// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-d00113: Deleted Questionnaire Submission Handling
//
// Submit questionnaire responses endpoint for the diary server.
// The mobile app calls this when a patient completes a questionnaire.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

/// Simple structured logger for Cloud Run
void _log(String level, String message, [Map<String, dynamic>? data]) {
  final logEntry = {
    'severity': level,
    'message': message,
    'time': DateTime.now().toUtc().toIso8601String(),
    if (data != null) ...data,
  };
  stderr.writeln(jsonEncode(logEntry));
}

/// Submit questionnaire responses.
/// POST /api/v1/user/questionnaires/<instanceId>/submit
/// Authorization: Bearer <jwt>
///
/// Body: { "responses": [...], "questionnaire_type": "...", "version": "...", "completed_at": "..." }
///
/// Validates:
/// - JWT is valid
/// - Instance exists and belongs to the authenticated patient
/// - Instance is not deleted (REQ-d00113-A,B)
/// - Instance status is 'sent' (patient has not already submitted)
///
/// On success: writes responses, updates status to 'ready_to_review', returns 200.
/// On deleted: returns 409 with error code 'questionnaire_deleted'.
Future<Response> submitQuestionnaireHandler(
  Request request,
  String instanceId,
) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final db = Database.instance;

    // Look up patient via linking code
    final userResult = await db.execute(
      '''
      SELECT p.patient_id
      FROM app_users u
      JOIN patient_linking_codes plc ON u.user_id = plc.used_by_user_id
        AND plc.used_at IS NOT NULL
      JOIN patients p ON plc.patient_id = p.patient_id
      WHERE u.auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'Patient not found'}, 401);
    }

    final patientId = userResult.first[0] as String;

    // Verify questionnaire instance exists and belongs to this patient
    final instanceResult = await db.execute(
      '''
      SELECT status::text, deleted_at, patient_id
      FROM questionnaire_instances
      WHERE id = @instanceId::uuid
      ''',
      parameters: {'instanceId': instanceId},
    );

    if (instanceResult.isEmpty) {
      return _jsonResponse({'error': 'Questionnaire not found'}, 404);
    }

    final instanceRow = instanceResult.first;
    final status = instanceRow[0] as String;
    final deletedAt = instanceRow[1];
    final instancePatientId = instanceRow[2] as String;

    // REQ-d00113-A: Check if instance belongs to this patient
    if (instancePatientId != patientId) {
      return _jsonResponse({'error': 'Questionnaire not found'}, 404);
    }

    // REQ-d00113-B: Check if questionnaire was deleted
    if (deletedAt != null) {
      _log('WARN', 'Submit attempt on deleted questionnaire', {
        'instanceId': instanceId,
        'patientId': patientId,
      });
      return _jsonResponse({
        'error': 'questionnaire_deleted',
        'message':
            'This questionnaire has been withdrawn by your investigator.',
      }, 409);
    }

    // Only allow submission when status is 'sent'
    if (status != 'sent') {
      return _jsonResponse({
        'error': 'invalid_status',
        'message': 'Questionnaire cannot be submitted in status: $status',
      }, 409);
    }

    // Parse request body
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final responses = body['responses'] as List<dynamic>?;

    if (responses == null || responses.isEmpty) {
      return _jsonResponse({'error': 'No responses provided'}, 400);
    }

    // Insert all responses
    for (final responseJson in responses) {
      final response = responseJson as Map<String, dynamic>;
      await db.execute(
        '''
        INSERT INTO questionnaire_responses
          (questionnaire_instance_id, question_id, value, display_label, normalized_label)
        VALUES
          (@instanceId::uuid, @questionId, @value, @displayLabel, @normalizedLabel)
        ON CONFLICT (questionnaire_instance_id, question_id) DO UPDATE SET
          value = EXCLUDED.value,
          display_label = EXCLUDED.display_label,
          normalized_label = EXCLUDED.normalized_label
        ''',
        parameters: {
          'instanceId': instanceId,
          'questionId': response['question_id'] as String,
          'value': response['value'] as int,
          'displayLabel': response['display_label'] as String,
          'normalizedLabel': response['normalized_label'] as String,
        },
      );
    }

    // Update instance status to ready_to_review and set submitted_at
    await db.execute(
      '''
      UPDATE questionnaire_instances
      SET status = 'ready_to_review',
          submitted_at = now(),
          updated_at = now()
      WHERE id = @instanceId::uuid
      ''',
      parameters: {'instanceId': instanceId},
    );

    _log('INFO', 'Questionnaire submitted', {
      'instanceId': instanceId,
      'patientId': patientId,
      'responseCount': responses.length,
    });

    return _jsonResponse({
      'success': true,
      'instance_id': instanceId,
      'status': 'ready_to_review',
    });
  } catch (e, stackTrace) {
    _log('ERROR', 'Submit questionnaire error', {
      'instanceId': instanceId,
      'error': e.toString(),
      'stackTrace': stackTrace.toString().split('\n').take(5).join('\n'),
    });
    return _jsonResponse({'error': 'Internal server error: $e'}, 500);
  }
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
