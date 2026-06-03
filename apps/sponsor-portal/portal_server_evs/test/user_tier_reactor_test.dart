// Verifies: DIARY-DEV-operator-tier-authz/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/user_tier_reactor.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<void> _appendRoleAssigned(
  EventStore store, {
  required String userId,
  required String role,
}) =>
    store.append(
      entryType: 'user_role_scope',
      aggregateType: 'user_role_scope',
      aggregateId: computeRoleAssignmentAggregateId(
        userId: userId,
        role: role,
        scope: const ValueWildcardScope(class_: 'site'),
      ),
      eventType: 'role_assigned',
      data: RoleAssignedPayload(
        userId: userId,
        role: role,
        scope: const ValueWildcardScope(class_: 'site'),
      ).toJson(),
      initiator: const AutomationInitiator(service: 'test'),
    );

Future<void> _appendRoleUnassigned(
  EventStore store, {
  required String userId,
  required String role,
}) =>
    store.append(
      entryType: 'user_role_scope',
      aggregateType: 'user_role_scope',
      aggregateId: computeRoleAssignmentAggregateId(
        userId: userId,
        role: role,
        scope: const ValueWildcardScope(class_: 'site'),
      ),
      eventType: 'role_unassigned',
      data: RoleUnassignedPayload(
        userId: userId,
        role: role,
        scope: const ValueWildcardScope(class_: 'site'),
      ).toJson(),
      initiator: const AutomationInitiator(service: 'test'),
    );

String? _tierFor(List<Map<String, Object?>> rows, String userId) {
  final row = rows.where((r) => r['user_id'] == userId).firstOrNull;
  return row?['tier'] as String?;
}

void main() {
  // Verifies: DIARY-DEV-operator-tier-authz/A
  late EventStore store;
  late StorageBackend backend;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('tier_reactor.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
  });

  test(
      'assigning SystemOperator sets tier to operator; '
      'unassigning reverts to staff', () async {
    final reactor = UserTierReactor(eventStore: store, backend: backend)
      ..start();
    addTearDown(reactor.stop);

    // (a) Assign SystemOperator -> tier becomes 'operator'.
    await _appendRoleAssigned(store, userId: 'u1', role: 'SystemOperator');

    // Wait for the reactor to process the event and emit user_tier_changed,
    // which will be folded into user_tier_index by the projection.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    var rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u1'), equals('operator'),
        reason: 'SystemOperator assignment must set tier to operator');

    // (b) Unassign SystemOperator -> tier reverts to 'staff'.
    await _appendRoleUnassigned(store, userId: 'u1', role: 'SystemOperator');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u1'), equals('staff'),
        reason: 'SystemOperator removal must revert tier to staff');
  });

  test('assigning a non-operator role results in staff tier', () async {
    final reactor = UserTierReactor(eventStore: store, backend: backend)
      ..start();
    addTearDown(reactor.stop);

    // (c) Assign a non-operator role -> tier should be 'staff'.
    await _appendRoleAssigned(store, userId: 'u2', role: 'Administrator');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u2'), equals('staff'),
        reason: 'non-operator role must yield staff tier');
  });

  // Verifies: DIARY-DEV-operator-tier-authz/A
  test('user_created seeds a staff tier row immediately', () async {
    final reactor = UserTierReactor(eventStore: store, backend: backend)
      ..start();
    addTearDown(reactor.stop);

    // Emit user_created for a brand-new user u9 (no prior role assignments).
    await store.append(
      entryType: 'user_created',
      aggregateType: 'portal_user',
      aggregateId: 'u9',
      eventType: 'user_created',
      data: const {'email': 'u9@example.com', 'status': 'pending'},
      initiator: const AutomationInitiator(service: 'test'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u9'), equals('staff'),
        reason: 'user_created must seed a staff tier row in user_tier_index');
  });

  test('user_created then role_assigned(SystemOperator) ends at operator tier',
      () async {
    final reactor = UserTierReactor(eventStore: store, backend: backend)
      ..start();
    addTearDown(reactor.stop);

    await store.append(
      entryType: 'user_created',
      aggregateType: 'portal_user',
      aggregateId: 'u10',
      eventType: 'user_created',
      data: const {'email': 'u10@example.com', 'status': 'pending'},
      initiator: const AutomationInitiator(service: 'test'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    var rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u10'), equals('staff'),
        reason: 'initial tier after user_created must be staff');

    await _appendRoleAssigned(store, userId: 'u10', role: 'SystemOperator');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    rows = await backend.findViewRows('user_tier_index');
    expect(_tierFor(rows, 'u10'), equals('operator'),
        reason:
            'user_created followed by SystemOperator assignment must end at operator');
  });

  test('no duplicate user_tier_changed events when tier does not change',
      () async {
    final reactor = UserTierReactor(eventStore: store, backend: backend)
      ..start();
    addTearDown(reactor.stop);

    // Assign SystemOperator -> operator tier.
    await _appendRoleAssigned(store, userId: 'u3', role: 'SystemOperator');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Count tier events before.
    final before = (await backend.readEventsReverse().toList())
        .where(
            (e) => e.eventType == 'user_tier_changed' && e.aggregateId == 'u3')
        .length;

    // Assign another role that does NOT change the tier (still operator).
    await _appendRoleAssigned(store, userId: 'u3', role: 'Administrator');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final after = (await backend.readEventsReverse().toList())
        .where(
            (e) => e.eventType == 'user_tier_changed' && e.aggregateId == 'u3')
        .length;

    expect(after, equals(before),
        reason: 'no-op tier change must not emit another user_tier_changed');
  });
}
