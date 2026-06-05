// Implements: DIARY-PRD-two-factor-authentication/B (client-side form gating)
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) => _emailRe.hasMatch(email);

bool loginFormReady({required String email, required String password}) =>
    isValidEmail(email) && password.isNotEmpty;

bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);

sealed class LoginNext {
  const LoginNext();
  const factory LoginNext.session(String token) = LoginNextSession;
  const factory LoginNext.otp(String maskedEmail) = LoginNextOtp;
}

final class LoginNextSession extends LoginNext {
  final String token;
  const LoginNextSession(this.token);
  @override
  bool operator ==(Object other) =>
      other is LoginNextSession && other.token == token;
  @override
  int get hashCode => token.hashCode;
}

final class LoginNextOtp extends LoginNext {
  final String maskedEmail;
  const LoginNextOtp(this.maskedEmail);
  @override
  bool operator ==(Object other) =>
      other is LoginNextOtp && other.maskedEmail == maskedEmail;
  @override
  int get hashCode => maskedEmail.hashCode;
}

/// Decides the post-/login step: a session token (2FA disabled) goes straight
/// to the authed shell; otherwise the masked email drives the OTP screen.
// Implements: DIARY-DEV-portal-second-factor-toggle/C
LoginNext loginNextStep(Map<String, Object?> body) {
  final token = body['sessionToken'];
  if (token is String && token.isNotEmpty) return LoginNext.session(token);
  return LoginNext.otp((body['maskedEmail'] as String?) ?? '');
}
