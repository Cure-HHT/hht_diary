import 'package:event_sourcing_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:event_sourcing_datastore/src/materialization/entry_type_definition_lookup.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Chunk size for the streaming read of the event log during a rebuild.
///
/// Bounds the per-iteration working set to a fixed number of [StoredEvent]s
/// regardless of total log size. Chosen to amortize find-query overhead while
/// keeping peak memory modest on mobile and tolerable on server-scale logs.
const int _rebuildChunkSize = 500;

/// Rebuild the `diary_entries` materialized view from the append-only event
/// log. Disaster-recovery helper — folds events directly through
/// `DiaryEntriesMaterializer.foldPure` using each event's own `data` as the
/// promoted payload (identity promotion).
///
/// Streams events ordered by `sequence_number` in fixed-size chunks of
/// [_rebuildChunkSize], folding each event into a per-aggregate accumulator
/// (using each aggregate's first-seen `client_timestamp` as the
/// `firstEventTimestamp` fallback). Clears the `diary_entries` store at the
/// start of the transaction and upserts the final per-aggregate rows at the
/// end — all inside one `StorageBackend.transaction` so the clear, the folds,
/// and the upserts are one atomic step.
///
/// Concurrency: Sembast serializes transaction bodies, so a concurrent
/// `appendEvent` transaction runs either entirely before or entirely after
/// this rebuild's body — never interleaved.
///
/// Memory profile: O(chunk_size + distinct_aggregates × row_size), not
/// O(total_events).
///
/// Returns the number of distinct aggregate_ids materialized.
///
/// Throws [StateError] if the event log references an `entry_type` that is
/// not registered in [lookup].
// Implements: REQ-d00121-G+H — disaster-recovery rebuild; replaces view from
// event log in one transaction, returns count of aggregates processed.
Future<int> rebuildMaterializedView(
  StorageBackend backend,
  EntryTypeDefinitionLookup lookup,
) async {
  return backend.transaction<int>((txn) async {
    // Clear first so prior cache contents can never be read back as input to
    // the rebuild (REQ-d00121-G). The clear only commits if the whole
    // rebuild commits — a mid-rebuild failure rolls everything back together.
    await backend.clearEntries(txn);

    final byAggregate = <String, DiaryEntry>{};
    final firstTsByAggregate = <String, DateTime>{};

    int? lastSeq;
    while (true) {
      final chunk = await backend.findAllEventsInTxn(
        txn,
        afterSequence: lastSeq,
        limit: _rebuildChunkSize,
      );
      if (chunk.isEmpty) break;

      for (final event in chunk) {
        final def = lookup.lookup(event.entryType);
        if (def == null) {
          throw StateError(
            'rebuildMaterializedView: unknown entry_type '
            '"${event.entryType}" on event ${event.eventId} '
            '(aggregate ${event.aggregateId}, seq '
            '${event.sequenceNumber}). The event log references a type '
            'that is not in the registry; this is a data-integrity '
            'failure.',
          );
        }
        final firstTs = firstTsByAggregate.putIfAbsent(
          event.aggregateId,
          () => event.clientTimestamp,
        );
        byAggregate[event.aggregateId] = DiaryEntriesMaterializer.foldPure(
          previous: byAggregate[event.aggregateId],
          event: event,
          // Identity promotion for the legacy disaster-recovery path.
          // The parameterized rebuildView is the version-aware entry point.
          promotedData: event.data,
          def: def,
          firstEventTimestamp: firstTs,
        );
      }

      if (chunk.length < _rebuildChunkSize) break;
      lastSeq = chunk.last.sequenceNumber;
    }

    for (final row in byAggregate.values) {
      await backend.upsertEntry(txn, row);
    }

    return byAggregate.length;
  });
}

