// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Tasks endpoint for the diary server.
// The mobile app calls this to discover pending questionnaire tasks
// that were assigned via the sponsor portal.

import 'dart:convert';

import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

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
    // and trial_started_at so the mobile client can activate its outbound
    // sync destinations at the exact portal click timestamp (REQ-CAL-p00079).
    final userResult = await db.execute(
      '''
      SELECT u.user_id, p.patient_id, p.mobile_linking_status::text,
             p.trial_started, p.trial_started_at
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
    final trialStarted = row[3] as bool?;
    final trialStartedAt = row[4] as DateTime?;

    if (patientId == null) {
      return _jsonResponse({
        'tasks': <Map<String, dynamic>>[],
        if (mobileLinkingStatus != null)
          'mobileLinkingStatus': mobileLinkingStatus,
        'isDisconnected': mobileLinkingStatus == 'disconnected',
        // CUR-1165: REQ-p01065-D
        'isNotParticipating': mobileLinkingStatus == 'not_participating',
      });
    }

    // CUR-1165: REQ-p01065-D — stop delivering tasks when patient is not participating.
    // Sponsor-specific rules (including questionnaire tasks) must be deactivated.
    if (mobileLinkingStatus == 'not_participating') {
      return _jsonResponse({
        'tasks': <Map<String, dynamic>>[],
        'mobileLinkingStatus': mobileLinkingStatus,
        'isDisconnected': false,
        'isNotParticipating': true,
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

    // CUR-1292: surface recently-tombstoned questionnaires so the diary
    // client can mark its local materialized row deleted (timeline card
    // disappears) and queue a "questionnaire cancelled" notification.
    // This is the pragmatic shim until /api/v1/user/inbound exists; it
    // piggybacks on the channel the diary already polls. 30-day window
    // avoids unbounded growth — the diary's tombstone record is
    // idempotent so a stale message that's already been applied is a
    // no-op.
    final cancelledResult = await db.execute(
      '''
      SELECT id, questionnaire_type::text, deleted_at
      FROM questionnaire_instances
      WHERE patient_id = @patientId
        AND deleted_at IS NOT NULL
        AND deleted_at >= NOW() - INTERVAL '30 days'
      ORDER BY deleted_at DESC
      ''',
      parameters: {'patientId': patientId},
    );

    final cancelled = cancelledResult.map((r) {
      return {
        'questionnaire_instance_id': r[0],
        'questionnaire_type': r[1],
        'deleted_at': (r[2] as DateTime?)?.toIso8601String(),
      };
    }).toList();

    logWithTrace(
      'INFO',
      'Tasks fetched',
      labels: {'patientId': patientId, 'taskCount': tasks.length},
    );

    return _jsonResponse({
      'tasks': tasks,
      'cancelled': cancelled,
      if (mobileLinkingStatus != null)
        'mobileLinkingStatus': mobileLinkingStatus,
      'isDisconnected': mobileLinkingStatus == 'disconnected',
      // CUR-1165: REQ-p01065-D
      'isNotParticipating': mobileLinkingStatus == 'not_participating',
      // REQ-CAL-p00079: trial-start signal. The mobile client uses
      // trial_started_at to set the legacy_sync / legacy_questionnaire_submit
      // destinations' start_date watermark, so events recorded before the
      // portal "Send EQ" click stay local (personal-use) and events
      // recorded after that click ship to the trial server.
      'trial_started': trialStarted ?? false,
      if (trialStartedAt != null)
        'trial_started_at': trialStartedAt.toUtc().toIso8601String(),
    });
  } catch (e, stackTrace) {
    reportAndRecordError(e, stackTrace: stackTrace);
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
