// Implements: DIARY-PRD-role-definitions/A
// Implements: DIARY-BASE-system-operator-role/A+B

/// Declarative role-permission seed for the portal server. Top-level `roles:`
/// names the four portal roles; `grants:` maps each role to the permission
/// NAMES it holds. Every granted name must be declared by a registered action
/// (see portal_permissions.dart); `bootstrapActionPermissions` validates this.
const String portalRoleSeedYaml = '''
roles:
  - StudyCoordinator
  - CRA
  - Administrator
  - SystemOperator
grants:
  StudyCoordinator:
    - portal.participant.link
    - portal.participant.start_trial
    - portal.participant.disconnect
    - portal.participant.reconnect
    - portal.participant.mark_not_participating
    - portal.participant.reactivate
    - portal.participant.view
    - portal.questionnaire.send
    - portal.questionnaire.call_back
    - portal.questionnaire.finalize
    - portal.questionnaire.unlock
    - portal.site.view
  CRA:
    - portal.participant.view
    - portal.site.view
    - portal.audit.view
  Administrator:
    - portal.participant.view
    - portal.site.view
    - portal.user.create
    - portal.user.create_admin
    - portal.user.edit
    - portal.user.deactivate
    - portal.user.reactivate
    - portal.user.unlock
    - portal.user.resend_activation
    - portal.user.assign_role
    # Implements: DIARY-DEV-operator-tier-authz/B — the Administrator may grant
    #   staff-tier roles (its tier scope assignment is BoundScope(tier, staff)),
    #   so grant_role here is satisfied only when assigning a non-operator role.
    - portal.user.grant_role
    - portal.user.assign_site
    - portal.user.revoke_role
    - portal.user.revoke_site
    - portal.user.delete_pending
    - portal.audit.view
    - portal.admin.view_settings
  SystemOperator:
    - portal.rave.unwedge
    - portal.user.create_sysop
    - portal.user.create_admin
    # Implements: DIARY-DEV-operator-tier-authz/F — the System Operator holds the
    #   same user-management permissions as the Administrator PLUS grant_role, and
    #   (via an operator-tier wildcard scope assignment) may exercise them against
    #   operator-tier accounts an Administrator cannot reach. This includes the
    #   base portal.user.create the UI provisioning flow submits (ACT-USR-001) —
    #   the operator-tier is the role that provisions the first Administrators, so
    #   it must be able to create accounts, not only the create_admin/_sysop ops
    #   variants.
    - portal.user.create
    - portal.user.grant_role
    - portal.user.edit
    - portal.user.deactivate
    - portal.user.reactivate
    - portal.user.unlock
    - portal.user.resend_activation
    - portal.user.assign_role
    - portal.user.assign_site
    - portal.user.revoke_role
    - portal.user.revoke_site
    - portal.user.delete_pending
''';
