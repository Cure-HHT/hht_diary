import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = UnwedgeRaveSyncAction();

  test('name + permission + idempotency', () {
    expect(action.name, 'ACT-OPS-001');
    expect(action.permissions, {portalPermissionsByActId['ACT-OPS-001']});
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput trims reason; validate rejects blank', () {
    final input = action.parseInput({'reason': '  creds rotated  '});
    expect(input.reason, 'creds rotated');
    expect(
      () => action.validate(UnwedgeRaveSyncInput(reason: '')),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('execute emits rave_unwedged on the rave_sync aggregate', () async {
    final ctx = ActionContext(
      principal: Principal.user(
        userId: 'op-1',
        roles: const {'SystemOperator'},
        activeRole: 'SystemOperator',
      ),
      security: const SecurityDetails(),
      requestStartedAt: DateTime.utc(2026, 5, 31),
    );
    final result = await action.execute(
      UnwedgeRaveSyncInput(reason: 'creds rotated'),
      ctx,
    );
    expect(result.events.single.entryType, 'rave_unwedged');
    expect(result.events.single.data['by'], 'op-1');
    expect(result.events.single.data['reason'], 'creds rotated');
    expect(result.events.single.data['consecutive_auth_failures'], 0);
  });
}
