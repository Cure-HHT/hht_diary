import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/event_store.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/sembast_security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';

/// Facade returned by `bootstrapAppendOnlyDatastore`. Exposes the four
/// collaborators an app reads through after startup: the write API
/// (`eventStore`), the registries (`entryTypes`, `destinations`), and the
/// security-context sidecar surface (`securityContexts`).
// Implements: REQ-d00134-A (Phase 4.4 revised) — AppendOnlyDatastore facade.
class AppendOnlyDatastore {
  const AppendOnlyDatastore({
    required this.eventStore,
    required this.entryTypes,
    required this.destinations,
    required this.securityContexts,
  });

  final EventStore eventStore;
  final EntryTypeRegistry entryTypes;
  final DestinationRegistry destinations;
  final SecurityContextStore securityContexts;
}

/// Wire the storage backend, the `EntryTypeRegistry`, the initial set of
/// `Destination`s, the security-context store, and the `EventStore`.
/// Returns an `AppendOnlyDatastore` facade the rest of the app reads
/// through.
///
/// Reserved system entry types (security-context audit events) are
/// auto-registered BEFORE the caller-supplied list. Id collision with a
/// reserved id throws `ArgumentError` with a "reserved" message.
///
/// Destinations are registered sequentially, preserving fail-fast on id
/// collision (REQ-d00134-D).
// Implements: REQ-d00134-A (Phase 4.4) — single entry point; facade return.
// Implements: REQ-d00134-B (Phase 4.4) — auto-register system entry types
//   before caller-supplied types.
// Implements: REQ-d00134-D (Phase 4.4) — caller id colliding with reserved
//   id throws ArgumentError with "reserved" message.
Future<AppendOnlyDatastore> bootstrapAppendOnlyDatastore({
  required SembastBackend backend,
  required Source source,
  required List<EntryTypeDefinition> entryTypes,
  required List<Destination> destinations,
  List<Materializer> materializers = const <Materializer>[],
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

  final securityContexts = SembastSecurityContextStore(backend: backend);
  final eventStore = EventStore(
    backend: backend,
    entryTypes: typeRegistry,
    source: source,
    securityContexts: securityContexts,
    materializers: materializers,
    syncCycleTrigger: syncCycleTrigger,
  );

  final destinationRegistry = DestinationRegistry(backend: backend);
  for (final destination in destinations) {
    await destinationRegistry.addDestination(destination);
  }

  return AppendOnlyDatastore(
    eventStore: eventStore,
    entryTypes: typeRegistry,
    destinations: destinationRegistry,
    securityContexts: securityContexts,
  );
}
