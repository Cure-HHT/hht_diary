// Verifies: DIARY-DEV-portal-reaction-server/A
// Verifies: DIARY-PRD-action-inventory/A+B
// Verifies: DIARY-DEV-audit-log-read/A+B
// Verifies: DIARY-DEV-portal-activation-email-delivery/B
// Verifies: DIARY-DEV-portal-reset-code-lifecycle/D
// Verifies: DIARY-DEV-portal-test-account-provisioning/A+B
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
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
      raveClient: DevSeedRaveClient(),
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

    // The assign_site action is now tier-scoped on the TARGET user: target-1
    // needs a user_tier_index row (staff) for the user-scoped permission to
    // resolve (ContainmentResolver is fail-closed on a missing row). The boot
    // user_tier_reactor only seeds tier rows for created users; target-1 is
    // never created here, so seed its staff-tier row explicitly.
    await boot.eventStore.append(
      entryType: 'user_tier_changed',
      aggregateType: 'portal_user',
      aggregateId: 'target-1',
      eventType: 'user_tier_changed',
      data: <String, Object?>{'user_id': 'target-1', 'tier': 'staff'},
      initiator: const AutomationInitiator(service: 'test-seed'),
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
      raveClient: DevSeedRaveClient(),
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
      'SystemOperator effective permissions include the user-provisioning set: '
      'view:users_index + view:user_role_scopes + portal.user.create '
      '(drives the User Accounts screen + Create User button)', () async {
    // The operator-tier is the role that provisions the first Administrators.
    // It must be able to (a) read the user list + role assignments, and
    // (b) create a user via the UI flow (ACT-USR-001 = portal.user.create).
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-sysop.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    // sysop-1 is seeded by the local convenience seed (operator-tier + site
    // wildcard, mirroring the deployed portal-users.json) during boot, before
    // the reactors start. The policy resolves a user's roles from
    // user_role_scopes, so the boot-time assignment is what surfaces the grants.
    final bootstrap =
        await buildPortalAuthorizationPolicy(eventStore: boot.eventStore);
    final policy = (bootstrap as PolicyReady).policy;

    final sysop = Principal.user(
      userId: 'sysop-1',
      roles: const {'SystemOperator'},
      activeRole: 'SystemOperator',
    );
    final eff = await policy.effectivePermissionsFor(sysop);
    final names = eff.rolePermissions.map((p) => p.name).toSet();

    expect(
      names,
      containsAll(<String>[
        'view:users_index',
        'view:user_role_scopes',
        'view:sites_index',
        'portal.user.create',
      ]),
      reason: 'SystemOperator can view users + sites to provision accounts',
    );
  });

  test(
      'view-permission grants are idempotent on reboot: a SECOND boot on an '
      'already-seeded store re-affirms the grants without duplicating them '
      '(deployed envs pick up new grants on redeploy, no DB reset)', () async {
    // Simulates the deploy path: the store is already seeded (marker present),
    // so the seed-once gate is skipped — but the view-permission grants run on
    // EVERY boot, so they must (a) still be present and (b) not pile up.
    // One factory, reopened by the same path: the in-memory store persists
    // across close→reopen, so boot2 sees boot1's seeded state (alreadySeeded).
    final factory = newDatabaseFactoryMemory();
    final db1 = await factory.openDatabase('skeleton-idem.db');
    final boot1 = await bootstrapPortalServer(
      backend: SembastBackend(database: db1),
      raveClient: DevSeedRaveClient(),
    );
    await boot1.dispose();

    // Reboot on the SAME backing store (already-seeded).
    final db2 = await factory.openDatabase('skeleton-idem.db');
    final boot2 = await bootstrapPortalServer(
      backend: SembastBackend(database: db2),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot2.dispose);

    // Exactly one grant event under the operator's users_index grant aggregate —
    // the second boot did NOT re-append a duplicate.
    final grantEvents = await boot2.eventStore.backend
        .findEventsForAggregate('SystemOperator:view:users_index');
    expect(
      grantEvents.where((e) => e.eventType == 'permission_granted'),
      hasLength(1),
      reason: 'grant is idempotent across reboots (no duplicate append)',
    );

    // And the grant is still effective after the reboot.
    final bootstrap =
        await buildPortalAuthorizationPolicy(eventStore: boot2.eventStore);
    final policy = (bootstrap as PolicyReady).policy;
    final sysop = Principal.user(
      userId: 'sysop-1',
      roles: const {'SystemOperator'},
      activeRole: 'SystemOperator',
    );
    final names = (await policy.effectivePermissionsFor(sysop))
        .rolePermissions
        .map((p) => p.name)
        .toSet();
    expect(
        names, containsAll(<String>['view:users_index', 'portal.user.create']));
  });

  test(
      'admin assigns a wildcard-scoped role (ACT-USR-007) and revokes it '
      '(ACT-USR-010)', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-wild.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    final admin = Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    );
    const wildcard = ValueWildcardScope(class_: 'site');

    // assign_role/revoke_role are tier-scoped on the TARGET user; seed target-w's
    // staff-tier row so the user-scoped permission resolves. The role being
    // assigned is 'Administrator' (a staff-tier role), so the grant_role/tier
    // escalation axis is satisfied by the admin's staff-tier coverage.
    await boot.eventStore.append(
      entryType: 'user_tier_changed',
      aggregateType: 'portal_user',
      aggregateId: 'target-w',
      eventType: 'user_tier_changed',
      data: <String, Object?>{'user_id': 'target-w', 'tier': 'staff'},
      initiator: const AutomationInitiator(service: 'test-seed'),
    );

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
    // Forces DevSeedRaveClient so the assertion is hermetic regardless of any
    // ambient RAVE_UAT_* env (which would otherwise drive a live RAVE fetch).
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-rave.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
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
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    // Administrator holds portal.audit.view (per role_seed) -> 200.
    // Bare userId: the dev validator resolves roles from user_role_scopes.
    final adminResp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit?limit=5'),
        headers: const {'Authorization': 'Bearer admin-1'},
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
    // Bare userId: the dev validator resolves roles from user_role_scopes.
    final coordResp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit'),
        headers: const {'Authorization': 'Bearer sc-1'},
      ),
    );
    expect(coordResp.statusCode, 403);
  });

  test(
      'GET /activate/<code> is mounted publicly: unknown code -> '
      '200 {valid: false}, not 401', () async {
    // Verifies: DIARY-DEV-portal-activation-email-delivery/B — the /activate
    // routes are outside authMiddleware (no Authorization header required).
    final db =
        await newDatabaseFactoryMemory().openDatabase('skeleton-activate.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    // No Authorization header — an unknown code must return 200 {valid:false},
    // proving the route is reachable without auth (i.e. it does NOT 401).
    final resp = await boot.router(
      Request('GET', Uri.parse('http://localhost/activate/UNKNOWN-CODE')),
    );
    expect(resp.statusCode, 200,
        reason: 'public route reachable without auth credentials');
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    expect(body['valid'], isFalse,
        reason: 'unknown code reports {valid: false}');
    // The activation page is served from a different origin than the server, so
    // the response must carry CORS headers or the browser can't read it.
    expect(resp.headers['access-control-allow-origin'], '*',
        reason: 'cross-origin browser must be able to read /activate');
  });

  test('OPTIONS /activate preflight -> 200 with CORS headers (public, no auth)',
      () async {
    // Verifies: DIARY-DEV-portal-activation-email-delivery/B — the POST /activate
    // preflight must succeed cross-origin without auth, else the browser blocks
    // the password submission.
    final db = await newDatabaseFactoryMemory()
        .openDatabase('skeleton-activate-opt.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    final resp = await boot.router(
      Request('OPTIONS', Uri.parse('http://localhost/activate')),
    );
    expect(resp.statusCode, 200);
    expect(resp.headers['access-control-allow-origin'], '*');
    expect(resp.headers['access-control-allow-methods'], contains('POST'));
  });

  // Verifies: DIARY-DEV-portal-settings-store/C
  test(
      'seedRequireSecondFactor: idempotent, seeds require_second_factor=false once',
      () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('seed-2fa-idem.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    await seedRequireSecondFactor(
        eventStore: store, backend: backend, raw: 'false');
    await seedRequireSecondFactor(
        eventStore: store, backend: backend, raw: 'false'); // 2nd call no-op
    final changed = await backend
        .readEventsReverse()
        .where((e) => e.eventType == 'portal_setting_changed')
        .toList();
    expect(changed.length, 1,
        reason: 'second call must not append a duplicate event');
    final rows = await backend.findViewRows('portal_settings');
    expect(rows.where((r) => r['key'] == 'require_second_factor').length, 1);
    expect(rows.firstWhere((r) => r['key'] == 'require_second_factor')['value'],
        isFalse);
  });

  // Verifies: DIARY-DEV-portal-settings-store/C
  test('seedRequireSecondFactor: does nothing when raw is not "false"',
      () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('seed-2fa-noop.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    await seedRequireSecondFactor(
        eventStore: store, backend: backend, raw: null);
    await seedRequireSecondFactor(
        eventStore: store, backend: backend, raw: 'true');
    final changed = await backend
        .readEventsReverse()
        .where((e) => e.eventType == 'portal_setting_changed')
        .toList();
    expect(changed, isEmpty,
        reason:
            'null/true raw must not append any portal_setting_changed event');
  });

  test(
      'password-reset request is mounted publicly (unknown email -> 200, not 401)',
      () async {
    // Verifies: DIARY-DEV-portal-reset-code-lifecycle/D — the /password-reset
    // routes are outside authMiddleware (no Authorization header required).
    final db = await newDatabaseFactoryMemory().openDatabase('boot-reset.db');
    final boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(boot.dispose);

    // No Authorization header — an unknown email must return 200 (enumeration-
    // resistant), proving the route is reachable without auth (i.e. does NOT 401).
    final resp = await boot.router(Request(
        'POST', Uri.parse('http://localhost/password-reset/request'),
        body: jsonEncode({'email': 'nobody@x.org'}),
        headers: const {'Content-Type': 'application/json'}));
    expect(resp.statusCode, 200,
        reason: 'public route reachable without auth credentials');
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    expect(body['ok'], isTrue,
        reason: 'enumeration-resistant: always confirms regardless of match');
  });

  // Verifies: DIARY-DEV-portal-test-account-provisioning/A+B
  test(
      'seedTestAccountActivations: provisions+activates seed emails with '
      'firebase_uid (idempotent)', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('seed-activate-idem.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    const seed = RoleAssignmentSeed(entries: [
      RoleAssignmentSeedEntry(
        userId: 'uat-admin@curehht.test',
        role: 'Administrator',
        scope: ValueWildcardScope(class_: 'site'),
      ),
      RoleAssignmentSeedEntry(
        userId: 'not-an-email',
        role: 'X',
        scope: ValueWildcardScope(class_: 'site'),
      ),
    ]);
    var provisionCalls = 0;
    Future<LookupOrProvisionResult> fake(
        {required String email,
        required String displayName,
        required String password}) async {
      provisionCalls++;
      return const LookupOrProvisionResult(uid: 'uid-uat-admin', created: true);
    }

    await seedTestAccountActivations(
        eventStore: store,
        backend: backend,
        seed: seed,
        password: 'curehht1',
        provision: fake);
    // Second run must be idempotent.
    await seedTestAccountActivations(
        eventStore: store,
        backend: backend,
        seed: seed,
        password: 'curehht1',
        provision: fake);
    // Provisioner called once per run for the one email entry (non-email skipped).
    expect(provisionCalls, 2, reason: 'provisioner called once per run');

    final rows = await backend.findViewRows('users_index');
    final row = rows.firstWhere((r) => r['email'] == 'uat-admin@curehht.test');
    expect(row['firebase_uid'], 'uid-uat-admin');
    expect(row['status'], 'active');

    // Non-email entry is skipped.
    expect(rows.any((r) => r['email'] == 'not-an-email'), isFalse,
        reason: 'non-email userId must be ignored');

    // Exactly one user_activated event despite two runs (idempotent).
    final activated = await backend
        .readEventsReverse()
        .where((e) => e.eventType == 'user_activated')
        .toList();
    expect(activated.length, 1,
        reason: 'second run must not append a duplicate user_activated');
  });

  // Verifies: DIARY-DEV-portal-test-account-provisioning/B
  test('seedTestAccountActivations: no password is a no-op', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('seed-activate-noop.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    const seed = RoleAssignmentSeed(entries: [
      RoleAssignmentSeedEntry(
        userId: 'x@y.test',
        role: 'Administrator',
        scope: ValueWildcardScope(class_: 'site'),
      ),
    ]);
    await seedTestAccountActivations(
      eventStore: store,
      backend: backend,
      seed: seed,
      password: null,
      provision: (
              {required email,
              required displayName,
              required password}) async =>
          const LookupOrProvisionResult(uid: 'u', created: false),
    );
    final created = await backend
        .readEventsReverse()
        .where((e) =>
            e.eventType == 'user_created' || e.eventType == 'user_activated')
        .toList();
    expect(created, isEmpty,
        reason: 'null password must not append any events');
  });
}
