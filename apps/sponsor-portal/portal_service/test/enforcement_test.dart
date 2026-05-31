// Verifies: DIARY-PRD-action-inventory/A+C — end-to-end portal enforcement:
//   role-permission grants gate the action, and site-scoped assignments gate
//   the scope. Built on the event_sourcing library's TableBackedAuthorizationPolicy.
//
// NOTE ON SCOPE CLASSES: every portal participant/questionnaire permission is
// scopeClass 'site', as is site.view; audit.view / the ops permissions are
// UNSCOPED.
// So a BoundScope('site', X) assignment matches a site-scoped request at X by
// direct value-equality (appliesExact). The participant->site containment in
// buildPortalScopeRegistry is exercised only when a 'participant'-scoped
// permission is requested; no current permission is participant-scoped, so the
// participant_site_index seeding below proves the projection wires cleanly
// rather than driving any allow/deny here.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

/// Test-local participant->site containment index. The production materializer
/// is a later sub-project; here we project `participant_synced_from_edc` events
/// (which carry participant_id + site_id) into the `participant_site_index`
/// view the ContainmentResolver reads.
final _participantSiteIndexSpec = TableProjectionSpec(
  viewName: 'participant_site_index',
  interest: const SubscriptionFilter(
    eventTypes: {'participant_synced_from_edc'},
    aggregateTypes: {'participant'},
  ),
  insertEventTypes: const {'participant_synced_from_edc'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.participant_id']),
  rowData: const SelectedFields(['participant_id', 'site_id']),
);

/// Open a portal event store that ALSO materializes the test-local
/// participant_site_index, then seed the role-permission grants and the given
/// role assignments. Returns the live policy + store + dispatcher.
Future<
  ({EventStore store, AuthorizationPolicy policy, ActionDispatcher dispatcher})
>
_openSeeded({
  required String dbName,
  required List<RoleAssignmentSeedEntry> assignments,
}) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  final projections = ProjectionRegistry()
    ..register(rolePermissionGrantsSpec)
    ..register(userRoleScopesSpec)
    ..register(_participantSiteIndexSpec);

  final bundle = await bootstrapEventStore(
    backend: SembastBackend(database: db),
    source: const Source(
      hopId: 'portal-server',
      identifier: '00000000-0000-4000-8000-0000000000t1',
      softwareVersion: 'portal_service@0.1.0-test',
    ),
    entryTypes: portalEntryTypes(),
    destinations: const <Destination>[],
    projections: projections,
  );
  final store = bundle.eventStore;

  final bootstrap = await buildPortalAuthorizationPolicy(eventStore: store);
  expect(bootstrap.isReady, isTrue, reason: 'seed errors: ${bootstrap.errors}');

  await bootstrapRoleAssignments(
    eventStore: store,
    seed: RoleAssignmentSeed(entries: assignments),
  );

  final dispatcher = await buildPortalDispatcher(eventStore: store);
  return (store: store, policy: bootstrap.policy, dispatcher: dispatcher);
}

/// Seed a participant->site mapping by appending a participant_synced_from_edc
/// event the test-local participant_site_index projects.
Future<void> _seedParticipantSite(
  EventStore store, {
  required String participantId,
  required String siteId,
}) async {
  await store.append(
    entryType: 'participant_synced_from_edc',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_synced_from_edc',
    data: <String, Object?>{'participant_id': participantId, 'site_id': siteId},
    initiator: const AutomationInitiator(service: 'edc_sync_test'),
  );
}

