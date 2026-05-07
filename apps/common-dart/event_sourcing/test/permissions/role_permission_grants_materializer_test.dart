// test/permissions/role_permission_grants_materializer_test.dart
// Verifies: REQ-d00174-C+D+E (materializer projects events into view in
// transaction; permission_revoked deletes view row; appliesTo filters
// by aggregateType).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('RolePermissionGrantsMaterializer', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test(
      'REQ-d00174-C: permission_granted upserts view row in same txn',
      () async {
        const payload = PermissionGrantedPayload(
          role: 'admin',
          permissionName: 'user.invite',
          scope: ScopeClass.global,
        );
        await eventStore.append(
          entryType: 'role_permission_grant',
          entryTypeVersion: 1,
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          eventType: 'permission_granted',
          data: payload.toJson(),
          initiator: const AutomationInitiator(service: 'test'),
        );
        final rows = await eventStore.backend.findViewRows(
          'role_permission_grants',
        );
        final row = rows.firstWhere(
          (r) => r['role'] == 'admin' && r['permissionName'] == 'user.invite',
          orElse: () => <String, dynamic>{},
        );
        expect(row, isNotEmpty);
        expect(row['role'], 'admin');
        expect(row['permissionName'], 'user.invite');
        expect(row['scope'], 'global');
      },
    );

    test('REQ-d00174-D: permission_revoked deletes view row', () async {
      await eventStore.append(
        entryType: 'role_permission_grant',
        entryTypeVersion: 1,
        aggregateType: 'role_permission_grant',
        aggregateId: 'admin:user.invite',
        eventType: 'permission_granted',
        data: const PermissionGrantedPayload(
          role: 'admin',
          permissionName: 'user.invite',
          scope: ScopeClass.global,
        ).toJson(),
        initiator: const AutomationInitiator(service: 'test'),
      );
      await eventStore.append(
        entryType: 'role_permission_grant',
        entryTypeVersion: 1,
        aggregateType: 'role_permission_grant',
        aggregateId: 'admin:user.invite',
        eventType: 'permission_revoked',
        data: const <String, Object?>{
          'role': 'admin',
          'permissionName': 'user.invite',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );
      final rows = await eventStore.backend.findViewRows(
        'role_permission_grants',
      );
      final row = rows.where(
        (r) => r['role'] == 'admin' && r['permissionName'] == 'user.invite',
      );
      expect(row, isEmpty);
    });

    test('REQ-d00174-E: appliesTo filters by aggregateType', () {
      const m = RolePermissionGrantsMaterializer();
      final matching = StoredEvent.synthetic(
        eventId: 'e1',
        aggregateId: 'admin:user.invite',
        aggregateType: 'role_permission_grant',
        entryType: 'role_permission_grant',
        initiator: const AutomationInitiator(service: 'test'),
        clientTimestamp: DateTime.utc(2026, 5, 7),
        eventHash: 'h1',
      );
      final notMatching = StoredEvent.synthetic(
        eventId: 'e2',
        aggregateId: 'some-diary-entry',
        aggregateType: 'DiaryEntry',
        entryType: 'NosebleedRecorded',
        initiator: const AutomationInitiator(service: 'test'),
        clientTimestamp: DateTime.utc(2026, 5, 7),
        eventHash: 'h2',
      );
      expect(m.appliesTo(matching), isTrue);
      expect(m.appliesTo(notMatching), isFalse);
    });
  });
}
