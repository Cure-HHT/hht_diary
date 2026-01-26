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

import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

import 'database.dart';
import 'email_service.dart';

/// Google Identity Platform REST API base URL
const _identityApiUrl = 'https://identitytoolkit.googleapis.com/v1';

/// Get the portal URL for constructing reset links
String get _portalUrl {
  return Platform.environment['PORTAL_URL'] ??
      Platform.environment['PORTAL_BASE_URL'] ??
      'http://localhost:8080';
}

/// Get access token for Identity Platform API
///
/// In Cloud Run: Uses Workload Identity Federation (WIF)
/// Locally: Falls back to gcloud auth print-access-token
Future<String> _getIdentityPlatformAccessToken() async {
  // First try WIF (works in Cloud Run)
  try {
    final client = await clientViaApplicationDefaultCredentials(
      scopes: [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/firebase',
      ],
    );

    final credentials = client.credentials;
    final accessToken = credentials.accessToken.data;
    client.close();
    return accessToken;
  } catch (e) {
    print('[PASSWORD_RESET] WIF failed, trying gcloud auth: $e');
  }

  // Fall back to gcloud CLI (works locally with `gcloud auth login`)
  try {
    final result = await Process.run('gcloud', ['auth', 'print-access-token']);
    if (result.exitCode == 0) {
      final token = (result.stdout as String).trim();
      if (token.isNotEmpty) {
        return token;
      }
    }
    print('[PASSWORD_RESET] gcloud auth failed: ${result.stderr}');
  } catch (e) {
    print('[PASSWORD_RESET] gcloud command failed: $e');
  }

  throw Exception('Failed to obtain access token via WIF or gcloud');
}

/// Get GCP project ID from environment
String get _gcpProjectId {
  return Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ??
      Platform.environment['GCP_PROJECT_ID'] ??
      'callisto4-dev';
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

    // Generate password reset link using Identity Platform's native oobCode
    print('[PASSWORD_RESET] Generating reset link for: $normalizedEmail');
    final resetLink = await _generatePasswordResetLink(normalizedEmail);

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

/// Generate a password reset link using Identity Platform's native oobCode
///
/// Uses the Identity Platform REST API to generate a password reset link
/// with Firebase's built-in oobCode. This allows the Flutter client to use
/// Firebase's verifyPasswordResetCode and confirmPasswordReset methods.
///
/// Returns the full reset URL with oobCode parameter, or null on error.
Future<String?> _generatePasswordResetLink(String email) async {
  try {
    print('[PASSWORD_RESET] Getting access token via WIF...');
    final accessToken = await _getIdentityPlatformAccessToken();

    // Use Identity Platform REST API to generate password reset link
    // returnOobLink: true returns the link without sending email
    final url = Uri.parse(
      '$_identityApiUrl/projects/$_gcpProjectId/accounts:sendOobCode',
    );

    // Construct the continue URL that Firebase will redirect to
    final continueUrl = Uri.parse(
      _portalUrl,
    ).replace(path: '/reset-password').toString();

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'x-goog-user-project': _gcpProjectId,
      },
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email,
        'returnOobLink': true,
        'continueUrl': continueUrl,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      print(
        '[PASSWORD_RESET] Identity Platform API error: ${response.statusCode} - $error',
      );
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final oobLink = data['oobLink'] as String?;

    if (oobLink == null || oobLink.isEmpty) {
      print('[PASSWORD_RESET] No oobLink in response: $data');
      return null;
    }

    // The oobLink from Firebase looks like:
    // https://project.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=XXX&apiKey=XXX&continueUrl=XXX
    // We need to extract the oobCode and construct our own URL
    final oobUri = Uri.parse(oobLink);
    final oobCode = oobUri.queryParameters['oobCode'];

    if (oobCode == null || oobCode.isEmpty) {
      print('[PASSWORD_RESET] No oobCode in link: $oobLink');
      return null;
    }

    print('[PASSWORD_RESET] Generated oobCode: ${oobCode.substring(0, 10)}...');

    // Construct our portal reset URL with the oobCode
    final resetUrl = Uri.parse(
      _portalUrl,
    ).replace(path: '/reset-password', queryParameters: {'oobCode': oobCode});

    return resetUrl.toString();
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

/// Helper to create JSON response
Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}
