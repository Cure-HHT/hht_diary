// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Gmail API integration for sending OTP and activation emails
// Uses service account with domain-wide delegation for HIPAA compliance
//
// Authentication: WIF (Workload Identity Federation)
//   - Cloud Run SA or local user impersonates Gmail SA via IAM
//   - Local dev: gcloud auth application-default login + serviceAccountTokenCreator role

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'database.dart';

/// Email service configuration from environment
class EmailConfig {
  /// Gmail service account email to impersonate via WIF
  /// Format: org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com
  final String? gmailServiceAccountEmail;

  /// Email address to send from (must exist in Google Workspace)
  final String senderEmail;

  /// Whether email sending is enabled
  final bool enabled;

  /// Console mode - logs emails to console instead of sending
  /// Useful for local development without GCP credentials
  final bool consoleMode;

  /// Display name for sender (hardcoded)
  static const senderName = 'Clinical Trial Portal';

  EmailConfig({
    this.gmailServiceAccountEmail,
    required this.senderEmail,
    required this.enabled,
    this.consoleMode = false,
  });

  /// Create config from environment variables
  factory EmailConfig.fromEnvironment() {
    return EmailConfig(
      gmailServiceAccountEmail:
          Platform.environment['GMAIL_SERVICE_ACCOUNT_EMAIL'],
      senderEmail: Platform.environment['EMAIL_SENDER'] ?? 'support@anspar.org',
      enabled: Platform.environment['EMAIL_ENABLED'] != 'false',
      consoleMode: Platform.environment['EMAIL_CONSOLE_MODE'] == 'true',
    );
  }

  /// Check if email service is properly configured
  /// Console mode counts as configured (for local development)
  bool get isConfigured =>
      enabled &&
      (consoleMode || (gmailServiceAccountEmail?.isNotEmpty ?? false));
}

/// Result of an email send operation
class EmailResult {
  final bool success;
  final String? messageId;
  final String? error;

  EmailResult.success(this.messageId) : success = true, error = null;

  EmailResult.failure(this.error) : success = false, messageId = null;
}

/// Email service singleton using Gmail API
class EmailService {
  static EmailService? _instance;
  static EmailConfig? _config;
  static gmail.GmailApi? _gmailApi;
  static DateTime? _tokenCreatedAt;

  /// Token refresh buffer - refresh 5 minutes before expiry
  static const _tokenRefreshBuffer = Duration(minutes: 5);

  /// Token lifetime - tokens are valid for 1 hour
  static const _tokenLifetime = Duration(hours: 1);

  EmailService._();

  static EmailService get instance {
    _instance ??= EmailService._();
    return _instance!;
  }

  /// Reset the service for testing purposes
  /// @visibleForTesting
  static void resetForTesting() {
    _instance = null;
    _config = null;
    _gmailApi = null;
    _tokenCreatedAt = null;
  }

  /// Check if token needs refresh (expired or about to expire)
  bool _needsTokenRefresh() {
    if (_tokenCreatedAt == null) return false;
    final tokenAge = DateTime.now().difference(_tokenCreatedAt!);
    final needsRefresh = tokenAge >= (_tokenLifetime - _tokenRefreshBuffer);
    if (needsRefresh) {
      print('[EMAIL] Token age: ${tokenAge.inMinutes} minutes - needs refresh');
    }
    return needsRefresh;
  }

  /// Refresh the Gmail API client if token is expired
  Future<void> _refreshIfNeeded() async {
    if (_config == null || _config!.consoleMode) return;
    if (!_needsTokenRefresh()) return;

    print('[EMAIL] Refreshing Gmail API token...');
    try {
      final httpClient = await _createWifClient(_config!);
      _gmailApi = gmail.GmailApi(httpClient);
      _tokenCreatedAt = DateTime.now();
      print('[EMAIL] Token refreshed successfully');
    } catch (e) {
      print('[EMAIL] Failed to refresh token: $e');
      // Don't null out _gmailApi - let it try with old token and fail explicitly
    }
  }

