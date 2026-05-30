// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-p70009: Link New Patient Workflow
//   REQ-d00078: Linking Code Validation
//   REQ-d00079: Linking Code Pattern Matching
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00022: Analyst Read-Only Site-Scoped Access
//
// Patient linking code handlers - generate and manage linking codes
// for patient mobile app linking

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:comms/comms.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'notification_service.dart';
import 'portal_auth.dart';
import 'sponsor.dart';

/// Expiration duration for linking codes (72 hours per REQ-p70007)
const linkingCodeExpiration = Duration(hours: 72);

/// Character set for linking codes (REQ-d00079.N)
/// Excludes visually ambiguous: I, 1, O, 0, S, 5, Z, 2
const _linkingCodeChars = 'ABCDEFGHJKLMNPQRTUVWXY346789';

/// Get the sponsor linking prefix from environment
String get sponsorLinkingPrefix =>
    Platform.environment['SPONSOR_LINKING_PREFIX'] ?? 'XX';

/// CUR-1311 (Phase 1B.2/3): outcome of a patient-status push dispatch.
/// Carries both ids so the action's audit row can record cross-table
/// traceability — `fcm_message_id` for legacy compatibility,
/// `notification_id` for the new envelope row when the flag is on.
typedef _StatusPushResult = ({String? fcmMessageId, String? notificationId});

