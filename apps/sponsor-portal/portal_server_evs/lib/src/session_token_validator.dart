import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

import 'session_store.dart';
import 'session_token.dart';

/// Named-role priority for choosing a default/fallback active role. Highest
/// privilege first (mirrors the reaction example's RoleAwareTrustingValidator).
const List<String> kPortalRolePriority = <String>[
  'SystemOperator',
  'Administrator',
  'CRA',
  'StudyCoordinator',
];

/// Picks the highest-priority role from [roles].
String highestPriorityRole(Set<String> roles) =>
    kPortalRolePriority.firstWhere(roles.contains, orElse: () => roles.first);

/// The single enforcement point for session auth. Verifies the HMAC token,
/// checks the session is live (sessions_index, not terminated) and not
/// idle-expired, resolves roles from user_role_scopes, and resolves the active
/// role from the per-request credential claim: the credential may be either
/// `<token>` or `<token>|<role>`. If a role is claimed and the user holds it,
/// that role is active; otherwise the highest-priority held role is used.
// Implements: DIARY-DEV-portal-session-token/B
// Implements: DIARY-DEV-portal-session-lifecycle/A+C
// Implements: DIARY-DEV-portal-active-role-switch/A+B+C
class SessionTokenValidator implements PrincipalAuthValidator {
  SessionTokenValidator({
    required this.signingKey,
    required this.backend,
    required this.eventStore,
    required this.sessionStore,
    required this.idleTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String signingKey;
  final StorageBackend backend;
  final EventStore eventStore;
  final SessionStore sessionStore;
  final Duration idleTimeout;
  final DateTime Function() _now;

  @override
  // Implements: DIARY-DEV-portal-active-role-switch/A+B+C
  Future<Principal> authenticate(String credential) async {
    // Split optional role claim: credential is `<token>` or `<token>|<role>`.
    // Session tokens use base64url + hex — '|' never appears in a bare token.
    final sep = credential.indexOf('|');
    final tokenStr = sep < 0 ? credential : credential.substring(0, sep);
    final claimedRole = sep < 0 ? null : credential.substring(sep + 1);

    final token = parseSessionToken(tokenStr, signingKey: signingKey);
    if (token == null) throw const AuthenticationDenied('bad session token');

    // Session must be live (a terminated session has no sessions_index row).
    final sessions = await backend.findViewRows('sessions_index');
    Map<String, Object?>? row;
    for (final r in sessions) {
      if (r['aggregateId'] == token.sid) {
        row = r;
        break;
      }
    }
    if (row == null) throw const AuthenticationDenied('session not live');

    // Idle check.
    final now = _now();
    final last = sessionStore.lastSeen(token.sid);
    if (last != null && now.difference(last) > idleTimeout) {
      await _terminate(token.sid, 'idle');
      sessionStore.forget(token.sid);
      throw const AuthenticationDenied('session idle-expired');
    }

    // Roles from the authoritative user_role_scopes view.
    final scopeRows = await backend.findViewRows('user_role_scopes');
    final roles = <String>{
      for (final r in scopeRows)
        if (r['user_id'] == token.userId) r['role']! as String,
    };
    if (roles.isEmpty) throw const AuthenticationDenied('no roles');

    // Active role from the per-request claim; fall back to highest-priority if
    // no claim is present or the claimed role is not currently held.
    final activeRole = (claimedRole != null && roles.contains(claimedRole))
        ? claimedRole
        : highestPriorityRole(roles);

    sessionStore.touch(token.sid, now);
    return UserPrincipal(
        userId: token.userId, roles: roles, activeRole: activeRole);
  }

  // Implements: DIARY-DEV-portal-session-lifecycle/C
  Future<void> _terminate(String sid, String reason) => eventStore.append(
        entryType: 'session_terminated',
        aggregateType: 'session',
        aggregateId: sid,
        eventType: 'session_terminated',
        data: <String, Object?>{'reason': reason},
        initiator: const AutomationInitiator(service: 'session-idle'),
      );
}
