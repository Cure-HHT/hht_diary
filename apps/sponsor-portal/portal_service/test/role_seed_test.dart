import 'package:portal_actions/portal_actions.dart';
import 'package:portal_service/portal_service.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('every granted permission name is a declared action permission', () {
    final declared = buildPortalActionRegistry().allDeclaredPermissions
        .map((p) => p.name)
        .toSet();
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final grants = doc['grants'] as YamlMap;
    for (final entry in grants.entries) {
      for (final perm in (entry.value as YamlList)) {
        expect(
          declared,
          contains(perm as String),
          reason: 'seed grants undeclared permission "$perm" to ${entry.key}',
        );
      }
    }
  });

  test('declares the 4 roles', () {
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final roles = (doc['roles'] as YamlList).cast<String>().toSet();
    expect(roles, {
      'StudyCoordinator',
      'CRA',
      'Administrator',
      'SystemOperator',
    });
  });

  // Verifies: DIARY-DEV-operator-tier-authz/F — the SystemOperator holds the ops
  //   perms PLUS the full user-management set (incl. grant_role); paired with an
  //   operator-tier wildcard scope assignment it may manage operator-tier
  //   accounts an Administrator (staff-tier) cannot reach.
  test('SystemOperator holds ops perms + user-management set; '
      'CRA holds no mutations', () {
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final grants = doc['grants'] as YamlMap;
    final sysop = (grants['SystemOperator'] as YamlList).cast<String>().toSet();
    expect(sysop, {
      'portal.rave.unwedge',
      'portal.user.create_sysop',
      'portal.user.create_admin',
      // The base create permission the UI provisioning flow submits
      // (ACT-USR-001); the SystemOperator must hold it to provision the first
      // Administrators, matching the Administrator's user-management set.
      'portal.user.create',
      'portal.user.grant_role',
      'portal.user.edit',
      'portal.user.deactivate',
      'portal.user.reactivate',
      'portal.user.unlock',
      'portal.user.resend_activation',
      'portal.user.assign_role',
      'portal.user.assign_site',
      'portal.user.revoke_role',
      'portal.user.revoke_site',
      'portal.user.delete_pending',
    });
    // The SystemOperator's user-management set is a SUPERSET of the
    // Administrator's (same user-management perms PLUS grant_role + the ops
    // create_sysop/create_admin), so anything the Administrator can do to
    // provision users, the operator can too.
    final adminUserMgmt = (grants['Administrator'] as YamlList)
        .cast<String>()
        .where((p) => p.startsWith('portal.user.'))
        .toSet();
    expect(
      sysop,
      containsAll(adminUserMgmt),
      reason: 'SystemOperator must hold every Administrator user-mgmt perm',
    );
    // The Administrator holds grant_role (staff-tier-scoped at assignment time).
    final admin = (grants['Administrator'] as YamlList).cast<String>().toSet();
    expect(admin, contains('portal.user.grant_role'));
    final cra = (grants['CRA'] as YamlList).cast<String>().toSet();
    expect(cra.any((p) => p.contains('.link') || p.contains('.send')), isFalse);
  });
}
