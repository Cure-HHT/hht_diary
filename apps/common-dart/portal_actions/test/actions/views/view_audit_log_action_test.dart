// Verifies: DIARY-PRD-action-inventory/A  (ACT-AUD-001)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ViewAuditLogAction();
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
    expect(action.name, 'ACT-AUD-001');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-AUD-001']),
    );
    expect(action.idempotency, Idempotency.none);
  });

  test('DIARY-PRD-action-inventory/A: parseInput accepts optional filter', () {
    // Verifies: DIARY-PRD-action-inventory/A
    final inputNoFilter = action.parseInput(<String, Object?>{});
    expect(inputNoFilter.filter, isNull);

    final inputWithFilter = action.parseInput(<String, Object?>{
      'filter': '2026-05',
    });
    expect(inputWithFilter.filter, '2026-05');
  });

  test(
    'DIARY-PRD-action-inventory/A: parseInput ignores non-String filter',
    () {
      // Verifies: DIARY-PRD-action-inventory/A
      final input = action.parseInput(<String, Object?>{'filter': true});
      expect(input.filter, isNull);
    },
  );

  test('DIARY-PRD-action-inventory/A: execute returns empty events', () async {
    // Verifies: DIARY-PRD-action-inventory/A
    final r = await action.execute(const ViewAuditLogInput(), ctx);
    expect(r.events, isEmpty);
  });
}