/// CUR-1311 (Phase 1B.2/3): unified send path for the
/// `patient_status_update` family of notifications. Branches on the
/// per-handler envelope flag — flag-OFF preserves S2 behaviour;
/// flag-ON persists a row in `notifications` before FCM dispatch and
/// returns the envelope id so the caller can surface it in
/// `admin_action_log`.
///
/// Caller responsibilities:
///   * Resolve [fcmToken] from `patient_fcm_tokens` (this helper does
///     not look it up — letting the caller short-circuit when the
///     patient has no active token).
///   * Pick the per-handler [useEnvelope] flag (e.g.
///     `NotificationConfig.fromEnvironment().useEnvelopeDisconnect`).
///   * Pass [logPrefix] used for both the legacy log line and the
///     envelope-path log line — keeps grep-friendly continuity.
///   * Pass any action-specific payload entries via [extraPayload] —
///     `new_status` for status transitions, `trial_started_at` for
///     start_trial, etc. The helper merges them with `action`.
///
/// Returns null fields when there is no token (caller should not call
/// this in that case) — defensive default if the helper is invoked.
Future<_StatusPushResult> _dispatchParticipantStatusPush({
  required String fcmToken,
  required String participantId,
  required String action,
  required String title,
  required String body,
  required Map<String, dynamic> extraPayload,
  required bool useEnvelope,
  required String logPrefix,
}) async {
  if (useEnvelope) {
    final outboxWriter = NotificationService.outboxWriter;
    if (outboxWriter != null) {
      final envelope = Envelope(
        notificationId: const Uuid().v4(),
        participantId: participantId,
        type: NotificationType.participantStatusUpdate,
        title: title,
        body: body,
        userVisible: true,
        payload: <String, dynamic>{'action': action, ...extraPayload},
        status: EnvelopeStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      try {
        final notificationId = await outboxWriter.send(
          envelope,
          fcmToken: fcmToken,
        );
        // Look up the persisted message_id for the legacy audit field
        // — the row already has it after OutboxWriter.markSent / markFailed.
        final stored = await outboxWriter.repo.findById(
          notificationId,
          participantId: participantId,
        );
        if (stored?.status == EnvelopeStatus.failed) {
          print(
            '[$logPrefix] Envelope dispatch failed for $action: ${stored?.error}',
          );
        }
        return (
          fcmMessageId: stored?.messageId,
          notificationId: notificationId,
        );
      } on PhiLeakException catch (e) {
        // Action succeeds without a push; polling reconciles on the
        // next cycle. Log so ops can investigate the leak source.
        print('[$logPrefix] PHI guard rejected $action envelope: $e');
        return (fcmMessageId: null, notificationId: null);
      }
    }
    // Writer not initialised — fall through to the legacy path so a
    // misconfigured rollout never silently drops the notification.
    print(
      '[$logPrefix] OutboxWriter not initialised; falling back to legacy FCM for $action',
    );
  }

  // Legacy direct-FCM path (S2 behaviour). FCM data values must be
  // strings on the wire — coerce non-string entries here rather than
  // burdening every caller.
  final extraData = <String, String>{
    for (final entry in extraPayload.entries) entry.key: entry.value.toString(),
  };
  final result = await NotificationService.instance
      .sendPatientStatusNotification(
        fcmToken: fcmToken,
        patientId: participantId,
        action: action,
        title: title,
        body: body,
        extraData: extraData,
      );
  if (!result.success) {
    print('[$logPrefix] FCM send failed for $action: ${result.error}');
  }
  return (fcmMessageId: result.messageId, notificationId: null);
}

/// Generate a patient linking code
/// POST /api/v1/portal/participants/link-code (participantId in body, CUR-1064)
/// Authorization: Bearer <Identity Platform ID token>
/// Body (optional): { "reconnect_reason": "..." } for reconnecting disconnected patients
///
/// Generates a new linking code for the patient.
/// - Requires Investigator role with site access to patient's site
/// - Invalidates any existing unused codes for this patient
/// - Updates patient status to 'linking_in_progress'
/// - Returns the code for display (shown only once)
/// - If reconnect_reason is provided for a disconnected patient, logs RECONNECT_PATIENT action
///
/// Returns:
///   200: { "code": "CAXXXX-XXXXX", "code_raw": "CAXXXXXXXX", "expires_at": "...", "patient_id": "..." }
///   401: Missing or invalid authorization
///   403: Unauthorized (not Investigator role or wrong site)
///   404: Patient not found
///   409: Patient already connected
Future<Response> generateParticipantLinkingCodeHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can generate linking codes
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can generate patient linking codes',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to request body
  Map<String, dynamic> requestData;
  try {
    final bodyStr = await request.readAsString();
    requestData = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (_) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final participantId = requestData['patientId'] as String?;
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing patientId in request body'}, 400);
  }
  final reconnectReason = requestData['reconnect_reason'] as String?;

  print(
    '[PATIENT_LINKING] generateParticipantLinkingCodeHandler for: $participantId',
  );

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $participantId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;
  final siteName = participantResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $participantSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - cannot link if already connected
  if (currentStatus == 'connected') {
    print('[PATIENT_LINKING] Patient $participantId is already connected');
    return _jsonResponse({
      'error':
          'Patient is already connected. Use "New Code" to generate a replacement code.',
    }, 409);
  }

  // Invalidate any existing unused codes for this patient
  final revokeResult = await db.executeWithContext(
    '''
    UPDATE patient_linking_codes
    SET revoked_at = now(),
        revoked_by = @userId::uuid,
        revoke_reason = 'Superseded by new code'
    WHERE patient_id = @patientId
      AND used_at IS NULL
      AND revoked_at IS NULL
      AND expires_at > now()
    RETURNING id
    ''',
    parameters: {'patientId': participantId, 'userId': user.id},
    context: serviceContext,
  );

  // Log revocation if any codes were superseded
  if (revokeResult.isNotEmpty) {
    await db.executeWithContext(
      '''
      INSERT INTO admin_action_log (
        admin_id, action_type, target_resource, action_details,
        justification, requires_review, ip_address
      )
      VALUES (
        @adminId, 'REVOKE_LINKING_CODE', @targetResource,
        @actionDetails::jsonb, @justification, false, @ipAddress::inet
      )
      ''',
      parameters: {
        'adminId': user.id,
        'targetResource': 'patient:$participantId',
        'actionDetails': jsonEncode({
          'patient_id': participantId,
          'revoked_code_count': revokeResult.length,
          'reason': 'Superseded by new code',
          'revoked_by_email': user.email,
        }),
        'justification':
            'Previous linking code(s) revoked - superseded by new code',
        'ipAddress': clientIp,
      },
      context: serviceContext,
    );
  }

  // Generate new code
  final code = generateParticipantLinkingCode(sponsorLinkingPrefix);
  final codeHash = hashLinkingCode(code);
  final expiresAt = DateTime.now().toUtc().add(linkingCodeExpiration);

  print(
    '[PATIENT_LINKING] Generated code for patient: $participantId, expires: $expiresAt',
  );

  // Store the code
  await db.executeWithContext(
    '''
    INSERT INTO patient_linking_codes (
      patient_id, code, code_hash, generated_by, expires_at, ip_address
    )
    VALUES (
      @patientId, @code, @codeHash, @generatedBy::uuid, @expiresAt, @ipAddress::inet
    )
    ''',
    parameters: {
      'patientId': participantId,
      'code': code,
      'codeHash': codeHash,
      'generatedBy': user.id,
      'expiresAt': expiresAt.toIso8601String(),
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  // Update patient status to 'linking_in_progress'
  await db.executeWithContext(
    '''
    UPDATE patients
    SET mobile_linking_status = 'linking_in_progress',
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  // Determine if this is a reconnection (disconnected patient with reason provided)
  final isReconnection =
      currentStatus == 'disconnected' &&
      reconnectReason != null &&
      reconnectReason.isNotEmpty;
  final actionType = isReconnection
      ? 'RECONNECT_PATIENT'
      : 'GENERATE_LINKING_CODE';
  final justification = isReconnection
      ? 'Patient reconnected to mobile app: $reconnectReason'
      : 'Patient linking code generated for mobile app linking';

  // On reconnect, notify the device that a new linking code is available.
  // Only fires when isReconnection — initial GENERATE_LINKING_CODE is for
  // patients who don't yet have the app installed.
  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (isReconnection) {
    final fcmTokenResult = await db.executeWithContext(
      '''
      SELECT fcm_token FROM patient_fcm_tokens
      WHERE patient_id = @patientId AND is_active = true
      ORDER BY updated_at DESC
      LIMIT 1
      ''',
      parameters: {'patientId': participantId},
      context: serviceContext,
    );

    if (fcmTokenResult.isNotEmpty) {
      final pushResult = await _dispatchParticipantStatusPush(
        fcmToken: fcmTokenResult.first[0] as String,
        participantId: participantId,
        action: 'reconnect',
        title: 'Reconnect to Study',
        body:
            'Your study coordinator has issued a new linking code. Open the app to reconnect.',
        extraPayload: const {'new_status': 'linking_in_progress'},
        useEnvelope: NotificationConfig.fromEnvironment().useEnvelopeReconnect,
        logPrefix: 'PATIENT_LINKING',
      );
      fcmMessageId = pushResult.fcmMessageId;
      notificationEnvelopeId = pushResult.notificationId;
    } else {
      print(
        '[PATIENT_LINKING] No active FCM token for $participantId; skipping reconnect push',
      );
    }
  }

  // Log to admin_action_log for audit trail (CUR-690)
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, @actionType, @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'actionType': actionType,
      'targetResource': 'patient:$participantId',
      'actionDetails': jsonEncode({
        'patient_id': participantId,
        'site_id': participantSiteId,
        'site_name': siteName,
        'expires_at': expiresAt.toIso8601String(),
        'generated_by_email': user.email,
        'generated_by_name': user.name,
        'previous_status': currentStatus,
        if (isReconnection) 'reconnect_reason': reconnectReason,
        if (isReconnection) 'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': justification,
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print('[PATIENT_LINKING] Code stored, status updated for: $participantId');

  return _jsonResponse({
    'success': true,
    'patient_id': participantId,
    'site_name': siteName,
    'code': formatLinkingCodeForDisplay(code),
    'code_raw': code,
    'expires_at': expiresAt.toIso8601String(),
    'expires_in_hours': linkingCodeExpiration.inHours,
  });
}

/// Get active linking code for patient (if any)
/// GET /api/v1/portal/participants/link-code/active (X-Patient-Id header, CUR-1064)
///
/// Returns the current active (unused, not expired, not revoked) linking code.
/// Per REQ-p70007.J, the code should only be displayed once at generation,
/// but this endpoint allows showing the code again (e.g., "Show Code" button).
///
/// Returns:
///   200: { "has_active_code": true, "code": "...", "expires_at": "..." }
///   200: { "has_active_code": false }
///   401: Missing or invalid authorization
///   403: Unauthorized
///   404: Patient not found
Future<Response> getParticipantLinkingCodeHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can view linking codes
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can view patient linking codes',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to X-Patient-Id header (GET request)
  final participantId = request.headers['x-patient-id'];
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing X-Patient-Id header'}, 400);
  }

  print(
    '[PATIENT_LINKING] getParticipantLinkingCodeHandler for: $participantId',
  );

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text
    FROM patients p
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Get active linking code
  final codeResult = await db.executeWithContext(
    '''
    SELECT code, expires_at, generated_at
    FROM patient_linking_codes
    WHERE patient_id = @patientId
      AND used_at IS NULL
      AND revoked_at IS NULL
      AND expires_at > now()
    ORDER BY generated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (codeResult.isEmpty) {
    // CUR-1069: Also return the most recently used code for Participant Linking Code
    // reference display (GUI-CAL-p00001-I). The plain code is stored in
    // patient_linking_codes.code so it can be shown for reference/troubleshooting.
    final usedCodeResult = await db.executeWithContext(
      '''
      SELECT code, used_at
      FROM patient_linking_codes
      WHERE patient_id = @patientId
        AND used_at IS NOT NULL
      ORDER BY used_at DESC
      LIMIT 1
      ''',
      parameters: {'patientId': participantId},
      context: serviceContext,
    );

    if (usedCodeResult.isNotEmpty) {
      final usedCode = usedCodeResult.first[0] as String;
      final usedAt = usedCodeResult.first[1] as DateTime;
      return _jsonResponse({
        'has_active_code': false,
        'patient_id': participantId,
        'mobile_linking_status': currentStatus,
        'used_code': formatLinkingCodeForDisplay(usedCode),
        'used_at': usedAt.toIso8601String(),
      });
    }

    return _jsonResponse({
      'has_active_code': false,
      'patient_id': participantId,
      'mobile_linking_status': currentStatus,
    });
  }

  final code = codeResult.first[0] as String;
  final expiresAt = codeResult.first[1] as DateTime;
  final generatedAt = codeResult.first[2] as DateTime;

  return _jsonResponse({
    'has_active_code': true,
    'patient_id': participantId,
    'mobile_linking_status': currentStatus,
    'code': formatLinkingCodeForDisplay(code),
    'code_raw': code,
    'expires_at': expiresAt.toIso8601String(),
    'generated_at': generatedAt.toIso8601String(),
  });
}

/// Generate a patient linking code
/// Format: {SS}{XXXXXXXX} where SS is 2-char sponsor prefix (REQ-d00079.K)
String generateParticipantLinkingCode(String sponsorPrefix) {
  final random = Random.secure();
  final randomPart = List.generate(
    8,
    (_) => _linkingCodeChars[random.nextInt(_linkingCodeChars.length)],
  ).join();
  return '$sponsorPrefix$randomPart';
}

/// Format code for display: {SS}{XXX}-{XXXXX} (REQ-d00079.L)
/// The dash is for readability only, not stored
String formatLinkingCodeForDisplay(String code) {
  if (code.length != 10) return code;
  return '${code.substring(0, 5)}-${code.substring(5)}';
}

/// Hash a linking code using SHA-256 for secure validation
String hashLinkingCode(String code) {
  final bytes = utf8.encode(code);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Valid disconnect reasons per CUR-768 specification
const validDisconnectReasons = ['Device Issues', 'Technical Issues', 'Other'];

/// Disconnect a patient from the mobile app
/// POST /api/v1/portal/participants/disconnect (participantId in body, CUR-1064)
/// Authorization: Bearer <Identity Platform ID token>
/// Body: { "reason": "Device Issues" | "Technical Issues" | "Other" }
///   When sponsor config disconnectReasonDropdown=false: reason may be any non-empty string.
///
/// Disconnects a connected patient:
/// - Requires Investigator role with site access to patient's site
/// - Patient must be in 'connected' status
/// - Revokes all active linking codes
/// - Updates patient status to 'disconnected'
/// - Logs action to admin_action_log
///
/// Returns:
///   200: { "success": true, "patient_id": "...", "previous_status": "connected", "new_status": "disconnected", ... }
///   400: Invalid or missing reason value
///   401: Missing or invalid authorization
///   403: Unauthorized (not Investigator role or wrong site)
///   404: Patient not found
///   409: Patient is not in 'connected' status
Future<Response> disconnectParticipantHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can disconnect patients
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can disconnect patients',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to request body
  String bodyStr;
  try {
    bodyStr = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final participantId = requestData['patientId'] as String?;
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing patientId in request body'}, 400);
  }

  print('[PATIENT_LINKING] disconnectParticipantHandler for: $participantId');

  // Validate reason field
  final reason = requestData['reason'] as String?;
  if (reason == null || reason.isEmpty) {
    return _jsonResponse({'error': 'Missing required field: reason'}, 400);
  }

  final sponsorFlags = getCurrentSponsorFlags();
  if (sponsorFlags.disconnectReasonDropdown) {
    if (!validDisconnectReasons.contains(reason)) {
      return _jsonResponse({
        'error':
            'Invalid reason. Must be one of: ${validDisconnectReasons.join(", ")}',
      }, 400);
    }
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $participantId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;
  final siteName = participantResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $participantSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only disconnect if connected
  if (currentStatus != 'connected') {
    print(
      '[PATIENT_LINKING] Patient $participantId is not connected (status: $currentStatus)',
    );
    return _jsonResponse({
      'error':
          'Patient is not in "connected" status. Current status: $currentStatus',
    }, 409);
  }

  // Revoke all active linking codes with reason "Patient disconnected"
  final revokeResult = await db.executeWithContext(
    '''
    UPDATE patient_linking_codes
    SET revoked_at = now(),
        revoked_by = @userId::uuid,
        revoke_reason = @revokeReason
    WHERE patient_id = @patientId
      AND used_at IS NULL
      AND revoked_at IS NULL
      AND expires_at > now()
    RETURNING id
    ''',
    parameters: {
      'patientId': participantId,
      'userId': user.id,
      'revokeReason': 'Patient disconnected: $reason',
    },
    context: serviceContext,
  );

  final codesRevoked = revokeResult.length;
  print(
    '[PATIENT_LINKING] Revoked $codesRevoked active codes for: $participantId',
  );

  // Update patient status to 'disconnected'
  await db.executeWithContext(
    '''
    UPDATE patients
    SET mobile_linking_status = 'disconnected',
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  // Notify the patient device that the account has been disconnected.
  // fcm_message_id is captured into the audit row below for traceability.
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchParticipantStatusPush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      action: 'disconnect',
      title: 'Account Disconnected',
      body:
          'Your study account has been disconnected. Please contact your study coordinator.',
      extraPayload: const {'new_status': 'disconnected'},
      useEnvelope: NotificationConfig.fromEnvironment().useEnvelopeDisconnect,
      logPrefix: 'PATIENT_LINKING',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  } else {
    print(
      '[PATIENT_LINKING] No active FCM token for $participantId; skipping disconnect push',
    );
  }

  // Log to admin_action_log for audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'DISCONNECT_PATIENT', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'patient:$participantId',
      'actionDetails': jsonEncode({
        'patient_id': participantId,
        'site_id': participantSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'disconnected',
        'reason': reason,
        'codes_revoked': codesRevoked,
        'disconnected_by_email': user.email,
        'disconnected_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': 'Patient disconnected from mobile app: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Patient disconnected successfully: $participantId, reason: $reason',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': participantId,
    'previous_status': currentStatus,
    'new_status': 'disconnected',
    'codes_revoked': codesRevoked,
    'reason': reason,
  });
}

/// Valid reasons for marking patient as not participating per CUR-770 specification
const validNotParticipatingReasons = [
  'Subject Withdrawal',
  'Death',
  'Protocol treatment/study complete',
  'Other',
];

/// Mark a patient as not participating in the study
/// POST /api/v1/portal/participants/not-participating (participantId in body, CUR-1064)
/// Authorization: Bearer <Identity Platform ID token>
/// Body: { "reason": "Subject Withdrawal" | "Death" | "Protocol treatment/study complete" | "Other", "notes": "..." }
///
/// Marks a disconnected patient as not participating:
/// - Requires Investigator role with site access to patient's site
/// - Patient must be in 'disconnected' status
/// - Updates patient status to 'not_participating'
/// - Logs action to admin_action_log
///
/// Returns:
///   200: { "success": true, "patient_id": "...", "previous_status": "disconnected", "new_status": "not_participating", ... }
///   400: Invalid or missing reason value
///   401: Missing or invalid authorization
///   403: Unauthorized (not Investigator role or wrong site)
///   404: Patient not found
///   409: Patient is not in 'disconnected' status
Future<Response> markParticipantNotParticipatingHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can mark patients as not participating
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can mark patients as not participating',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to request body
  String bodyStr;
  try {
    bodyStr = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final participantId = requestData['patientId'] as String?;
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing patientId in request body'}, 400);
  }

  print(
    '[PATIENT_LINKING] markParticipantNotParticipatingHandler for: $participantId',
  );

  // Validate reason field
  final reason = requestData['reason'] as String?;
  if (reason == null || reason.isEmpty) {
    return _jsonResponse({'error': 'Missing required field: reason'}, 400);
  }

  if (!validNotParticipatingReasons.contains(reason)) {
    return _jsonResponse({
      'error':
          'Invalid reason. Must be one of: ${validNotParticipatingReasons.join(", ")}',
    }, 400);
  }

  // If reason is "Other", notes are required
  final notes = requestData['notes'] as String?;
  if (reason == 'Other' && (notes == null || notes.trim().isEmpty)) {
    return _jsonResponse({
      'error': 'Notes are required when reason is "Other"',
    }, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $participantId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;
  final siteName = participantResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $participantSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only mark as not participating if disconnected
  if (currentStatus != 'disconnected') {
    print(
      '[PATIENT_LINKING] Patient $participantId is not disconnected (status: $currentStatus)',
    );
    return _jsonResponse({
      'error':
          'Patient must be in "disconnected" status. Current status: $currentStatus',
    }, 409);
  }

  // Update patient status to 'not_participating'
  await db.executeWithContext(
    '''
    UPDATE patients
    SET mobile_linking_status = 'not_participating',
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  // Notify the patient device that participation has ended.
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchParticipantStatusPush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      action: 'mark_not_participating',
      title: 'Study Participation Ended',
      body:
          'Your study participation has ended. Please contact your study coordinator if you have questions.',
      extraPayload: const {'new_status': 'not_participating'},
      useEnvelope:
          NotificationConfig.fromEnvironment().useEnvelopeNotParticipating,
      logPrefix: 'PATIENT_LINKING',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  } else {
    print(
      '[PATIENT_LINKING] No active FCM token for $participantId; skipping not-participating push',
    );
  }

  // Log to admin_action_log for audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'MARK_NOT_PARTICIPATING', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'patient:$participantId',
      'actionDetails': jsonEncode({
        'patient_id': participantId,
        'site_id': participantSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'not_participating',
        'reason': reason,
        'notes': notes,
        'marked_by_email': user.email,
        'marked_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': 'Patient marked as not participating: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Patient marked as not participating: $participantId, reason: $reason',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': participantId,
    'previous_status': currentStatus,
    'new_status': 'not_participating',
    'reason': reason,
  });
}

/// Reactivate a patient who was marked as not participating
/// POST /api/v1/portal/participants/reactivate (participantId in body, CUR-1064)
/// Authorization: Bearer <Identity Platform ID token>
/// Body: { "reason": "..." }
///
/// Reactivates a patient who was marked as not participating:
/// - Requires Investigator role with site access to patient's site
/// - Patient must be in 'not_participating' status
/// - Updates patient status to 'disconnected' (requires reconnection)
/// - Logs action to admin_action_log
///
/// Returns:
///   200: { "success": true, "patient_id": "...", "previous_status": "not_participating", "new_status": "disconnected", ... }
///   400: Invalid or missing reason value
///   401: Missing or invalid authorization
///   403: Unauthorized (not Investigator role or wrong site)
///   404: Patient not found
///   409: Patient is not in 'not_participating' status
Future<Response> reactivateParticipantHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can reactivate patients
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can reactivate patients',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to request body
  String bodyStr;
  try {
    bodyStr = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  final participantId = requestData['patientId'] as String?;
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing patientId in request body'}, 400);
  }

  print('[PATIENT_LINKING] reactivateParticipantHandler for: $participantId');

  // Validate reason field
  final reason = requestData['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    return _jsonResponse({'error': 'Missing required field: reason'}, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $participantId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;
  final siteName = participantResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $participantSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only reactivate if not_participating
  if (currentStatus != 'not_participating') {
    print(
      '[PATIENT_LINKING] Patient $participantId is not "not_participating" (status: $currentStatus)',
    );
    return _jsonResponse({
      'error':
          'Patient must be in "not_participating" status. Current status: $currentStatus',
    }, 409);
  }

  // Update patient status to 'disconnected' (they will need to reconnect)
  await db.executeWithContext(
    '''
    UPDATE patients
    SET mobile_linking_status = 'disconnected',
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  // Notify the patient device that their account is reactivated.
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  String? fcmMessageId;
  String? notificationEnvelopeId;
  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchParticipantStatusPush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      action: 'reactivate',
      title: 'Account Reactivated',
      body:
          'Your study account has been reactivated. Please contact your study coordinator to reconnect.',
      extraPayload: const {'new_status': 'disconnected'},
      useEnvelope: NotificationConfig.fromEnvironment().useEnvelopeReactivate,
      logPrefix: 'PATIENT_LINKING',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  } else {
    print(
      '[PATIENT_LINKING] No active FCM token for $participantId; skipping reactivate push',
    );
  }

  // Log to admin_action_log for audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'REACTIVATE_PATIENT', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'patient:$participantId',
      'actionDetails': jsonEncode({
        'patient_id': participantId,
        'site_id': participantSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'disconnected',
        'reason': reason,
        'reactivated_by_email': user.email,
        'reactivated_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': 'Patient reactivated: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Patient reactivated: $participantId, reason: $reason',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': participantId,
    'previous_status': currentStatus,
    'new_status': 'disconnected',
    'reason': reason,
  });
}

/// Start trial for a patient
/// POST /api/v1/portal/participants/start-trial (participantId in body, CUR-1064)
/// Authorization: Bearer <Identity Platform ID token>
/// Body: {} (empty body)
///
/// Starts the trial for a connected patient who hasn't started yet:
/// - Requires Investigator role with site access to patient's site
/// - Patient must be in 'connected' status with trial_started = false
/// - Updates patient: trial_started = true, trial_started_at, trial_started_by
/// - Logs action to admin_action_log with START_TRIAL
///
/// Returns:
///   200: { "success": true, "patient_id": "...", "trial_started": true, ... }
///   401: Missing or invalid authorization
///   403: Unauthorized (not Investigator role or wrong site)
///   404: Patient not found
///   409: Patient is not in 'connected' status OR trial already started
Future<Response> startTrialHandler(Request request) async {
  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can start trial
  if (user.activeRole != 'Investigator') {
    return _jsonResponse({
      'error': 'Only Investigators can start trial for patients',
    }, 403);
  }

  // CUR-1064: participantId moved from URL path to request body
  String? participantId;
  try {
    final bodyStr = await request.readAsString();
    final bodyJson = bodyStr.isNotEmpty
        ? jsonDecode(bodyStr) as Map<String, dynamic>
        : <String, dynamic>{};
    participantId = bodyJson['patientId'] as String?;
  } catch (_) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }
  if (participantId == null || participantId.isEmpty) {
    return _jsonResponse({'error': 'Missing patientId in request body'}, 400);
  }

  print('[PATIENT_LINKING] startTrialHandler for: $participantId');

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final participantResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text,
           p.trial_started, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (participantResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $participantId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final participantSiteId = participantResult.first[1] as String;
  final currentStatus = participantResult.first[2] as String;
  final trialStarted = participantResult.first[3] as bool;
  final siteName = participantResult.first[4] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(participantSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $participantSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - must be connected to start trial
  if (currentStatus != 'connected') {
    print(
      '[PATIENT_LINKING] Patient $participantId is not connected (status: $currentStatus)',
    );
    return _jsonResponse({
      'error':
          'Patient must be in "connected" status to start trial. Current status: $currentStatus',
    }, 409);
  }

  // Check if trial already started
  if (trialStarted) {
    print(
      '[PATIENT_LINKING] Trial already started for patient: $participantId',
    );
    return _jsonResponse({
      'error': 'Trial has already been started for this patient',
    }, 409);
  }

  final now = DateTime.now().toUtc();

  // Update patient: trial_started = true
  await db.executeWithContext(
    '''
    UPDATE patients
    SET trial_started = true,
        trial_started_at = @trialStartedAt,
        trial_started_by = @trialStartedBy,
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {
      'patientId': participantId,
      'trialStartedAt': now.toIso8601String(),
      'trialStartedBy': user.id,
    },
    context: serviceContext,
  );

  // Send FCM notification to patient's device to inform trial has started.
  // Use the patient_status_update channel (not questionnaire) so the mobile
  // app can sub-route on action='start_trial'. No patient identifier is
  // included in the FCM payload — the device already knows which patient
  // it belongs to.
  String? fcmMessageId;
  String? notificationEnvelopeId;
  final fcmTokenResult = await db.executeWithContext(
    '''
    SELECT fcm_token FROM patient_fcm_tokens
    WHERE patient_id = @patientId AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1
    ''',
    parameters: {'patientId': participantId},
    context: serviceContext,
  );

  if (fcmTokenResult.isNotEmpty) {
    final pushResult = await _dispatchParticipantStatusPush(
      fcmToken: fcmTokenResult.first[0] as String,
      participantId: participantId,
      action: 'start_trial',
      title: 'Trial Started',
      body: 'Your study has started. Open the app to begin.',
      extraPayload: {'trial_started_at': now.toIso8601String()},
      useEnvelope: NotificationConfig.fromEnvironment().useEnvelopeStartTrial,
      logPrefix: 'PATIENT_LINKING',
    );
    fcmMessageId = pushResult.fcmMessageId;
    notificationEnvelopeId = pushResult.notificationId;
  } else {
    print(
      '[PATIENT_LINKING] No FCM token found for patient $participantId. '
      'Patient will discover trial start via sync.',
    );
  }

  // Log to admin_action_log for audit trail
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'START_TRIAL', @targetResource,
      @actionDetails::jsonb, @justification, false, @ipAddress::inet
    )
    ''',
    parameters: {
      'adminId': user.id,
      'targetResource': 'patient:$participantId',
      'actionDetails': jsonEncode({
        'patient_id': participantId,
        'site_id': participantSiteId,
        'site_name': siteName,
        'trial_started_at': now.toIso8601String(),
        'started_by_email': user.email,
        'started_by_name': user.name,
        'fcm_message_id': fcmMessageId,
        if (notificationEnvelopeId != null)
          'notification_id': notificationEnvelopeId,
      }),
      'justification': 'Trial started for patient',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Trial started successfully for patient: $participantId',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': participantId,
    'site_id': participantSiteId,
    'site_name': siteName,
    'trial_started': true,
    'trial_started_at': now.toIso8601String(),
  });
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
