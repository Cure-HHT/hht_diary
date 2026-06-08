// Verifies: DIARY-DEV-view-action-permissions/A — UI gates use Action
//   permissions, not the retired view:<projection> names. After CUR-1474 the
//   server dropped every view:<projection> grant, so any nav section still
//   gating on one would go dark for every role.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/nav_sections.dart';
import 'package:portal_ui_evs/src/users_screen_binding.dart';

void main() {
  test('no nav section gates on a legacy view:<projection> permission', () {
    for (final s in kNavSections) {
      expect(
        s.permission.startsWith('view:'),
        isFalse,
        reason: 'nav "${s.label}" still gates on legacy ${s.permission}',
      );
    }
  });

  test(
    'the users screen gates on Action permissions, not legacy view: names',
    () {
      expect(
        UsersScreenBinding.viewUsersPermission.startsWith('view:'),
        isFalse,
        reason: 'users directory still gates on a legacy view: permission',
      );
      expect(
        UsersScreenBinding.viewAssignmentsPermission.startsWith('view:'),
        isFalse,
        reason: 'user assignments still gate on a legacy view: permission',
      );
    },
  );
}
