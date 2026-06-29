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

  // Verifies: DIARY-DEV-role-permissions-seed/A — a permission dropped from the
  //   YAML between boots is revoked (drift applied), while still-declared grants
  //   survive.
  test(
    'buildPortalAuthorizationPolicy revokes drift when the YAML drops a grant',
    () async {
      final db = await databaseFactoryMemory.openDatabase('authz-drift.db');
      final eventStore = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );

      Future<Set<String>> grantPairs() async {
        final rows = await eventStore.backend.findViewRows(
          'role_permission_grants',
        );
        return {for (final r in rows) '${r['role']}:${r['permissionName']}'};
      }

      const yamlV1 = '''
roles:
  - StudyCoordinator
grants:
  StudyCoordinator:
    - portal.participant.view
    - portal.audit.view
''';
      final r1 = await buildPortalAuthorizationPolicy(
        eventStore: eventStore,
        roleGrantsYaml: yamlV1,
      );
      expect(r1.isReady, isTrue, reason: 'v1 errors: ${r1.errors}');
      expect(await grantPairs(), <String>{
        'StudyCoordinator:portal.participant.view',
        'StudyCoordinator:portal.audit.view',
      });

      // v2 drops portal.audit.view.
      const yamlV2 = '''
roles:
  - StudyCoordinator
grants:
  StudyCoordinator:
    - portal.participant.view
''';
      final r2 = await buildPortalAuthorizationPolicy(
        eventStore: eventStore,
        roleGrantsYaml: yamlV2,
      );
      expect(r2.isReady, isTrue, reason: 'v2 errors: ${r2.errors}');
      expect(await grantPairs(), <String>{
        'StudyCoordinator:portal.participant.view',
      });
    },
  );

  // Verifies: DIARY-DEV-role-permissions-seed/A — re-running the same YAML emits
  //   no further grant/revoke events (drift reconcile is idempotent).
  test('buildPortalAuthorizationPolicy drift reconcile is idempotent', () async {
    final db = await databaseFactoryMemory.openDatabase('authz-drift-idem.db');
    final eventStore = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );
    final yaml = referenceRoleGrantsYaml();
    await buildPortalAuthorizationPolicy(
      eventStore: eventStore,
      roleGrantsYaml: yaml,
    );
    final before = (await eventStore.backend.findAllEvents(limit: 5000)).length;
    await buildPortalAuthorizationPolicy(
      eventStore: eventStore,
      roleGrantsYaml: yaml,
    );
    final after = (await eventStore.backend.findAllEvents(limit: 5000)).length;
    expect(after, before);
  });
}
