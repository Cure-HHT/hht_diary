/// Returns the `code` query parameter from an activation URL, or null.
// Implements: DIARY-PRD-user-account-activation-workflow/A
String? activationCodeFromUri(Uri uri) {
  final code = uri.queryParameters['code'];
  return (code == null || code.isEmpty) ? null : code;
}

/// True when both passwords are non-empty and equal.
// Implements: DIARY-PRD-user-account-activation-workflow/C
bool passwordsMatch(String a, String b) => a.isNotEmpty && a == b;
