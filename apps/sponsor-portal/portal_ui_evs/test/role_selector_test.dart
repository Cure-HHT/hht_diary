import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/role_selector.dart';

void main() {
  // Verifies: DIARY-GUI-role-switching/A+B
  test('selector visible only for 2+ roles', () {
    expect(roleSelectorVisible({'Administrator'}), isFalse);
    expect(roleSelectorVisible({'Administrator', 'StudyCoordinator'}), isTrue);
  });

  // Verifies: DIARY-GUI-role-switching/C+D
  test('roles render in priority order with active marked', () {
    final items = roleMenuItems(
      roles: {'StudyCoordinator', 'Administrator', 'CRA'},
      activeRole: 'StudyCoordinator',
    );
    expect(items.map((i) => i.role).toList(), [
      'Administrator',
      'CRA',
      'StudyCoordinator',
    ]);
    expect(
      items.firstWhere((i) => i.role == 'StudyCoordinator').isActive,
      isTrue,
    );
  });

  // Verifies: DIARY-GUI-role-switching/B
  test('roleSelectorVisible returns false for empty set', () {
    expect(roleSelectorVisible({}), isFalse);
  });

  // Verifies: DIARY-GUI-role-switching/C+D
  test('roleMenuItems marks only active role as active', () {
    final items = roleMenuItems(
      roles: {'Administrator', 'StudyCoordinator', 'CRA'},
      activeRole: 'Administrator',
    );
    expect(items.where((i) => i.isActive).length, 1);
    expect(items.firstWhere((i) => i.isActive).role, 'Administrator');
  });

  // Verifies: DIARY-GUI-role-switching/C
  test('unknown roles sort after known priority roles', () {
    final items = roleMenuItems(
      roles: {'Unknown Role', 'Administrator'},
      activeRole: 'Administrator',
    );
    expect(items.first.role, 'Administrator');
    expect(items.last.role, 'Unknown Role');
  });
}
