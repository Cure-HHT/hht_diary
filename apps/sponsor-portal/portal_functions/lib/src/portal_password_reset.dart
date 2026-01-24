// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00071: Password Complexity
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-d00031: Identity Platform Integration
//
// Password reset handlers using Google Identity Platform REST API
// Generates password reset links and sends them via Gmail API
// Always returns generic success message to prevent email enumeration

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

import 'database.dart';
import 'email_service.dart';

/// Google Identity Platform REST API base URL
const _identityApiUrl = 'https://identitytoolkit.googleapis.com/v1';

/// Get the portal URL for constructing reset links
String get _portalUrl {
  return Platform.environment['PORTAL_BASE_URL'] ?? 'http://localhost:8080';
}

/// Get access token for Identity Platform API via Workload Identity Federation
///
/// Uses Application Default Credentials (Cloud Run's service account or local gcloud auth)
Future<String> _getIdentityPlatformAccessToken() async {
  // Get Application Default Credentials
  final client = await clientViaApplicationDefaultCredentials(
    scopes: [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/firebase',
    ],
  );

  // Extract access token from authenticated client
  final credentials = client.credentials;
  final accessToken = credentials.accessToken.data;

  client.close();
  return accessToken;
}

/// Update user password in Identity Platform using REST API
///
/// Uses WIF to authenticate as Cloud Run service account.
/// Returns true on success, false on failure.
Future<bool> _updatePasswordInIdentityPlatform(
  String firebaseUid,
  String newPassword,
) async {
  try {
    print('[PASSWORD_RESET] Getting access token via WIF...');
    final accessToken = await _getIdentityPlatformAccessToken();

    final url = Uri.parse('$_identityApiUrl/accounts:update');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'localId': firebaseUid,
        'password': newPassword,
        'returnSecureToken': false,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      print(
        '[PASSWORD_RESET] Identity Platform API error: ${response.statusCode} - $error',
      );
      return false;
    }

    print(
      '[PASSWORD_RESET] Password updated successfully in Identity Platform',
    );
    return true;
  } catch (e) {
    print('[PASSWORD_RESET] Error updating password: $e');
    return false;
  }
}

/// Generate a password reset code in XXXXX-XXXXX format
///
/// Uses crypto-secure random with 32-character alphabet (avoiding ambiguous chars).
/// Total entropy: 32^10 ≈ 1,152,921,504,606,846,976 combinations
/// Format matches activation codes for consistency.
String _generatePasswordResetCode() {
  final random = Random.secure();
  // Exclude ambiguous characters: 0O, 1Il
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String generatePart() {
    return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  }

  return '${generatePart()}-${generatePart()}';
}

