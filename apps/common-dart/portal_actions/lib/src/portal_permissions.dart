// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

/// Permission for each DIARY-PRD-action-inventory action, keyed by ACT id.
/// Scoped permissions declare scopeClass for the future scope-aware policy
/// (CUR-1331); coarse-grained today.
final Map<String, Permission> portalPermissionsByActId = <String, Permission>{
  'ACT-PAT-001': const Permission(
    'portal.participant.link',
    scopeClass: 'site',
  ),
  'ACT-PAT-002': const Permission(
    'portal.participant.start_trial',
    scopeClass: 'site',
  ),
  'ACT-PAT-003': const Permission(
    'portal.participant.disconnect',
    scopeClass: 'site',
  ),
  'ACT-PAT-004': const Permission(
    'portal.participant.reconnect',
    scopeClass: 'site',
  ),
  'ACT-PAT-005': const Permission(
    'portal.participant.mark_not_participating',
    scopeClass: 'site',
  ),
  'ACT-PAT-006': const Permission(
    'portal.participant.reactivate',
    scopeClass: 'site',
  ),
  'ACT-PAT-007': const Permission(
    'portal.participant.view',
    scopeClass: 'site',
  ),
  'ACT-QST-001': const Permission(
    'portal.questionnaire.send',
    scopeClass: 'site',
  ),
  'ACT-QST-002': const Permission(
    'portal.questionnaire.call_back',
    scopeClass: 'site',
  ),
  'ACT-QST-003': const Permission(
    'portal.questionnaire.finalize',
    scopeClass: 'site',
  ),
  'ACT-QST-004': const Permission(
    'portal.questionnaire.unlock',
    scopeClass: 'site',
  ),
  // ACT-USR-001 (create) is UNSCOPED: a new account has no tier yet, so there
  // is no target-tier to gate on; the create_admin/create_sysop ops actions
  // (ACT-OPS-002/003) carry the privileged-creation authority instead.
  'ACT-USR-001': const Permission('portal.user.create'),
  // Implements: DIARY-DEV-operator-tier-authz/B — the target-bearing user-
  //   management permissions are tier-scoped via the `user` scope class
  //   (user-contained-in-tier), so a non-operator cannot modify a System
  //   Operator account. scopeFor returns BoundScope('user', target userId).
  'ACT-USR-002': const Permission('portal.user.edit', scopeClass: 'user'),
  'ACT-USR-003': const Permission('portal.user.deactivate', scopeClass: 'user'),
  'ACT-USR-004': const Permission('portal.user.reactivate', scopeClass: 'user'),
  'ACT-USR-005': const Permission('portal.user.unlock', scopeClass: 'user'),
  'ACT-USR-006': const Permission(
    'portal.user.resend_activation',
    scopeClass: 'user',
  ),
  'ACT-USR-007': const Permission(
    'portal.user.assign_role',
    scopeClass: 'user',
  ),
  // Implements: DIARY-DEV-operator-tier-authz/B — the escalation axis: granting
  //   the SystemOperator role is gated on the `tier` scope class (operator),
  //   independent of the assign_role target gate above. AssignRoleAction
  //   declares BOTH this and portal.user.assign_role.
  'ACT-USR-007-GRANT': const Permission(
    'portal.user.grant_role',
    scopeClass: 'tier',
  ),
  'ACT-USR-008': const Permission(
    'portal.user.assign_site',
    scopeClass: 'user',
  ),
  'ACT-USR-009': const Permission(
    'portal.user.delete_pending',
    scopeClass: 'user',
  ),
  'ACT-USR-010': const Permission(
    'portal.user.revoke_role',
    scopeClass: 'user',
  ),
  'ACT-USR-011': const Permission(
    'portal.user.revoke_site',
    scopeClass: 'user',
  ),
  'ACT-SIT-001': const Permission('portal.site.view', scopeClass: 'site'),
  'ACT-AUD-001': const Permission('portal.audit.view'),
  'ACT-ADM-001': const Permission('portal.admin.view_settings'),
  // Operations (DIARY-BASE-ops-action-inventory): unscoped, ops-only.
  'ACT-OPS-001': const Permission('portal.rave.unwedge'),
  'ACT-OPS-002': const Permission('portal.user.create_sysop'),
  'ACT-OPS-003': const Permission('portal.user.create_admin'),
};
