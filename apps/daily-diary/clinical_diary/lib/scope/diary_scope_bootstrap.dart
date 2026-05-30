// Implements: DIARY-DEV-evs-stack-adoption/A+B — composes the data layer through
//   bootstrapEventStore + a LocalScope (mounted at the app root in main.dart).
// Implements: DIARY-DEV-local-participant-authorization/A+B+C — the local
//   participant is authenticated from launch (setCredential) with a stable
//   per-install id, so recording works regardless of enrollment; enrollment
//   gates sync, not entry.
import 'package:clinical_diary/scope/diary_action_registry.dart';
import 'package:clinical_diary/scope/local_participant_authorization_policy.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

/// Holder for the new reactive composition root, built alongside (not replacing)
/// the old ClinicalDiaryRuntime during the transition.
class DiaryScopeRuntime {
  DiaryScopeRuntime({
    required this.scope,
    required this.bundle,
    required this.authSession,
  });

  final LocalScope scope;
  final EventStoreBundle bundle;
  final LocalAuthSession authSession;

  Future<void> dispose() async {
    await scope.dispose();
    await bundle.eventStore.close();
  }
}

/// Wires the new stack: bootstrapEventStore -> ActionDispatcher -> LocalScope.
/// [localUserId] is the stable per-install id (recording is never gated on
/// study enrollment). [extraEntryTypes] carries dynamic `<id>_survey` defs when
/// the caller has them (empty is fine for I1).
Future<DiaryScopeRuntime> bootstrapDiaryScope({
  required StorageBackend backend,
  required String deviceId,
  required String softwareVersion,
  required String localUserId,
  List<EntryTypeDefinition> extraEntryTypes = const [],
}) async {
  final entryTypes = <EntryTypeDefinition>[
    for (final t in diaryOriginatedEventTypes) t.definition,
    ...extraEntryTypes,
  ];
  final projections = ProjectionRegistry()
    ..register(diaryEntriesProjection)
    ..register(settingsProjection);

  final bundle = await bootstrapEventStore(
    backend: backend,
    source: Source(
      hopId: 'mobile-device',
      identifier: deviceId,
      softwareVersion: softwareVersion,
    ),
    entryTypes: entryTypes,
    destinations: const [], // native ingest Destination is I2
    projections: projections,
  );

  // The local participant is authenticated from first launch (stable id).
  final authSession = LocalAuthSession(defaultActiveRole: 'participant')
    ..setCredential(localUserId);

  final registry = buildDiaryActionRegistry();
  final policy = LocalParticipantAuthorizationPolicy(
    grantedPermissions: registry.allDeclaredPermissions,
  );
  final dispatcher = ActionDispatcher(
    registry: registry,
    authorization: policy,
    events: bundle.eventStore,
    idempotency: InMemoryIdempotencyStore(),
  );

  final permissionSource = LocalPermissionSource(
    eventStore: bundle.eventStore,
    policy: policy,
  )..setActivePrincipal(authSession.principal);

  final scope = LocalScope(
    authSession: authSession,
    actionSubmitter: LocalActionSubmitter(
      dispatcher: dispatcher,
      authSession: authSession,
    ),
    viewSource: LocalViewSource(eventStore: bundle.eventStore),
    permissionSource: permissionSource,
  );

  return DiaryScopeRuntime(
    scope: scope,
    bundle: bundle,
    authSession: authSession,
  );
}
