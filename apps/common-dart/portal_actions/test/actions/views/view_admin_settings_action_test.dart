// Verifies: DIARY-PRD-action-inventory/A  (ACT-ADM-001)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ViewAdminSettingsAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'adm-1',
      roles: {'Admin'},
      activeRole: 'Admin',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('DIARY-PRD-action-inventory/A: name, permission, idempotency.none', () {
    // Verifies: DIARY-PRD-action-inventory/A
    expect(action.name, 'ACT-ADM-001');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-ADM-001']),
    );
    expect(action.idempotency, Idempotency.none);
  });

  test('DIARY-PRD-action-inventory/A: parseInput returns const input', () {
    // Verifies: DIARY-PRD-action-inventory/A
    final input = action.parseInput(<String, Object?>{});
    expect(input, isA<ViewAdminSettingsInput>());
  });

  test('DIARY-PRD-action-inventory/A: execute returns empty events', () async {
    // Verifies: DIARY-PRD-action-inventory/A
    final r = await action.execute(const ViewAdminSettingsInput(), ctx);
    expect(r.events, isEmpty);
  });
}
