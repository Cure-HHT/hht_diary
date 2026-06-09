import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: one unique permission per ACT id', () {
    final byId = portalPermissionsByActId;
    expect(
      byId.keys,
      containsAll(<String>[
        'ACT-PAT-001',
        'ACT-PAT-002',
        'ACT-PAT-003',
        'ACT-PAT-004',
        'ACT-PAT-005',
        'ACT-PAT-006',
        'ACT-PAT-007',
        'ACT-QST-001',
        'ACT-QST-002',
        'ACT-QST-003',
        'ACT-QST-004',
        'ACT-USR-001',
        'ACT-USR-002',
        'ACT-USR-003',
        'ACT-USR-004',
        'ACT-USR-005',
        'ACT-USR-006',
        'ACT-USR-007',
        'ACT-USR-008',
        'ACT-USR-009',
        'ACT-SIT-001',
        'ACT-AUD-001',
        'ACT-ADM-001',
        'ACT-SEE-001',
        'ACT-SEE-002',
        'ACT-SEE-003',
        'ACT-SEE-004',
      ]),
    );
    for (final p in byId.values) {
      expect(p.name, startsWith('portal.'));
      expect(p.name, isNot(contains(' ')));
    }
    final names = byId.values.map((p) => p.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('ops permissions exist with correct names and scoping', () {
    expect(
      portalPermissionsByActId['ACT-OPS-001']!.name,
      'portal.rave.unwedge',
    );
    expect(portalPermissionsByActId['ACT-OPS-001']!.scopeClass, isNull);
    expect(
      portalPermissionsByActId['ACT-OPS-002']!.name,
      'portal.user.create_sysop',
    );
    expect(portalPermissionsByActId['ACT-OPS-002']!.scopeClass, isNull);
    expect(
      portalPermissionsByActId['ACT-OPS-003']!.name,
      'portal.user.create_admin',
    );
    expect(portalPermissionsByActId['ACT-OPS-003']!.scopeClass, isNull);
    // 28 ACT-id-backed permissions + 1 grant_role pseudo-id (the second
    // permission AssignRoleAction declares) + 4 ACT-SEE view permissions = 33.
    expect(portalPermissionsByActId.length, 33);
  });

  // Verifies: DIARY-DEV-operator-tier-authz/B — the target-bearing user-
  //   management permissions are user-scoped (gated on the target's tier),
  //   create is unscoped, and grant_role is the tier-scoped escalation axis.
  test(
    'DIARY-DEV-operator-tier-authz/B: user-management permission scoping',
    () {
      // create stays unscoped (no target tier yet).
      expect(portalPermissionsByActId['ACT-USR-001']!.scopeClass, isNull);
      // every target-bearing user-management permission is `user`-scoped.
      for (final actId in const <String>[
        'ACT-USR-002',
        'ACT-USR-003',
        'ACT-USR-004',
        'ACT-USR-005',
        'ACT-USR-006',
        'ACT-USR-007',
        'ACT-USR-008',
        'ACT-USR-009',
        'ACT-USR-010',
        'ACT-USR-011',
      ]) {
        expect(
          portalPermissionsByActId[actId]!.scopeClass,
          'user',
          reason: '$actId must be user-scoped',
        );
      }
      // grant_role is the tier-scoped escalation axis.
      final grant = portalPermissionsByActId['ACT-USR-007-GRANT']!;
      expect(grant.name, 'portal.user.grant_role');
      expect(grant.scopeClass, 'tier');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('ACT-SIT-001 portal.site.view is site-scoped', () {
    final perm = portalPermissionsByActId['ACT-SIT-001']!;
    expect(perm.name, 'portal.site.view');
    expect(perm.scopeClass, 'site');
  });

  test('revoke permissions declared', () {
    expect(
      portalPermissionsByActId['ACT-USR-010']!.name,
      'portal.user.revoke_role',
    );
    expect(
      portalPermissionsByActId['ACT-USR-011']!.name,
      'portal.user.revoke_site',
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: registry registers actions with declared permissions',
    () {
      final registry = buildPortalActionRegistry();
      final names = registry.all.map((a) => a.name).toSet();
      expect(names, contains('ACT-USR-003'));
      final catalogPerms = portalPermissionsByActId.values.toSet();
      for (final a in registry.all) {
        for (final p in a.permissions) {
          expect(catalogPerms, contains(p), reason: '${a.name} perm ${p.name}');
        }
      }
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A — the View ("SEE") category.
  test('ACT-SEE view permissions are declared with the agreed names', () {
    final byId = portalPermissionsByActId;
    expect(byId['ACT-SEE-001']?.name, 'portal.questionnaire.view_status');
    expect(byId['ACT-SEE-002']?.name, 'portal.rave.view_sync');
    expect(byId['ACT-SEE-003']?.name, 'portal.user.view_accounts');
    expect(byId['ACT-SEE-004']?.name, 'portal.diary.view_entries');
    expect(byId['ACT-SEE-001']?.scopeClass, 'site');
    expect(byId['ACT-SEE-002']?.scopeClass, isNull);
    expect(byId['ACT-SEE-003']?.scopeClass, isNull);
    expect(byId['ACT-SEE-004']?.scopeClass, isNull);
  });
}
