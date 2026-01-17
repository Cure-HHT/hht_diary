// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Portal activation handlers - validate and process activation codes
// for new user account setup
//
// Conditional MFA behavior:
// - Developer Admin: requires TOTP (authenticator app) enrollment
// - All other roles: uses email OTP on every login (no TOTP enrollment)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'email_service.dart';
import 'feature_flags.dart';
import 'identity_platform.dart';

/// Validate an activation code (unauthenticated endpoint)
/// GET /api/v1/portal/activate/:code
///
/// Returns masked email if code is valid and not expired.
/// Used by frontend to display activation form.
Future<Response> validateActivationCodeHandler(
  Request request,
  String code,
) async {
  print('[ACTIVATION] Validating code: ${code.substring(0, 5)}...');

  final db = Database.instance;

  // Use service context since this is unauthenticated
  const serviceContext = UserContext.service;

  final result = await db.executeWithContext(
    '''
    SELECT id, email, name, status, activation_code_expires_at
    FROM portal_users
    WHERE activation_code = @code
    ''',
    parameters: {'code': code},
    context: serviceContext,
  );

  if (result.isEmpty) {
    print('[ACTIVATION] Code not found');
    return _jsonResponse({'error': 'Invalid activation code'}, 401);
  }

  final row = result.first;
  final email = row[1] as String;
  final status = row[3] as String;
  final expiresAt = row[4] as DateTime?;

  // Check if already activated
  if (status == 'active') {
    print('[ACTIVATION] Account already activated');
    return _jsonResponse({'error': 'Account already activated'}, 400);
  }

  // Check expiration
  if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
    print('[ACTIVATION] Code expired');
    return _jsonResponse({'error': 'Activation code has expired'}, 401);
  }

  // Mask email for display (show first 2 chars + domain)
  final atIndex = email.indexOf('@');
  final maskedEmail = atIndex > 2
      ? '${email.substring(0, 2)}***${email.substring(atIndex)}'
      : '***${email.substring(atIndex)}';

  print('[ACTIVATION] Code valid for: $maskedEmail');

  return _jsonResponse({'valid': true, 'email': maskedEmail});
}

