// Verifies: DIARY-PRD-action-inventory/A  (every inventory action is registered)
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('registry registers every action-inventory action exactly once', () {
    final names = buildPortalActionRegistry().all.map((a) => a.name).toList();
    expect(
      names.toSet().length,
      names.length,
      reason: 'no duplicate action names',
    );
    // The catalog has one entry per ACT id PLUS the ACT-USR-007-GRANT pseudo-id
    // (the second permission AssignRoleAction declares — the grant_role
    // escalation axis), which is not a distinct registered action. Compare
    // against the action-backed ids only.
    final actionBackedActIds = portalPermissionsByActId.keys
        .where((k) => k != 'ACT-USR-007-GRANT')
        .toSet();
    expect(names.toSet(), containsAll(actionBackedActIds));
    expect(names.length, actionBackedActIds.length);
    expect(
      names.toSet(),
      containsAll(<String>['ACT-OPS-001', 'ACT-OPS-002', 'ACT-OPS-003']),
    );
  });

  test('registry declares the ops-action permissions', () {
    final declared = buildPortalActionRegistry().all
        .expand((a) => a.permissions)
        .map((p) => p.name)
        .toSet();
    expect(
      declared,
      containsAll(<String>[
        'portal.rave.unwedge',
        'portal.user.create_sysop',
        'portal.user.create_admin',
      ]),
    );
  });

  test('every registered action declares a permission from the catalog', () {
    final catalog = portalPermissionsByActId.values.toSet();
    for (final a in buildPortalActionRegistry().all) {
      for (final p in a.permissions) {
        expect(catalog, contains(p), reason: '${a.name} perm ${p.name}');
      }
    }
  });
}
