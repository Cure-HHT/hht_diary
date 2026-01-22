// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Email OTP handlers for second-factor authentication
// Used by all non-Developer-Admin users on every login

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'email_service.dart';
import 'identity_platform.dart';

/// Send email OTP code to authenticated user
/// POST /api/v1/portal/auth/send-otp
/// Authorization: Bearer <Identity Platform ID token>
///
/// The user must have already authenticated with email/password via Identity Platform.
/// This endpoint generates a 6-digit OTP, sends it via email, and stores the hash.
///
/// Rate limited: max 3 OTPs per email address per 15 minutes.
/// OTP expires in 10 minutes.
///
/// Returns:
///   200: { "success": true, "masked_email": "t***@example.com", "expires_in": 600 }
///   401: Missing or invalid authorization
///   429: Rate limit exceeded
///   500: Email send failure
Future<Response> sendEmailOtpHandler(Request request) async {
  print('[EMAIL_OTP] sendEmailOtpHandler called');

  // Extract and verify bearer token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    print('[EMAIL_OTP] No authorization header');
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    print('[EMAIL_OTP] Token verification failed: ${verification.error}');
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;
  final email = verification.email;

  print('[EMAIL_OTP] Token verified: uid=$firebaseUid, email=$email');

  if (email == null) {
    return _jsonResponse({'error': 'Token missing email claim'}, 401);
  }

  final db = Database.instance;
  final emailService = EmailService.instance;

  // Look up user by firebase_uid to get user_id
  final userResult = await db.executeWithContext(
    '''
    SELECT id, name, status
    FROM portal_users
    WHERE firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
    context: UserContext.service,
  );

  if (userResult.isEmpty) {
    print('[EMAIL_OTP] User not found for uid: $firebaseUid');
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final userId = userResult.first[0] as String;
  final userName = userResult.first[1] as String?;
  final userStatus = userResult.first[2] as String;

  if (userStatus != 'active') {
    return _jsonResponse({'error': 'Account not active'}, 403);
  }

  // Check rate limit
  final canSend = await emailService.checkRateLimit(
    email: email,
    emailType: 'otp',
  );

  if (!canSend) {
    print('[EMAIL_OTP] Rate limit exceeded for: $email');
    return _jsonResponse({
      'error': 'Too many OTP requests. Please wait before trying again.',
      'retry_after': 900, // 15 minutes in seconds
    }, 429);
  }

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Invalidate any existing unused OTP codes for this user
  await db.executeWithContext(
    '''
    UPDATE email_otp_codes
    SET used_at = now()
    WHERE user_id = @userId::uuid
      AND used_at IS NULL
      AND expires_at > now()
    ''',
    parameters: {'userId': userId},
    context: UserContext.service,
  );

  // Generate new OTP code
  final code = generateOtpCode();
  final codeHash = hashOtpCode(code);
  // Use UTC consistently to avoid timezone mismatches
  final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));

  print(
    '[EMAIL_OTP] Generated OTP $code for user: $userId, expires: $expiresAt',
  );

  // Store hashed OTP in database
  await db.executeWithContext(
    '''
    INSERT INTO email_otp_codes
      (user_id, code_hash, expires_at, ip_address)
    VALUES
      (@userId::uuid, @codeHash, @expiresAt, @ipAddress::inet)
    ''',
    parameters: {
      'userId': userId,
      'codeHash': codeHash,
      'expiresAt': expiresAt.toIso8601String(),
      'ipAddress': clientIp,
    },
    context: UserContext.service,
  );

  // Record rate limit
  await emailService.recordRateLimit(
    email: email,
    emailType: 'otp',
    ipAddress: clientIp,
  );

  // Send OTP via email
  final result = await emailService.sendOtpCode(
    recipientEmail: email,
    code: code,
    recipientName: userName,
  );

  if (!result.success) {
    print('[EMAIL_OTP] Failed to send email: ${result.error}');
    return _jsonResponse({'error': 'Failed to send verification email'}, 500);
  }

  print('[EMAIL_OTP] OTP email sent successfully: ${result.messageId}');

  // Mask email for response (e.g., t***@example.com)
  final maskedEmail = _maskEmail(email);

  return _jsonResponse({
    'success': true,
    'masked_email': maskedEmail,
    'expires_in': 600, // 10 minutes in seconds
  });
}

/// Verify email OTP code
/// POST /api/v1/portal/auth/verify-otp
/// Authorization: Bearer <Identity Platform ID token>
/// Body: { "code": "123456" }
///
/// Verifies the 6-digit OTP code entered by the user.
/// Max 5 attempts per code. Code is invalidated after successful verification.
///
/// Returns:
///   200: { "success": true, "email_otp_verified": true }
///   400: Missing or invalid code
///   401: Missing or invalid authorization
///   403: Too many attempts (code invalidated)
///   410: Code expired
///   422: Invalid code
Future<Response> verifyEmailOtpHandler(Request request) async {
  print('[EMAIL_OTP] verifyEmailOtpHandler called');

  // Extract and verify bearer token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;

  // Parse request body
  final body = await request.readAsString();
  Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final code = data['code'] as String?;
  if (code == null || code.isEmpty) {
    return _jsonResponse({'error': 'Missing code'}, 400);
  }

  // Validate code format (6 digits)
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    return _jsonResponse({'error': 'Invalid code format'}, 400);
  }

  final db = Database.instance;

  // Look up user by firebase_uid
  final userResult = await db.executeWithContext(
    'SELECT id FROM portal_users WHERE firebase_uid = @firebaseUid',
    parameters: {'firebaseUid': firebaseUid},
    context: UserContext.service,
  );

  if (userResult.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final userId = userResult.first[0] as String;
  final codeHash = hashOtpCode(code);

  // Get client IP for audit
  final clientIp =
      request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'];

  // Find valid OTP code for this user
  final otpResult = await db.executeWithContext(
    '''
    SELECT id, expires_at, attempts
    FROM email_otp_codes
    WHERE user_id = @userId::uuid
      AND code_hash = @codeHash
      AND used_at IS NULL
    ORDER BY created_at DESC
    LIMIT 1
    ''',
    parameters: {'userId': userId, 'codeHash': codeHash},
    context: UserContext.service,
  );

  if (otpResult.isEmpty) {
    // Code doesn't match - increment attempts on most recent unused code
    await _incrementAttempts(db, userId, clientIp);

    print('[EMAIL_OTP] Invalid code for user: $userId');
    return _jsonResponse({'error': 'Invalid verification code'}, 422);
  }

  final otpId = otpResult.first[0] as String;
  final expiresAt = otpResult.first[1] as DateTime;
  final attempts = otpResult.first[2] as int;

  // Check if expired (use UTC for consistent timezone handling)
  if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
    print('[EMAIL_OTP] Code expired for user: $userId');
    return _jsonResponse({
      'error': 'Verification code has expired',
      'expired': true,
    }, 410);
  }

  // Check attempt limit (already should be enforced by constraint, but double-check)
  if (attempts >= 5) {
    print('[EMAIL_OTP] Max attempts reached for user: $userId');
    return _jsonResponse({
      'error': 'Too many failed attempts. Please request a new code.',
      'max_attempts_reached': true,
    }, 403);
  }

  // Mark code as used
  await db.executeWithContext(
    '''
    UPDATE email_otp_codes
    SET used_at = now()
    WHERE id = @otpId::uuid
    ''',
    parameters: {'otpId': otpId},
    context: UserContext.service,
  );

  print('[EMAIL_OTP] OTP verified successfully for user: $userId');

  return _jsonResponse({'success': true, 'email_otp_verified': true});
}

/// Increment failed attempts on the most recent unused OTP code
Future<void> _incrementAttempts(
  Database db,
  String userId,
  String? clientIp,
) async {
  try {
    // Increment attempts and check if we hit the limit
    final result = await db.executeWithContext(
      '''
      UPDATE email_otp_codes
      SET attempts = attempts + 1
      WHERE id = (
        SELECT id FROM email_otp_codes
        WHERE user_id = @userId::uuid
          AND used_at IS NULL
          AND expires_at > now()
        ORDER BY created_at DESC
        LIMIT 1
      )
      RETURNING attempts
      ''',
      parameters: {'userId': userId},
      context: UserContext.service,
    );

    if (result.isNotEmpty) {
      final newAttempts = result.first[0] as int;
      print('[EMAIL_OTP] Attempt count for $userId: $newAttempts/5');

      // If we hit max attempts, the code is effectively invalidated
      if (newAttempts >= 5) {
        print('[EMAIL_OTP] Code invalidated due to max attempts for: $userId');
      }
    }
  } catch (e) {
    print('[EMAIL_OTP] Failed to increment attempts: $e');
  }
}

/// Mask email address for display (e.g., test@example.com -> t***@example.com)
String _maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return '***@***';

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