/// Activate user account with code and GCP Idenity Provider token
/// POST /api/v1/portal/activate
/// Authorization: Bearer <GCP Idenity Provider ID token>
/// Body: { code: "XXXXX-XXXXX" }
///
/// Links firebase_uid to account, sets status to 'active'.
/// Returns user info with roles for redirect.
Future<Response> activateUserHandler(Request request) async {
  print('[ACTIVATION] Activation request received');

  // Extract bearer token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    print('[ACTIVATION] No authorization header found');
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  // Verify Identity Platform token
  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    print('[ACTIVATION] Token verification FAILED: ${verification.error}');
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;
  final firebaseEmail = verification.email;

  print('[ACTIVATION] Token verified: uid=$firebaseUid, email=$firebaseEmail');

  // Parse request body
  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final code = body['code'] as String?;
  if (code == null || code.isEmpty) {
    return _jsonResponse({'error': 'Activation code is required'}, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Find user by activation code
  final result = await db.executeWithContext(
    '''
    SELECT id, email, name, status, activation_code_expires_at
    FROM portal_users
    WHERE activation_code = @code
    ''',
    parameters: {'code': code},
    context: serviceContext,
  );

  if (result.isEmpty) {
    print('[ACTIVATION] Code not found: $code');
    return _jsonResponse({'error': 'Invalid activation code'}, 401);
  }

  final row = result.first;
  final userId = row[0] as String;
  final userEmail = row[1] as String;
  final userName = row[2] as String;
  final status = row[3] as String;
  final expiresAt = row[4] as DateTime?;

  // Check if already activated
  if (status == 'active') {
    print('[ACTIVATION] Account already activated');
    return _jsonResponse({'error': 'Account already activated'}, 400);
  }

  // Check expiration
  if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
    print('[ACTIVATION] Code expired');
    return _jsonResponse({'error': 'Activation code has expired'}, 401);
  }

  // Verify email matches (case-insensitive)
  if (firebaseEmail?.toLowerCase() != userEmail.toLowerCase()) {
    print(
      '[ACTIVATION] Email mismatch: Firebase=$firebaseEmail, DB=$userEmail',
    );
    return _jsonResponse({
      'error': 'Email does not match activation code',
    }, 403);
  }

  // Fetch user's roles to determine MFA requirements
  final rolesResult = await db.executeWithContext(
    '''
    SELECT role::text
    FROM portal_user_roles
    WHERE user_id = @userId::uuid
    ORDER BY role
    ''',
    parameters: {'userId': userId},
    context: serviceContext,
  );

  final roles = rolesResult.map((r) => r[0] as String).toList();
  final isDeveloperAdmin = roles.contains('Developer Admin');

  // Determine MFA type based on role and feature flags
  final mfaType = getMfaTypeForRole(
    isDeveloperAdmin ? 'Developer Admin' : roles.firstOrNull ?? '',
  );
  final requiresTotp = requiresTotpEnrollment(
    isDeveloperAdmin ? 'Developer Admin' : roles.firstOrNull ?? '',
  );

  print(
    '[ACTIVATION] User roles: $roles, MFA type: $mfaType, requires TOTP: $requiresTotp',
  );

  // Check MFA enrollment status (FDA 21 CFR Part 11 compliance)
  // Only Developer Admins require TOTP enrollment; others use email OTP
  final mfaInfo = verification.mfaInfo;

  if (requiresTotp) {
    // Developer Admin must have TOTP enrolled
    if (mfaInfo == null || !mfaInfo.isEnrolled) {
      print(
        '[ACTIVATION] Developer Admin MFA not enrolled - activation blocked',
      );
      return _jsonResponse({
        'error': 'MFA enrollment required',
        'mfa_required': true,
        'mfa_type': 'totp',
        'message':
            'Please complete authenticator app setup before activating your account',
      }, 403);
    }
    print(
      '[ACTIVATION] Developer Admin MFA verified: method=${mfaInfo.method}',
    );
  } else {
    // Non-admin users use email OTP - no TOTP enrollment required
    print('[ACTIVATION] Non-admin user - will use email OTP on login');
  }

  // Activate the account with MFA tracking
  await db.executeWithContext(
    '''
    UPDATE portal_users
    SET firebase_uid = @firebaseUid,
        status = 'active',
        activated_at = now(),
        mfa_enrolled = @mfaEnrolled,
        mfa_enrolled_at = CASE WHEN @mfaEnrolled THEN now() ELSE NULL END,
        mfa_method = @mfaMethod,
        mfa_type = @mfaType,
        activation_code = NULL,
        activation_code_expires_at = NULL,
        updated_at = now()
    WHERE id = @userId::uuid
    ''',
    parameters: {
      'firebaseUid': firebaseUid,
      'userId': userId,
      'mfaEnrolled': requiresTotp && mfaInfo?.isEnrolled == true,
      'mfaMethod': requiresTotp ? (mfaInfo?.method ?? 'totp') : null,
      'mfaType': mfaType,
    },
    context: serviceContext,
  );

  print('[ACTIVATION] Account activated: $userId, mfa_type: $mfaType');

  return _jsonResponse({
    'success': true,
    'user': {
      'id': userId,
      'email': userEmail,
      'name': userName,
      'roles': roles,
      'mfa_type': mfaType,
      'status': 'active',
    },
  });
}

/// Generate activation code for an existing user (Developer Admin only)
/// POST /api/v1/portal/admin/generate-code
/// Body: { user_id: "uuid" } or { email: "email@example.com" }
///
/// Used by Developer Admin to generate activation codes for Portal Admins.
Future<Response> generateActivationCodeHandler(Request request) async {
  print('[ACTIVATION] Generate code request received');

  // Extract and verify token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Check if caller is Developer Admin
  final callerResult = await db.executeWithContext(
    '''
    SELECT pur.role::text
    FROM portal_users pu
    JOIN portal_user_roles pur ON pu.id = pur.user_id
    WHERE pu.firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
    context: serviceContext,
  );

  final callerRoles = callerResult.map((r) => r[0] as String).toList();
  if (!callerRoles.contains('Developer Admin')) {
    print('[ACTIVATION] Caller is not Developer Admin');
    return _jsonResponse({
      'error': 'Only Developer Admin can generate activation codes',
    }, 403);
  }

  // Parse request body
  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final userId = body['user_id'] as String?;
  final email = body['email'] as String?;

  if (userId == null && email == null) {
    return _jsonResponse({'error': 'Either user_id or email is required'}, 400);
  }

  // Find target user
  List<List<dynamic>> targetResult;
  if (userId != null) {
    targetResult = await db.executeWithContext(
      'SELECT id, email, name, status FROM portal_users WHERE id = @userId::uuid',
      parameters: {'userId': userId},
      context: serviceContext,
    );
  } else {
    targetResult = await db.executeWithContext(
      'SELECT id, email, name, status FROM portal_users WHERE email = @email',
      parameters: {'email': email},
      context: serviceContext,
    );
  }

  if (targetResult.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final targetUserId = targetResult.first[0] as String;
  final targetEmail = targetResult.first[1] as String;
  final targetName = targetResult.first[2] as String;

  // Generate new activation code
  final activationCode = _generateCode();
  final activationExpiry = DateTime.now().add(const Duration(days: 14));

  await db.executeWithContext(
    '''
    UPDATE portal_users
    SET activation_code = @code,
        activation_code_expires_at = @expiry,
        status = 'pending',
        updated_at = now()
    WHERE id = @userId::uuid
    ''',
    parameters: {
      'userId': targetUserId,
      'code': activationCode,
      'expiry': activationExpiry,
    },
    context: serviceContext,
  );

  print('[ACTIVATION] Generated code for: $targetEmail');

  // Get caller's user ID for audit trail
  final callerIdResult = await db.executeWithContext(
    'SELECT id FROM portal_users WHERE firebase_uid = @firebaseUid',
    parameters: {'firebaseUid': firebaseUid},
    context: serviceContext,
  );
  final callerId = callerIdResult.isNotEmpty
      ? callerIdResult.first[0] as String
      : null;

  // Build activation URL from environment
  final portalUrl =
      Platform.environment['PORTAL_URL'] ?? 'https://portal.example.com';
  final activationUrl = '$portalUrl/activate?code=$activationCode';

  // Send activation email if feature is enabled
  bool emailSent = false;
  String? emailError;

  if (FeatureFlags.emailActivation) {
    final emailService = EmailService.instance;

    if (emailService.isReady) {
      print('[ACTIVATION] Sending activation email to: $targetEmail');

      final result = await emailService.sendActivationCode(
        recipientEmail: targetEmail,
        recipientName: targetName,
        activationCode: activationCode,
        activationUrl: activationUrl,
        sentByUserId: callerId,
      );

      emailSent = result.success;
      emailError = result.error;

      if (emailSent) {
        print('[ACTIVATION] Activation email sent: ${result.messageId}');
      } else {
        print('[ACTIVATION] Failed to send activation email: $emailError');
      }
    } else {
      print(
        '[ACTIVATION] Email service not ready - code must be shared manually',
      );
      emailError = 'Email service not configured';
    }
  } else {
    print(
      '[ACTIVATION] Email activation disabled - code must be shared manually',
    );
  }

  return _jsonResponse({
    'success': true,
    'user': {'id': targetUserId, 'email': targetEmail, 'name': targetName},
    'activation_code': activationCode,
    'activation_url': activationUrl,
    'expires_at': activationExpiry.toIso8601String(),
    'email_sent': emailSent,
    'email_error': emailError,
  });
}

/// Generate a random code in XXXXX-XXXXX format
String _generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  String part() =>
      List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  return '${part()}-${part()}';
}

Future<Map<String, dynamic>?> _parseJson(Request request) async {
  try {
    final body = await request.readAsString();
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
