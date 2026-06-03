// Verifies: DIARY-DEV-operator-tier-authz/C+D+F
// Verifies: DIARY-PRD-user-account-edit/H
//
// Operator-tier authorization matrix. User-management permissions are tier-
// scoped via the `user` scope class (user-contained-in-tier through
// user_tier_index); granting the SystemOperator role is gated separately on the
// `tier` scope class (the grant_role escalation axis). An Administrator carries
// staff-tier coverage (BoundScope(tier, staff)) and therefore CANNOT modify an
// operator-tier account or grant the SystemOperator role; a SystemOperator
// carries operator-tier wildcard coverage (ValueWildcardScope(tier)) and CAN.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

ActionContext _ctx(Principal principal) => ActionContext(
  principal: principal,
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 1, 1),
);

Principal _admin() => Principal.user(
  userId: 'admin-1',
  roles: const <String>{'Administrator'},
  activeRole: 'Administrator',
);

Principal _sysop() => Principal.user(
  userId: 'sysop-1',
  roles: const <String>{'SystemOperator'},
  activeRole: 'SystemOperator',
);

/// Opens a portal store, seeds an Administrator (staff-tier coverage + site
/// wildcard) and a SystemOperator (operator-tier wildcard), and seeds
/// user_tier_index rows for a staff target and an operator target. Returns the
/// live store + policy + dispatcher.
Future<
  ({EventStore store, AuthorizationPolicy policy, ActionDispatcher dispatcher})
>
_openMatrix(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  final store = await openPortalEventStore(
    backend: SembastBackend(database: db),
  );

  final bootstrap = await buildPortalAuthorizationPolicy(eventStore: store);
  expect(bootstrap.isReady, isTrue, reason: 'seed errors: ${bootstrap.errors}');

  await bootstrapRoleAssignments(
    eventStore: store,
    seed: const RoleAssignmentSeed(
      entries: <RoleAssignmentSeedEntry>[
        // Administrator: site wildcard (for the existing operational perms) AND
        // staff-tier coverage (so it can manage staff accounts + grant staff
        // roles, but NOT operator accounts / the SystemOperator role).
        RoleAssignmentSeedEntry(
          userId: 'admin-1',
          role: 'Administrator',
          scope: ValueWildcardScope(class_: 'site'),
        ),
        RoleAssignmentSeedEntry(
          userId: 'admin-1',
          role: 'Administrator',
          scope: BoundScope(class_: 'tier', value: 'staff'),
        ),
        // SystemOperator: operator-tier wildcard covers every tier (staff +
        // operator) and the grant_role escalation axis.
        RoleAssignmentSeedEntry(
          userId: 'sysop-1',
          role: 'SystemOperator',
          scope: ValueWildcardScope(class_: 'tier'),
        ),
      ],
    ),
  );

  // user_tier_index rows for the two target accounts. This test does not run the
  // user_tier_reactor, so seed them directly via user_tier_changed events.
  Future<void> seedTier(String userId, String tier) => store.append(
    entryType: 'user_tier_changed',
    aggregateType: 'portal_user',
    aggregateId: userId,
    eventType: 'user_tier_changed',
    data: <String, Object?>{'user_id': userId, 'tier': tier},
    initiator: const AutomationInitiator(service: 'test-seed'),
  );
  await seedTier('staff-target', 'staff');
  await seedTier('op-target', 'operator');

  final dispatcher = await buildPortalDispatcher(eventStore: store);
  return (store: store, policy: bootstrap.policy, dispatcher: dispatcher);
}

