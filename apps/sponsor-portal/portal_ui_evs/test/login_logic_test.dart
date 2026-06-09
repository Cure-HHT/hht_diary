import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/login_logic.dart';

void main() {
  // Verifies: DIARY-DEV-portal-login-second-factor/B
  test('isValidEmail', () {
    expect(isValidEmail('a@b.org'), isTrue);
    expect(isValidEmail('nope'), isFalse);
    expect(isValidEmail(''), isFalse);
  });
  test('loginFormReady requires email + non-empty password', () {
    expect(loginFormReady(email: 'a@b.org', password: 'pw'), isTrue);
    expect(loginFormReady(email: 'a@b.org', password: ''), isFalse);
    expect(loginFormReady(email: 'bad', password: 'pw'), isFalse);
  });
  test('isValidOtp requires exactly 6 digits', () {
    expect(isValidOtp('123456'), isTrue);
    expect(isValidOtp('12345'), isFalse);
    expect(isValidOtp('12345a'), isFalse);
  });

  // Verifies: DIARY-GUI-password-forgot-workflow/P
  test('meetsPasswordPolicy enforces the minimum length', () {
    expect(minPasswordLength, 8);
    expect(meetsPasswordPolicy('1234567'), isFalse);
    expect(meetsPasswordPolicy('12345678'), isTrue);
    expect(meetsPasswordPolicy(''), isFalse);
  });

  // Verifies: DIARY-DEV-portal-second-factor-toggle/C
  test('loginNextStep: a session token routes straight to the session', () {
    expect(
      loginNextStep({'sessionToken': 'abc'}),
      const LoginNext.session('abc'),
    );
  });
  test(
    'loginNextStep: no token falls back to the OTP step with masked email',
    () {
      expect(
        loginNextStep({'maskedEmail': 'a***@x'}),
        const LoginNext.otp('a***@x'),
      );
    },
  );
  test('loginNextStep: empty token is treated as OTP fallback', () {
    expect(
      loginNextStep({'sessionToken': '', 'maskedEmail': 'b***@y'}),
      const LoginNext.otp('b***@y'),
    );
  });
}
