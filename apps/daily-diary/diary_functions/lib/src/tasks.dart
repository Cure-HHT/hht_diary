// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Tasks endpoint for the diary server.
// The mobile app calls this to discover pending questionnaire tasks
// that were assigned via the sponsor portal.

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

/// Get pending tasks for a patient.
/// GET /api/v1/user/tasks
/// Authorization: Bearer <jwt>
///
/// Returns questionnaire instances that are active (sent, in_progress,
/// ready_to_review) for the linked patient. The mobile app uses this
/// to discover tasks when FCM push notifications are unavailable.
Future<Response> getTasksHandler(Request request) async {
  if (request.method != 'GET') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final db = Database.instance;

    // Look up user and their linked patient via patient_linking_codes
    // Include mobile_linking_status for disconnection detection (REQ-CAL-p00077)
    final userResult = await db.execute(
      '''
      SELECT u.user_id, p.patient_id, p.mobile_linking_status::text
      FROM app_users u
      LEFT JOIN patient_linking_codes plc ON u.user_id = plc.used_by_user_id
        AND plc.used_at IS NOT NULL
      LEFT JOIN patients p ON plc.patient_id = p.patient_id
      WHERE u.auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final row = userResult.first;
    final patientId = row[1] as String?;
    final mobileLinkingStatus = row[2] as String?;

    if (patientId == null) {
      return _jsonResponse({
        'tasks': <Map<String, dynamic>>[],
        if (mobileLinkingStatus != null)
          'mobileLinkingStatus': mobileLinkingStatus,
        'isDisconnected': mobileLinkingStatus == 'disconnected',
      });
    }

    // Fetch active questionnaire instances for this patient
    final tasksResult = await db.execute(
      '''
      SELECT id, questionnaire_type::text, status::text,
             study_event, version, sent_at
      FROM questionnaire_instances
      WHERE patient_id = @patientId
        AND status IN ('sent', 'in_progress', 'ready_to_review')
        AND deleted_at IS NULL
      ORDER BY sent_at DESC
      ''',
      parameters: {'patientId': patientId},
    );

    final tasks = tasksResult.map((r) {
      return {
        'questionnaire_instance_id': r[0],
        'questionnaire_type': r[1],
        'status': r[2],
        'study_event': r[3],
        'version': r[4],
        'sent_at': (r[5] as DateTime?)?.toIso8601String(),
      };
    }).toList();

    _log('INFO', 'Tasks fetched', {
      'patientId': patientId,
      'taskCount': tasks.length,
    });

    return _jsonResponse({
      'tasks': tasks,
      if (mobileLinkingStatus != null)
        'mobileLinkingStatus': mobileLinkingStatus,
      'isDisconnected': mobileLinkingStatus == 'disconnected',
    });
  } catch (e, stackTrace) {
    _log('ERROR', 'Get tasks error', {
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
