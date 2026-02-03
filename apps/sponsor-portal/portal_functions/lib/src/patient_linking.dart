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
//
// Patient linking code handlers - generate and manage linking codes
// for patient mobile app enrollment

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'portal_auth.dart';

/// Expiration duration for linking codes (72 hours per REQ-p70007)
const linkingCodeExpiration = Duration(hours: 72);

/// Character set for linking codes (REQ-d00079.N)
/// Excludes visually ambiguous: I, 1, O, 0, S, 5, Z, 2
const _linkingCodeChars = 'ABCDEFGHJKLMNPQRTUVWXY346789';

/// Get the sponsor linking prefix from environment
String get sponsorLinkingPrefix =>
    Platform.environment['SPONSOR_LINKING_PREFIX'] ?? 'XX';

/// Generate a patient linking code
/// POST /api/v1/portal/patients/:patientId/link-code
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
Future<Response> generatePatientLinkingCodeHandler(
  Request request,
  String patientId,
) async {
  print('[PATIENT_LINKING] generatePatientLinkingCodeHandler for: $patientId');

  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can generate linking codes
  if (user.activeRole != 'Investigator') {
    print('[PATIENT_LINKING] User ${user.id} is not Investigator');
    return _jsonResponse({
      'error': 'Only Investigators can generate patient linking codes',
    }, 403);
  }

  // Parse optional reconnect_reason from request body
  String? reconnectReason;
  try {
    final body = await request.readAsString();
    if (body.isNotEmpty) {
      final requestData = jsonDecode(body) as Map<String, dynamic>;
      reconnectReason = requestData['reconnect_reason'] as String?;
    }
  } catch (_) {
    // Ignore parsing errors - body is optional
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Fetch patient and verify site access
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $patientId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final currentStatus = patientResult.first[2] as String;
  final siteName = patientResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $patientSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - cannot link if already connected
  if (currentStatus == 'connected') {
    print('[PATIENT_LINKING] Patient $patientId is already connected');
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
    parameters: {'patientId': patientId, 'userId': user.id},
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
        'targetResource': 'patient:$patientId',
        'actionDetails': jsonEncode({
          'patient_id': patientId,
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
  final code = generatePatientLinkingCode(sponsorLinkingPrefix);
  final codeHash = hashLinkingCode(code);
  final expiresAt = DateTime.now().toUtc().add(linkingCodeExpiration);

  print(
    '[PATIENT_LINKING] Generated code for patient: $patientId, expires: $expiresAt',
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
      'patientId': patientId,
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
    parameters: {'patientId': patientId},
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
      : 'Patient linking code generated for mobile app enrollment';

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
      'targetResource': 'patient:$patientId',
      'actionDetails': jsonEncode({
        'patient_id': patientId,
        'site_id': patientSiteId,
        'site_name': siteName,
        'expires_at': expiresAt.toIso8601String(),
        'generated_by_email': user.email,
        'generated_by_name': user.name,
        'previous_status': currentStatus,
        if (isReconnection) 'reconnect_reason': reconnectReason,
      }),
      'justification': justification,
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print('[PATIENT_LINKING] Code stored, status updated for: $patientId');

  return _jsonResponse({
    'success': true,
    'patient_id': patientId,
    'site_name': siteName,
    'code': formatLinkingCodeForDisplay(code),
    'code_raw': code,
    'expires_at': expiresAt.toIso8601String(),
    'expires_in_hours': linkingCodeExpiration.inHours,
  });
}

/// Get active linking code for patient (if any)
/// GET /api/v1/portal/patients/:patientId/link-code
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
Future<Response> getPatientLinkingCodeHandler(
  Request request,
  String patientId,
) async {
  print('[PATIENT_LINKING] getPatientLinkingCodeHandler for: $patientId');

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

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Fetch patient and verify site access
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text
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
  final currentStatus = patientResult.first[2] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
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
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (codeResult.isEmpty) {
    return _jsonResponse({
      'has_active_code': false,
      'patient_id': patientId,
      'mobile_linking_status': currentStatus,
    });
  }

  final code = codeResult.first[0] as String;
  final expiresAt = codeResult.first[1] as DateTime;
  final generatedAt = codeResult.first[2] as DateTime;

  return _jsonResponse({
    'has_active_code': true,
    'patient_id': patientId,
    'mobile_linking_status': currentStatus,
    'code': formatLinkingCodeForDisplay(code),
    'code_raw': code,
    'expires_at': expiresAt.toIso8601String(),
    'generated_at': generatedAt.toIso8601String(),
  });
}

/// Generate a patient linking code
/// Format: {SS}{XXXXXXXX} where SS is 2-char sponsor prefix (REQ-d00079.K)
String generatePatientLinkingCode(String sponsorPrefix) {
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
/// POST /api/v1/portal/patients/:patientId/disconnect
/// Authorization: Bearer <Identity Platform ID token>
/// Body: { "reason": "Device Issues" | "Technical Issues" | "Other", "notes": "..." }
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
Future<Response> disconnectPatientHandler(
  Request request,
  String patientId,
) async {
  print('[PATIENT_LINKING] disconnectPatientHandler for: $patientId');

  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can disconnect patients
  if (user.activeRole != 'Investigator') {
    print('[PATIENT_LINKING] User ${user.id} is not Investigator');
    return _jsonResponse({
      'error': 'Only Investigators can disconnect patients',
    }, 403);
  }

  // Parse request body
  String body;
  try {
    body = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = body.isNotEmpty
        ? jsonDecode(body) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

  // Validate reason field
  final reason = requestData['reason'] as String?;
  if (reason == null || reason.isEmpty) {
    return _jsonResponse({'error': 'Missing required field: reason'}, 400);
  }

  if (!validDisconnectReasons.contains(reason)) {
    return _jsonResponse({
      'error':
          'Invalid reason. Must be one of: ${validDisconnectReasons.join(", ")}',
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
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $patientId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final currentStatus = patientResult.first[2] as String;
  final siteName = patientResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $patientSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only disconnect if connected
  if (currentStatus != 'connected') {
    print(
      '[PATIENT_LINKING] Patient $patientId is not connected (status: $currentStatus)',
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
      'patientId': patientId,
      'userId': user.id,
      'revokeReason': 'Patient disconnected: $reason',
    },
    context: serviceContext,
  );

  final codesRevoked = revokeResult.length;
  print('[PATIENT_LINKING] Revoked $codesRevoked active codes for: $patientId');

  // Update patient status to 'disconnected'
  await db.executeWithContext(
    '''
    UPDATE patients
    SET mobile_linking_status = 'disconnected',
        updated_at = now()
    WHERE patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

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
      'targetResource': 'patient:$patientId',
      'actionDetails': jsonEncode({
        'patient_id': patientId,
        'site_id': patientSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'disconnected',
        'reason': reason,
        'notes': notes,
        'codes_revoked': codesRevoked,
        'disconnected_by_email': user.email,
        'disconnected_by_name': user.name,
      }),
      'justification': 'Patient disconnected from mobile app: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Patient disconnected successfully: $patientId, reason: $reason',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': patientId,
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
/// POST /api/v1/portal/patients/:patientId/not-participating
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
Future<Response> markPatientNotParticipatingHandler(
  Request request,
  String patientId,
) async {
  print('[PATIENT_LINKING] markPatientNotParticipatingHandler for: $patientId');

  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can mark patients as not participating
  if (user.activeRole != 'Investigator') {
    print('[PATIENT_LINKING] User ${user.id} is not Investigator');
    return _jsonResponse({
      'error': 'Only Investigators can mark patients as not participating',
    }, 403);
  }

  // Parse request body
  String body;
  try {
    body = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = body.isNotEmpty
        ? jsonDecode(body) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

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
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $patientId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final currentStatus = patientResult.first[2] as String;
  final siteName = patientResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $patientSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only mark as not participating if disconnected
  if (currentStatus != 'disconnected') {
    print(
      '[PATIENT_LINKING] Patient $patientId is not disconnected (status: $currentStatus)',
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
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

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
      'targetResource': 'patient:$patientId',
      'actionDetails': jsonEncode({
        'patient_id': patientId,
        'site_id': patientSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'not_participating',
        'reason': reason,
        'notes': notes,
        'marked_by_email': user.email,
        'marked_by_name': user.name,
      }),
      'justification': 'Patient marked as not participating: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print(
    '[PATIENT_LINKING] Patient marked as not participating: $patientId, reason: $reason',
  );

  return _jsonResponse({
    'success': true,
    'patient_id': patientId,
    'previous_status': currentStatus,
    'new_status': 'not_participating',
    'reason': reason,
  });
}

/// Reactivate a patient who was marked as not participating
/// POST /api/v1/portal/patients/:patientId/reactivate
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
Future<Response> reactivatePatientHandler(
  Request request,
  String patientId,
) async {
  print('[PATIENT_LINKING] reactivatePatientHandler for: $patientId');

  // Authenticate and get user
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Missing or invalid authorization'}, 401);
  }

  // Check role - only Investigators can reactivate patients
  if (user.activeRole != 'Investigator') {
    print('[PATIENT_LINKING] User ${user.id} is not Investigator');
    return _jsonResponse({
      'error': 'Only Investigators can reactivate patients',
    }, 403);
  }

  // Parse request body
  String body;
  try {
    body = await request.readAsString();
  } catch (e) {
    return _jsonResponse({'error': 'Failed to read request body'}, 400);
  }

  Map<String, dynamic> requestData;
  try {
    requestData = body.isNotEmpty
        ? jsonDecode(body) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON in request body'}, 400);
  }

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
  final patientResult = await db.executeWithContext(
    '''
    SELECT p.patient_id, p.site_id, p.mobile_linking_status::text, s.site_name
    FROM patients p
    JOIN sites s ON p.site_id = s.site_id
    WHERE p.patient_id = @patientId
    ''',
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

  if (patientResult.isEmpty) {
    print('[PATIENT_LINKING] Patient not found: $patientId');
    return _jsonResponse({'error': 'Patient not found'}, 404);
  }

  final patientSiteId = patientResult.first[1] as String;
  final currentStatus = patientResult.first[2] as String;
  final siteName = patientResult.first[3] as String;

  // Verify Investigator has access to this patient's site
  final userSiteIds = user.sites.map((s) => s['site_id'] as String).toList();
  if (!userSiteIds.contains(patientSiteId)) {
    print(
      '[PATIENT_LINKING] User ${user.id} has no access to site $patientSiteId',
    );
    return _jsonResponse({
      'error': 'You do not have access to patients at this site',
    }, 403);
  }

  // Check patient status - can only reactivate if not_participating
  if (currentStatus != 'not_participating') {
    print(
      '[PATIENT_LINKING] Patient $patientId is not "not_participating" (status: $currentStatus)',
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
    parameters: {'patientId': patientId},
    context: serviceContext,
  );

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
      'targetResource': 'patient:$patientId',
      'actionDetails': jsonEncode({
        'patient_id': patientId,
        'site_id': patientSiteId,
        'site_name': siteName,
        'previous_status': currentStatus,
        'new_status': 'disconnected',
        'reason': reason,
        'reactivated_by_email': user.email,
        'reactivated_by_name': user.name,
      }),
      'justification': 'Patient reactivated: $reason',
      'ipAddress': clientIp,
    },
    context: serviceContext,
  );

  print('[PATIENT_LINKING] Patient reactivated: $patientId, reason: $reason');

  return _jsonResponse({
    'success': true,
    'patient_id': patientId,
    'previous_status': currentStatus,
    'new_status': 'disconnected',
    'reason': reason,
  });
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