  /// Initialize with a mock Gmail API for testing
  /// @visibleForTesting
  static void initializeWithMock(gmail.GmailApi mockApi, EmailConfig config) {
    _instance ??= EmailService._();
    _gmailApi = mockApi;
    _config = config;
  }

  /// Initialize the email service with configuration
  ///
  /// Uses WIF: Cloud Run SA or local user impersonates Gmail SA via IAM
  /// Or console mode for local development (EMAIL_CONSOLE_MODE=true)
  Future<void> initialize(EmailConfig config) async {
    if (_gmailApi != null) return;
    _config = config;

    if (!config.isConfigured) {
      print('[EMAIL] Email service disabled or not configured');
      return;
    }

    // Console mode - just log emails, don't initialize Gmail API
    if (config.consoleMode) {
      print('[EMAIL] Console mode enabled - emails will be logged to console');
      print('[EMAIL] Email service initialized in console mode');
      return;
    }

    try {
      print('[EMAIL] Using Workload Identity Federation');
      final httpClient = await _createWifClient(config);
      _gmailApi = gmail.GmailApi(httpClient);
      _tokenCreatedAt = DateTime.now();
      print('[EMAIL] Email service initialized successfully');
    } catch (e) {
      print('[EMAIL] Failed to initialize email service: $e');
      _gmailApi = null;
      _tokenCreatedAt = null;
    }
  }

  /// Create HTTP client using Workload Identity Federation with domain-wide delegation
  ///
  /// Domain-wide delegation requires:
  /// 1. Sign a JWT with 'sub' claim (the user to impersonate, e.g., support@anspar.org)
  /// 2. Exchange the signed JWT for an access token at oauth2.googleapis.com
  ///
  /// Note: generateAccessToken API does NOT support user impersonation - it only
  /// gets a token as the service account itself. For Gmail API with domain-wide
  /// delegation, we must use signJwt with a sub claim.
  Future<http.Client> _createWifClient(EmailConfig config) async {
    print('[EMAIL_WIF] Starting WIF client creation...');
    print('[EMAIL_WIF] Gmail SA: ${config.gmailServiceAccountEmail}');
    print('[EMAIL_WIF] Sender email: ${config.senderEmail}');

    // Get Application Default Credentials (Cloud Run's identity or local user)
    print('[EMAIL_WIF] Getting Application Default Credentials...');
    final adcClient = await clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    );
    print('[EMAIL_WIF] ADC obtained successfully');

    final targetSa = config.gmailServiceAccountEmail!;
    final senderEmail = config.senderEmail;

    // Step 1: Create JWT claims with 'sub' for domain-wide delegation
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + 3600; // 1 hour expiry

    final jwtClaims = jsonEncode({
      'iss': targetSa,
      'sub': senderEmail, // The user to impersonate (domain-wide delegation)
      'scope': gmail.GmailApi.gmailSendScope,
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now,
      'exp': exp,
    });

    // Step 2: Sign the JWT using the service account
    final signUrl = Uri.parse(
      'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$targetSa:signJwt',
    );

