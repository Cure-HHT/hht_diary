// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (Bootstrap) — composes ActionDispatcher with all dependencies
//   into a single DemoServerComponents facade the demo server reads through.
//   REQ-d00175 (Seed appliers) — runs both YAML seed appliers (matrix +
//   user directory) before the dispatcher accepts any request.
//   REQ-d00178-B+C (PolicyReady / PolicyFailSafe) — surfaces the seed-bootstrap
//   verdict and the FailSafe policy's errors so the inspector can show why
//   every dispatch denies.

import 'package:action_permissions_demo/server/action_catalog.dart';
import 'package:action_permissions_demo/server/demo_idempotency_store.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:action_permissions_demo/server/user_directory_seed_applier.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

/// Collaborators a running demo server reads through after bootstrap.
@immutable
class DemoServerComponents {
  const DemoServerComponents({
    required this.dispatcher,
    required this.eventStore,
    required this.directory,
    required this.policy,
    required this.idempotencyStore,
    required this.policyErrors,
  });

  final ActionDispatcher dispatcher;
  final EventStore eventStore;
  final UserDirectory directory;
  final AuthorizationPolicy policy;
  final DemoIdempotencyStore idempotencyStore;

  /// Empty when the YAML seed validated cleanly. Non-empty when the
  /// policy is the FailSafe variant — every dispatch will deny with
  /// `DenyReason.notGranted` and the inspector surfaces these errors so
  /// operators can see why.
  final List<String> policyErrors;
}

/// Bootstrap a fresh demo server.
///
/// [dbPath] is honored only when [ephemeral] is `false`. When [ephemeral] is
/// `true` the database lives in memory and disappears with the process —
/// suitable for tests and for ad-hoc demo runs.
///
/// [installIdentifier] is the per-installation unique identity stamped onto
/// `metadata.provenance[0]` of every appended event (see
/// `Source.identifier`). Production callers persist a UUIDv4 across boots;
/// tests can pass any UUID-shaped string.
Future<DemoServerComponents> bootstrapDemoServer({
  required String dbPath,
  required bool ephemeral,
  required String permissionsYaml,
  required String usersYaml,
  required String installIdentifier,
}) async {
  final Database db = ephemeral
      ? await databaseFactoryMemory.openDatabase('demo')
      : await databaseFactoryIo.openDatabase(dbPath);
  final backend = SembastBackend(database: db);

  // 1. Build the action registry up front so we can pass its declared
  //    permissions to the seed validator. The directory the
  //    ProvisionUserAction reads/writes is the same one the materializer
  //    populates from user_provisioned events.
  final directory = UserDirectory();
  final directoryMaterializer = UserDirectoryMaterializer(directory: directory);
  final registry = buildDemoActionRegistry(directory: directory);

  // 2. Bootstrap the append-only datastore. Materializers wired here are
  //    RolePermissionGrants (for the matrix) and the directory adapter (for
  //    the in-memory user directory). Every entry type the demo writes
  //    must be registered up front; missing registrations fail at append.
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: 'portal-server',
      identifier: installIdentifier,
      softwareVersion: '0.1.0+1',
    ),
    entryTypes: _demoEntryTypes,
    destinations: const <Destination>[],
    materializers: <Materializer>[
      const RolePermissionGrantsMaterializer(),
      _DirectoryMaterializerAdapter(directoryMaterializer),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'role_permission_grants': <String, int>{'role_permission_grant': 1},
      'user_directory': <String, int>{'user_provisioned': 1},
    },
  );
  final eventStore = datastore.eventStore;

  // 3. Apply the role-permission matrix YAML seed. Returns either
  //    PolicyReady(policy) or PolicyFailSafe(errors); on FailSafe the
  //    returned policy denies everything and the errors flow back to the
  //    caller via DemoServerComponents.policyErrors.
  final policyBootstrap = await bootstrapActionPermissions(
    eventStore: eventStore,
    declaredPermissions: registry.allDeclaredPermissions,
    yamlSource: permissionsYaml,
  );

  // 4. Apply the user-directory YAML seed. The applier diffs YAML against
  //    the in-memory directory; for each missing entry it calls `emit`
  //    (a sync callback typed `void Function(...)`) and `applyDirect`.
  //    `eventStore.append` is async, so we collect emissions in `pending`
  //    and await each append sequentially after `applyYaml` returns. This
  //    keeps seed-write ordering deterministic without changing the
  //    applier's API.
  final pending = <Map<String, Object?>>[];
  final dirSeedApplier = UserDirectorySeedApplier(
    directory: directory,
    materializer: directoryMaterializer,
    emit: pending.add,
  );
  dirSeedApplier.applyYaml(usersYaml);
  for (final payload in pending) {
    await eventStore.append(
      entryType: 'user_provisioned',
      entryTypeVersion: 1,
      aggregateType: 'user_directory',
      aggregateId: payload['userId']! as String,
      eventType: 'user_provisioned',
      data: Map<String, Object?>.from(payload),
      initiator: const AutomationInitiator(service: 'user_directory_seed'),
    );
  }

  // 5. Idempotency cache + dispatcher.
  final idempotencyStore = DemoIdempotencyStore();
  final dispatcher = bootstrapAuditedActions(
    events: eventStore,
    authorization: policyBootstrap.policy,
    idempotency: idempotencyStore,
    actions: registry.all,
  );

  return DemoServerComponents(
    dispatcher: dispatcher,
    eventStore: eventStore,
    directory: directory,
    policy: policyBootstrap.policy,
    idempotencyStore: idempotencyStore,
    policyErrors: policyBootstrap.errors,
  );
}

