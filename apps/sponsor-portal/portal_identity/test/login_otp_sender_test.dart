import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-login-second-factor/A
  test('LoginOtpSender renders + sends the code through its transport',
      () async {
    final lines = <String>[];
    final sender = LoginOtpSender(transport: ConsoleTransport(out: lines.add));
    await sender.sendOtp(recipientEmail: 'jane@site.org', code: '654321');
    final joined = lines.join('\n');
    expect(joined, contains('jane@site.org'));
    expect(joined, contains('654321'));
  });
}
