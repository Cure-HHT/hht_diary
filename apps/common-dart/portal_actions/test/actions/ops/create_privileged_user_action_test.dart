import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  ActionContext ctx() => ActionContext(
    principal: Principal.user(
      userId: 'op-1',
      roles: const {'SystemOperator'},
      activeRole: 'SystemOperator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 31),
  );

  test('CreateAdministrator: id, perm, stamps Administrator role', () async {
    final a = CreateAdministratorAction();
    expect(a.name, 'ACT-OPS-003');
    expect(a.permissions, {portalPermissionsByActId['ACT-OPS-003']});
    final r = await a.execute(
      CreatePrivilegedUserInput(email: 'x@y.z', name: 'X'),
      ctx(),
    );
    final created = r.events.firstWhere((e) => e.entryType == 'user_created');
    expect(created.data['roles'], ['Administrator']);
  });

  test('CreateSystemOperator: id, perm, stamps SystemOperator role', () async {
    final a = CreateSystemOperatorAction();
    expect(a.name, 'ACT-OPS-002');
    expect(a.permissions, {portalPermissionsByActId['ACT-OPS-002']});
    final r = await a.execute(
      CreatePrivilegedUserInput(email: 'x@y.z', name: 'X'),
      ctx(),
    );
    final created = r.events.firstWhere((e) => e.entryType == 'user_created');
    expect(created.data['roles'], ['SystemOperator']);
  });

  test('parseInput trims; validate requires @ in email and non-blank name', () {
    final a = CreateAdministratorAction();
    expect(
      () => a.validate(CreatePrivilegedUserInput(email: 'noat', name: 'X')),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => a.validate(CreatePrivilegedUserInput(email: 'x@y.z', name: '')),
      throwsA(isA<ArgumentError>()),
    );
  });
}
