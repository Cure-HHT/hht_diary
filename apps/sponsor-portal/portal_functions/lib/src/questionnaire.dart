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

import 'package:comms/comms.dart';
import 'package:otel_common/otel_common.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:trial_data_types/trial_data_types.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'notification_service.dart';
import 'portal_auth.dart';
import 'portal_metrics.dart';
import 'sponsor.dart';

// ============================================================
// Sealed result type for _computeNextCycleInfo
// ============================================================

/// Typed result returned by [_computeNextCycleInfo].
///
/// Replaces the previous loosely-typed [Map<String, dynamic>] to make the
/// compiler enforce exhaustive handling at every call site.
sealed class NextCycleResult {
  const NextCycleResult();

  /// Serialise to the wire-format map that is embedded in the GET response
  /// under `next_cycle_info`.
  Map<String, dynamic> toJson();
}

/// No further questionnaires of this type may be sent.
///
/// Caused either by a finalised end-event or (when [cycleTrackingDisabled]
/// is true) by a sponsor policy that limits each type to one submission.
class NextCycleBlocked extends NextCycleResult {
  const NextCycleBlocked({
    required this.blockedReason,
    this.endEvent,
    this.endedOnStudyEvent,
    this.cycleTrackingDisabled = false,
  });

  final String blockedReason;

  /// The end-event value (e.g. `'end_of_treatment'`) if blocked by an end-event.
  final String? endEvent;

  /// The study_event on which the end-event was finalised, if known.
  final String? endedOnStudyEvent;

  /// True when the sponsor has disabled cycle tracking entirely.
  final bool cycleTrackingDisabled;

  @override
  Map<String, dynamic> toJson() => {
    'blocked': true,
    'blocked_reason': blockedReason,
    if (endEvent != null) 'end_event': endEvent,
    if (endedOnStudyEvent != null) 'ended_on_study_event': endedOnStudyEvent,
    if (cycleTrackingDisabled) 'cycle_tracking_disabled': true,
  };
}

/// Sponsor has disabled cycle tracking; a send is allowed but [study_event]
/// will be null.
class NextCycleCycleTrackingDisabled extends NextCycleResult {
  const NextCycleCycleTrackingDisabled();

  @override
  Map<String, dynamic> toJson() => {
    'needs_initial_selection': false,
    'cycle_tracking_disabled': true,
  };
}

/// The study_event has been auto-computed (auto-increment or Cycle 1 default).
/// The caller may use [studyEvent] directly without prompting the SC.
class NextCycleAutoComputed extends NextCycleResult {
  const NextCycleAutoComputed({
    required this.suggestedCycle,
    required this.studyEvent,
  });

  final int suggestedCycle;
  final String studyEvent;

  @override
  Map<String, dynamic> toJson() => {
    'needs_initial_selection': false,
    'suggested_cycle': suggestedCycle,
    'study_event': studyEvent,
  };
}

/// No prior cycles exist and the sponsor requires the SC to pick a starting
/// cycle (REQ-CAL-p00080 Assertion H).
class NextCycleNeedsSelection extends NextCycleResult {
  const NextCycleNeedsSelection();

  @override
  Map<String, dynamic> toJson() => {'needs_initial_selection': true};
}

// ============================================================

