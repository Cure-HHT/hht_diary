import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Pluggable fold contract. One `Materializer` maintains one backend view.
/// `EventStore.append` (post-Phase-4.4) runs every materializer whose
/// `appliesTo(event)` returns true for each appended event, inside the
/// same transaction as the append; a throw rolls back the whole append.
// Implements: REQ-d00140-A — abstract fold contract with viewName,
// appliesTo, applyInTxn.
abstract class Materializer {
  const Materializer();

  /// Name of the backend view this materializer maintains. Used by
  /// `StorageBackend.{read,upsert,delete,find,clear}View*` methods to
  /// scope reads and writes.
  String get viewName;

  /// True iff this materializer folds [event] into its view.
  bool appliesTo(StoredEvent event);

  /// Apply the fold step inside [txn]. Reads prior view rows and writes
  /// the next row via the generic view methods on [backend].
  /// [aggregateHistory] is the aggregate's event list inside the same
  /// transaction (callers pass this to avoid a redundant read when the
  /// fold needs prior events).
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  });
}
