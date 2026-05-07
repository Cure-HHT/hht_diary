// test/permissions/materialized_view_role_matrix_reader_test.dart
// Verifies: REQ-d00176-C (server-side RoleMatrixReader over StorageBackend).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('MaterializedViewRoleMatrixReader', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test(
      'REQ-d00176-C: isGranted returns true after PermissionGranted appended',
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
        final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
        expect(await reader.isGranted('admin', 'user.invite'), isTrue);
      },
    );

    test(
      'REQ-d00176-C: isGranted returns false after PermissionRevoked appended',
      () async {
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
        final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
        expect(await reader.isGranted('admin', 'user.invite'), isFalse);
      },
    );

    test(
      'REQ-d00176-C: grantsForRole returns all current grants for role',
      () async {
        for (final perm in <String>['user.invite', 'user.role.assign']) {
          await eventStore.append(
            entryType: 'role_permission_grant',
            entryTypeVersion: 1,
            aggregateType: 'role_permission_grant',
            aggregateId: 'admin:$perm',
            eventType: 'permission_granted',
            data: PermissionGrantedPayload(
              role: 'admin',
              permissionName: perm,
              scope: ScopeClass.global,
            ).toJson(),
            initiator: const AutomationInitiator(service: 'test'),
          );
        }
        final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
        final grants = await reader.grantsForRole('admin');
        expect(grants.map((p) => p.name).toSet(), <String>{
          'user.invite',
          'user.role.assign',
        });
      },
    );
  });
}