ActionContext _ctx(Principal principal) => ActionContext(
  principal: principal,
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('portal enforcement (allow / deny / scope)', () {
    test('1. StudyCoordinator at site-1 dispatching ACT-PAT-001 link at site-1 '
        '-> DispatchSuccess', () async {
      final seeded = await _openSeeded(
        dbName: 'enf-1',
        assignments: const <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: 'sc-1',
            role: 'StudyCoordinator',
            scope: BoundScope(class_: 'site', value: 'site-1'),
          ),
        ],
      );
      await _seedParticipantSite(
        seeded.store,
        participantId: 'p-1',
        siteId: 'site-1',
      );

      final result = await seeded.dispatcher.dispatch(
        const ActionSubmission(
          actionName: 'ACT-PAT-001',
          rawInput: <String, Object?>{
            'siteId': 'site-1',
            'participantId': 'p-1',
            'linkingCode': 'CODE-123',
            'expiresAt': '2026-12-31T00:00:00Z',
          },
          idempotencyKey: 'link-p-1-once',
        ),
        _ctx(
          Principal.user(
            userId: 'sc-1',
            roles: const <String>{'StudyCoordinator'},
            activeRole: 'StudyCoordinator',
          ),
        ),
      );
      expect(result, isA<DispatchSuccess<Object?>>());
    });

    test('1b. CRA at site-1 dispatching ACT-PAT-001 link -> '
        'DispatchAuthorizationDenied + recorded action_denial event', () async {
      // CRA lacks portal.participant.link, so the dispatch must be denied
      // end-to-end: it returns the authorization-denied shape AND records an
      // action_denial entry-type event (eventType authorization_denied).
      final seeded = await _openSeeded(
        dbName: 'enf-1b',
        assignments: const <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: 'cra-1',
            role: 'CRA',
            scope: BoundScope(class_: 'site', value: 'site-1'),
          ),
        ],
      );
      await _seedParticipantSite(
        seeded.store,
        participantId: 'p-1',
        siteId: 'site-1',
      );

      final result = await seeded.dispatcher.dispatch(
        const ActionSubmission(
          actionName: 'ACT-PAT-001',
          rawInput: <String, Object?>{
            'siteId': 'site-1',
            'participantId': 'p-1',
            'linkingCode': 'CODE-123',
            'expiresAt': '2026-12-31T00:00:00Z',
          },
          idempotencyKey: 'link-p-1-cra-denied',
        ),
        _ctx(
          Principal.user(
            userId: 'cra-1',
            roles: const <String>{'CRA'},
            activeRole: 'CRA',
          ),
        ),
      );
      expect(result, isA<DispatchAuthorizationDenied<Object?>>());

      // The denial SHALL be recorded as an action_denial entry-type event.
      final denials = await seeded.store.backend.findAllEvents(
        entryType: 'action_denial',
      );
      expect(
        denials.where((e) => e.eventType == 'authorization_denied'),
        hasLength(1),
        reason: 'exactly one authorization_denied event must be recorded',
      );
    });

    test(
      '2. StudyCoordinator at site-2 (unassigned) -> link at site-2 Denied',
      () async {
        final seeded = await _openSeeded(
          dbName: 'enf-2',
          assignments: const <RoleAssignmentSeedEntry>[
            RoleAssignmentSeedEntry(
              userId: 'sc-1',
              role: 'StudyCoordinator',
              scope: BoundScope(class_: 'site', value: 'site-1'),
            ),
          ],
        );
        final decision = await seeded.policy.isPermitted(
          Principal.user(
            userId: 'sc-1',
            roles: const <String>{'StudyCoordinator'},
            activeRole: 'StudyCoordinator',
          ),
          const Permission('portal.participant.link', scopeClass: 'site'),
          const BoundScope(class_: 'site', value: 'site-2'),
        );
        expect(decision, isA<Deny>());
        expect((decision as Deny).reason, DenyReason.notGranted);
      },
    );

    test(
      '3. CRA (monitor-only) -> participant.link Denied notGranted',
      () async {
        final seeded = await _openSeeded(
          dbName: 'enf-3',
          assignments: const <RoleAssignmentSeedEntry>[
            RoleAssignmentSeedEntry(
              userId: 'cra-1',
              role: 'CRA',
              scope: BoundScope(class_: 'site', value: 'site-1'),
            ),
          ],
        );
        final decision = await seeded.policy.isPermitted(
          Principal.user(
            userId: 'cra-1',
            roles: const <String>{'CRA'},
            activeRole: 'CRA',
          ),
          const Permission('portal.participant.link', scopeClass: 'site'),
          const BoundScope(class_: 'site', value: 'site-1'),
        );
        expect(decision, isA<Deny>());
        expect((decision as Deny).reason, DenyReason.notGranted);
      },
    );

    test('4. SystemOperator (TotalWildcardScope) -> rave.unwedge Allowed; '
        'participant.view Denied', () async {
      final seeded = await _openSeeded(
        dbName: 'enf-4',
        assignments: const <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: 'sysop-1',
            role: 'SystemOperator',
            scope: TotalWildcardScope(),
          ),
        ],
      );
      final principal = Principal.user(
        userId: 'sysop-1',
        roles: const <String>{'SystemOperator'},
        activeRole: 'SystemOperator',
      );
      // Unscoped ops permission the role carries -> Allow.
      final allow = await seeded.policy.isPermitted(
        principal,
        const Permission('portal.rave.unwedge'),
        null,
      );
      expect(allow, isA<Allow>());
      // Site-scoped permission the role does NOT carry -> Deny notGranted.
      final deny = await seeded.policy.isPermitted(
        principal,
        const Permission('portal.participant.view', scopeClass: 'site'),
        const BoundScope(class_: 'site', value: 'site-1'),
      );
      expect(deny, isA<Deny>());
      expect((deny as Deny).reason, DenyReason.notGranted);
    });

    test('5. Administrator (ValueWildcardScope site) -> site.view at any '
        'site Allowed; participant.link Denied', () async {
      // portal.site.view is site-scoped and IS granted to Administrator, so
      // it is the right probe for a ValueWildcardScope('site') assignment
      // matching any site value.
      final seeded = await _openSeeded(
        dbName: 'enf-5',
        assignments: const <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: 'admin-1',
            role: 'Administrator',
            scope: ValueWildcardScope(class_: 'site'),
          ),
        ],
      );
      final principal = Principal.user(
        userId: 'admin-1',
        roles: const <String>{'Administrator'},
        activeRole: 'Administrator',
      );
      // Granted, site-scoped: value-wildcard covers any site value.
      final allowA = await seeded.policy.isPermitted(
        principal,
        const Permission('portal.site.view', scopeClass: 'site'),
        const BoundScope(class_: 'site', value: 'site-99'),
      );
      expect(allowA, isA<Allow>());
      // Not granted to Administrator -> Deny notGranted.
      final deny = await seeded.policy.isPermitted(
        principal,
        const Permission('portal.participant.link', scopeClass: 'site'),
        const BoundScope(class_: 'site', value: 'site-99'),
      );
      expect(deny, isA<Deny>());
      expect((deny as Deny).reason, DenyReason.notGranted);
    });
  });
}
