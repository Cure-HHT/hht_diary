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
}
