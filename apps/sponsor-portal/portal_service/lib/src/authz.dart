// Implements: DIARY-PRD-action-inventory/A — composes the portal action
//   registry's declared permissions with the role-permission seed and scope
//   registry into an event-log-backed authorization policy.
import 'package:event_sourcing/event_sourcing.dart';
// portal_actions re-exports diary_shared_model's sharedEventCatalog
// (including diaryEntriesProjection, diaryEntryAggregateType, diaryEntriesViewName).
import 'package:portal_actions/portal_actions.dart';

import 'fcm_projections.dart';
import 'projections.dart';
import 'scope_classes.dart';

/// Stable per-installation identity stamped onto every appended event's
/// provenance (see `Source.identifier`). A real deployment persists a UUIDv4
/// across boots; the in-memory enforcement core uses this fixed value.
// Implements: DIARY-DEV-portal-durable-event-store/B — fixed originating-node
//   identity, stable across process restarts.
const String _portalInstallIdentifier = '00000000-0000-4000-8000-0000000000p1';

/// Every entry type the portal server writes through the EventStore: the
/// portal-private event types, the cross-wire shared-event catalog, and the
/// three framework projection/denial aggregate types the permissions policy
/// requires (`role_permission_grant`, `user_role_scope`, `action_denial`).
///
/// This helper lives here (not in portal_actions) because it composes library
/// framework types with the shared catalog. The lists are disjoint by id; a
/// defensive dedupe-by-id guards against a duplicate registration throwing at
/// bootstrap.
List<EntryTypeDefinition> portalEntryTypes() {
  final byId = <String, EntryTypeDefinition>{};
  void add(EntryTypeDefinition def) => byId.putIfAbsent(def.id, () => def);

  for (final def in portalPrivateEventTypes) {
    add(def);
  }
  for (final shared in sharedEventCatalog) {
    add(shared.definition);
  }
  // Framework projection + denial aggregate types the policy reads/writes.
  add(
    const EntryTypeDefinition(
      id: 'role_permission_grant',
      registeredVersion: 1,
      name: 'Role-Permission Grant',
    ),
  );
  add(
    const EntryTypeDefinition(
      id: 'user_role_scope',
      registeredVersion: 1,
      name: 'User-Role-Scope Assignment',
    ),
  );
  add(
    const EntryTypeDefinition(
      id: 'action_denial',
      registeredVersion: 1,
      name: 'Action Denial',
    ),
  );
  // Implements: DIARY-DEV-portal-durable-event-store/C — one-time boot-seed
  //   marker. Appended last in the seed block; its presence on a durable store
  //   gates re-seeding on subsequent boots.
  add(
    const EntryTypeDefinition(
      id: 'portal_seed_marker',
      registeredVersion: 1,
      name: 'Portal Boot-Seed Marker',
    ),
  );
  // Implements: DIARY-DEV-portal-settings-store/A — event-sourced portal config.
  add(
    const EntryTypeDefinition(
      id: 'portal_setting_changed',
      registeredVersion: 1,
      name: 'Portal Setting Changed',
    ),
  );
  // Implements: DIARY-DEV-portal-second-factor-toggle/D — attributable bypass.
  add(
    const EntryTypeDefinition(
      id: 'user_login_otp_skipped',
      registeredVersion: 1,
      name: 'User Login OTP Skipped',
    ),
  );
  // Implements: DIARY-DEV-sponsor-branding-source/A — event-sourced sponsor
  //   branding (metadata + asset manifest).
  add(
    const EntryTypeDefinition(
      id: 'sponsor_branding_configured',
      registeredVersion: 1,
      name: 'Sponsor Branding Configured',
    ),
  );

  return byId.values.toList(growable: false);
}