/// Request password reset email
/// POST /api/v1/portal/auth/password-reset/request
/// Body: { "email": "user@example.com" }
///
/// Always returns 200 with generic success message, regardless of whether
/// the email exists in the system. This prevents email enumeration attacks
/// per REQ-p00044.B.
///
/// If email exists and user is active:
///   - Generates Firebase password reset link with 24-hour expiration
///   - Sends email via Gmail API with custom template
///   - Records audit log entry (PASSWORD_RESET event)
///   - Records rate limit entry
///
/// Rate limited: max 3 requests per email per 15 minutes.
///
/// Returns:
///   200: { "success": true, "message": "If an account exists..." }
///   429: Rate limit exceeded
///   500: Internal server error
Future<Response> requestPasswordResetHandler(Request request) async {
  print('[PASSWORD_RESET] requestPasswordResetHandler called');

  try {
    // Parse request body
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final email = json['email'] as String?;

    if (email == null || email.isEmpty) {
      return _jsonResponse({'error': 'Email is required'}, 400);
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      return _jsonResponse({'error': 'Invalid email format'}, 400);
    }

    final normalizedEmail = email.trim().toLowerCase();

    // Get client IP for audit and rate limiting
    final clientIp =
        request.headers['x-forwarded-for']?.split(',').first.trim() ??
        request.headers['x-real-ip'];

    final db = Database.instance;
    final emailService = EmailService.instance;

    // Check rate limit FIRST (before checking if user exists)
    // This prevents attackers from using rate limiting to enumerate emails
    final canSend = await emailService.checkRateLimit(
      email: normalizedEmail,
      emailType: 'password_reset',
    );

    if (!canSend) {
      print('[PASSWORD_RESET] Rate limit exceeded for: $normalizedEmail');
      return _jsonResponse({
        'error':
            'Too many password reset requests. Please wait 15 minutes before trying again.',
        'retry_after': 900, // 15 minutes in seconds
      }, 429);
    }

    // Record rate limit entry (do this even if email doesn't exist)
    await emailService.recordRateLimit(
      email: normalizedEmail,
      emailType: 'password_reset',
      ipAddress: clientIp,
    );

    // Check if email exists in portal_users table
    final userResult = await db.executeWithContext(
      '''
      SELECT id, name, status, firebase_uid
      FROM portal_users
      WHERE LOWER(email) = @email
      ''',
      parameters: {'email': normalizedEmail},
      context: UserContext.service,
    );

    // Generic success message (per REQ-p00044.B - prevent email enumeration)
    const successMessage =
        'If an account exists with that email, you will receive a password '
        'reset link within a few minutes. Check your spam folder if you don\'t '
        'see it. The link expires in 24 hours.';

    // If user doesn't exist, return success anyway (but don't send email)
    if (userResult.isEmpty) {
      print('[PASSWORD_RESET] Email not found, returning generic success');
      return _jsonResponse({'success': true, 'message': successMessage}, 200);
    }

    final userId = userResult.first[0] as String;
    final userName = userResult.first[1] as String?;
    final userStatus = userResult.first[2] as String;
    final firebaseUid = userResult.first[3] as String?;

    // If user is not active, return success anyway (but don't send email)
    if (userStatus != 'active') {
      print(
        '[PASSWORD_RESET] User $userId not active (status: $userStatus), '
        'returning generic success',
      );

      // Log audit event for inactive user attempt
      await _logPasswordResetAudit(
        userId: userId,
        email: normalizedEmail,
        success: false,
        reason: 'inactive_user',
        ipAddress: clientIp,
      );

      return _jsonResponse({'success': true, 'message': successMessage}, 200);
    }

    // If user doesn't have firebase_uid (Identity Platform UID), they haven't activated yet
    if (firebaseUid == null || firebaseUid.isEmpty) {
      print(
        '[PASSWORD_RESET] User $userId not activated (no firebase_uid), '
        'returning generic success',
      );

      await _logPasswordResetAudit(
        userId: userId,
        email: normalizedEmail,
        success: false,
        reason: 'not_activated',
        ipAddress: clientIp,
      );

      return _jsonResponse({'success': true, 'message': successMessage}, 200);
    }

    // Generate custom password reset code (XXXXX-XXXXX format)
    print('[PASSWORD_RESET] Generating reset code for: $normalizedEmail');
    final resetLink = await _generatePasswordResetLink(userId);

    if (resetLink == null) {
      print('[PASSWORD_RESET] Failed to generate reset link');

      await _logPasswordResetAudit(
        userId: userId,
        email: normalizedEmail,
        success: false,
        reason: 'identity_api_error',
        ipAddress: clientIp,
      );

      // Still return generic success to prevent information disclosure
      return _jsonResponse({'success': true, 'message': successMessage}, 200);
    }

    // Send password reset email
    print('[PASSWORD_RESET] Sending reset email to: $normalizedEmail');
    final emailResult = await emailService.sendPasswordResetEmail(
      recipientEmail: normalizedEmail,
      recipientName: userName,
      resetLink: resetLink,
    );

    if (!emailResult.success) {
      print('[PASSWORD_RESET] Failed to send email: ${emailResult.error}');

      await _logPasswordResetAudit(
        userId: userId,
        email: normalizedEmail,
        success: false,
        reason: 'email_send_failed',
        ipAddress: clientIp,
      );

      // Still return generic success
      return _jsonResponse({'success': true, 'message': successMessage}, 200);
    }

    // Log successful password reset request
    await _logPasswordResetAudit(
      userId: userId,
      email: normalizedEmail,
      success: true,
      ipAddress: clientIp,
    );

    print('[PASSWORD_RESET] Password reset email sent successfully');

    return _jsonResponse({'success': true, 'message': successMessage}, 200);
  } catch (e, stack) {
    print('[PASSWORD_RESET] Error: $e\n$stack');

    // Return generic error (don't leak details)
    return _jsonResponse({
      'error': 'An error occurred processing your request. Please try again.',
    }, 500);
  }
}