/// Computes the next cycle info for a (patient, questionnaire type) pair.
///
/// Per REQ-CAL-p00080 Assertions C, D, H.
Future<NextCycleResult> _computeNextCycleInfo(
  Database db,
  UserContext ctx,
  String participantId,
  String questionnaireType, {
  SponsorFeatureFlags? sponsorFlags,
}) async {
  // REQ-CAL-p00080-M: If cycle tracking disabled, single-use per type
  final flags = sponsorFlags ?? getCurrentSponsorFlags();
  if (!flags.enableCycleTracking) {
    final anyFinalized = await db.executeWithContext(
      '''
      SELECT 1 FROM questionnaire_instances
      WHERE patient_id = @participantId
        AND questionnaire_type = @questionnaireType::questionnaire_type
        AND status = 'finalized'
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      parameters: {
        'patientId': participantId,
        'questionnaireType': questionnaireType,
      },
      context: ctx,
    );
    if (anyFinalized.isNotEmpty) {
      return const NextCycleBlocked(
        blockedReason: 'Questionnaire completed',
        cycleTrackingDisabled: true,
      );
    }
    return const NextCycleCycleTrackingDisabled();
  }

  // REQ-CAL-p00080-G: Check for finalized end events (blocks further sends)
  final endEventResult = await db.executeWithContext(
    '''
    SELECT qi.end_event::text, qi.study_event
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @participantId
      AND qi.questionnaire_type = @questionnaireType::questionnaire_type
      AND qi.status = 'finalized'
      AND qi.deleted_at IS NULL
      AND qi.end_event IS NOT NULL
    LIMIT 1
    ''',
    parameters: {
      'patientId': participantId,
      'questionnaireType': questionnaireType,
    },
    context: ctx,
  );

  if (endEventResult.isNotEmpty) {
    final endEvent = endEventResult.first[0].toString();
    final studyEvent = endEventResult.first[1]?.toString();
    return NextCycleBlocked(
      blockedReason:
          '${StudyEvent.endEventDisplayLabel(endEvent)} was finalized'
          '${studyEvent != null ? ' on $studyEvent' : ''}',
      endEvent: endEvent,
      endedOnStudyEvent: studyEvent,
    );
  }

  // Query 1: Max cycle from finalized, non-deleted instances
  final finalizedResult = await db.executeWithContext(
    '''
    SELECT qi.study_event
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @participantId
      AND qi.questionnaire_type = @questionnaireType::questionnaire_type
      AND qi.status = 'finalized'
      AND qi.deleted_at IS NULL
      AND qi.study_event ~ '^Cycle [1-9]\\d* Day 1\$'  -- matches StudyEvent._cyclePattern
    ''',
    parameters: {
      'patientId': participantId,
      'questionnaireType': questionnaireType,
    },
    context: ctx,
  );

  int? maxFinalizedCycle;
  for (final row in finalizedResult) {
    final studyEvent = row[0] as String?;
    if (studyEvent == null) continue;
    final cycle = StudyEvent.parseCycleNumber(studyEvent);
    if (cycle != null &&
        (maxFinalizedCycle == null || cycle > maxFinalizedCycle)) {
      maxFinalizedCycle = cycle;
    }
  }

  // If finalized cycles exist → auto-increment
  if (maxFinalizedCycle != null) {
    final nextCycle = maxFinalizedCycle + 1;
    return NextCycleAutoComputed(
      suggestedCycle: nextCycle,
      studyEvent: StudyEvent.format(nextCycle),
    );
  }

  // No finalized cycles — check sponsor config
  // REQ-CAL-p00080-I/J: If sponsor disabled the prompt, auto-assign Cycle 1
  if (!flags.requireInitialCycleSelection) {
    return NextCycleAutoComputed(
      suggestedCycle: 1,
      studyEvent: StudyEvent.format(1),
    );
  }

  // Prompt SC for starting cycle
  return const NextCycleNeedsSelection();
}

/// CUR-1311 (Phase 1B.3): outcome of a questionnaire push dispatch.
/// Same shape as the patient_status helper — both ids surface in the
/// admin_action_log so an auditor can pivot to the notifications row.
typedef _QuestionnairePushResult = ({
  String? fcmMessageId,
  String? notificationId,
});

/// CUR-1311 (Phase 1B.3): one of the four questionnaire-lifecycle
/// actions. Drives title/body/userVisible defaults and the legacy-path
/// dispatch method choice. Sub-actions live in `payload.action`
/// (mobile sub-routes on it); the [NotificationType] is always
/// `questionnaireUpdate`.
enum _QuestionnaireAction {
  sent('new_task', 'questionnaire_sent'),
  deleted('remove_task', 'questionnaire_deleted'),
  unlocked('unlock_task', 'questionnaire_unlocked'),
  finalized('lock_task', 'questionnaire_finalized');

  const _QuestionnaireAction(this.payloadAction, this.fcmType);
  final String payloadAction;

  /// Wire `data.type` value used by the legacy
  /// sendQuestionnaire*Notification methods. Distinct from
  /// [NotificationType.questionnaireUpdate] which is the
  /// envelope/protocol-level vocabulary.
  final String fcmType;
}

/// CUR-1311 (Phase 1B.3): unified send path for the
/// `questionnaireUpdate` family of notifications. Mirrors
/// `_dispatchPatientStatusPush` in patient_linking.dart but for the
/// questionnaire-specific payload shape (carries
/// `questionnaire_instance_id` instead of `new_status`).
///
/// `deleted` is the only silent action — userVisible is forced false
/// and title/body are not sent over FCM. Every other action is an
/// alert (priority 10, lock-screen visible).
Future<_QuestionnairePushResult> _dispatchQuestionnairePush({
  required String fcmToken,
  required String participantId,
  required String questionnaireInstanceId,
  required _QuestionnaireAction action,
  required bool useEnvelope,
  required String logPrefix,
  String? questionnaireType, // populated for `sent`; null otherwise
}) async {
  final isUserVisible = action != _QuestionnaireAction.deleted;
  final title = switch (action) {
    _QuestionnaireAction.sent => 'New Questionnaire Available',
    _QuestionnaireAction.deleted => null,
    _QuestionnaireAction.unlocked => 'Questionnaire Unlocked',
    _QuestionnaireAction.finalized => 'Questionnaire Finalized',
  };
  final body = switch (action) {
    _QuestionnaireAction.sent => 'You have a new questionnaire to complete.',
    _QuestionnaireAction.deleted => null,
    _QuestionnaireAction.unlocked =>
      'A questionnaire has been unlocked for editing.',
    _QuestionnaireAction.finalized => 'Your questionnaire has been finalized.',
  };

  if (useEnvelope) {
    final outboxWriter = NotificationService.outboxWriter;
    if (outboxWriter != null) {
      final envelope = Envelope(
        notificationId: const Uuid().v4(),
        participantId: participantId,
        type: NotificationType.questionnaireUpdate,
        // The envelope still stores a title for audit / UI fallback,
        // even on silent actions — it just isn't sent over FCM.
        title: title ?? 'Questionnaire Removed',
        body: body,
        userVisible: isUserVisible,
        payload: <String, dynamic>{
          'action': action.payloadAction,
          'questionnaire_instance_id': questionnaireInstanceId,
          if (questionnaireType != null)
            'questionnaire_type': questionnaireType,
        },
        status: EnvelopeStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      try {
        final notificationId = await outboxWriter.send(
          envelope,
          fcmToken: fcmToken,
        );
        final stored = await outboxWriter.repo.findById(
          notificationId,
          participantId: participantId,
        );
        if (stored?.status == EnvelopeStatus.failed) {
          logWithTrace(
            'WARNING',
            '[$logPrefix] Envelope dispatch failed for ${action.fcmType}',
            labels: {
              'instance_id': questionnaireInstanceId,
              'error': stored?.error ?? 'unknown',
            },
          );
        }
        return (
          fcmMessageId: stored?.messageId,
          notificationId: notificationId,
        );
      } on PhiLeakException catch (e) {
        logWithTrace(
          'ERROR',
          '[$logPrefix] PHI guard rejected ${action.fcmType} envelope',
          labels: {'error': e.toString()},
        );
        return (fcmMessageId: null, notificationId: null);
      }
    }
    logWithTrace(
      'INFO',
      '[$logPrefix] OutboxWriter not initialised; falling back to legacy FCM',
      labels: {'action': action.fcmType},
    );
  }

  // Legacy direct-FCM path (S2 behaviour). Each questionnaire action
  // maps to a dedicated NotificationService method — switch is bounded
  // to four cases.
  final result = switch (action) {
    _QuestionnaireAction.sent =>
      await NotificationService.instance.sendQuestionnaireNotification(
        fcmToken: fcmToken,
        questionnaireType: questionnaireType ?? '',
        questionnaireInstanceId: questionnaireInstanceId,
        participantId: participantId,
      ),
    _QuestionnaireAction.deleted =>
      await NotificationService.instance.sendQuestionnaireDeletedNotification(
        fcmToken: fcmToken,
        questionnaireInstanceId: questionnaireInstanceId,
        participantId: participantId,
      ),
    _QuestionnaireAction.unlocked =>
      await NotificationService.instance.sendQuestionnaireUnlockedNotification(
        fcmToken: fcmToken,
        questionnaireInstanceId: questionnaireInstanceId,
        participantId: participantId,
      ),
    _QuestionnaireAction.finalized =>
      await NotificationService.instance.sendQuestionnaireFinalizedNotification(
        fcmToken: fcmToken,
        questionnaireInstanceId: questionnaireInstanceId,
        participantId: participantId,
      ),
  };
  if (!result.success) {
    logWithTrace(
      'WARNING',
      '[$logPrefix] FCM send failed for ${action.fcmType}',
      labels: {
        'instance_id': questionnaireInstanceId,
        'error': result.error ?? 'unknown',
      },
    );
  }
  return (fcmMessageId: result.messageId, notificationId: null);
}

/// GET /api/v1/portal/participants/questionnaires (X-Patient-Id header)
///
/// Returns the current status of all questionnaire types for a patient.
/// Per REQ-CAL-p00023: statuses are Not Sent, Sent, In Progress,
/// Ready to Review, Finalized.
Future<Response> getQuestionnaireStatusHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // CUR-1064: patientId moved from URL path to X-Patient-Id header (GET request)
  final participantId = request.headers['x-patient-id'];
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing X-Patient-Id header'}, 400);
  }

  logWithTrace(
    'INFO',
    'getQuestionnaireStatusHandler',
    labels: {'patient_id': participantId},
  );

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Verify patient exists and user has site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.trial_started
    FROM patients p
    WHERE p.patient_id = @participantId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
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
    WHERE qi.patient_id = @participantId
      AND qi.deleted_at IS NULL
    ORDER BY qi.created_at DESC
    ''',
    parameters: {'patientId': participantId},
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

  // Fetch once — used inside the loop and forwarded to _computeNextCycleInfo
  // to avoid a second env-lookup per type (Issue 9).
  final sponsorFlags = getCurrentSponsorFlags();

  // REQ-CAL-p00080: Fetch last-finalized metadata for nose_hht and qol in one query
  final lastFinalizedBatch = await db.executeWithContext(
    '''
    SELECT DISTINCT ON (qi.questionnaire_type)
           qi.questionnaire_type::text, qi.finalized_at, qi.study_event
    FROM questionnaire_instances qi
    WHERE qi.patient_id = @participantId
      AND qi.questionnaire_type IN ('nose_hht'::questionnaire_type, 'qol'::questionnaire_type)
      AND qi.status = 'finalized'
      AND qi.deleted_at IS NULL
    ORDER BY qi.questionnaire_type, qi.finalized_at DESC
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  // Index batch results by type
  final lastFinalizedByType = <String, List<dynamic>>{};
  for (final row in lastFinalizedBatch) {
    lastFinalizedByType[row[0] as String] = row;
  }

  // Compute next cycle info and add finalized metadata
  // for nose_hht and qol (eq excluded — managed via Start Trial)
  for (final type in ['nose_hht', 'qol']) {
    final entry = statusMap[type]!;
    final status = entry['status'] as String;

    // Apply last-finalized metadata from batch query
    final lastFinalizedRow = lastFinalizedByType[type];
    if (lastFinalizedRow != null) {
      entry['last_finalized_at'] = (lastFinalizedRow[1] as DateTime?)
          ?.toIso8601String();
      entry['last_finalized_study_event'] = lastFinalizedRow[2] as String?;
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
    if (!sponsorFlags.enableCycleTracking) {
      entry['cycle_tracking_disabled'] = true;
    }

    // Compute next cycle info for types that are ready for a new send
    if (entry['status'] == 'not_sent') {
      final nextCycleInfo = await _computeNextCycleInfo(
        db,
        serviceContext,
        participantId,
        type,
        sponsorFlags: sponsorFlags,
      );
      entry['next_cycle_info'] = nextCycleInfo.toJson();
    }
  }

  return _jsonResponse({
    'patient_id': participantId,
    'questionnaires': statusMap.values.toList(),
  });
}

/// POST /api/v1/portal/participants/questionnaires/send (patientId + questionnaireType in body)
///
/// Sends a questionnaire to a patient. Creates a questionnaire instance,
/// sends an FCM notification, and logs the action.
///
/// Per REQ-CAL-p00023-D: patient receives push notification and task.
/// Per REQ-CAL-p00023-E: Nose HHT and QoL can be sent multiple times.
Future<Response> sendQuestionnaireHandler(Request request) async {
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

  // CUR-1064: patientId and questionnaireType moved from URL path to request body
  Map<String, dynamic> bodyJson;
  try {
    final bodyStr = await request.readAsString();
    bodyJson = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (_) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final participantId = bodyJson['patientId'] as String?;
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({
      'error': 'Missing participantId in request body',
    }, 400);
  }

  final questionnaireType = bodyJson['questionnaireType'] as String?;
  if (questionnaireType == null || questionnaireType.isEmpty) {
    return _jsonResponse({
      'error': 'Missing questionnaireType in request body',
    }, 400);
  }

  var studyEvent = bodyJson['study_event'] as String?;

  // Validate questionnaire type per REQ-CAL-p00047-A
  const validTypes = ['nose_hht', 'qol', 'eq'];
  if (!validTypes.contains(questionnaireType)) {
    return _jsonResponse({
      'error': 'Invalid questionnaire type: $questionnaireType',
    }, 400);
  }

  logWithTrace(
    'INFO',
    'sendQuestionnaireHandler',
    labels: {
      'patient_id': participantId,
      'questionnaire_type': questionnaireType,
    },
  );

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // REQ-CAL-p00080-B: Validate study_event format if provided.
  // StudyEvent.isValid enforces both the strict regex (N >= 1) and maxLength.
  if (studyEvent != null && !StudyEvent.isValid(studyEvent)) {
    return _jsonResponse({
      'error':
          'Invalid study_event format. Must be "Cycle N Day 1" '
          'where N is a positive integer (max ${StudyEvent.maxLength} chars).',
    }, 400);
  }

  // Verify patient exists, has trial started, and user has site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.trial_started,
           p.mobile_linking_status::text
    FROM patients p
    WHERE p.patient_id = @participantId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final trialStarted = participantResult.first[2] as bool;

  // Verify site access
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
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
    WHERE patient_id = @participantId
      AND questionnaire_type = @questionnaireType::questionnaire_type
      AND deleted_at IS NULL
      AND status != 'finalized'
    ORDER BY created_at DESC
    LIMIT 1
    ''',
    parameters: {
      'patientId': participantId,
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
      participantId,
      questionnaireType,
    );

    switch (nextCycleInfo) {
      // REQ-CAL-p00080-G: Block sends after finalized end events or when
      // the single-use quota is exhausted (cycle tracking disabled).
      case NextCycleBlocked(:final blockedReason):
        return _jsonResponse({
          'error': 'Cannot send questionnaire: $blockedReason',
        }, 409);

      // Cycle tracking disabled — study_event stays null, proceed to INSERT.
      case NextCycleCycleTrackingDisabled():
        break;

      // study_event auto-computed — use it if the caller didn't supply one.
      case NextCycleAutoComputed(studyEvent: final computed):
        studyEvent ??= computed;

      // SC must pick a starting cycle — reject if study_event not provided.
      case NextCycleNeedsSelection():
        if (studyEvent == null) {
          return _jsonResponse({
            'error':
                'Initial cycle selection required for the first $questionnaireType '
                'questionnaire. Provide study_event in the request body.',
          }, 400);
        }
    }
  }

  // REQ-CAL-p00080-E: Pre-check for study_event uniqueness to return a clean
  // 409 rather than leaking a raw PostgreSQL unique-constraint violation.
  // The idx_qi_unique_study_event index is the authoritative enforcement;
  // this check provides a user-readable error for defence-in-depth.
  if (studyEvent != null) {
    final conflictResult = await db.executeWithContext(
      '''
      SELECT 1 FROM questionnaire_instances
      WHERE patient_id = @participantId
        AND questionnaire_type = @questionnaireType::questionnaire_type
        AND study_event = @studyEvent
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      parameters: {
        'patientId': participantId,
        'questionnaireType': questionnaireType,
        'studyEvent': studyEvent,
      },
      context: serviceContext,
    );

    if (conflictResult.isNotEmpty) {
      return _jsonResponse({
        'error':
            'A $questionnaireType questionnaire for study event '
            '"$studyEvent" already exists and has not been deleted. '
            'Delete it first or choose a different cycle.',
      }, 409);
    }
  }

  // Determine questionnaire version per REQ-CAL-p00047-E
  const versionMap = {'nose_hht': '1.0.0', 'qol': '1.0.0', 'eq': '1.0.0'};
  final version = versionMap[questionnaireType]!;

  final now = DateTime.now().toUtc();

  // Create questionnaire instance.
  // Catch UniqueViolationException (SQLSTATE 23505) in case two concurrent
  // requests both pass the pre-check above and race to INSERT. The pre-check
  // already provides a clean 409 for the common case; this catch ensures the
  // rare concurrent race also returns a 409 instead of a raw 500.
  final List<List<dynamic>> insertResult;
  try {
    insertResult = await db.executeWithContext(
      '''
      INSERT INTO questionnaire_instances (
        patient_id, questionnaire_type, status, study_event,
        version, sent_by, sent_at, created_at, updated_at
      )
      VALUES (
        @participantId, @questionnaireType::questionnaire_type, 'sent', @studyEvent,
        @version, @sentBy, @sentAt, @sentAt, @sentAt
      )
      RETURNING id
      ''',
      parameters: {
        'patientId': participantId,
        'questionnaireType': questionnaireType,
        'studyEvent': studyEvent,
        'version': version,
        'sentBy': user.id,
        'sentAt': now.toIso8601String(),
      },
      context: serviceContext,
    );
  } on UniqueViolationException {
    return _jsonResponse({
      'error':
          'A $questionnaireType questionnaire for study event '
          '"$studyEvent" already exists and has not been deleted. '
          'Delete it first or choose a different cycle.',
    }, 409);
  }

  final instanceId = insertResult.first[0] as String;

  // REQ-d00182-B/C: suppress the push if the questionnaire is already
  // submitted or has been called back. Defensive — for a fresh INSERT
  // these columns are always null, so the check is a no-op for
  // sendQuestionnaireHandler today. Kept so a future cron-based
  // resender that reaches the same notification site cannot dispatch
  // a stale "you have a new questionnaire" alert.
  final suppressionCheck = await db.executeWithContext(
    '''
    SELECT submitted_at, deleted_at
    FROM questionnaire_instances
    WHERE id = @instanceId::uuid
    ''',
    parameters: {'instanceId': instanceId},
    context: serviceContext,
  );
  final shouldSuppress =
      suppressionCheck.isNotEmpty &&
      (suppressionCheck.first[0] != null || suppressionCheck.first[1] != null);

  // Send FCM notification to patient's device
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @participantId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (shouldSuppress) {
    logWithTrace(
      'INFO',
      'questionnaire_sent suppressed (already-submitted or called-back)',
      labels: {'instance_id': instanceId},
    );
  } else if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchQuestionnairePush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      questionnaireInstanceId: instanceId,
      action: _QuestionnaireAction.sent,
      questionnaireType: questionnaireType,
      useEnvelope:
          NotificationConfig.fromEnvironment().useEnvelopeQuestionnaireSent,
      logPrefix: 'QUESTIONNAIRE_SEND',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  } else {
    logWithTrace(
      'INFO',
      'No FCM token found, patient will discover via sync',
      labels: {'patient_id': participantId},
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
        'patient_id': participantId,
        'questionnaire_type': questionnaireType,
        'study_event': studyEvent,
        'version': version,
        'sent_at': now.toIso8601String(),
        'sent_by_email': user.email,
        'sent_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
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
      'patient_id': participantId,
      'questionnaire_type': questionnaireType,
    },
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': participantId,
    'questionnaire_type': questionnaireType,
    'status': 'sent',
    'study_event': studyEvent,
    'version': version,
    'sent_at': now.toIso8601String(),
  });
}

/// DELETE /api/v1/portal/questionnaire-instances/<instanceId>
///
/// Deletes (revokes) a questionnaire. Soft-deletes the instance and sends
/// an FCM notification to remove it from the patient's app.
///
/// Per REQ-CAL-p00023-F: allowed at any status before finalization.
/// Per REQ-CAL-p00023-I: NOT allowed after finalization.
/// Per REQ-CAL-p00066: requires a reason (max 25 chars).
Future<Response> deleteQuestionnaireHandler(
  Request request,
  String instanceId,
) async {
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

  // CUR-1064: patientId removed from URL; look it up from the instance and verify site access
  final instanceResult = await db.executeWithContext(
    '''
    SELECT qi.id, qi.questionnaire_type::text, qi.status::text, qi.patient_id,
           qi.deleted_at, p.site_id, qi.study_event
    FROM questionnaire_instances qi
    JOIN patients p ON p.patient_id = qi.patient_id
    WHERE qi.id = @instanceId::uuid
    ''',
    parameters: {'instanceId': instanceId},
    context: serviceContext,
  );

  if (instanceResult.isEmpty) {
    return _jsonResponse({'error': 'Questionnaire instance not found'}, 404);
  }

  final participantId = instanceResult.first[3] as String;
  final participantSiteId = instanceResult.first[5] as String;
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  logWithTrace(
    'INFO',
    'deleteQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': participantId},
  );

  final currentStatus = instanceResult.first[2] as String;
  final alreadyDeleted = instanceResult.first[4] != null;

  if (alreadyDeleted) {
    return _jsonResponse({
      'error': 'Questionnaire has already been deleted',
    }, 409);
  }

  // REQ-CAL-p00023-I: Cannot delete after finalization.
  //
  // This also covers terminal-cycle questionnaires (end_event IS NOT NULL,
  // REQ-CAL-p00080-G): end_event is only set during finalization, so a
  // terminal-cycle questionnaire is always 'finalized' by the time it carries
  // a non-null end_event. Deletion is therefore permanently blocked at the
  // application layer once a terminal cycle is finalized.
  //
  // Corollary (REQ-CAL-p00080-G): if the questionnaire is still in 'sent'
  // or 'ready_to_review' status (i.e. finalization has not yet happened),
  // it CAN be deleted — and doing so clears the end_event block, allowing a
  // new send. See: _computeNextCycleInfo end_event check (deleted_at IS NULL).
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
    WHERE patient_id = @participantId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchQuestionnairePush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      questionnaireInstanceId: instanceId,
      action: _QuestionnaireAction.deleted,
      useEnvelope:
          NotificationConfig.fromEnvironment().useEnvelopeQuestionnaireDeleted,
      logPrefix: 'QUESTIONNAIRE_DELETE',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
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
        'patient_id': participantId,
        'questionnaire_type': instanceResult.first[1] as String,
        'study_event': instanceResult.first[6] as String?,
        'previous_status': currentStatus,
        'reason': reason.trim(),
        'deleted_at': now.toIso8601String(),
        'deleted_by_email': user.email,
        'deleted_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
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
    labels: {'instance_id': instanceId, 'patient_id': participantId},
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': participantId,
    'deleted_at': now.toIso8601String(),
    'reason': reason.trim(),
  });
}

/// POST /api/v1/portal/questionnaire-instances/<instanceId>/unlock
///
/// Unlocks a questionnaire so the patient can re-edit their answers.
/// Changes status from 'ready_to_review' back to 'sent'.
///
/// Per REQ-CAL-p00023: Investigator can unlock a submitted questionnaire.
Future<Response> unlockQuestionnaireHandler(
  Request request,
  String instanceId,
) async {
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

  // CUR-1064: patientId removed from URL; look it up from the instance and verify site access
  final instanceResult = await db.executeWithContext(
    '''
    SELECT qi.id, qi.questionnaire_type::text, qi.status::text, qi.patient_id,
           qi.deleted_at, p.site_id, qi.study_event
    FROM questionnaire_instances qi
    JOIN patients p ON p.patient_id = qi.patient_id
    WHERE qi.id = @instanceId::uuid
    ''',
    parameters: {'instanceId': instanceId},
    context: serviceContext,
  );

  if (instanceResult.isEmpty) {
    return _jsonResponse({'error': 'Questionnaire instance not found'}, 404);
  }

  final participantId = instanceResult.first[3] as String;
  final participantSiteId = instanceResult.first[5] as String;
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  logWithTrace(
    'INFO',
    'unlockQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': participantId},
  );

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
    WHERE patient_id = @participantId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchQuestionnairePush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      questionnaireInstanceId: instanceId,
      action: _QuestionnaireAction.unlocked,
      useEnvelope:
          NotificationConfig.fromEnvironment().useEnvelopeQuestionnaireUnlocked,
      logPrefix: 'QUESTIONNAIRE_UNLOCK',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
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
        'patient_id': participantId,
        'questionnaire_type': instanceResult.first[1] as String,
        'study_event': instanceResult.first[6] as String?,
        'previous_status': currentStatus,
        'new_status': 'sent',
        'unlocked_at': now.toIso8601String(),
        'unlocked_by_email': user.email,
        'unlocked_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
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
    labels: {'instance_id': instanceId, 'patient_id': participantId},
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': participantId,
    'status': 'sent',
    'unlocked_at': now.toIso8601String(),
  });
}

/// POST /api/v1/portal/questionnaire-instances/<instanceId>/finalize
///
/// Finalizes a questionnaire. Sets status to 'finalized', records score,
/// and logs the action.
///
/// Per REQ-CAL-p00023: Investigator finalizes a submitted questionnaire.
/// Score calculation is placeholder (deferred to questionnaire content sprint).
Future<Response> finalizeQuestionnaireHandler(
  Request request,
  String instanceId,
) async {
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

  // CUR-1064: patientId removed from URL; look it up from the instance and verify site access
  final instanceResult = await db.executeWithContext(
    '''
    SELECT qi.id, qi.questionnaire_type::text, qi.status::text, qi.patient_id,
           qi.deleted_at, p.site_id, qi.study_event
    FROM questionnaire_instances qi
    JOIN patients p ON p.patient_id = qi.patient_id
    WHERE qi.id = @instanceId::uuid
    ''',
    parameters: {'instanceId': instanceId},
    context: serviceContext,
  );

  if (instanceResult.isEmpty) {
    return _jsonResponse({'error': 'Questionnaire instance not found'}, 404);
  }

  final participantId = instanceResult.first[3] as String;
  final participantSiteId = instanceResult.first[5] as String;
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  logWithTrace(
    'INFO',
    'finalizeQuestionnaireHandler',
    labels: {'instance_id': instanceId, 'patient_id': participantId},
  );

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
  if (endEvent != null && !StudyEvent.isEndEvent(endEvent)) {
    return _jsonResponse({
      'error':
          'Invalid end_event. Must be "${StudyEvent.endOfTreatment}" '
          'or "${StudyEvent.endOfStudy}".',
    }, 400);
  }

  final now = DateTime.now().toUtc();

  // TODO(CUR-856): Replace with real scoring logic before EDC integration.
  // WARNING: This placeholder sends score=0 for all finalizations.
  // Do NOT consume this value downstream until scoring is implemented.
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

  // Notify the patient device that the questionnaire is locked.
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @participantId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchQuestionnairePush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      questionnaireInstanceId: instanceId,
      action: _QuestionnaireAction.finalized,
      useEnvelope: NotificationConfig.fromEnvironment()
          .useEnvelopeQuestionnaireFinalized,
      logPrefix: 'QUESTIONNAIRE_FINALIZE',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  }

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
        'patient_id': participantId,
        'questionnaire_type': instanceResult.first[1] as String,
        'study_event': instanceResult.first[6] as String?,
        'previous_status': currentStatus,
        'new_status': 'finalized',
        'end_event': endEvent,
        'score': score,
        'finalized_at': now.toIso8601String(),
        'finalized_by_email': user.email,
        'finalized_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': endEvent != null
          ? 'Questionnaire finalized as ${StudyEvent.endEventDisplayLabel(endEvent)}'
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
      'patient_id': participantId,
      'score': score.toString(),
      if (endEvent != null) 'end_event': endEvent,
    },
  );

  return _jsonResponse({
    'success': true,
    'instance_id': instanceId,
    'patient_id': participantId,
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
