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

  /// Display name for sender (hardcoded)
  static const senderName = 'Clinical Trial Portal';

  EmailConfig({
    this.gmailServiceAccountEmail,
    required this.senderEmail,
    required this.enabled,
  });

  /// Create config from environment variables
  factory EmailConfig.fromEnvironment() {
    return EmailConfig(
      gmailServiceAccountEmail:
          Platform.environment['GMAIL_SERVICE_ACCOUNT_EMAIL'],
      senderEmail: Platform.environment['EMAIL_SENDER'] ?? 'support@anspar.org',
      enabled: Platform.environment['EMAIL_ENABLED'] != 'false',
    );
  }

  /// Check if email service is properly configured
  bool get isConfigured =>
      enabled && (gmailServiceAccountEmail?.isNotEmpty ?? false);
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
  Future<void> initialize(EmailConfig config) async {
    if (_gmailApi != null) return;
    _config = config;

    if (!config.isConfigured) {
      print('[EMAIL] Email service disabled or not configured');
      return;
    }

    try {
      print('[EMAIL] Using Workload Identity Federation');
      final httpClient = await _createWifClient(config);
      _gmailApi = gmail.GmailApi(httpClient);
      print('[EMAIL] Email service initialized successfully');
    } catch (e) {
      print('[EMAIL] Failed to initialize email service: $e');
      _gmailApi = null;
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
    // Get Application Default Credentials (Cloud Run's identity or local user)
    final adcClient = await clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    );

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

    if (signResponse.statusCode != 200) {
      throw Exception(
        'Failed to sign JWT for Gmail SA: ${signResponse.statusCode} ${signResponse.body}',
      );
    }

    final signData = jsonDecode(signResponse.body) as Map<String, dynamic>;
    final signedJwt = signData['signedJwt'] as String;

    // Step 3: Exchange signed JWT for access token (validates domain-wide delegation)
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$signedJwt',
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception(
        'Failed to exchange JWT for token (check domain-wide delegation): '
        '${tokenResponse.statusCode} ${tokenResponse.body}',
      );
    }

    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;

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
  bool get isReady => _gmailApi != null && (_config?.enabled ?? false);

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
    if (_gmailApi == null || _config == null) {
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
