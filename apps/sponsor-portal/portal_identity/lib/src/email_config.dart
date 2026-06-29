import 'dart:io';

// Implements: DIARY-DEV-portal-activation-email-delivery/A
/// Email configuration from environment. Console mode logs the rendered email
/// instead of sending (local dev without GCP credentials).
class EmailConfig {
  EmailConfig({
    this.gmailServiceAccountEmail,
    required this.senderEmail,
    required this.enabled,
    this.consoleMode = false,
  });

  final String? gmailServiceAccountEmail;
  final String senderEmail;
  final bool enabled;
  final bool consoleMode;

  static const senderName = 'Sponsor Portal';

  factory EmailConfig.fromEnvironment() => EmailConfig(
        gmailServiceAccountEmail: Platform.environment['EMAIL_SVC_ACCT'],
        senderEmail:
            Platform.environment['EMAIL_SENDER'] ?? 'support@anspar.org',
        enabled: Platform.environment['EMAIL_ENABLED'] != 'false',
        consoleMode: Platform.environment['EMAIL_CONSOLE_MODE'] == 'true',
      );

  bool get isConfigured =>
      enabled &&
      (consoleMode || (gmailServiceAccountEmail?.isNotEmpty ?? false));
}
