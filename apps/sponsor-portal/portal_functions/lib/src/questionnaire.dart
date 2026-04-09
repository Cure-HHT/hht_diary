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

import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'notification_service.dart';
import 'portal_auth.dart';
import 'portal_metrics.dart';
import 'sponsor.dart';

/// Cycle number regex for parsing "Cycle N Day 1" study_event values.
final _cyclePattern = RegExp(r'^Cycle (\d+) Day 1$');

/// Computes the next cycle info for a (patient, questionnaire type) pair.
///
/// Returns a map with:
/// - `needs_initial_selection`: true if the SC must pick a starting cycle
/// - `suggested_cycle`: hint for pre-selecting the dropdown (from last deleted)
/// - `study_event`: the computed study_event string (only if auto-increment)
///
/// Per REQ-CAL-p00080 Assertions C, D, H.
Future<Map<String, dynamic>> _computeNextCycleInfo(
  Database db,
  UserContext ctx,
  String patientId,
  String questionnaireType,
) async {
  // REQ-CAL-p00080-M: If cycle tracking disabled, single-use per type
  final flags = getCurrentSponsorFlags();
  if (!flags.enableCycleTracking) {
    final anyFinalized = await db.executeWithContext(
      '''
      SELECT 1 FROM questionnaire_instances
      WHERE patient_id = @patientId
        AND questionnaire_type = @questionnaireType::questionnaire_type
        AND status = 'finalized'
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      parameters: {
        'patientId': patientId,
        'questionnaireType': questionnaireType,
      },
      context: ctx,
    );
    if (anyFinalized.isNotEmpty) {
      return {
        'blocked': true,
        'blocked_reason': 'Questionnaire completed',
        'cycle_tracking_disabled': true,
      };
    }
    return {'needs_initial_selection': false, 'cycle_tracking_disabled': true};
  }

  // REQ-CAL-p00080-G: Check for finalized end events (blocks further sends)
  final endEventResult = await db.executeWithContext(
    '''
    SELECT qi.end_event::text, qi.study_event
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @patientId
      AND qi.questionnaire_type = @questionnaireType::questionnaire_type
      AND qi.status = 'finalized'
      AND qi.deleted_at IS NULL
      AND qi.end_event IS NOT NULL
    LIMIT 1
    ''',
    parameters: {
      'patientId': patientId,
      'questionnaireType': questionnaireType,
    },
    context: ctx,
  );

  if (endEventResult.isNotEmpty) {
    final endEvent = endEventResult.first[0].toString();
    final studyEvent = endEventResult.first[1]?.toString();
    return {
      'blocked': true,
      'blocked_reason':
          '$endEvent was finalized${studyEvent != null ? ' on $studyEvent' : ''}',
      'end_event': endEvent,
      'ended_on_study_event': studyEvent,
    };
  }

  // Query 1: Max cycle from finalized, non-deleted instances
  final finalizedResult = await db.executeWithContext(
    '''
    SELECT qi.study_event
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @patientId
      AND qi.questionnaire_type = @questionnaireType::questionnaire_type
      AND qi.status = 'finalized'
      AND qi.deleted_at IS NULL
      AND qi.study_event ~ '^Cycle \\d+ Day 1\$'
    ''',
    parameters: {
      'patientId': patientId,
      'questionnaireType': questionnaireType,
    },
    context: ctx,
  );

  int? maxFinalizedCycle;
  for (final row in finalizedResult) {
    final studyEvent = row[0] as String?;
    if (studyEvent == null) continue;
    final match = _cyclePattern.firstMatch(studyEvent);
    if (match != null) {
      final cycle = int.tryParse(match.group(1)!);
      if (cycle != null &&
          (maxFinalizedCycle == null || cycle > maxFinalizedCycle)) {
        maxFinalizedCycle = cycle;
      }
    }
  }

  // If finalized cycles exist → auto-increment
  if (maxFinalizedCycle != null) {
    final nextCycle = maxFinalizedCycle + 1;
    return {
      'needs_initial_selection': false,
      'suggested_cycle': nextCycle,
      'study_event': 'Cycle $nextCycle Day 1',
    };
  }

  // No finalized cycles — check sponsor config
  // REQ-CAL-p00080-I/J: If sponsor disabled the prompt, auto-assign Cycle 1
  if (!flags.requireInitialCycleSelection) {
    return {
      'needs_initial_selection': false,
      'suggested_cycle': 1,
      'study_event': 'Cycle 1 Day 1',
    };
  }

  // Prompt SC for starting cycle
  return {'needs_initial_selection': true};
}

/// GET /api/v1/portal/patients/<patientId>/questionnaires
///
/// Returns the current status of all questionnaire types for a patient.
/// Per REQ-CAL-p00023: statuses are Not Sent, Sent, In Progress,
/// Ready to Review, Finalized.
Future<Response> getQuestionnaireStatusHandler(
  Request request,
  String patientId,
) async {
  logWithTrace(
    'INFO',
    'getQuestionnaireStatusHandler',
    labels: {'patient_id': patientId},
  );

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

  // REQ-CAL-p00080: Compute next cycle info and add finalized metadata
  // for nose_hht and qol (eq excluded — managed via Start Trial)
  for (final type in ['nose_hht', 'qol']) {
    final entry = statusMap[type]!;
    final status = entry['status'] as String;

    // Always query the most recent finalized instance for this type,
    // so Last Completed is shown even when a new cycle is active.
    final lastFinalizedResult = await db.executeWithContext(
      '''
      SELECT qi.finalized_at, qi.study_event
      FROM questionnaire_instances qi
      WHERE qi.patient_id = @patientId
        AND qi.questionnaire_type = @type::questionnaire_type
        AND qi.status = 'finalized'
        AND qi.deleted_at IS NULL
      ORDER BY qi.finalized_at DESC
      LIMIT 1
      ''',
      parameters: {'patientId': patientId, 'type': type},
      context: serviceContext,
    );

    if (lastFinalizedResult.isNotEmpty) {
      entry['last_finalized_at'] = (lastFinalizedResult.first[0] as DateTime?)
          ?.toIso8601String();
      entry['last_finalized_study_event'] =
          lastFinalizedResult.first[1] as String?;
    }

    // If the latest instance is "finalized", transform to "not_sent".
    // This matches the Miro flow: "Now questionnaire is available to be
    // sent again in the next Cycle."
    if (status == 'finalized') {
      entry['status'] = 'not_sent';
      entry.remove('id');
      entry.remove('study_event');
      entry.remove('version');
      entry.remove('sent_at');
      entry.remove('submitted_at');
      entry.remove('finalized_at');
      entry.remove('score');
    }

    // Always include cycle_tracking_disabled flag
    final sponsorFlags = getCurrentSponsorFlags();
    if (!sponsorFlags.enableCycleTracking) {
      entry['cycle_tracking_disabled'] = true;
    }

    // Compute next cycle info for types that are ready for a new send
    if (entry['status'] == 'not_sent') {
      final nextCycleInfo = await _computeNextCycleInfo(
        db,
        serviceContext,
        patientId,
        type,
      );
      entry['next_cycle_info'] = nextCycleInfo;
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
  logWithTrace(
    'INFO',
    'sendQuestionnaireHandler',
    labels: {'patient_id': patientId, 'questionnaire_type': questionnaireType},
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

  // REQ-CAL-p00080-B: Validate study_event format if provided
  if (studyEvent != null) {
    final cyclePattern = RegExp(r'^Cycle [1-9]\d* Day 1$');
    if (!cyclePattern.hasMatch(studyEvent) || studyEvent.length > 32) {
      return _jsonResponse({
        'error':
            'Invalid study_event format. Must be "Cycle N Day 1" '
            'where N is a positive integer (max 32 chars).',
      }, 400);
    }
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

  // REQ-CAL-p00080: Auto-compute study_event if not provided (for nose_hht/qol)
  if (questionnaireType == 'nose_hht' || questionnaireType == 'qol') {
    final nextCycleInfo = await _computeNextCycleInfo(
      db,
      serviceContext,
      patientId,
      questionnaireType,
    );

    // REQ-CAL-p00080-G: Block sends after finalized end events
    if (nextCycleInfo['blocked'] == true) {
      return _jsonResponse({
        'error':
            'Cannot send questionnaire: ${nextCycleInfo['blocked_reason']}',
      }, 409);
    }

    // When cycle tracking is disabled, study_event stays null
    final cycleDisabled =
        nextCycleInfo['cycle_tracking_disabled'] as bool? ?? false;

    if (studyEvent == null && !cycleDisabled) {
      final needsSelection =
          nextCycleInfo['needs_initial_selection'] as bool? ?? true;
      if (needsSelection) {
        return _jsonResponse({
          'error':
              'Initial cycle selection required for the first $questionnaireType '
              'questionnaire. Provide study_event in the request body.',
        }, 400);
      }
      studyEvent = nextCycleInfo['study_event'] as String;
    }
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
      logWithTrace(
        'WARNING',
        'FCM send failed for questionnaire',
        labels: {
          'instance_id': instanceId,
          'error': notificationResult.error ?? 'unknown',
        },
      );
      // Don't fail the request - the questionnaire is still created.
      // Patient can discover it via sync.
    }
  } else {
    logWithTrace(
      'INFO',
      'No FCM token found, patient will discover via sync',
      labels: {'patient_id': patientId},
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

  questionnaireOp(operation: 'send', status: 'success');
  logWithTrace(
    'INFO',
    'Questionnaire sent',
    labels: {
      'instance_id': instanceId,
      'patient_id': patientId,
      'questionnaire_type': questionnaireType,
    },
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
  logWithTrace(
    'INFO',
    'deleteQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': patientId},
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
           qi.deleted_at, qi.study_event
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
      logWithTrace(
        'WARNING',
        'FCM delete notification failed',
        labels: {
          'instance_id': instanceId,
          'error': notificationResult.error ?? 'unknown',
        },
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
        'study_event': instanceResult.first[5] as String?,
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

  questionnaireOp(operation: 'delete', status: 'success');
  logWithTrace(
    'INFO',
    'Questionnaire deleted',
    labels: {'instance_id': instanceId, 'patient_id': patientId},
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': patientId,
    'deleted_at': now.toIso8601String(),
    'reason': reason.trim(),
  });
}

/// POST /api/v1/portal/patients/<patientId>/questionnaires/<instanceId>/unlock
///
/// Unlocks a questionnaire so the patient can re-edit their answers.
/// Changes status from 'ready_to_review' back to 'sent'.
///
/// Per REQ-CAL-p00023: Investigator can unlock a submitted questionnaire.
Future<Response> unlockQuestionnaireHandler(
  Request request,
  String patientId,
  String instanceId,
) async {
  logWithTrace(
    'INFO',
    'unlockQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': patientId},
  );

  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Only Investigators can unlock questionnaires
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can unlock questionnaires',
    }, 403);
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
           qi.deleted_at, qi.study_event
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
    return _jsonResponse({'error': 'Questionnaire has been deleted'}, 409);
  }

  // Only allowed when status is 'ready_to_review'
  if (currentStatus != 'ready_to_review') {
    return _jsonResponse({
      'error':
          'Can only unlock questionnaires with status ready_to_review '
          '(current: $currentStatus)',
    }, 409);
  }

  final now = DateTime.now().toUtc();

  // Change status back to 'sent'
  await db.executeWithContext(
    '''
    UPDATE questionnaire_instances
    SET status = 'sent',
        submitted_at = NULL,
        updated_at = @updatedAt
    WHERE id = @instanceId::uuid
    ''',
    parameters: {'instanceId': instanceId, 'updatedAt': now.toIso8601String()},
    context: serviceContext,
  );

  // Send FCM notification to patient
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
        .sendQuestionnaireUnlockedNotification(
          fcmToken: fcmToken,
          questionnaireInstanceId: instanceId,
          patientId: patientId,
        );

    if (!notificationResult.success) {
      logWithTrace(
        'WARNING',
        'FCM unlock notification failed',
        labels: {
          'instance_id': instanceId,
          'error': notificationResult.error ?? 'unknown',
        },
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
      @adminId, 'QUESTIONNAIRE_UNLOCKED', @targetResource,
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
        'study_event': instanceResult.first[5] as String?,
        'previous_status': currentStatus,
        'new_status': 'sent',
        'unlocked_at': now.toIso8601String(),
        'unlocked_by_email': user.email,
        'unlocked_by_name': user.name,
      }),
      'justification': 'Questionnaire unlocked for patient re-edit',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  questionnaireOp(operation: 'unlock', status: 'success');
  logWithTrace(
    'INFO',
    'Questionnaire unlocked',
    labels: {'instance_id': instanceId, 'patient_id': patientId},
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': patientId,
    'status': 'sent',
    'unlocked_at': now.toIso8601String(),
  });
}

/// POST /api/v1/portal/patients/<patientId>/questionnaires/<instanceId>/finalize
///
/// Finalizes a questionnaire. Sets status to 'finalized', records score,
/// and logs the action.
///
/// Per REQ-CAL-p00023: Investigator finalizes a submitted questionnaire.
/// Score calculation is placeholder (deferred to questionnaire content sprint).
Future<Response> finalizeQuestionnaireHandler(
  Request request,
  String patientId,
  String instanceId,
) async {
  logWithTrace(
    'INFO',
    'finalizeQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': patientId},
  );

  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Only Investigators can finalize questionnaires
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can finalize questionnaires',
    }, 403);
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
           qi.deleted_at, qi.study_event
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
    return _jsonResponse({'error': 'Questionnaire has been deleted'}, 409);
  }

  // Only allowed when status is 'ready_to_review'
  if (currentStatus != 'ready_to_review') {
    return _jsonResponse({
      'error':
          'Can only finalize questionnaires with status ready_to_review '
          '(current: $currentStatus)',
    }, 409);
  }

  // REQ-CAL-p00080-F: Parse optional end_event from body
  String? endEvent;
  try {
    final body = await request.readAsString();
    if (body.isNotEmpty) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      endEvent = json['end_event'] as String?;
    }
  } catch (_) {
    // Body is optional for finalize
  }

  // Validate end_event if provided
  if (endEvent != null &&
      endEvent != 'end_of_treatment' &&
      endEvent != 'end_of_study') {
    return _jsonResponse({
      'error':
          'Invalid end_event. Must be "end_of_treatment" or "end_of_study".',
    }, 400);
  }

  final now = DateTime.now().toUtc();

  // Placeholder score calculation (real scoring deferred to questionnaire content sprint)
  const score = 0;

  // Set status to finalized, optionally set end_event
  await db.executeWithContext(
    '''
    UPDATE questionnaire_instances
    SET status = 'finalized',
        finalized_at = @finalizedAt,
        finalized_by = @finalizedBy,
        end_event = @endEvent::end_event_type,
        score = @score,
        updated_at = @finalizedAt
    WHERE id = @instanceId::uuid
    ''',
    parameters: {
      'instanceId': instanceId,
      'finalizedAt': now.toIso8601String(),
      'finalizedBy': user.id,
      'endEvent': endEvent,
      'score': score,
    },
    context: serviceContext,
  );

  // REQ-CAL-p00023-U: Log to audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'QUESTIONNAIRE_FINALIZED', @targetResource,
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
        'study_event': instanceResult.first[5] as String?,
        'previous_status': currentStatus,
        'new_status': 'finalized',
        'end_event': endEvent,
        'score': score,
        'finalized_at': now.toIso8601String(),
        'finalized_by_email': user.email,
        'finalized_by_name': user.name,
      }),
      'justification': endEvent != null
          ? 'Questionnaire finalized as $endEvent'
          : 'Questionnaire finalized with score $score',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  questionnaireOp(operation: 'finalize', status: 'success');
  logWithTrace(
    'INFO',
    'Questionnaire finalized',
    labels: {
      'instance_id': instanceId,
      'patient_id': patientId,
      'score': score${endEvent != null ? ', end_event: $endEvent' : ''}.toString(),
    },
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': patientId,
    'status': 'finalized',
    'end_event': endEvent,
    'score': score,
    'finalized_at': now.toIso8601String(),
  });
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
