import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

import 'session_token_validator.dart' show highestPriorityRole;

/// Dev-only validator. Trusts the supplied identity (`<userId>` with an optional
/// `|<role>` claim) — NO password/token — but resolves the user's roles from the
/// event-derived `user_role_scopes` view (like the production session validator)
/// and honors the optional role claim, defaulting to the highest-priority held
/// role. The SP1/SP2 policy still enforces every action. Replaced by the session
/// validator in production (PORTAL_AUTH_MODE=session).
// Implements: DIARY-DEV-portal-reaction-server/B
class DevCredentialAuthValidator implements PrincipalAuthValidator {
  const DevCredentialAuthValidator({required this.backend});

  final StorageBackend backend;

  @override
  Future<Principal> authenticate(String credential) async {
    final sep = credential.indexOf('|');
    final userId = (sep < 0 ? credential : credential.substring(0, sep)).trim();
    final claimedRole = sep < 0 ? null : credential.substring(sep + 1).trim();
    if (userId.isEmpty) {
      throw const AuthenticationDenied('userId must be non-empty');
    }
    final scopeRows = await backend.findViewRows('user_role_scopes');
    final roles = <String>{
      for (final r in scopeRows)
        if (r['user_id'] == userId) r['role']! as String,
    };
    if (roles.isEmpty) throw const AuthenticationDenied('no roles for user');
    final activeRole = (claimedRole != null &&
            claimedRole.isNotEmpty &&
            roles.contains(claimedRole))
        ? claimedRole
        : highestPriorityRole(roles);
    return Principal.user(userId: userId, roles: roles, activeRole: activeRole);
  }
}
