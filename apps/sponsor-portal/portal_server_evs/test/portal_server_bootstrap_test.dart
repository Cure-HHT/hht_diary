// Verifies: DIARY-DEV-portal-reaction-server/A
// Verifies: DIARY-PRD-action-inventory/A+B
// Verifies: DIARY-DEV-audit-log-read/A+B
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
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

  test(
      'admin assigns a wildcard-scoped role (ACT-USR-007) and revokes it '
      '(ACT-USR-010)', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-wild.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
    );
    addTearDown(boot.dispose);

    final admin = Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    );
    const wildcard = ValueWildcardScope(class_: 'site');

    final assign = await boot.dispatcher.dispatch(
      ActionSubmission(
        actionName: 'ACT-USR-007',
        rawInput: <String, Object?>{
          'userId': 'target-w',
          'role': 'Administrator',
          'scope': wildcard.toJson(),
        },
        idempotencyKey: 'assign-targetw-wild',
      ),
      _ctx(admin),
    );
    expect(assign, isA<DispatchSuccess<Object?>>());

    var rows = await boot.eventStore.backend.findViewRows('user_role_scopes');
    expect(
      rows.where((r) => r['user_id'] == 'target-w'),
      isNotEmpty,
      reason: 'wildcard-scoped assignment materialized',
    );

    final revoke = await boot.dispatcher.dispatch(
      ActionSubmission(
        actionName: 'ACT-USR-010',
        rawInput: <String, Object?>{
          'userId': 'target-w',
          'role': 'Administrator',
          'scope': wildcard.toJson(),
        },
        idempotencyKey: 'revoke-targetw-wild',
      ),
      _ctx(admin),
    );
    expect(revoke, isA<DispatchSuccess<Object?>>());

    rows = await boot.eventStore.backend.findViewRows('user_role_scopes');
    expect(
      rows.where((r) => r['user_id'] == 'target-w'),
      isEmpty,
      reason: 'revoke removed the wildcard assignment',
    );
  });

  test(
      'boot-time RAVE sync seeds sites_index + participant_record from the dev '
      'fixture, and admin can view those + rave_sync_status', () async {
    // No RAVE_UAT_* env in the test harness -> DevSeedRaveClient is used.
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-rave.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
    );
    addTearDown(boot.dispose);

    // sites_index materialized from the 3 dev-seed sites.
    final sites = await boot.eventStore.backend.findViewRows('sites_index');
    final siteIds = sites.map((r) => r['site_id']).toSet();
    expect(siteIds, containsAll(<String>['site-1', 'site-2', 'site-3']),
        reason: 'dev-seed sites synced into sites_index');

    // participant_record materialized from the 4 dev-seed subjects.
    final participants =
        await boot.eventStore.backend.findViewRows('participant_record');
    expect(participants, isNotEmpty,
        reason: 'dev-seed subjects synced into participant_record');

    // participant_site_index too (containment-resolution backing view).
    final psi =
        await boot.eventStore.backend.findViewRows('participant_site_index');
    expect(psi, isNotEmpty,
        reason: 'dev-seed subjects synced into participant_site_index');

    // Administrator's effective permissions include the new view grants
    // (drives PermissionGate on the sites / participants / RAVE-sync screens).
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
    expect(
      names,
      containsAll(<String>[
        'view:sites_index',
        'view:participant_record',
        'view:rave_sync_status',
        'view:users_index',
      ]),
      reason: 'admin granted the operational view-read permissions',
    );
  });

  test(
      'GET /audit: admin (portal.audit.view) -> 200 with {rows, count}; '
      'coordinator (no portal.audit.view) -> 403', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-audit.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
    );
    addTearDown(boot.dispose);

    // Administrator holds portal.audit.view (per role_seed) -> 200.
    final adminResp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit?limit=5'),
        headers: const {'Authorization': 'Bearer admin-1:Administrator'},
      ),
    );
    expect(adminResp.statusCode, 200);
    final body = jsonDecode(await adminResp.readAsString());
    expect(body, isA<Map<String, Object?>>());
    expect((body as Map)['rows'], isA<List<Object?>>());
    expect(body['count'], isA<int>());
    expect(body['count'], (body['rows'] as List).length,
        reason: 'count reflects the number of returned rows');

    // StudyCoordinator lacks portal.audit.view -> 403 from our gate.
    final coordResp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit'),
        headers: const {'Authorization': 'Bearer sc-1:StudyCoordinator'},
      ),
    );
    expect(coordResp.statusCode, 403);
  });
}