/// Bootstrap a fresh portal EventStore over [backend]. Registers the
/// role_permission_grants and user_role_scopes table projections (which drive
/// the authorization policy's grant + scope-coverage checks), the
/// participant_site_index projection (which backs containment resolution), and
/// every portal entry type. Returns the live [EventStore].
// Implements: DIARY-DEV-participant-site-index/B — openPortalEventStore registers
//   participant_site_index so the policy's ContainmentResolver reads it in-txn.
Future<EventStore> openPortalEventStore({
  required StorageBackend backend,
}) async {
  final projections = ProjectionRegistry()
    ..register(rolePermissionGrantsSpec)
    ..register(userRoleScopesSpec)
    ..register(userTierIndexSpec)
    ..register(participantSiteIndexSpec)
    ..register(linkingCodesSpec)
    // Implements: DIARY-DEV-portal-activation-code-lifecycle/E — activation_codes
    //   projects the durable keyed-hash lifecycle the ActivationCodeStore reads.
    ..register(activationCodesSpec)
    ..register(sitesIndexSpec)
    ..register(participantRecordSpec)
    ..register(usersIndexSpec)
    ..register(sessionsIndexSpec)
    ..register(raveSyncStatusSpec)
    // Implements: DIARY-DEV-portal-settings-store/B — portal_settings projects
    //   the latest value per setting key for runtime config reads.
    ..register(portalSettingsSpec)
    // Implements: DIARY-DEV-sponsor-branding-source/A — sponsor_branding projects
    //   the latest branding configuration per sponsor for the JWT-gated asset
    //   endpoint + diary branding fetch.
    ..register(sponsorBrandingSpec)
    // participant_fcm_tokens materializes the current active FCM token per
    //   (participant, platform) for push dispatch.
    ..register(fcmActiveTokensSpec)
    // Implements: DIARY-DEV-participant-ingest/C — ingested diary events materialize
    //   into the diary_entries view.
    ..register(diaryEntriesProjection)
    // Implements: DIARY-PRD-questionnaire-system/B — questionnaire_instance projects
    //   Completion Status per instance (Phase 1: folds questionnaire_assigned).
    ..register(questionnaireInstanceSpec)
    // Implements: DIARY-DEV-outgoing-intent-correlation/B — recall notices
    //   durably queryable per (participant, instance); removed on device ack.
    ..register(questionnaireRecallNoticeSpec);

  final bundle = await bootstrapEventStore(
    backend: backend,
    source: const Source(
      hopId: 'portal-server',
      identifier: _portalInstallIdentifier,
      softwareVersion: 'portal_service@0.1.0',
    ),
    entryTypes: portalEntryTypes(),
    destinations: const <Destination>[],
    projections: projections,
  );
  return bundle.eventStore;
}

/// Apply the portal role-permission seed against [eventStore] and build the
/// authorization policy. Returns `PolicyReady` on a clean seed (the returned
/// policy reads grants + scope coverage from the event log) or `PolicyFailSafe`
/// (deny-everything) carrying the validation errors.
///
/// The YAML is treated as the authoritative source of role→permission grants.
/// `bootstrapActionPermissions` appends `permission_granted` events for pairs
/// the YAML adds but the projection lacks; this function additionally applies
/// the *drift* — `permission_revoked` events for grants present in the
/// `role_permission_grants` projection that the YAML no longer declares — so a
/// permission removed from the YAML actually disappears on the next boot.
///
/// This is safe today because no Portal Action grants role→permission pairs at
/// runtime: the only writer of those grants is this seed, so the drift is
/// exactly "what the YAML dropped since last boot". If/when runtime
/// role-permission editing is introduced, this full-reconcile would clobber
/// those runtime grants and the reconcile strategy must be revisited
/// (DIARY-DEV-role-permissions-seed).
// Implements: DIARY-DEV-role-permissions-seed/A — YAML is authoritative: boot
//   grants what the YAML adds and revokes the drift it dropped.
Future<AuthorizationBootstrapResult> buildPortalAuthorizationPolicy({
  required EventStore eventStore,
  required String roleGrantsYaml,
}) async {
  final result = await bootstrapActionPermissions(
    eventStore: eventStore,
    declaredPermissions: buildPortalActionRegistry().allDeclaredPermissions,
    scopeClassRegistry: buildPortalScopeRegistry(),
    yamlSource: roleGrantsYaml,
  );
  // Only reconcile when the seed itself applied. On PolicyFailSafe the seed was
  // rejected (validation error) and never touched the log — there is nothing to
  // reconcile against, and revoking here would act on a stale, unvalidated YAML.
  if (result is PolicyReady) {
    await _revokePermissionDrift(
      eventStore: eventStore,
      roleGrantsYaml: roleGrantsYaml,
    );
  }
  return result;
}

/// Revoke every grant in the `role_permission_grants` projection that the
/// current [roleGrantsYaml] does not declare. Idempotent: a revoked grant
/// leaves the projection, so a subsequent boot with the same YAML finds no
/// drift and emits nothing.
// Implements: DIARY-DEV-role-permissions-seed/A — applies the computed drift
//   (view-minus-seed) as permission_revoked events.
Future<void> _revokePermissionDrift({
  required EventStore eventStore,
  required String roleGrantsYaml,
}) async {
  final seed = YamlSeedLoader().loadFromString(roleGrantsYaml);
  final inSeed = <String>{
    for (final entry in seed.grants.entries)
      for (final permission in entry.value) '${entry.key}:$permission',
  };

  final rows = await eventStore.backend.findViewRows('role_permission_grants');
  for (final row in rows) {
    final role = row['role'] as String;
    final permissionName = row['permissionName'] as String;
    if (inSeed.contains('$role:$permissionName')) continue;
    await eventStore.append(
      entryType: 'role_permission_grant',
      aggregateType: 'role_permission_grant',
      aggregateId: '$role:$permissionName',
      eventType: 'permission_revoked',
      data: PermissionRevokedPayload(
        role: role,
        permissionName: permissionName,
      ).toJson(),
      initiator: const AutomationInitiator(
        service: 'portal_permissions_seed_drift',
      ),
    );
  }
}