/// Adapter so the demo's [UserDirectoryMaterializer] plugs into the
/// `event_sourcing` `Materializer` protocol. Filters by aggregateType and
/// forwards the `user_provisioned` payload to `UserDirectory.upsert`.
class _DirectoryMaterializerAdapter extends Materializer {
  const _DirectoryMaterializerAdapter(this._directoryMaterializer);

  final UserDirectoryMaterializer _directoryMaterializer;

  @override
  String get viewName => 'user_directory';

  @override
  bool appliesTo(StoredEvent event) =>
      event.aggregateType == 'user_directory' &&
      event.eventType == 'user_provisioned';

  @override
  EntryPromoter get promoter => identityPromoter;

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    _directoryMaterializer.applyDirect(promotedData);
  }
}

/// All entry types the demo writes through the EventStore. Every entry
/// type the actions emit (or that the dispatcher emits as denial events,
/// or that the seed appliers emit) must appear here so the EntryTypeRegistry
/// accepts the append.
const List<EntryTypeDefinition> _demoEntryTypes = <EntryTypeDefinition>[
  // Action-emitted entry types.
  EntryTypeDefinition(
    id: 'help_request',
    registeredVersion: 1,
    name: 'Help Request',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  EntryTypeDefinition(
    id: 'demo_note',
    registeredVersion: 1,
    name: 'Demo Note',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  EntryTypeDefinition(
    id: 'green_button_press',
    registeredVersion: 1,
    name: 'Green Button Press',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  EntryTypeDefinition(
    id: 'blue_button_press',
    registeredVersion: 1,
    name: 'Blue Button Press',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  EntryTypeDefinition(
    id: 'red_alarm',
    registeredVersion: 1,
    name: 'Red Alarm',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  EntryTypeDefinition(
    id: 'user_provisioned',
    registeredVersion: 1,
    name: 'User Provisioned',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  // Permissions module emits these via EventSeedApplier on bootstrap and
  // the matrix materializer folds them into role_permission_grants.
  EntryTypeDefinition(
    id: 'role_permission_grant',
    registeredVersion: 1,
    name: 'Role-Permission Grant',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
  // The dispatcher emits one of these for every denial stage.
  EntryTypeDefinition(
    id: 'action_denial',
    registeredVersion: 1,
    name: 'Action Denial',
    widgetId: 'none',
    widgetConfig: <String, Object?>{},
  ),
];
