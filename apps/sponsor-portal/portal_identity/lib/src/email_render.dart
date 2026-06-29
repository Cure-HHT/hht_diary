// Implements: DIARY-DEV-portal-activation-email-delivery/A+B
class RenderedEmail {
  const RenderedEmail(
      {required this.subject, required this.text, required this.html});
  final String subject;
  final String text;
  final String html;
}

RenderedEmail buildActivationEmail({
  required String recipientEmail,
  required String activationUrl,
}) {
  const subject = 'Activate your Sponsor Portal account';
  final text = '''
Welcome to the Sponsor Portal.

Activate your account and set your password using the link below
(valid for a limited time, single use):

$activationUrl

If you did not expect this email, contact your Administrator.
''';
  final html = '''
<p>Welcome to the Sponsor Portal.</p>
<p>Activate your account and set your password using the link below
(valid for a limited time, single use):</p>
<p><a href="$activationUrl">$activationUrl</a></p>
<p>If you did not expect this email, contact your Administrator.</p>
''';
  return RenderedEmail(subject: subject, text: text, html: html);
}

// Implements: DIARY-DEV-portal-login-second-factor/A
RenderedEmail buildOtpEmail({
  required String recipientEmail,
  required String code,
}) {
  const subject = 'Your Sponsor Portal verification code';
  final text = '''
Your one-time verification code is:

    $code

Enter it to finish signing in. It expires shortly and can be used once.
If you did not try to sign in, contact your Administrator.
''';
  final html = '''
<p>Your one-time verification code is:</p>
<p style="font-size:24px;font-weight:bold;letter-spacing:3px">$code</p>
<p>Enter it to finish signing in. It expires shortly and can be used once.</p>
<p>If you did not try to sign in, contact your Administrator.</p>
''';
  return RenderedEmail(subject: subject, text: text, html: html);
}

// Implements: DIARY-DEV-portal-reset-code-lifecycle/A
RenderedEmail buildPasswordResetEmail({
  required String recipientEmail,
  required String resetUrl,
}) {
  const subject = 'Reset your Sponsor Portal password';
  final text = '''
We received a request to reset your Sponsor Portal password.

Set a new password using the link below (valid for 24 hours, single use):

$resetUrl

If you did not request this, you can ignore this email — your password is unchanged.
''';
  final html = '''
<p>We received a request to reset your Sponsor Portal password.</p>
<p>Set a new password using the link below (valid for 24 hours, single use):</p>
<p><a href="$resetUrl">$resetUrl</a></p>
<p>If you did not request this, you can ignore this email — your password is unchanged.</p>
''';
  return RenderedEmail(subject: subject, text: text, html: html);
}

/// Masks an email to `x***@y***.tld` so responses never echo the full address.
// Implements: DIARY-DEV-portal-activation-email-delivery/B
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return '***';
  final local = email.substring(0, at);
  final domain = email.substring(at + 1);
  final dot = domain.lastIndexOf('.');
  final dom = dot <= 0 ? domain : domain.substring(0, dot);
  final tld = dot <= 0 ? '' : domain.substring(dot); // includes leading '.'
  return '${local[0]}***@${dom[0]}***$tld';
}
