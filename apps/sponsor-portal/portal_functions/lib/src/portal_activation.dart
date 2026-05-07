// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-d00166: Server-owned portal activation; {code, password} body; no bearer required
//
// Portal activation handlers - validate and process activation codes
// for new user account setup
//
// Conditional MFA behavior:
// - Developer Admin: requires TOTP (authenticator app) enrollment (tracked
//   server-side once portal_users.totp_enrolled_at column is available;
//   see TODO(REQ-d00166-B) below)
// - All other roles: uses email OTP on every login (no TOTP enrollment)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'email_service.dart';
import 'feature_flags.dart';
import 'identity_admin.dart';
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
  print('[ACTIVATION] Validating code: $code');

  final db = Database.instance;

  // Debug: Check what codes exist in the database
  const serviceContext = UserContext.service;
  final debugResult = await db.executeWithContext('''
    SELECT id, email, activation_code, status
    FROM portal_users
    WHERE activation_code IS NOT NULL
    ''', context: serviceContext);
  print(
    '[ACTIVATION] DEBUG: Found ${debugResult.length} users with activation codes:',
  );
  for (final row in debugResult) {
    print(
      '[ACTIVATION] DEBUG:   id=${row[0]}, email=${row[1]}, code=${row[2]}, status=${row[3]}',
    );
  }

  print('[ACTIVATION] Querying with service context for code: $code');
  final result = await db.executeWithContext(
    '''
    SELECT id, email, name, status, activation_code_expires_at
    FROM portal_users
    WHERE activation_code = @code
    ''',
    parameters: {'code': code},
    context: serviceContext,
  );

  print('[ACTIVATION] Query returned ${result.length} rows');

  if (result.isEmpty) {
    print('[ACTIVATION] Code not found in query result');
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

  // Return full email so UI can create Firebase account with correct address
  // The activation code provides security (random, expiring token) so
  // exposing the email to the code holder is acceptable
  // Also return masked version for display purposes
  final maskedEmail = _maskEmail(email);
  print('[ACTIVATION] Code valid for: $email');

  return _jsonResponse({
    'valid': true,
    'email': email, // Full email for Firebase account creation
    'maskedEmail': maskedEmail, // Masked for display in UI
  });
}

