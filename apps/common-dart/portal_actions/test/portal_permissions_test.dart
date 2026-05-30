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
}
