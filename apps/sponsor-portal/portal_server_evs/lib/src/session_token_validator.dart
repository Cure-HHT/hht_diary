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
/// idle-expired, resolves roles from user_role_scopes and the active role from
/// session state, and returns the Principal.
// Implements: DIARY-DEV-portal-session-token/B
// Implements: DIARY-DEV-portal-session-lifecycle/A+C
// Implements: DIARY-DEV-portal-active-role-switch/A+C
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
  Future<Principal> authenticate(String credential) async {
    final token = parseSessionToken(credential, signingKey: signingKey);
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

    // Active role from session state; fall back to highest-priority if the
    // stored role is no longer held (cascade race).
    final stored = row['active_role'] as String?;
    final activeRole = (stored != null && roles.contains(stored))
        ? stored
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
