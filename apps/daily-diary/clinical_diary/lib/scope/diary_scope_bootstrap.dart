import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/questionnaire_status_projection.dart';
import 'package:clinical_diary/scope/diary_action_registry.dart';
import 'package:clinical_diary/scope/local_participant_authorization_policy.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

/// Holder for the diary's reactive composition root.
class DiaryScopeRuntime {
  DiaryScopeRuntime({
    required this.scope,
    required this.bundle,
    required this.authSession,
    required this.permissionSource,
    this.syncCycle,
  });

  final LocalScope scope;
  final EventStoreBundle bundle;
  final LocalAuthSession authSession;
  final LocalPermissionSource permissionSource;

  /// The outbound [SyncCycle] driving the registered destination(s), or `null`
  /// when bootstrapped with no outbound destination (tests / headless). When
  /// present, the app installs drain triggers (`installDiarySyncTriggers`) that
  /// route into [SyncCycle.call]; the post-append fire-and-forget trigger is
  /// already wired through `bootstrapEventStore`'s `syncCycleTrigger`.
  final SyncCycle? syncCycle;

  /// Disposes all owned resources in dependency order.
  ///
  /// [LocalScope.dispose] does NOT cascade to [LocalPermissionSource] or
  /// [LocalAuthSession] (it only sets an internal disposed flag), so the
  /// composition root disposes them explicitly to avoid resource leaks.
  Future<void> dispose() async {
    await permissionSource.dispose();
    await authSession.dispose();
    await scope.dispose();
    await bundle.eventStore.close();
  }
}

// Implements: DIARY-DEV-action-write-path/A — the dispatcher records an
//   `action_denial` audit event on every failed dispatch stage (unknown-action /
//   parse / validate / authorize / execute). The diary scope registers the
//   (non-materializing) type so a denial returns a clean DispatchResult instead
//   of throwing `entryType not registered`.
const EntryTypeDefinition _actionDenialEntryType = EntryTypeDefinition(
  id: 'action_denial',
  registeredVersion: 1,
  name: 'Action Denial',
  isMaterialized: false,
);

// Implements: DIARY-DEV-evs-stack-adoption/A+B
// Implements: DIARY-DEV-local-participant-authorization/A+B+C
/// Wires the new stack: bootstrapEventStore -> ActionDispatcher -> LocalScope.
/// [localUserId] is the stable per-install id (recording is never gated on
/// study enrollment). [extraEntryTypes] carries dynamic `<id>_survey` defs when
/// the caller has them (empty is fine for I1).
///
/// [outboundDestinations] supplies the native outbound [Destination]s (the
/// diary-server / portal ingest queues — clinical diary entries via
/// `DiaryServerDestination`, system/FCM events via `SystemEventsDestination`).
/// When non-empty they are all registered with `bootstrapEventStore` and a
/// single [SyncCycle] is constructed and wired as the post-append
/// `syncCycleTrigger` (fire-and-forget drain after every write); the SyncCycle
/// drives the WHOLE `bundle.destinations` registry, so every registered
/// destination drains on each cycle. The caller is responsible for (a) calling
/// `bundle.destinations.setStartDate(<destinationId>, ...)` to activate each
/// destination at the appropriate watermark (diary entries gate on trial-start;
/// system events activate at link), and (b) installing the lifecycle /
/// connectivity / periodic triggers via `installDiarySyncTriggers`. When empty,
/// the no-destination path is kept for tests / headless boots.
Future<DiaryScopeRuntime> bootstrapDiaryScope({
  required StorageBackend backend,
  required String deviceId,
  required String softwareVersion,
  required String localUserId,
  List<EntryTypeDefinition> extraEntryTypes = const [],
  List<Destination> outboundDestinations = const [],
}) async {
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S — register the
  //   shared questionnaire lifecycle entry types so the diary store accepts
  //   appends of questionnaire_finalized / questionnaire_unlocked (diary is a
  //   second emitter; per-event provenance records the real origin).
  final entryTypes = <EntryTypeDefinition>[
    for (final t in diaryOriginatedEventTypes) t.definition,
    _actionDenialEntryType,
    ...extraEntryTypes,
    for (final t in questionnaireEventTypes.where(
      (t) =>
          t.definition.id == 'questionnaire_finalized' ||
          t.definition.id == 'questionnaire_unlocked',
    ))
      t.definition,
  ];
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S — register the
  //   questionnaire_status projection so device-observed lifecycle events are
  //   materialized into the questionnaire_status view.
  final projections = ProjectionRegistry()
    ..register(diaryEntriesProjection)
    ..register(settingsProjection)
    ..register(diaryIncompleteProjection)
    ..register(questionnaireStatusProjection);

  final source = Source(
    hopId: 'mobile-device',
    identifier: deviceId,
    softwareVersion: softwareVersion,
  );

  // Implements: DIARY-DEV-native-outbound-sync/A
  // Implements: DIARY-DEV-evs-stack-adoption/B
  // Forward-declare the SyncCycle so the post-append trigger closure can capture
  // the variable; it is assigned after the bundle exists (the registry it drives
  // lives on the bundle). `bootstrapEventStore` itself appends a registry-init
  // event that fires this trigger BEFORE assignment, so the variable is plain
  // nullable (not `late`) and the closure tolerates the not-yet-assigned null.
  SyncCycle? syncCycle;
  Future<void> triggerDrain() async => syncCycle?.call();

  final bundle = await bootstrapEventStore(
    backend: backend,
    source: source,
    entryTypes: entryTypes,
    destinations: outboundDestinations,
    projections: projections,
    syncCycleTrigger: outboundDestinations.isEmpty ? null : triggerDrain,
  );

  syncCycle = outboundDestinations.isEmpty
      ? null
      : SyncCycle(
          backend: backend,
          registry: bundle.destinations,
          source: source,
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
    permissionSource: permissionSource,
    syncCycle: syncCycle,
  );
}
