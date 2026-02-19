// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00080: Questionnaire Study Event Association
//   REQ-CAL-p00047: Hard-Coded Questionnaires
//
// Portal API handlers for questionnaire management.
// Supports sending, deleting, and retrieving questionnaire statuses.

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'notification_service.dart';
import 'portal_auth.dart';

/// GET /api/v1/portal/patients/<patientId>/questionnaires
///
/// Returns the current status of all questionnaire types for a patient.
/// Per REQ-CAL-p00023: statuses are Not Sent, Sent, In Progress,
/// Ready to Review, Finalized.
Future<Response> getQuestionnaireStatusHandler(
  Request request,
  String patientId,
) async {
  print('[QUESTIONNAIRE] getQuestionnaireStatusHandler for: $patientId');

  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Verify patient exists and user has site access
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.trial_started
    FROM patients p
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Get latest non-deleted questionnaire instance for each type
  final questionnaires = await db.executeWithContext(
    '''
    SELECT qi.id, qi.questionnaire_type::text, qi.status::text, qi.study_event,
           qi.version, qi.sent_at, qi.submitted_at, qi.finalized_at,
           qi.score, qi.sent_by
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @patientId
      AND qi.deleted_at IS NULL
    ORDER BY qi.created_at DESC
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  // Build response with all questionnaire types
  // Default to 'not_sent' for types that have no active instance
  final statusMap = <String, Map<String, dynamic>>{
    'nose_hht': {'questionnaire_type': 'nose_hht', 'status': 'not_sent'},
    'qol': {'questionnaire_type': 'qol', 'status': 'not_sent'},
    'eq': {'questionnaire_type': 'eq', 'status': 'not_sent'},
  };

  for (final row in questionnaires) {
    final type = row[1] as String;
    // Only take the first (most recent) instance per type
    if (statusMap[type]?['status'] == 'not_sent') {
      statusMap[type] = {
        'id': row[0] as String,
        'questionnaire_type': type,
        'status': row[2] as String,
        'study_event': row[3] as String?,
        'version': row[4] as String,
        'sent_at': (row[5] as DateTime?)?.toIso8601String(),
        'submitted_at': (row[6] as DateTime?)?.toIso8601String(),
        'finalized_at': (row[7] as DateTime?)?.toIso8601String(),
        'score': row[8] as int?,
      };
    }
  }

  return _jsonResponse({
    'patient_id': patientId,
    'questionnaires': statusMap.values.toList(),
  });
}

/// POST /api/v1/portal/patients/<patientId>/questionnaires/<questionnaireType>/send
///
/// Sends a questionnaire to a patient. Creates a questionnaire instance,
/// sends an FCM notification, and logs the action.
///
/// Per REQ-CAL-p00023-D: patient receives push notification and task.
/// Per REQ-CAL-p00023-E: Nose HHT and QoL can be sent multiple times.
Future<Response> sendQuestionnaireHandler(
  Request request,
  String patientId,
  String questionnaireType,
) async {
  print(
    '[QUESTIONNAIRE] sendQuestionnaireHandler: $questionnaireType for $patientId',
  );

  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Only Investigators can send questionnaires
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can send questionnaires',
    }, 403);
  }

  // Validate questionnaire type per REQ-CAL-p00047-A
  const validTypes = ['nose_hht', 'qol', 'eq'];
  if (!validTypes.contains(questionnaireType)) {
    return _jsonResponse({
      'error': 'Invalid questionnaire type: $questionnaireType',
    }, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Parse optional request body for study event
  String? studyEvent;
  try {
    final body = await request.readAsString();
    if (body.isNotEmpty) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      studyEvent = json['study_event'] as String?;
    }
  } catch (_) {
    // Body is optional for send
  }

  // Verify patient exists, has trial started, and user has site access
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.trial_started,
           p.mobile_linking_status::text
    FROM patients p
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final trialStarted = patientResult.first[2] as bool;

  // Verify site access
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // REQ-CAL-p00079: Trial must be started before questionnaire operations
  if (!trialStarted) {
    return _jsonResponse({
      'error': 'Trial must be started before sending questionnaires',
    }, 409);
  }

  // Check for existing non-finalized, non-deleted instance of this type
  final existingResult = await db.executeWithContext(
    '''
    SELECT id, status::text FROM questionnaire_instances
    WHERE patient_id = @patientId
      AND questionnaire_type = @questionnaireType::questionnaire_type
      AND deleted_at IS NULL
      AND status != 'finalized'
    ORDER BY created_at DESC
    LIMIT 1
    ''',
    parameters: {
      'patientId': patientId,
      'questionnaireType': questionnaireType,
    },
    context: serviceContext,
  );

  if (existingResult.isNotEmpty) {
    final existingStatus = existingResult.first[1] as String;
    return _jsonResponse({
      'error':
          'A $questionnaireType questionnaire is already active '
          '(status: $existingStatus). Delete it first before sending a new one.',
    }, 409);
  }

  // Determine questionnaire version per REQ-CAL-p00047-E
  const versionMap = {'nose_hht': '1.0.0', 'qol': '1.0.0', 'eq': '1.0.0'};
  final version = versionMap[questionnaireType]!;

  final now = DateTime.now().toUtc();

  // Create questionnaire instance
  final insertResult = await db.executeWithContext(
    '''
    INSERT INTO questionnaire_instances (
      patient_id, questionnaire_type, status, study_event,
      version, sent_by, sent_at, created_at, updated_at
    )
    VALUES (
      @patientId, @questionnaireType::questionnaire_type, 'sent', @studyEvent,
      @version, @sentBy, @sentAt, @sentAt, @sentAt
    )
    RETURNING id
    ''',
    parameters: {
      'patientId': patientId,
      'questionnaireType': questionnaireType,
      'studyEvent': studyEvent,
      'version': version,
      'sentBy': user.id,
      'sentAt': now.toIso8601String(),
    },
    context: serviceContext,
  );

  final instanceId = insertResult.first[0] as String;

  // Send FCM notification to patient's device
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  String? fcmMessageId;
  if (fcmTokenResult.isNotEmpty) {
    final fcmToken = fcmTokenResult.first[0] as String;
    final notificationResult = await NotificationService.instance
        .sendQuestionnaireNotification(
          fcmToken: fcmToken,
          questionnaireType: questionnaireType,
          questionnaireInstanceId: instanceId,
          patientId: patientId,
        );
    fcmMessageId = notificationResult.messageId;

    if (!notificationResult.success) {
      print('[QUESTIONNAIRE] FCM send failed: ${notificationResult.error}');
      // Don't fail the request - the questionnaire is still created.
      // Patient can discover it via sync.
    }
  } else {
    print(
      '[QUESTIONNAIRE] No FCM token found for patient $patientId. '
      'Patient will discover questionnaire via sync.',
    );
  }

  // REQ-CAL-p00023-U: Log to audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'QUESTIONNAIRE_SENT', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'questionnaire:$instanceId',
      'actionDetails': jsonEncode({
        'instance_id': instanceId,
        'patient_id': patientId,
        'questionnaire_type': questionnaireType,
        'study_event': studyEvent,
        'version': version,
        'sent_at': now.toIso8601String(),
        'sent_by_email': user.email,
        'sent_by_name': user.name,
        'fcm_message_id': fcmMessageId,
      }),
      'justification': '$questionnaireType questionnaire sent to patient',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[QUESTIONNAIRE] Sent $questionnaireType to patient $patientId: '
    'instance=$instanceId',
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': patientId,
    'questionnaire_type': questionnaireType,
    'status': 'sent',
    'study_event': studyEvent,
    'version': version,
    'sent_at': now.toIso8601String(),
  });
}

/// DELETE /api/v1/portal/patients/<patientId>/questionnaires/<instanceId>
///
/// Deletes (revokes) a questionnaire. Soft-deletes the instance and sends
/// an FCM notification to remove it from the patient's app.
///
/// Per REQ-CAL-p00023-F: allowed at any status before finalization.
/// Per REQ-CAL-p00023-I: NOT allowed after finalization.
/// Per REQ-CAL-p00066: requires a reason (max 25 chars).
Future<Response> deleteQuestionnaireHandler(
  Request request,
  String patientId,
  String instanceId,
) async {
  print(
    '[QUESTIONNAIRE] deleteQuestionnaireHandler: $instanceId for $patientId',
  );

  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Only Investigators can delete questionnaires
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can delete questionnaires',
    }, 403);
  }

  // Parse request body for reason
  String body;
  try {
    body = await request.readAsString();
  } catch (_) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final reason = json['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    return _jsonResponse({'error': 'Missing required field: reason'}, 400);
  }

  // REQ-CAL-p00066-B: max 25 characters
  if (reason.length > 25) {
    return _jsonResponse({
      'error': 'Reason must be 25 characters or fewer',
    }, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch the questionnaire instance
  final instanceResult = await db.executeWithContext(
    '''
    SELECT qi.id, qi.questionnaire_type::text, qi.status::text, qi.patient_id,
           qi.deleted_at
    FROM questionnaire_instances qi
    WHERE qi.id = @instanceId::uuid AND qi.patient_id = @patientId
    ''',
    parameters: {'instanceId': instanceId, 'patientId': patientId},
    context: serviceContext,
  );

  if (instanceResult.isEmpty) {
    return _jsonResponse({'error': 'Questionnaire instance not found'}, 404);
  }

  final currentStatus = instanceResult.first[2] as String;
  final alreadyDeleted = instanceResult.first[4] != null;

  if (alreadyDeleted) {
    return _jsonResponse({
      'error': 'Questionnaire has already been deleted',
    }, 409);
  }

  // REQ-CAL-p00023-I: Cannot delete after finalization
  if (currentStatus == 'finalized') {
    return _jsonResponse({
      'error': 'Cannot delete a finalized questionnaire',
    }, 409);
  }

  final now = DateTime.now().toUtc();

  // Soft-delete the instance
  await db.executeWithContext(
    '''
    UPDATE questionnaire_instances
    SET deleted_at = @deletedAt,
        delete_reason = @deleteReason,
        deleted_by = @deletedBy,
        updated_at = @deletedAt
    WHERE id = @instanceId::uuid
    ''',
    parameters: {
      'instanceId': instanceId,
      'deletedAt': now.toIso8601String(),
      'deleteReason': reason.trim(),
      'deletedBy': user.id,
    },
    context: serviceContext,
  );

  // Send FCM notification to remove from patient's app
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (fcmTokenResult.isNotEmpty) {
    final fcmToken = fcmTokenResult.first[0] as String;
    final notificationResult = await NotificationService.instance
        .sendQuestionnaireDeletedNotification(
          fcmToken: fcmToken,
          questionnaireInstanceId: instanceId,
          patientId: patientId,
        );

    if (!notificationResult.success) {
      print(
        '[QUESTIONNAIRE] FCM delete notification failed: '
        '${notificationResult.error}',
      );
    }
  }

  // REQ-CAL-p00023-U: Log to audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'QUESTIONNAIRE_DELETED', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'questionnaire:$instanceId',
      'actionDetails': jsonEncode({
        'instance_id': instanceId,
        'patient_id': patientId,
        'questionnaire_type': instanceResult.first[1] as String,
        'previous_status': currentStatus,
        'reason': reason.trim(),
        'deleted_at': now.toIso8601String(),
        'deleted_by_email': user.email,
        'deleted_by_name': user.name,
      }),
      'justification': 'Questionnaire deleted: ${reason.trim()}',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[QUESTIONNAIRE] Deleted questionnaire $instanceId for patient $patientId',
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': patientId,
    'deleted_at': now.toIso8601String(),
    'reason': reason.trim(),
  });
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
