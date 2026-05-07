// test/permissions/event_seed_applier_test.dart
// Verifies: REQ-d00175-F (applier diff logic), REQ-d00175-G (idempotent
// across restarts), REQ-d00175-H (drift reported, not auto-revoked).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('EventSeedApplier', () {
    late EventStore eventStore;
    final declared = <Permission>{
      const Permission('user.invite', scope: ScopeClass.global),
      const Permission('patient.read', scope: ScopeClass.global),
    };

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test(
      'REQ-d00175-F: emits PermissionGranted for every pair in seed when view is empty',
      () async {
        final applier = EventSeedApplier(
          eventStore: eventStore,
          seedInitiator: const AutomationInitiator(service: 'test'),
        );
        const seed = PermissionSeed(
          roles: <String>{'admin', 'investigator'},
          grants: <String, Set<String>>{
            'admin': <String>{'user.invite'},
            'investigator': <String>{'patient.read'},
          },
        );
        final result = await applier.apply(seed, declared);
        expect(result.grantsEmitted, 2);
        expect(result.grantsAlreadyPresent, 0);
        expect(result.grantsInViewNotInSeed, isEmpty);
      },
    );

    test(
      'REQ-d00175-G: re-running with unchanged seed emits zero events (idempotent)',
      () async {
        final applier = EventSeedApplier(
          eventStore: eventStore,
          seedInitiator: const AutomationInitiator(service: 'test'),
        );
        const seed = PermissionSeed(
          roles: <String>{'admin'},
          grants: <String, Set<String>>{
            'admin': <String>{'user.invite'},
          },
        );
        await applier.apply(seed, declared);
        final result2 = await applier.apply(seed, declared);
        expect(result2.grantsEmitted, 0);
        expect(result2.grantsAlreadyPresent, 1);
      },
    );

    test(
      'REQ-d00175-H: reports drift (grant in view not in seed) without revoking',
      () async {
        // Manually grant something the seed will not contain.
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
          initiator: const AutomationInitiator(service: 'pre-existing'),
        );

        final applier = EventSeedApplier(
          eventStore: eventStore,
          seedInitiator: const AutomationInitiator(service: 'test'),
        );
        // Seed does not include user.invite for admin.
        const seed = PermissionSeed(
          roles: <String>{'admin'},
          grants: <String, Set<String>>{'admin': <String>{}},
        );
        final result = await applier.apply(seed, declared);
        expect(result.grantsEmitted, 0);
        expect(result.grantsInViewNotInSeed, contains('admin:user.invite'));

        // The pre-existing grant is still in the view (no revocation emitted).
        final rows = await eventStore.backend.findViewRows(
          'role_permission_grants',
        );
        final matching = rows.where(
          (r) => r['role'] == 'admin' && r['permissionName'] == 'user.invite',
        );
        expect(matching, isNotEmpty);
      },
    );
  });
}