void main() {
  group('operator-tier enforcement matrix', () {
    // Implements/Verifies: DIARY-DEV-operator-tier-authz/C — the `user` scope
    //   axis: Administrator (staff-tier) may act on a staff account; an operator
    //   account is unreachable. Probed at the policy level for both the actor's
    //   coverage and the target's tier resolution.
    test(
      'Administrator vs staff-target: allowed; vs op-target: denied',
      () async {
        final m = await _openMatrix('opmx-policy');

        // staff-target -> Allow (admin holds the perm + staff-tier coverage,
        // target resolves to staff via user_tier_index).
        for (final perm in const <String>[
          'portal.user.edit',
          'portal.user.deactivate',
          'portal.user.unlock',
          'portal.user.revoke_role',
        ]) {
          final d = await m.policy.isPermitted(
            _admin(),
            Permission(perm, scopeClass: 'user'),
            const BoundScope(class_: 'user', value: 'staff-target'),
          );
          expect(d, isA<Allow>(), reason: 'admin $perm on staff-target');
        }

        // op-target -> Deny (admin's tier coverage is staff-only; op-target
        // resolves to operator, outside coverage).
        for (final perm in const <String>[
          'portal.user.edit',
          'portal.user.deactivate',
          'portal.user.unlock',
          'portal.user.revoke_role',
        ]) {
          final d = await m.policy.isPermitted(
            _admin(),
            Permission(perm, scopeClass: 'user'),
            const BoundScope(class_: 'user', value: 'op-target'),
          );
          expect(d, isA<Deny>(), reason: 'admin $perm on op-target');
        }
      },
    );

    // Verifies: DIARY-DEV-operator-tier-authz/F — the SystemOperator (operator-
    //   tier wildcard) may act on every tier.
    test('SystemOperator vs staff-target AND op-target: allowed', () async {
      final m = await _openMatrix('opmx-sysop-policy');
      for (final target in const <String>['staff-target', 'op-target']) {
        for (final perm in const <String>[
          'portal.user.edit',
          'portal.user.deactivate',
          'portal.user.unlock',
          'portal.user.revoke_role',
        ]) {
          final d = await m.policy.isPermitted(
            _sysop(),
            Permission(perm, scopeClass: 'user'),
            BoundScope(class_: 'user', value: target),
          );
          expect(d, isA<Allow>(), reason: 'sysop $perm on $target');
        }
      }
    });

    // Verifies: DIARY-PRD-user-account-edit/H — end-to-end dispatch: Administrator
    //   editing/deactivating a staff account succeeds.
    test(
      'dispatch: Administrator edits/deactivates staff-target -> success',
      () async {
        final m = await _openMatrix('opmx-disp-admin-staff');

        final edit = await m.dispatcher.dispatch(
          const ActionSubmission(
            actionName: 'ACT-USR-002',
            rawInput: <String, Object?>{
              'userId': 'staff-target',
              'name': 'New Name',
            },
            idempotencyKey: 'edit-staff-1',
          ),
          _ctx(_admin()),
        );
        expect(edit, isA<DispatchSuccess<Object?>>());

        final deact = await m.dispatcher.dispatch(
          const ActionSubmission(
            actionName: 'ACT-USR-003',
            rawInput: <String, Object?>{
              'userId': 'staff-target',
              'reason': 'offboarding',
            },
            idempotencyKey: 'deact-staff-1',
          ),
          _ctx(_admin()),
        );
        expect(deact, isA<DispatchSuccess<Object?>>());
      },
    );

    // Verifies: DIARY-PRD-user-account-edit/H — end-to-end dispatch: Administrator
    //   editing/deactivating an OPERATOR account is denied AND records an
    //   action_denial event.
    test('dispatch: Administrator edits/deactivates op-target -> denied + '
        'recorded action_denial', () async {
      final m = await _openMatrix('opmx-disp-admin-op');

      final edit = await m.dispatcher.dispatch(
        const ActionSubmission(
          actionName: 'ACT-USR-002',
          rawInput: <String, Object?>{
            'userId': 'op-target',
            'name': 'New Name',
          },
          idempotencyKey: 'edit-op-1',
        ),
        _ctx(_admin()),
      );
      expect(edit, isA<DispatchAuthorizationDenied<Object?>>());

      final deact = await m.dispatcher.dispatch(
        const ActionSubmission(
          actionName: 'ACT-USR-003',
          rawInput: <String, Object?>{
            'userId': 'op-target',
            'reason': 'offboarding',
          },
          idempotencyKey: 'deact-op-1',
        ),
        _ctx(_admin()),
      );
      expect(deact, isA<DispatchAuthorizationDenied<Object?>>());

      final denials = await m.store.backend.findAllEvents(
        entryType: 'action_denial',
      );
      expect(
        denials.where((e) => e.eventType == 'authorization_denied'),
        hasLength(2),
        reason: 'both denied dispatches record an authorization_denied event',
      );
    });

    // Verifies: DIARY-DEV-operator-tier-authz/D — the grant_role escalation axis.
    //   Administrator assigning the SystemOperator role to ANY target is denied
    //   (its tier coverage is staff-only); assigning a staff role succeeds.
    test('dispatch: Administrator grant_role of SystemOperator -> denied; '
        'staff role -> success', () async {
      final m = await _openMatrix('opmx-disp-grant');

      // Granting SystemOperator -> Deny on the grant_role/tier axis.
      final grantOp = await m.dispatcher.dispatch(
        ActionSubmission(
          actionName: 'ACT-USR-007',
          rawInput: <String, Object?>{
            'userId': 'staff-target',
            'role': 'SystemOperator',
            'scope': const ValueWildcardScope(class_: 'site').toJson(),
          },
          idempotencyKey: 'grant-op-role',
        ),
        _ctx(_admin()),
      );
      expect(grantOp, isA<DispatchAuthorizationDenied<Object?>>());

      // Granting a staff role to a staff target -> Success (both axes pass).
      final grantStaff = await m.dispatcher.dispatch(
        ActionSubmission(
          actionName: 'ACT-USR-007',
          rawInput: <String, Object?>{
            'userId': 'staff-target',
            'role': 'StudyCoordinator',
            'scope': const BoundScope(class_: 'site', value: 'site-1').toJson(),
          },
          idempotencyKey: 'grant-staff-role',
        ),
        _ctx(_admin()),
      );
      expect(grantStaff, isA<DispatchSuccess<Object?>>());
    });

    // Verifies: DIARY-DEV-operator-tier-authz/D+F — the SystemOperator may grant
    //   the SystemOperator role (operator-tier coverage satisfies grant_role).
    test(
      'dispatch: SystemOperator grant_role of SystemOperator -> success',
      () async {
        final m = await _openMatrix('opmx-disp-grant-sysop');
        final grantOp = await m.dispatcher.dispatch(
          ActionSubmission(
            actionName: 'ACT-USR-007',
            rawInput: <String, Object?>{
              'userId': 'op-target',
              'role': 'SystemOperator',
              'scope': const ValueWildcardScope(class_: 'site').toJson(),
            },
            idempotencyKey: 'sysop-grant-op-role',
          ),
          _ctx(_sysop()),
        );
        expect(grantOp, isA<DispatchSuccess<Object?>>());
      },
    );

    // Verifies: DIARY-DEV-operator-tier-authz/F — end-to-end dispatch: the
    //   SystemOperator can edit/deactivate/revoke-role on an OPERATOR account
    //   (the case an Administrator is denied).
    test(
      'dispatch: SystemOperator edits/deactivates op-target -> success',
      () async {
        final m = await _openMatrix('opmx-disp-sysop-op');

        final edit = await m.dispatcher.dispatch(
          const ActionSubmission(
            actionName: 'ACT-USR-002',
            rawInput: <String, Object?>{
              'userId': 'op-target',
              'name': 'Operator Renamed',
            },
            idempotencyKey: 'sysop-edit-op',
          ),
          _ctx(_sysop()),
        );
        expect(edit, isA<DispatchSuccess<Object?>>());

        final deact = await m.dispatcher.dispatch(
          const ActionSubmission(
            actionName: 'ACT-USR-003',
            rawInput: <String, Object?>{
              'userId': 'op-target',
              'reason': 'rotating operator',
            },
            idempotencyKey: 'sysop-deact-op',
          ),
          _ctx(_sysop()),
        );
        expect(deact, isA<DispatchSuccess<Object?>>());
      },
    );
  });
}