/// Activate user account with activation code and chosen password.
///
/// POST /api/v1/portal/activate
/// Body: { code: "XXXXX-XXXXX", password: "<new password>" }
///
/// No bearer token required. The activation code is the authenticating
/// credential. The server creates the Identity Platform account (Task 9)
/// and links firebase_uid in one transaction.
///
/// Implements: REQ-d00166-A,B,E — server-owned activation; validation
/// runs before any IdP call; idempotent retry-after-success.
Future<Response> activateUserHandler(Request request) async {
  print('[ACTIVATION] Activation request received');

  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({
      'error': 'Invalid JSON body',
      'code': 'invalid_body',
    }, 400);
  }

  final code = body['code'] as String?;
  final password = body['password'] as String?;
  if (code == null || code.isEmpty) {
    return _jsonResponse({
      'error': 'Activation code is required',
      'code': 'code_required',
    }, 400);
  }
  if (password == null || password.isEmpty) {
    return _jsonResponse({
      'error': 'Password is required',
      'code': 'password_required',
    }, 400);
  }

  final db = Database.instance;
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
    print('[ACTIVATION] Code not found: $code');
    return _jsonResponse({
      'error': 'Invalid activation code',
      'code': 'code_invalid',
    }, 400);
  }

  final row = result.first;
  final userId = row[0] as String;
  final userEmail = row[1] as String;
  final userName = row[2] as String;
  final status = row[3] as String;
  final expiresAt = row[4] as DateTime?;

  // REQ-d00166-E: idempotent retry-after-success.
  if (status == 'active') {
    print('[ACTIVATION] Account already activated (idempotent)');
    return _jsonResponse({'ok': true, 'already_active': true}, 200);
  }

  // REQ-d00166-B: only 'pending' rows may proceed to the IdP call. Any
  // other non-active state ('revoked' per schema.sql:625, plus any future
  // additions to the status enum) is rejected here, before IdentityAdmin
  // can mutate the IdP password for an unauthorized row.
  if (status != 'pending') {
    print('[ACTIVATION] Row not pending (status=$status): $code');
    return _jsonResponse({
      'error': 'Account is not pending activation',
      'code': 'not_pending',
    }, 400);
  }

  if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
    print('[ACTIVATION] Code expired: $code');
    return _jsonResponse({
      'error': 'Activation code has expired',
      'code': 'code_expired',
    }, 400);
  }

  // Role lookup. Dev-Admin TOTP enrollment-at-activation gate is
  // deferred (REQ-d00166-B) — see the if(isDeveloperAdmin) block below
  // and the TODO at the call site. Non-Dev-Admin roles use email OTP
  // at sign-in time, not here.
  final rolesResult = await db.executeWithContext(
    'SELECT role::text FROM portal_user_roles WHERE user_id = @userId::uuid ORDER BY role',
    parameters: {'userId': userId},
    context: serviceContext,
  );
  final roles = rolesResult.map((r) => r[0] as String).toList();
  final isDeveloperAdmin = roles.contains('Developer Admin');

  if (isDeveloperAdmin) {
    // CUR-1296: with bearer-token-based MFA claims gone (REQ-d00166-A),
    // Dev-Admin enrollment must be tracked server-side. The MFA setup
    // page at /activate/2fa writes to portal_users.totp_enrolled_at on
    // successful enrollment. Until that column lands and the UI is
    // wired, the gate is informational only.
    // TODO(REQ-d00166-B): wire Dev-Admin TOTP enrollment check once
    //   portal_users.totp_enrolled_at column is added to the schema.
    print(
      '[ACTIVATION] Dev Admin activation: TOTP enforcement deferred (no totp_enrolled_at column yet)',
    );
  }

  // Implements: REQ-d00166-C+D+F — single IdP call; IdP-first / DB-second
  // mutation order; transactional DB stamp. Idempotent on retry.
  final LookupOrProvisionResult idp;
  try {
    idp = await IdentityAdmin.lookupOrProvisionByEmail(
      email: userEmail,
      displayName: userName,
      password: password,
    );
  } on IdentityAdminException catch (e) {
    print('[ACTIVATION] Identity Platform call failed: $e');
    // 4xx from Identity Toolkit = caller-correctable (weak password,
    // invalid request body). Surface a 400 with a stable code so the
    // UI can render a useful message (ActivationPage._mapServerErrorCode
    // already maps password_too_weak). 5xx / no statusCode = upstream
    // availability; keep 502 idp_unavailable so the caller knows a
    // retry might succeed.
    final sc = e.statusCode;
    if (sc != null && sc >= 400 && sc < 500) {
      final code = e.message.contains('WEAK_PASSWORD')
          ? 'password_too_weak'
          : 'idp_request_invalid';
      return _jsonResponse({
        'error': 'Identity Platform rejected the request',
        'code': code,
      }, 400);
    }
    return _jsonResponse({
      'error': 'Identity Platform unavailable',
      'code': 'idp_unavailable',
    }, 502);
  }

  // Stamp firebase_uid + flip to active, gated by status='pending' AND
  // matching activation_code. The activation_code clause defends against
  // a code rotation racing this handler (Dev Admin reissues a fresh code
  // between SELECT and UPDATE — the in-flight request must not activate
  // the row using a now-stale code). The status='pending' clause defends
  // against a concurrent activate that already flipped the row.
  // RETURNING id lets us detect the 0-row case deterministically.
  // REQ-d00166-E: activation_code is preserved on success so retries with
  // the same code re-enter the SELECT->status=='active' short-circuit
  // above and return 200 already_active=true.
  final updated = await db.executeWithContext(
    '''
    UPDATE portal_users
    SET firebase_uid = @uid,
        status = 'active',
        updated_at = now()
    WHERE id = @id::uuid AND status = 'pending' AND activation_code = @code
    RETURNING id
    ''',
    parameters: {'uid': idp.uid, 'id': userId, 'code': code},
    context: serviceContext,
  );

  if (updated.isEmpty) {
    // Row was deleted, status changed, or activation_code was rotated
    // between the pre-check and this UPDATE. The IdP write already
    // happened; the DB binding does not reflect this request. The
    // caller must restart with the current row state.
    print(
      '[ACTIVATION] Activation conflict: row state changed under us '
      '(userId=$userId, code=$code)',
    );
    return _jsonResponse({
      'error': 'Activation state changed; please retry',
      'code': 'activation_conflict',
    }, 409);
  }

  print(
    '[ACTIVATION] Activated $userEmail (uid=${idp.uid}, created=${idp.created})',
  );

  return _jsonResponse({'ok': true, 'roles': roles}, 200);
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

  // Use service context for admin code generation - privileged operation
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
      'SELECT id, email, name, status FROM portal_users '
      'WHERE LOWER(email) = LOWER(@email)',
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

  // Build activation URL from the portal origin the caller used
  final portalUrl = getPortalBaseUrl(
    request,
    portalUrlEnv: Platform.environment['PORTAL_URL'],
  );
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

/// Extract portal base URL for activation links.
///
/// Prefers [portalUrlEnv] (PORTAL_URL env var) — this is the authoritative,
/// per-environment domain (e.g. portal-qa.callisto.anspar.org).
/// Falls back to Origin header, then Referer, then localhost.
///
/// Production callers pass `Platform.environment['PORTAL_URL']` as
/// [portalUrlEnv]; tests pass explicit values for determinism.
String getPortalBaseUrl(Request request, {String? portalUrlEnv}) {
  if (portalUrlEnv != null && portalUrlEnv.isNotEmpty) {
    return portalUrlEnv;
  }
  final origin = request.headers['origin'];
  if (origin != null && origin.isNotEmpty) {
    return origin;
  }
  final referer = request.headers['referer'];
  if (referer != null && referer.isNotEmpty) {
    final uri = Uri.tryParse(referer);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return '${uri.scheme}://${uri.authority}';
    }
  }
  return 'http://localhost:8081';
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

/// Mask email address for display (e.g., p***@example.com)
/// Security best practice: don't expose full emails in responses/logs
String _maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return '***';

  final local = parts[0];
  final domain = parts[1];

  if (local.isEmpty) return '***@$domain';
  return '${local[0]}***@$domain';
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
