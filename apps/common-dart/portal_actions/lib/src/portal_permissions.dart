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
  'ACT-USR-001': const Permission('portal.user.create'),
  'ACT-USR-002': const Permission('portal.user.edit'),
  'ACT-USR-003': const Permission('portal.user.deactivate'),
  'ACT-USR-004': const Permission('portal.user.reactivate'),
  'ACT-USR-005': const Permission('portal.user.unlock'),
  'ACT-USR-006': const Permission('portal.user.resend_activation'),
  'ACT-USR-007': const Permission('portal.user.assign_role'),
  'ACT-USR-008': const Permission('portal.user.assign_site'),
  'ACT-USR-009': const Permission('portal.user.delete_pending'),
  'ACT-SIT-001': const Permission('portal.site.view'),
  'ACT-AUD-001': const Permission('portal.audit.view'),
  'ACT-ADM-001': const Permission('portal.admin.view_settings'),
  // Operations (DIARY-BASE-ops-action-inventory): unscoped, ops-only.
  'ACT-OPS-001': const Permission('portal.rave.unwedge'),
  'ACT-OPS-002': const Permission('portal.user.create_sysop'),
  'ACT-OPS-003': const Permission('portal.user.create_admin'),
};