    final signResponse = await adcClient.post(
      signUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'payload': jwtClaims}),
    );

    print('[EMAIL_WIF] Sign JWT response status: ${signResponse.statusCode}');
    if (signResponse.statusCode != 200) {
      print('[EMAIL_WIF] Sign JWT FAILED: ${signResponse.body}');
      throw Exception(
        'Failed to sign JWT for Gmail SA: ${signResponse.statusCode} ${signResponse.body}',
      );
    }

    final signData = jsonDecode(signResponse.body) as Map<String, dynamic>;
    final signedJwt = signData['signedJwt'] as String;
    print('[EMAIL_WIF] JWT signed successfully');

    // Step 3: Exchange signed JWT for access token (validates domain-wide delegation)
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$signedJwt',
    );

    print(
      '[EMAIL_WIF] Token exchange response status: ${tokenResponse.statusCode}',
    );
    if (tokenResponse.statusCode != 200) {
      print('[EMAIL_WIF] Token exchange FAILED: ${tokenResponse.body}');
      throw Exception(
        'Failed to exchange JWT for token (check domain-wide delegation): '
        '${tokenResponse.statusCode} ${tokenResponse.body}',
      );
    }

    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;
    print('[EMAIL_WIF] Token exchange successful, got access token');

    // Create authenticated client with the impersonated user's token
    return authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().add(Duration(hours: 1)).toUtc(),
        ),
        null,
        [gmail.GmailApi.gmailSendScope],
      ),
    );
  }

  /// Check if service is ready to send emails
  /// Returns true for console mode (logs to console) or when Gmail API is initialized
  bool get isReady =>
      (_config?.enabled ?? false) &&
      ((_config?.consoleMode ?? false) || _gmailApi != null);

  /// Check if running in console mode
  bool get isConsoleMode => _config?.consoleMode ?? false;

  /// Send a 6-digit OTP code via email
  Future<EmailResult> sendOtpCode({
    required String recipientEmail,
    required String code,
    String? recipientName,
  }) async {
    if (!isReady) {
      return EmailResult.failure('Email service not ready');
    }

    final subject = 'Your Clinical Trial Portal verification code';
    final bodyText =
        '''
Your verification code is: $code

This code expires in 10 minutes.

If you didn't request this code, please ignore this email or contact your administrator.

---
Clinical Trial Portal
    ''';

    final bodyHtml =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .code { font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 20px; background: #f4f4f4; border-radius: 8px; display: inline-block; }
    .footer { margin-top: 30px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <p>Your verification code is:</p>
  <p class="code">$code</p>
  <p>This code expires in <strong>10 minutes</strong>.</p>
  <p>If you didn't request this code, please ignore this email or contact your administrator.</p>
  <div class="footer">
    <p>Clinical Trial Portal</p>
  </div>
</body>
</html>
    ''';

    return _sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      emailType: 'otp',
    );
  }

  /// Send activation code to a new user
  Future<EmailResult> sendActivationCode({
    required String recipientEmail,
    required String recipientName,
    required String activationCode,
    required String activationUrl,
    String? sentByUserId,
  }) async {
    if (!isReady) {
      return EmailResult.failure('Email service not ready');
    }

    final subject = 'Welcome to Clinical Trial Portal - Activate Your Account';
    final bodyText =
        '''
Hi $recipientName,

You've been invited to Clinical Trial Portal.

To activate your account, click the link below:
$activationUrl

This link expires in 14 days.

Questions? Contact your sponsor administrator.

---
Clinical Trial Portal
    ''';

    final bodyHtml =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; }
    .footer { margin-top: 30px; color: #666; font-size: 12px; border-top: 1px solid #eee; padding-top: 20px; }
    .button { display: inline-block; background: #1976d2; color: #ffffff !important; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
  </style>
</head>
<body>
  <p>Hi <strong>$recipientName</strong>,</p>
  <p>You've been invited to <strong>Clinical Trial Portal</strong>.</p>

  <p>Click the button below to activate your account and create your password:</p>

  <p><a href="$activationUrl" class="button" style="display: inline-block; background: #1976d2; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Activate Your Account</a></p>

  <p><em>This link expires in 14 days.</em></p>
  <p>Questions? Contact your sponsor administrator.</p>

  <div class="footer">
    <p>Clinical Trial Portal</p>
  </div>
</body>
</html>
    ''';

    return _sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      emailType: 'activation',
      sentByUserId: sentByUserId,
    );
  }

  /// Send password reset link to user
  Future<EmailResult> sendPasswordResetEmail({
    required String recipientEmail,
    required String resetLink,
    String? recipientName,
  }) async {
    if (!isReady) {
      return EmailResult.failure('Email service not ready');
    }

    final greeting = recipientName != null ? 'Hi $recipientName' : 'Hello';
    final subject = 'Reset Your Clinical Trial Portal Password';
    final bodyText =
        '''
$greeting,

You requested to reset your Clinical Trial Portal password.

Click the link below to reset your password:
$resetLink

This link expires in 24 hours.

IMPORTANT SECURITY NOTICE:
- Do not share this link with anyone
- If you didn't request this password reset, please ignore this email
- Your password will not change until you create a new one using this link

Questions? Contact your administrator.

---
Clinical Trial Portal
    ''';

    final bodyHtml =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
    .footer { margin-top: 30px; color: #666; font-size: 12px; border-top: 1px solid #eee; padding-top: 20px; }
    .button { display: inline-block; background: #1976d2; color: #ffffff !important; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
    .warning { background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; padding: 12px; margin: 20px 0; }
    .warning-title { font-weight: bold; color: #856404; margin-bottom: 8px; }
  </style>
</head>
<body>
  <p>$greeting,</p>
  <p>You requested to reset your <strong>Clinical Trial Portal</strong> password.</p>

  <p>Click the button below to reset your password:</p>

  <p><a href="$resetLink" class="button" style="display: inline-block; background: #1976d2; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Reset Password</a></p>

  <p><em>This link expires in 24 hours.</em></p>

  <div class="warning">
    <div class="warning-title">IMPORTANT SECURITY NOTICE:</div>
    <ul style="margin: 0; padding-left: 20px;">
      <li>Do not share this link with anyone</li>
      <li>If you didn't request this password reset, please ignore this email</li>
      <li>Your password will not change until you create a new one using this link</li>
    </ul>
  </div>

  <p>Questions? Contact your administrator.</p>

  <div class="footer">
    <p>Clinical Trial Portal</p>
  </div>
</body>
</html>
    ''';

    return _sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      emailType: 'password_reset',
    );
  }

  /// Internal method to send email via Gmail API
  Future<EmailResult> _sendEmail({
    required String recipientEmail,
    String? recipientName,
    required String subject,
    required String bodyText,
    required String bodyHtml,
    required String emailType,
    String? sentByUserId,
  }) async {
    if (_config == null) {
      return EmailResult.failure('Email service not configured');
    }

    // Refresh token if needed before sending
    await _refreshIfNeeded();

    // Console mode - log to console instead of sending
    if (_config!.consoleMode) {
      print('');
      print('=' * 60);
      print('[EMAIL CONSOLE MODE] Would send $emailType email:');
      print('  To: ${recipientName ?? recipientEmail} <$recipientEmail>');
      print('  Subject: $subject');
      print('-' * 60);
      print(bodyText);
      print('=' * 60);
      print('');

      // Log to audit table as 'console' (local dev mode)
      await _logEmailAudit(
        recipientEmail: recipientEmail,
        emailType: emailType,
        status: 'console',
        messageId: 'console-${DateTime.now().millisecondsSinceEpoch}',
        sentByUserId: sentByUserId,
      );

      return EmailResult.success('console-mode');
    }

    if (_gmailApi == null) {
      return EmailResult.failure('Gmail API not initialized');
    }

    try {
      // Build MIME message
      final toAddress = recipientName != null
          ? '$recipientName <$recipientEmail>'
          : recipientEmail;
      final fromAddress = '${EmailConfig.senderName} <${_config!.senderEmail}>';

      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      final mimeMessage =
          '''
From: $fromAddress
To: $toAddress
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="$boundary"

--$boundary
Content-Type: text/plain; charset=utf-8

$bodyText
--$boundary
Content-Type: text/html; charset=utf-8

$bodyHtml
--$boundary--
''';

      // Encode as base64url (required by Gmail API)
      final encodedMessage = base64Url.encode(utf8.encode(mimeMessage));

      // Create Gmail message
      final message = gmail.Message()..raw = encodedMessage;

      // Send via Gmail API
      // 'me' refers to the authenticated user (impersonated sender)
      final result = await _gmailApi!.users.messages.send(
        message,
        _config!.senderEmail,
      );

      final messageId = result.id ?? 'unknown';
      print('[EMAIL] Sent $emailType email to $recipientEmail: $messageId');

      // Log to audit table
      await _logEmailAudit(
        recipientEmail: recipientEmail,
        emailType: emailType,
        status: 'sent',
        messageId: messageId,
        sentByUserId: sentByUserId,
      );

      return EmailResult.success(messageId);
    } catch (e) {
      final error = e.toString();
      print('[EMAIL] Failed to send $emailType email to $recipientEmail: $e');

      // Log failure to audit table
      await _logEmailAudit(
        recipientEmail: recipientEmail,
        emailType: emailType,
        status: 'failed',
        error: error,
        sentByUserId: sentByUserId,
      );

      return EmailResult.failure(error);
    }
  }

  /// Check rate limit for email sending
  ///
  /// Returns true if email can be sent, false if rate limited.
  /// Rate limit: max 3 emails per address per 15 minutes
  Future<bool> checkRateLimit({
    required String email,
    required String emailType,
  }) async {
    try {
      final db = Database.instance;

      // Count emails sent in last 15 minutes
      final result = await db.executeWithContext(
        '''
        SELECT COUNT(*) as count
        FROM email_rate_limits
        WHERE email = @email
          AND email_type = @email_type
          AND sent_at > NOW() - INTERVAL '15 minutes'
        ''',
        parameters: {'email': email, 'email_type': emailType},
        context: UserContext.service,
      );

      final count = result.first[0] as int;
      return count < 3;
    } catch (e) {
      print('[EMAIL] Rate limit check failed: $e');
      // Allow email if check fails (fail open for better UX)
      return true;
    }
  }

  /// Record email send for rate limiting
  Future<void> recordRateLimit({
    required String email,
    required String emailType,
    String? ipAddress,
  }) async {
    try {
      final db = Database.instance;

      await db.executeWithContext(
        '''
        INSERT INTO email_rate_limits (email, email_type, ip_address)
        VALUES (@email, @email_type, @ip_address::inet)
        ''',
        parameters: {
          'email': email,
          'email_type': emailType,
          'ip_address': ipAddress,
        },
        context: UserContext.service,
      );
    } catch (e) {
      print('[EMAIL] Failed to record rate limit: $e');
    }
  }

  /// Log email to audit table (FDA compliance)
  Future<void> _logEmailAudit({
    required String recipientEmail,
    required String emailType,
    required String status,
    String? messageId,
    String? error,
    String? sentByUserId,
  }) async {
    try {
      final db = Database.instance;

      await db.executeWithContext(
        '''
        INSERT INTO email_audit_log
          (recipient_email, email_type, status, gmail_message_id, error_message, sent_by, metadata)
        VALUES
          (@recipient_email, @email_type, @status, @message_id, @error, @sent_by::uuid, @metadata::jsonb)
        ''',
        parameters: {
          'recipient_email': recipientEmail,
          'email_type': emailType,
          'status': status,
          'message_id': messageId,
          'error': error,
          'sent_by': sentByUserId,
          'metadata': jsonEncode({
            'masked_email': _maskEmail(recipientEmail),
            'timestamp': DateTime.now().toIso8601String(),
          }),
        },
        context: UserContext.service,
      );
    } catch (e) {
      print('[EMAIL] Failed to log email audit: $e');
    }
  }

  /// Mask email address for display/logging (e.g., t***@example.com)
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '***';

    final local = parts[0];
    final domain = parts[1];

    if (local.length <= 2) {
      return '${local[0]}***@$domain';
    } else {
      return '${local[0]}***@$domain';
    }
  }
}

/// Generate a cryptographically secure 6-digit OTP code
String generateOtpCode() {
  final secureRandom = Random.secure();
  final digits = List<int>.generate(6, (_) => secureRandom.nextInt(10));
  return digits.join();
}

/// Hash an OTP code using SHA-256
String hashOtpCode(String code) {
  final bytes = utf8.encode(code);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
