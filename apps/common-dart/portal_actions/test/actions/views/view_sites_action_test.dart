// Verifies: DIARY-PRD-action-inventory/A  (ACT-SIT-001)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ViewSitesAction();
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
    expect(action.name, 'ACT-SIT-001');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-SIT-001']),
    );
    expect(action.idempotency, Idempotency.none);
  });

  test('DIARY-PRD-action-inventory/A: parseInput requires siteId, trims it, '
      'keeps filter optional', () {
    // Verifies: DIARY-PRD-action-inventory/A
    expect(() => action.parseInput(<String, Object?>{}), throwsFormatException);
    expect(
      () => action.parseInput(<String, Object?>{'siteId': 42}),
      throwsFormatException,
    );

    final inputNoFilter = action.parseInput(<String, Object?>{
      'siteId': ' site-1 ',
    });
    expect(inputNoFilter.siteId, 'site-1');
    expect(inputNoFilter.filter, isNull);

    final inputWithFilter = action.parseInput(<String, Object?>{
      'siteId': 'site-1',
      'filter': 'site-A',
    });
    expect(inputWithFilter.siteId, 'site-1');
    expect(inputWithFilter.filter, 'site-A');
  });

  test(
    'DIARY-PRD-action-inventory/A: parseInput ignores non-String filter',
    () {
      // Verifies: DIARY-PRD-action-inventory/A
      final input = action.parseInput(<String, Object?>{
        'siteId': 'site-1',
        'filter': 42,
      });
      expect(input.filter, isNull);
    },
  );

  test('DIARY-PRD-action-inventory/A: validate rejects blank siteId', () {
    // Verifies: DIARY-PRD-action-inventory/A
    expect(
      () => action.validate(const ViewSitesInput(siteId: '')),
      throwsArgumentError,
    );
  });

  test('DIARY-PRD-action-inventory/A: scopeFor binds the site scope', () {
    // Verifies: DIARY-PRD-action-inventory/A
    final perm = portalPermissionsByActId['ACT-SIT-001']!;
    final scope = action.scopeFor(perm, const ViewSitesInput(siteId: 'site-1'));
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 'site-1');
  });

  test('DIARY-PRD-action-inventory/A: execute returns empty events', () async {
    // Verifies: DIARY-PRD-action-inventory/A
    final r = await action.execute(const ViewSitesInput(siteId: 'site-1'), ctx);
    expect(r.events, isEmpty);
  });
}
