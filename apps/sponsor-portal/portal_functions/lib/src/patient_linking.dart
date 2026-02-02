// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-p70009: Link New Patient Workflow
//   REQ-d00078: Linking Code Validation
//   REQ-d00079: Linking Code Pattern Matching
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00073: Patient Status Definitions
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
///
/// Generates a new linking code for the patient.
/// - Requires Investigator role with site access to patient's site
/// - Invalidates any existing unused codes for this patient
/// - Updates patient status to 'linking_in_progress'
/// - Returns the code for display (shown only once)
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

  // Log to admin_action_log for audit trail (CUR-690)
  await db.executeWithContext(
    '''
    INSERT INTO admin_action_log (
      admin_id, action_type, target_resource, action_details,
      justification, requires_review, ip_address
    )
    VALUES (
      @adminId, 'GENERATE_LINKING_CODE', @targetResource,
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
        'expires_at': expiresAt.toIso8601String(),
        'generated_by_email': user.email,
        'generated_by_name': user.name,
      }),
      'justification':
          'Patient linking code generated for mobile app enrollment',
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

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
