import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/materialization/entry_promoter.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';

/// Pluggable fold contract. One `Materializer` maintains one backend view.
/// `EventStore.append` runs every materializer whose `appliesTo(event)`
/// returns true for each appended event, inside the same transaction as the
/// append; a throw rolls back the whole append.
// Implements: REQ-d00140-A — abstract fold contract with viewName,
//   appliesTo, promoter, targetVersionFor (default), applyInTxn.
abstract class Materializer {
  const Materializer();

  /// Name of the backend view this materializer maintains. Used by
  /// `StorageBackend.{read,upsert,delete,find,clear}View*` methods to
  /// scope reads and writes.
  String get viewName;

  /// True iff this materializer folds [event] into its view.
  bool appliesTo(StoredEvent event);

  /// External callback the lib invokes before every fold. Required.
  /// See REQ-d00140-G+H.
  // Implements: REQ-d00140-G.
  EntryPromoter get promoter;

  /// Target version for [entryType] in this view. Default impl reads from
  /// `view_target_versions` via [backend]. Throws `StateError` when no
  /// entry is registered for the (`viewName`, `entryType`) pair (REQ-d00140-L).
  // Implements: REQ-d00140-L.
  Future<int> targetVersionFor(
    Txn txn,
    StorageBackend backend,
    String entryType,
  ) async {
    final stored = await backend.readViewTargetVersionInTxn(
      txn,
      viewName,
      entryType,
    );
    if (stored == null) {
      throw StateError(
        'Materializer "$viewName": no view_target_version registered for '
        'entry type "$entryType". Either bootstrap with a target version map '
        'covering this entry type, or rebuildView with a map that includes it.',
      );
    }
    return stored;
  }

  /// Apply the fold step inside [txn]. Reads prior view rows and writes the
  /// next row via the generic view methods on [backend]. [promotedData] is
  /// the lib-supplied result of invoking [promoter] (REQ-d00140-G).
  /// [aggregateHistory] is the aggregate's event list inside the same
  /// transaction (callers pass this to avoid a redundant read when the
  /// fold needs prior events).
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  });
}
