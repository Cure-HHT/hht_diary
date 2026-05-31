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
    expect(portalPermissionsByActId.length, 26);
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
}
