// Verifies: DIARY-PRD-user-account-edit/E
// Verifies: DIARY-PRD-action-inventory/A+C
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

ActionContext _ctx(Principal p) => ActionContext(
  principal: p,
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 1, 1),
);

Principal _admin() => Principal.user(
  userId: 'admin-1',
  roles: const {'Administrator'},
  activeRole: 'Administrator',
);

void main() {
  test('AssignSite makes a StudyCoordinator enforced at the granted site; '
      'RevokeSite removes it', () async {
    final db = await databaseFactoryMemory.openDatabase('grant-realizes');
    final store = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );

    final policyBootstrap = await buildPortalAuthorizationPolicy(
      eventStore: store,
    );
    expect(
      policyBootstrap.isReady,
      isTrue,
      reason: 'seed errors: ${policyBootstrap.errors}',
    );

    // Seed the Administrator who will do the granting.
    await bootstrapRoleAssignments(
      eventStore: store,
      seed: const RoleAssignmentSeed(
        entries: <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: 'admin-1',
            role: 'Administrator',
            scope: ValueWildcardScope(class_: 'site'),
          ),
        ],
      ),
    );

    final dispatcher = await buildPortalDispatcher(eventStore: store);
    final policy = policyBootstrap.policy;

    final sc = Principal.user(
      userId: 'sc-1',
      roles: const {'StudyCoordinator'},
      activeRole: 'StudyCoordinator',
    );
    const linkPerm = Permission('portal.participant.link', scopeClass: 'site');
    const atSite1 = BoundScope(class_: 'site', value: 'site-1');

    // Before any grant: SC has no assignment -> denied.
    expect(await policy.isPermitted(sc, linkPerm, atSite1), isA<Deny>());

    // Admin assigns StudyCoordinator @ site-1 to sc-1 via the action.
    final assign = await dispatcher.dispatch(
      const ActionSubmission(
        actionName: 'ACT-USR-008',
        rawInput: <String, Object?>{
          'userId': 'sc-1',
          'role': 'StudyCoordinator',
          'site': 'site-1',
        },
        idempotencyKey: 'assign-sc1-site1',
      ),
      _ctx(_admin()),
    );
    expect(assign, isA<DispatchSuccess<Object?>>());

    // Now SC is enforced at site-1.
    expect(await policy.isPermitted(sc, linkPerm, atSite1), isA<Allow>());

    // Admin revokes the same tuple.
    final revoke = await dispatcher.dispatch(
      const ActionSubmission(
        actionName: 'ACT-USR-011',
        rawInput: <String, Object?>{
          'userId': 'sc-1',
          'role': 'StudyCoordinator',
          'site': 'site-1',
        },
        idempotencyKey: 'revoke-sc1-site1',
      ),
      _ctx(_admin()),
    );
    expect(revoke, isA<DispatchSuccess<Object?>>());

    // Enforcement removed.
    expect(await policy.isPermitted(sc, linkPerm, atSite1), isA<Deny>());
  });
}
