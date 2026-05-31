// Implements: DIARY-DEV-portal-reaction-server/B — establishes a Principal per
//   connection/request. Dev-only: trusts a "userId:activeRole" credential; the
//   SP1/SP2 policy still enforces every action against the event-derived seed, so
//   a claimed role with no user_role_scopes assignment is denied. Replaced by an
//   Identity Platform validator in production.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

class DevCredentialAuthValidator implements PrincipalAuthValidator {
  const DevCredentialAuthValidator();

  @override
  Future<Principal> authenticate(String credential) async {
    final parts = credential.split(':');
    if (parts.length != 2) {
      throw const AuthenticationDenied('expected "userId:activeRole"');
    }
    final userId = parts[0].trim();
    final activeRole = parts[1].trim();
    if (userId.isEmpty || activeRole.isEmpty) {
      throw const AuthenticationDenied(
          'userId and activeRole must be non-empty');
    }
    return Principal.user(
      userId: userId,
      roles: <String>{activeRole},
      activeRole: activeRole,
    );
  }
}
