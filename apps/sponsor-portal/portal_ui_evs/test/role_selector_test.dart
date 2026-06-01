import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/role_selector.dart';

void main() {
  // Verifies: DIARY-GUI-role-switching/A+B+C+D
  test('selector visible only for 2+ roles', () {
    expect(roleSelectorVisible({'Administrator'}), isFalse);
    expect(roleSelectorVisible({'Administrator', 'Study Coordinator'}), isTrue);
  });

  test('roles render in priority order with active marked', () {
    final items = roleMenuItems(
      roles: {'Study Coordinator', 'Administrator'},
      activeRole: 'Study Coordinator',
    );
    expect(items.first.role, 'Administrator'); // highest priority first
    expect(
      items.firstWhere((i) => i.role == 'Study Coordinator').isActive,
      isTrue,
    );
  });

  // Verifies: DIARY-GUI-role-switching/B
  test('roleSelectorVisible returns false for empty set', () {
    expect(roleSelectorVisible({}), isFalse);
  });

  test('roleMenuItems marks only active role as active', () {
    final items = roleMenuItems(
      roles: {
        'Administrator',
        'Study Coordinator',
        'Clinical Research Associate',
      },
      activeRole: 'Administrator',
    );
    expect(items.where((i) => i.isActive).length, 1);
    expect(items.firstWhere((i) => i.isActive).role, 'Administrator');
  });

  test('unknown roles sort after known priority roles', () {
    final items = roleMenuItems(
      roles: {'Unknown Role', 'Administrator'},
      activeRole: 'Administrator',
    );
    expect(items.first.role, 'Administrator');
    expect(items.last.role, 'Unknown Role');
  });
}
