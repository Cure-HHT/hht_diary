import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/entry_type_registry.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Wire the storage backend, the `EntryTypeRegistry`, and the initial
/// set of `Destination`s for an app's `main()`. Returns the two
/// registries the rest of the app reads through.
///
/// Types register before destinations so that a destination whose
/// construction or filter resolution needs the registry can rely on
/// every supplied `EntryTypeDefinition` being present at the moment its
/// own `addDestination` runs (REQ-d00134-B).
///
/// Destination id collisions surface as `ArgumentError` from
/// `DestinationRegistry.addDestination` (REQ-d00129-A) and are NOT
/// caught here — bootstrap fails fast so a misconfigured app crashes
/// at startup rather than rendering UI on top of a half-initialized
/// datastore (REQ-d00134-D).
///
/// The returned `DestinationRegistry` remains open to subsequent
/// runtime `addDestination` / `setStartDate` / `setEndDate` calls per
/// REQ-d00129; bootstrap is the *initial* registration pass, not a
/// freeze (REQ-d00134-C).
// Implements: REQ-d00134-A — single entry point for datastore init.
// Implements: REQ-d00134-B — entry types registered before destinations.
// Implements: REQ-d00134-C — addDestination remains available after bootstrap.
// Implements: REQ-d00134-D — duplicate destination id throws.
Future<(EntryTypeRegistry, DestinationRegistry)> bootstrapAppendOnlyDatastore({
  required StorageBackend backend,
  required List<EntryTypeDefinition> entryTypes,
  required List<Destination> destinations,
}) async {
  final typeRegistry = EntryTypeRegistry();
  for (final defn in entryTypes) {
    typeRegistry.register(defn);
  }
  final destinationRegistry = DestinationRegistry(backend: backend);
  for (final destination in destinations) {
    await destinationRegistry.addDestination(destination);
  }
  return (typeRegistry, destinationRegistry);
}