/// Generate a password reset link with custom XXXXX-XXXXX code
///
/// Generates a 10-character code (XXXXX-XXXXX format) for consistency with
/// activation codes. Code expires in 24 hours and is single-use.
///
/// Returns the full reset URL with code parameter, or null on error.
Future<String?> _generatePasswordResetLink(String userId) async {
  try {
    final db = Database.instance;

    // Generate unique reset code
    String resetCode;
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 5;

    while (!isUnique && attempts < maxAttempts) {
      resetCode = _generatePasswordResetCode();

      // Check if code is already in use (extremely unlikely but check anyway)
      final existing = await db.executeWithContext(
        'SELECT id FROM portal_users WHERE password_reset_code = @code',
        parameters: {'code': resetCode},
        context: UserContext.service,
      );

      isUnique = existing.isEmpty;
      attempts++;

      if (isUnique) {
        // Store code in database with 24-hour expiration
        await db.executeWithContext(
          '''
          UPDATE portal_users
          SET password_reset_code = @code,
              password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
              password_reset_used_at = NULL
          WHERE id = @userId
          ''',
          parameters: {'code': resetCode, 'userId': userId},
          context: UserContext.service,
        );

        print('[PASSWORD_RESET] Generated reset code: $resetCode');

        // Construct reset URL
        final resetUrl = Uri.parse(_portalUrl).replace(
          path: '/reset-password',
          queryParameters: {'code': resetCode},
        );

        return resetUrl.toString();
      }
    }

    print(
      '[PASSWORD_RESET] Failed to generate unique code after $maxAttempts attempts',
    );
    return null;
  } catch (e) {
    print('[PASSWORD_RESET] Error generating reset link: $e');
    return null;
  }
}

