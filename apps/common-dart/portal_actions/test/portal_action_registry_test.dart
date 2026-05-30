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
    expect(names.toSet(), containsAll(portalPermissionsByActId.keys));
    expect(names.length, portalPermissionsByActId.length); // 23
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
