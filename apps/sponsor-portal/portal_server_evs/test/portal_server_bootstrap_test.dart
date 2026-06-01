// Verifies: DIARY-DEV-portal-reaction-server/A
// Verifies: DIARY-PRD-action-inventory/A+B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

ActionContext _ctx(Principal p) => ActionContext(
      principal: p,
      security: const SecurityDetails(),
      requestStartedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test(
      'boot seeds admin + coordinator; admin assigns site (enforced), '
      'coordinator denied', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('skeleton.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
    );
    addTearDown(boot.dispose);

    final admin = Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    );
    final coordinator = Principal.user(
      userId: 'sc-1',
      roles: const {'StudyCoordinator'},
      activeRole: 'StudyCoordinator',
    );

    // Admin assigns StudyCoordinator @ site-1 to a target user -> allowed.
    final assign = await boot.dispatcher.dispatch(
      const ActionSubmission(
        actionName: 'ACT-USR-008',
        rawInput: <String, Object?>{
          'userId': 'target-1',
          'role': 'StudyCoordinator',
          'site': 'site-1',
        },
        idempotencyKey: 'assign-target1-site1',
      ),
      _ctx(admin),
    );
    expect(assign, isA<DispatchSuccess<Object?>>());

    final rows = await boot.eventStore.backend.findViewRows('user_role_scopes');
    expect(
      rows.where((r) => r['user_id'] == 'target-1'),
      isNotEmpty,
      reason: 'assignment materialized into user_role_scopes',
    );

    // Coordinator attempts the same -> denied (lacks portal.user.assign_site).
    final denied = await boot.dispatcher.dispatch(
      const ActionSubmission(
        actionName: 'ACT-USR-008',
        rawInput: <String, Object?>{
          'userId': 'target-2',
          'role': 'StudyCoordinator',
          'site': 'site-1',
        },
        idempotencyKey: 'assign-target2-bycoord',
      ),
      _ctx(coordinator),
    );
    expect(denied, isA<DispatchAuthorizationDenied<Object?>>());
  });

  test(
      'admin effective permissions include assign_site + view:user_role_scopes '
      '(drives PermissionGate)', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-perms.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
    );
    addTearDown(boot.dispose);

    final bootstrap =
        await buildPortalAuthorizationPolicy(eventStore: boot.eventStore);
    final policy = (bootstrap as PolicyReady).policy;

    final admin = Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    );
    final eff = await policy.effectivePermissionsFor(admin);
    final names = eff.rolePermissions.map((p) => p.name).toSet();

    expect(names, contains('portal.user.assign_site'),
        reason: 'admin can assign sites');
    expect(names, contains('view:user_role_scopes'),
        reason: 'admin can subscribe to the assignments view');

    // The coordinator's snapshot must NOT carry those, so its PermissionGates
    // close (no Assign widget; "no access" for the list).
    final coordinator = Principal.user(
      userId: 'sc-1',
      roles: const {'StudyCoordinator'},
      activeRole: 'StudyCoordinator',
    );
    final scEff = await policy.effectivePermissionsFor(coordinator);
    final scNames = scEff.rolePermissions.map((p) => p.name).toSet();
    expect(scNames, isNot(contains('portal.user.assign_site')));
    expect(scNames, isNot(contains('view:user_role_scopes')));
  });
}