/// Rebuild exactly one view by replaying the event log through
/// [materializer]. Clears the view AND the view's `view_target_versions`
/// rows, writes the supplied [targetVersionByEntryType], then calls
/// `materializer.applyInTxn` (after invoking `materializer.promoter`) for
/// every event where `materializer.appliesTo(event)` returns true. Events
/// whose `EntryTypeDefinition.materialize == false` are skipped. Runs in
/// one backend transaction.
///
/// Strict-superset rule: every entry-type already present in the stored
/// `view_target_versions` for `materializer.viewName` MUST appear in
/// [targetVersionByEntryType]; otherwise [ArgumentError] is thrown before
/// any clear or write. New entry types may be added (superset). An event
/// in the log whose `entry_type` is not in [targetVersionByEntryType] also
/// raises [ArgumentError] — every materialized event needs a target
/// version to promote toward.
///
/// Returns the number of events processed. Idempotent — running twice on
/// the same log with the same map produces the same view rows.
// Implements: REQ-d00140-D — rebuildView per-view, idempotent; materializer-
//   parameterized replay; strict-superset target-version map.
// Implements: REQ-d00140-C — materialize=false on the entry type skips
//   this materializer entirely.
// Implements: REQ-d00140-G+H — promoter invoked before applyInTxn during
//   replay, even when fromVersion == toVersion.
// Implements: REQ-d00140-I — view_target_versions cleared and rewritten
//   atomically with the view rebuild.
Future<int> rebuildView(
  Materializer materializer,
  StorageBackend backend,
  EntryTypeDefinitionLookup lookup, {
  required Map<String, int> targetVersionByEntryType,
}) async {
  return backend.transaction<int>((txn) async {
    // Strict-superset check BEFORE any destructive write.
    final existing = await backend.readAllViewTargetVersionsInTxn(
      txn,
      materializer.viewName,
    );
    for (final entry in existing.entries) {
      if (!targetVersionByEntryType.containsKey(entry.key)) {
        throw ArgumentError(
          'rebuildView: targetVersionByEntryType is not a strict superset '
          'of the existing view_target_versions for view '
          '"${materializer.viewName}". Missing existing entry type '
          '"${entry.key}" (stored target ${entry.value}). '
          'Partial rebuilds are not allowed; supply every existing entry '
          'type plus any new ones.',
        );
      }
    }

    await backend.clearViewInTxn(txn, materializer.viewName);
    await backend.clearViewTargetVersionsInTxn(txn, materializer.viewName);
    for (final e in targetVersionByEntryType.entries) {
      await backend.writeViewTargetVersionInTxn(
        txn,
        materializer.viewName,
        e.key,
        e.value,
      );
    }

    final historyByAggregate = <String, List<StoredEvent>>{};
    var processed = 0;

    int? lastSeq;
    while (true) {
      final chunk = await backend.findAllEventsInTxn(
        txn,
        afterSequence: lastSeq,
        limit: _rebuildChunkSize,
      );
      if (chunk.isEmpty) break;

      for (final event in chunk) {
        final def = lookup.lookup(event.entryType);
        if (def == null) {
          throw StateError(
            'rebuildView: unknown entry_type "${event.entryType}" on '
            'event ${event.eventId} (aggregate ${event.aggregateId}, '
            'seq ${event.sequenceNumber}).',
          );
        }
        if (!def.materialize) {
          continue;
        }
        if (!materializer.appliesTo(event)) {
          continue;
        }
        final target = targetVersionByEntryType[event.entryType];
        if (target == null) {
          throw ArgumentError(
            'rebuildView: event ${event.eventId} (entry_type '
            '"${event.entryType}", seq ${event.sequenceNumber}) has no '
            'target version in targetVersionByEntryType. Every event '
            'subject to this materializer needs a target version.',
          );
        }
        final promoted = materializer.promoter(
          entryType: event.entryType,
          fromVersion: event.entryTypeVersion,
          toVersion: target,
          data: event.data,
        );
        final history = historyByAggregate.putIfAbsent(
          event.aggregateId,
          () => <StoredEvent>[],
        );
        await materializer.applyInTxn(
          txn,
          backend,
          event: event,
          promotedData: promoted,
          def: def,
          aggregateHistory: List<StoredEvent>.unmodifiable(history),
        );
        history.add(event);
        processed += 1;
      }

      if (chunk.length < _rebuildChunkSize) break;
      lastSeq = chunk.last.sequenceNumber;
    }

    return processed;
  });
}