/// Log password reset event to auth_audit_log table
Future<void> _logPasswordResetAudit({
  required String userId,
  required String email,
  required bool success,
  String? reason,
  String? ipAddress,
}) async {
  try {
    final db = Database.instance;

    await db.executeWithContext(
      '''
      INSERT INTO auth_audit_log
        (user_id, event_type, success, client_ip, metadata)
      VALUES
        (@user_id, 'PASSWORD_RESET', @success, @client_ip::inet, @metadata::jsonb)
      ''',
      parameters: {
        'user_id': userId,
        'success': success,
        'client_ip': ipAddress,
        'metadata': jsonEncode({
          'email': email,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      },
      context: UserContext.service,
    );
  } catch (e) {
    print('[PASSWORD_RESET] Failed to log audit event: $e');
    // Don't throw - logging failure shouldn't break the flow
  }
}

/// Simple email validation
bool _isValidEmail(String email) {
  return email.contains('@') && email.length >= 3;
}

/// Validate password reset code (unauthenticated endpoint)
/// GET /api/v1/portal/auth/password-reset/validate/:code
///
/// Returns email if code is valid and not expired.
/// Used by frontend to display the reset form.
Future<Response> validatePasswordResetCodeHandler(
  Request request,
  String code,
) async {
  print('[PASSWORD_RESET] Validating code: $code');

  final db = Database.instance;

  // Use service context for unauthenticated code lookup
  final result = await db.executeWithContext(
    '''
    SELECT id, email, name, password_reset_code_expires_at, password_reset_used_at
    FROM portal_users
    WHERE password_reset_code = @code
    ''',
    parameters: {'code': code},
    context: UserContext.service,
  );

  if (result.isEmpty) {
    print('[PASSWORD_RESET] Code not found');
    return _jsonResponse({'error': 'Invalid password reset code'}, 401);
  }

  final row = result.first;
  final email = row[1] as String;
  final expiresAt = row[3] as DateTime?;
  final usedAt = row[4] as DateTime?;

  // Check if already used
  if (usedAt != null) {
    print('[PASSWORD_RESET] Code already used');
    return _jsonResponse({
      'error': 'Password reset code has already been used',
    }, 401);
  }

  // Check expiration
  if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
    print('[PASSWORD_RESET] Code expired');
    return _jsonResponse({'error': 'Password reset code has expired'}, 401);
  }

  print('[PASSWORD_RESET] Code valid for: $email');

  return _jsonResponse({'valid': true, 'email': email}, 200);
}

/// Complete password reset (unauthenticated endpoint)
/// POST /api/v1/portal/auth/password-reset/complete
/// Body: { "code": "XXXXX-XXXXX", "password": "newpassword" }
///
/// Verifies code and updates password in Identity Platform.
/// Marks code as used (single-use enforcement).
Future<Response> completePasswordResetHandler(Request request) async {
  print('[PASSWORD_RESET] Complete password reset called');

  try {
    // Parse request body
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = json['code'] as String?;
    final password = json['password'] as String?;

    if (code == null || code.isEmpty) {
      return _jsonResponse({'error': 'Reset code is required'}, 400);
    }

    if (password == null || password.isEmpty) {
      return _jsonResponse({'error': 'Password is required'}, 400);
    }

    // Validate password requirements (8-64 characters per REQ-p00071)
    if (password.length < 8) {
      return _jsonResponse({
        'error': 'Password must be at least 8 characters',
      }, 400);
    }

    if (password.length > 64) {
      return _jsonResponse({
        'error': 'Password must not exceed 64 characters',
      }, 400);
    }

    final db = Database.instance;

    // Find user by reset code
    final result = await db.executeWithContext(
      '''
      SELECT id, email, firebase_uid, password_reset_code_expires_at, password_reset_used_at
      FROM portal_users
      WHERE password_reset_code = @code
      ''',
      parameters: {'code': code},
      context: UserContext.service,
    );

    if (result.isEmpty) {
      print('[PASSWORD_RESET] Code not found');
      return _jsonResponse({'error': 'Invalid password reset code'}, 401);
    }

    final row = result.first;
    final userId = row[0] as String;
    final email = row[1] as String;
    final firebaseUid = row[2] as String?;
    final expiresAt = row[3] as DateTime?;
    final usedAt = row[4] as DateTime?;

    // Check if already used
    if (usedAt != null) {
      print('[PASSWORD_RESET] Code already used');
      return _jsonResponse({
        'error': 'Password reset code has already been used',
      }, 401);
    }

    // Check expiration
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      print('[PASSWORD_RESET] Code expired');
      return _jsonResponse({'error': 'Password reset code has expired'}, 401);
    }

    if (firebaseUid == null || firebaseUid.isEmpty) {
      print('[PASSWORD_RESET] User not activated (no firebase_uid)');
      return _jsonResponse({'error': 'Account not activated'}, 400);
    }

    // Get client IP for audit
    final clientIp =
        request.headers['x-forwarded-for']?.split(',').first.trim() ??
        request.headers['x-real-ip'];

    // Update password in Identity Platform using REST API with WIF
    print('[PASSWORD_RESET] Updating password for user: $firebaseUid');
    final passwordUpdated = await _updatePasswordInIdentityPlatform(
      firebaseUid,
      password,
    );

    if (!passwordUpdated) {
      print('[PASSWORD_RESET] Failed to update password in Identity Platform');
      await _logPasswordResetAudit(
        userId: userId,
        email: email,
        success: false,
        reason: 'identity_platform_update_failed',
        ipAddress: clientIp,
      );
      return _jsonResponse({
        'error': 'Failed to update password. Please try again.',
      }, 500);
    }

    // Mark code as used
    await db.executeWithContext(
      '''
      UPDATE portal_users
      SET password_reset_used_at = NOW(),
          password_reset_code = NULL,
          password_reset_code_expires_at = NULL
      WHERE id = @userId
      ''',
      parameters: {'userId': userId},
      context: UserContext.service,
    );

    // Log successful password reset
    await _logPasswordResetAudit(
      userId: userId,
      email: email,
      success: true,
      ipAddress: clientIp,
    );

    print('[PASSWORD_RESET] Password reset completed successfully');

    return _jsonResponse({'success': true}, 200);
  } catch (e, stack) {
    print('[PASSWORD_RESET] Error: $e\n$stack');
    return _jsonResponse({
      'error': 'An error occurred. Please try again.',
    }, 500);
  }
}

/// Helper to create JSON response
Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}
