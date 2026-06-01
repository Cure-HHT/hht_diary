import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

void main() {
  test('activation email contains the link and recipient', () {
    final e = buildActivationEmail(
        recipientEmail: 'jane@site.org',
        activationUrl: 'https://p/activate?code=AB-CD');
    expect(e.subject, contains('Activate'));
    expect(e.text, contains('https://p/activate?code=AB-CD'));
    expect(e.html, contains('https://p/activate?code=AB-CD'));
  });

  test('maskEmail hides the local part and domain', () {
    expect(maskEmail('jane@site.org'), 'j***@s***.org');
    expect(maskEmail('a@b.io'), 'a***@b***.io');
  });

  test('otp email contains the code and recipient context', () {
    final e = buildOtpEmail(recipientEmail: 'jane@site.org', code: '123456');
    expect(e.subject, contains('verification code'));
    expect(e.text, contains('123456'));
    expect(e.html, contains('123456'));
  });
}
