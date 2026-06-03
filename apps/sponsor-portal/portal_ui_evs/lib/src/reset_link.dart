/// Returns the `reset` query parameter from a reset URL, or null.
// Implements: DIARY-GUI-password-forgot-workflow/L
String? resetCodeFromUri(Uri uri) {
  final code = uri.queryParameters['reset'];
  return (code == null || code.isEmpty) ? null : code;
}
