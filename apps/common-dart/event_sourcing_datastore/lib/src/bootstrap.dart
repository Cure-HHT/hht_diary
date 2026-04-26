import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/event_store.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/sembast_security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';

/// Facade returned by `bootstrapAppendOnlyDatastore`. Exposes the four
/// collaborators an app reads through after startup: the write API
/// (`eventStore`), the registries (`entryTypes`, `destinations`), and the
/// security-context sidecar surface (`securityContexts`). Also exposes
/// `setViewTargetVersion` for post-bootstrap registration of new entry
/// types into a materializer's `view_target_versions`.
// Implements: REQ-d00134-A (Phase 4.4 revised) — AppendOnlyDatastore facade.
// Implements: REQ-d00140-K — setViewTargetVersion on AppendOnlyDatastore.
class AppendOnlyDatastore {
  const AppendOnlyDatastore({
    required this.eventStore,
    required this.entryTypes,
    required this.destinations,
    required this.securityContexts,
    required SembastBackend backend,
  }) : _backend = backend;

  final EventStore eventStore;
  final EntryTypeRegistry entryTypes;
  final DestinationRegistry destinations;
  final SecurityContextStore securityContexts;
  final SembastBackend _backend;

  /// Register or update a (`viewName`, `entryType`) → `version` entry in
  /// the persisted `view_target_versions`. Used to add a new entry type
  /// to a materialized view after bootstrap (e.g., when a sponsor adds a
  /// new diary entry type at runtime).
  // Implements: REQ-d00140-K.
  Future<void> setViewTargetVersion(
    String viewName,
    String entryType,
    int version,
  ) {
    return _backend.transaction((txn) async {
      await _backend.writeViewTargetVersionInTxn(
        txn,
        viewName,
        entryType,
        version,
      );
    });
  }
}

/// Wire the storage backend, the `EntryTypeRegistry`, the initial set of
/// `Destination`s, the security-context store, the `EventStore`, and the
/// per-materializer initial `view_target_versions`. Returns an
/// `AppendOnlyDatastore` facade the rest of the app reads through.
///
/// Reserved system entry types (security-context audit events) are
/// auto-registered BEFORE the caller-supplied list. Id collision with a
/// reserved id throws `ArgumentError` with a "reserved" message.
///
/// Destinations are registered sequentially, preserving fail-fast on id
/// collision (REQ-d00134-D).
///
/// Initial view target versions: every entry in [materializers] MUST have
/// a matching key in [initialViewTargetVersions]; otherwise [ArgumentError]
/// is raised. When persisted storage already holds a target version for
/// some (`viewName`, `entryType`) pair AND the supplied value differs, a
/// [StateError] surfaces — bootstrap conflicts must be resolved by
/// `rebuildView` rather than silently overwritten.
// Implements: REQ-d00134-A (Phase 4.4) — single entry point; facade return.
// Implements: REQ-d00134-B (Phase 4.4) — auto-register system entry types
//   before caller-supplied types.
// Implements: REQ-d00134-D (Phase 4.4) — caller id colliding with reserved
//   id throws ArgumentError with "reserved" message.
// Implements: REQ-d00140-J — initial view target versions written before
//   any event is appended; missing entries error; conflicts on existing
//   storage error.
Future<AppendOnlyDatastore> bootstrapAppendOnlyDatastore({
  required SembastBackend backend,
  required Source source,
  required List<EntryTypeDefinition> entryTypes,
  required List<Destination> destinations,
  required List<Materializer> materializers,
  required Map<String, Map<String, int>> initialViewTargetVersions,
  EventStoreSyncCycleTrigger? syncCycleTrigger,
}) async {
  final typeRegistry = EntryTypeRegistry();
  for (final defn in kSystemEntryTypes) {
    typeRegistry.register(defn);
  }
  for (final defn in entryTypes) {
    if (kReservedSystemEntryTypeIds.contains(defn.id)) {
      throw ArgumentError.value(
        defn.id,
        'defn.id',
        'entryType id "${defn.id}" is reserved for system events',
      );
    }
    typeRegistry.register(defn);
  }

  // Initial view target versions are written before any event can be
  // appended. Missing entry for a registered materializer fails loudly,
  // and a stored value that disagrees with the supplied value also fails
  // loudly (resolve via rebuildView).
  await backend.transaction((txn) async {
    for (final m in materializers) {
      final supplied = initialViewTargetVersions[m.viewName];
      if (supplied == null) {
        throw ArgumentError(
          'bootstrapAppendOnlyDatastore: no initialViewTargetVersions entry '
          'for materializer "${m.viewName}". Every materializer needs a '
          'target-version map covering its entry types.',
        );
      }
      for (final entry in supplied.entries) {
        final stored = await backend.readViewTargetVersionInTxn(
          txn,
          m.viewName,
          entry.key,
        );
        if (stored != null && stored != entry.value) {
          throw StateError(
            'bootstrap conflict for (${m.viewName}, ${entry.key}): '
            'stored target $stored, supplied ${entry.value}; '
            'resolve via rebuildView.',
          );
        }
        await backend.writeViewTargetVersionInTxn(
          txn,
          m.viewName,
          entry.key,
          entry.value,
        );
      }
    }
  });

  final securityContexts = SembastSecurityContextStore(backend: backend);
  final eventStore = EventStore(
    backend: backend,
    entryTypes: typeRegistry,
    source: source,
    securityContexts: securityContexts,
    materializers: materializers,
    syncCycleTrigger: syncCycleTrigger,
  );

  final destinationRegistry = DestinationRegistry(
    backend: backend,
    eventStore: eventStore,
  );
  const bootstrapInitiator = AutomationInitiator(service: 'lib-bootstrap');

  // Implements: REQ-d00134-E+F — emit a registry-initialized audit
  //   event recording the registry's full id->registered_version map
  //   after EventStore construction and before destination registration.
  //   dedupeByContent: same-state reboots no-op; a schema bump (added
  //   entry type or registeredVersion bump) emits a new event.
  // Implements: REQ-d00134-G — entryTypeVersion read from the registry
  //   (registry is the source of truth for system entry-type versions).
  final registryStateMap = <String, int>{};
  for (final defn in typeRegistry.all()) {
    registryStateMap[defn.id] = defn.registeredVersion;
  }
  final initDef = typeRegistry.byId(kEntryTypeRegistryInitializedEntryType)!;
  await eventStore.append(
    entryType: kEntryTypeRegistryInitializedEntryType,
    entryTypeVersion: initDef.registeredVersion,
    aggregateId: 'system:entry-type-registry',
    aggregateType: 'system_registry',
    eventType: 'finalized',
    data: <String, Object?>{'registry': registryStateMap},
    initiator: bootstrapInitiator,
    dedupeByContent: true,
  );

  for (final destination in destinations) {
    await destinationRegistry.addDestination(
      destination,
      initiator: bootstrapInitiator,
    );
  }

  return AppendOnlyDatastore(
    eventStore: eventStore,
    entryTypes: typeRegistry,
    destinations: destinationRegistry,
    securityContexts: securityContexts,
    backend: backend,
  );
}
