import 'package:portal_screens/portal_screens.dart' show isValidUserEmail;

// Implements: DIARY-PRD-two-factor-authentication/B (client-side form gating)
// Single email-format rule shared with the Create/Edit User form —
// defined once in portal_screens (the package this app already depends
// on), delegated to here.
bool isValidEmail(String email) => isValidUserEmail(email);

bool loginFormReady({required String email, required String password}) =>
    isValidEmail(email) && password.isNotEmpty;

bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);

/// Minimum password length enforced client-side for inline feedback. The
/// server remains authoritative on the real policy.
// Implements: DIARY-GUI-password-forgot-workflow/P
const int minPasswordLength = 8;

/// Whether [pw] satisfies the client-side length policy.
// Implements: DIARY-GUI-password-forgot-workflow/P
bool meetsPasswordPolicy(String pw) => pw.length >= minPasswordLength;

/// Sign-in failure messages. A transport failure must NOT blame the
/// user's credentials — "check your email and password" when the auth
/// service was unreachable sends the user on a futile password-reset
/// loop (seen on the local-stack when the auth emulator restarts under
/// an open page).
const String credentialSignInError =
    'Sign-in failed. Check your email and password.';
const String unreachableSignInError =
    'Could not reach the sign-in service. Check your connection and '
    'try again.';
const String tooManyAttemptsSignInError =
    'Too many sign-in attempts. Wait a moment and try again.';
const String serverSignInError =
    'The sign-in service reported an error. Try again in a moment.';

/// Maps a FirebaseAuthException code to the login banner message.
/// Unknown codes stay on the credential message so nothing internal
/// leaks to the form.
String signInErrorForAuthCode(String code) => switch (code) {
  'network-request-failed' => unreachableSignInError,
  'too-many-requests' => tooManyAttemptsSignInError,
  _ => credentialSignInError,
};

/// Maps a non-200 POST /login status to the banner message: 5xx is a
/// server-side fault, anything else is treated as a rejected login.
String signInErrorForLoginStatus(int statusCode) =>
    statusCode >= 500 ? serverSignInError : credentialSignInError;

sealed class LoginNext {
  const LoginNext();
  const factory LoginNext.session(String token, {String? displayName}) =
      LoginNextSession;
  const factory LoginNext.otp(String maskedEmail) = LoginNextOtp;
}

final class LoginNextSession extends LoginNext {
  final String token;

  /// The user's human name from the login response, used to greet them by
  /// name on the role-selection screen. Null when the server didn't supply
  /// one (the client then falls back to the email).
  // Implements: DIARY-GUI-role-switching/H
  final String? displayName;
  const LoginNextSession(this.token, {this.displayName});
  @override
  bool operator ==(Object other) =>
      other is LoginNextSession &&
      other.token == token &&
      other.displayName == displayName;
  @override
  int get hashCode => Object.hash(token, displayName);
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
  if (token is String && token.isNotEmpty) {
    return LoginNext.session(
      token,
      displayName: body['displayName'] as String?,
    );
  }
  return LoginNext.otp((body['maskedEmail'] as String?) ?? '');
}
