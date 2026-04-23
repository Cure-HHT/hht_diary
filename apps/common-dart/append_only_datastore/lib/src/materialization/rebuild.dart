import 'package:append_only_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:append_only_datastore/src/materialization/entry_type_definition_lookup.dart';
import 'package:append_only_datastore/src/materialization/materializer.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';

/// Chunk size for the streaming read of the event log during a rebuild.
///
/// Bounds the per-iteration working set to a fixed number of [StoredEvent]s
/// regardless of total log size. Chosen to amortize find-query overhead while
/// keeping peak memory modest on mobile and tolerable on server-scale logs.
const int _rebuildChunkSize = 500;

/// Rebuild the `diary_entries` materialized view from the append-only event
/// log.
///
/// Streams events ordered by `sequence_number` in fixed-size chunks of
/// [_rebuildChunkSize], folding each event into a per-aggregate accumulator
/// via `Materializer.apply` (using each aggregate's first-seen
/// `client_timestamp` as the `firstEventTimestamp` fallback). Clears the
/// `diary_entries` store at the start of the transaction and upserts the
/// final per-aggregate rows at the end — all inside one
/// `StorageBackend.transaction` so the clear, the folds, and the upserts are
/// one atomic step.
///
/// Concurrency: Sembast serializes transaction bodies, so a concurrent
/// `appendEvent` transaction runs either entirely before or entirely after
/// this rebuild's body — never interleaved. If `appendEvent` commits first,
/// its event is in the log at snapshot time and is folded into the rebuilt
/// view. If `appendEvent` commits after, its event is in the log but NOT in
/// this rebuild's just-committed view — the view is consistent with the log
/// as of the rebuild's transaction, nothing later.
///
/// Runtime view/log consistency is the write path's concern, not rebuild's:
/// Phase 5's `EntryService.record` applies `Materializer.apply` in the same
/// transaction as its `appendEvent`, so any event appended after a rebuild
/// also writes its own `diary_entries` row atomically with the append. This
/// function exists for disaster recovery; it is not a live-sync primitive.
///
/// Memory profile: O(chunk_size + distinct_aggregates × row_size), not
/// O(total_events). Suitable for event logs that do not fit comfortably in
/// memory — the per-aggregate accumulator still scales with the aggregate
/// count, but the event log itself is never fully materialized.
///
/// Not a runtime operation: this exists as a disaster-recovery tool and as
/// the guarantee that makes `diary_entries` a cache rather than a source of
/// truth. Production code MAY NOT depend on its state being live-up-to-date
/// with events unless the write path (Phase 5's `EntryService.record`)
/// maintains that invariant.
///
/// Returns the number of distinct aggregate_ids materialized.
///
/// Throws [StateError] if the event log references an `entry_type` that is
/// not registered in [lookup] — an unknown type in persisted events is a
/// data-integrity failure and must surface loudly rather than silently
/// dropping events from the rebuilt view.
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
/// [materializer]. Clears the view, then calls `materializer.applyInTxn`
/// for every event where `materializer.appliesTo(event)` returns true.
/// Events whose `EntryTypeDefinition.materialize == false` are skipped
/// (REQ-d00140-C). Runs in one backend transaction.
///
/// Returns the number of events processed. Idempotent — running twice on
/// the same log produces the same view rows.
// Implements: REQ-d00140-D — rebuildView per-view, idempotent; materializer-
// parameterized replay.
// Implements: REQ-d00140-C — materialize=false on the entry type skips
// this materializer entirely.
Future<int> rebuildView(
  Materializer materializer,
  StorageBackend backend,
  EntryTypeDefinitionLookup lookup,
) async {
  return backend.transaction<int>((txn) async {
    await backend.clearViewInTxn(txn, materializer.viewName);
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
        final history = historyByAggregate.putIfAbsent(
          event.aggregateId,
          () => <StoredEvent>[],
        );
        await materializer.applyInTxn(
          txn,
          backend,
          event: event,
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
