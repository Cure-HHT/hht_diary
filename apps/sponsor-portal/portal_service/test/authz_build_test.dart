import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import '_reference_role_grants.dart';

void main() {
  test(
    'buildPortalAuthorizationPolicy returns a ready policy (no seed errors)',
    () async {
      final db = await databaseFactoryMemory.openDatabase('authz-build');
      final eventStore = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );
      final result = await buildPortalAuthorizationPolicy(
        eventStore: eventStore,
        roleGrantsYaml: referenceRoleGrantsYaml(),
      );
      expect(result.isReady, isTrue, reason: 'seed errors: ${result.errors}');
    },
  );

  test(
    'buildPortalAuthorizationPolicy seeds grants from the passed YAML',
    () async {
      final db = await databaseFactoryMemory.openDatabase('authz-yaml.db');
      final eventStore = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );
      const yaml = '''
roles:
  - StudyCoordinator
grants:
  StudyCoordinator:
    - portal.participant.view
''';
      final result = await buildPortalAuthorizationPolicy(
        eventStore: eventStore,
        roleGrantsYaml: yaml,
      );
      final policy = (result as PolicyReady).policy;
      // effectivePermissionsFor gates on a user_role_scopes assignment for
      // (userId, activeRole); assign sc-1 the StudyCoordinator role so its grants
      // surface.
      await bootstrapRoleAssignments(
        eventStore: eventStore,
        seed: const RoleAssignmentSeed(
          entries: <RoleAssignmentSeedEntry>[
            RoleAssignmentSeedEntry(
              userId: 'sc-1',
              role: 'StudyCoordinator',
              scope: BoundScope(class_: 'site', value: 'site-1'),
            ),
          ],
        ),
      );
      final sc = Principal.user(
        userId: 'sc-1',
        roles: const {'StudyCoordinator'},
        activeRole: 'StudyCoordinator',
      );
      final names = (await policy.effectivePermissionsFor(
        sc,
      )).rolePermissions.map((p) => p.name).toSet();
      expect(names, contains('portal.participant.view'));
    },
  );

  test('buildPortalDispatcher wires registry + policy + idempotency', () async {
    final db = await databaseFactoryMemory.openDatabase('dispatch-build');
    final eventStore = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );
    final dispatcher = await buildPortalDispatcher(
      eventStore: eventStore,
      roleGrantsYaml: referenceRoleGrantsYaml(),
    );
    expect(dispatcher, isA<ActionDispatcher>());
  });
}
