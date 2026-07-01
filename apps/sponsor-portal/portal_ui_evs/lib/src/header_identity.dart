import 'package:event_sourcing/event_sourcing.dart';

/// Resolves the identity label shown in the portal header's right cluster.
///
/// The session [Principal] carries only the account identifier (the login
/// email); the human display name is supplied separately by the login
/// response and threaded down from the app state. Prefer the display name so
/// the header reads "Dr. Emily Parker" rather than the raw
/// `elyakolyadina48@gmail.com`; fall back to the account identifier only when
/// no name is on hand (e.g. a session restored without a fresh login, so the
/// login response's name never arrived).
///
/// This mirrors the role-selection screen's greet-by-name rule
/// (DIARY-GUI-role-switching/H) applied to the always-visible header — no
/// header-specific assertion exists yet, so the behaviour is documented here.
String headerUserName(Principal principal, String? displayName) {
  final trimmed = displayName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return switch (principal) {
    UserPrincipal(:final userId) => userId,
    final p => p.id,
  };
}
