// Implements: DIARY-PRD-two-factor-authentication/B (client-side form gating)
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) => _emailRe.hasMatch(email);

bool loginFormReady({required String email, required String password}) =>
    isValidEmail(email) && password.isNotEmpty;

bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);
