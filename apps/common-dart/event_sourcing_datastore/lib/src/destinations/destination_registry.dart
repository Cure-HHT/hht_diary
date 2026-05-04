import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/event_store.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/sync/historical_replay.dart';

/// Process-wide registry of synchronization destinations.
///
/// Under REQ-d00129, the registry supports a dynamic lifecycle: destinations
/// may be added at any time after bootstrap, their `startDate` may be set
/// exactly once (immutable once assigned), their `endDate` may be mutated,
/// and they may be deactivated or hard-deleted per the per-destination
/// `allowHardDelete` opt-in.
///
/// Every runtime mutation of registry-controlled state (add, set start
/// date, set end date, deactivate, delete, tombstoneAndRefill) emits a
/// system audit event in the SAME `backend.transaction` as the mutation
/// itself. The audit event lands or rolls back atomically with the
/// underlying mutation: a failed audit append rolls back the mutation,
/// and a failed mutation rolls back any partially-formed audit row.
///
/// The registry is bound to a `StorageBackend` for schedule / FIFO
/// persistence and to an `EventStore` for in-transaction audit emission.
/// Production code constructs a single instance during bootstrap; tests
/// construct a fresh instance per test against an in-memory
/// `SembastBackend` and a matching `EventStore`.
// Implements: REQ-d00122-A — destination ids are unique in the registry.
// Implements: REQ-d00129-A+J — addDestination accepts registrations at any
// time after bootstrap; duplicate id is rejected; emits a registration
// audit event atomically with the schedule write.
// Implements: REQ-d00129-C+K — setStartDate is one-shot immutable; emits
// a start_date audit event atomically with the schedule write (and
// historical replay, when applicable).
// Implements: REQ-d00129-F+G+L — setEndDate returns SetEndDateResult;
// deactivateDestination is the now() shorthand; both emit an end_date
// audit event atomically with the schedule write.
// Implements: REQ-d00129-H+M — deleteDestination is gated on
// allowHardDelete and drops the schedule + FIFO store atomically with
// a deletion audit event.
// Implements: REQ-d00129-N — every audit emission participates in the
// same transaction as the mutation, so partial states cannot persist.
// Implements: REQ-d00144-A+B+C+D+E+F+G — tombstoneAndRefill is the sole
// operator wedge-recovery primitive; emits a wedge-recovery audit event
// atomically with the FIFO mutations.
class DestinationRegistry {
  /// Construct a registry bound to [backend] for storage persistence and
  /// [eventStore] for in-transaction audit emission. The registry does
  /// not open the database — the caller retains ownership of the
  /// backend's lifecycle.
  DestinationRegistry({required this.backend, required EventStore eventStore})
    : _eventStore = eventStore;

  /// Backend used for schedule persistence and FIFO-store drop on
  /// delete. Stored as a final field so the binding is established at
  /// construction and cannot drift.
  final StorageBackend backend;

  /// Event store used to stamp config-change audit events inside the
  /// same transaction as the underlying mutation. The store's own
  /// `Source` is reused for every audit emission.
  final EventStore _eventStore;

  final Map<String, Destination> _destinations = <String, Destination>{};
  final Map<String, DestinationSchedule> _schedules =
      <String, DestinationSchedule>{};

  /// Register [destination]. Seeds the in-memory schedule cache with a
  /// dormant `DestinationSchedule` (no `startDate`, no `endDate`) and
  /// persists that initial schedule so a subsequent process restart
  /// recovers the same dormant state. Emits a
  /// `system.destination_registered` audit event in the same
  /// transaction as the schedule write.
  ///
  /// Throws `ArgumentError` if a destination with the same id is already
  /// registered (REQ-d00129-A).
  // Implements: REQ-d00129-A — addDestination at any time after
  // bootstrap; duplicate id rejected with ArgumentError.
  // Implements: REQ-d00129-C — addDestination preserves any persisted
  // schedule across process restart, so setStartDate's one-shot
  // immutability survives bootstrap re-running addDestination with the
  // same id. Only seeds a dormant schedule when no schedule is persisted.
  // Implements: REQ-d00129-J+N — registration audit emitted in the same
  // transaction as the schedule write.
  Future<void> addDestination(
    Destination destination, {
    required Initiator initiator,
  }) async {
    if (_destinations.containsKey(destination.id)) {
      throw ArgumentError.value(
        destination.id,
        'destination.id',
        'destination id ${destination.id} is already registered '
            '(REQ-d00129-A)',
      );
    }
    // Read schedule outside the txn — it's a pure read, and the
    // SembastBackend contract has no readScheduleInTxn surface. The
    // subsequent transaction body is the one that must commit
    // atomically with the audit emission.
    final persisted = await backend.readSchedule(destination.id);
    final resolved = persisted ?? const DestinationSchedule();
    await backend.transaction((txn) async {
      if (persisted == null) {
        await backend.writeScheduleTxn(txn, destination.id, resolved);
      }
      await _emitDestinationAuditInTxn(
        txn,
        entryType: kDestinationRegisteredEntryType,
        data: <String, Object?>{
          'id': destination.id,
          'wire_format': destination.wireFormat,
          'allow_hard_delete': destination.allowHardDelete,
          'serializes_natively': destination.serializesNatively,
          'filter_entry_types': destination.filter.entryTypes?.toList(),
          'filter_event_types': destination.filter.eventTypes?.toList(),
          // REQ-d00129-J: explicit null until SubscriptionFilter exposes a
          // predicate API. Downstream key-based queries should find the
          // key present-but-null rather than absent.
          'filter_predicate_description': null,
        },
        initiator: initiator,
      );
    });
    // Update in-memory state only after the transaction commits, so a
    // rolled-back transaction (e.g. audit append failure) leaves the
    // registry consistent with persistence.
    _destinations[destination.id] = destination;
    _schedules[destination.id] = resolved;
  }

  /// All registered destinations, in registration order. Returned list
  /// is unmodifiable so callers cannot mutate the registry by mutating
  /// the view.
  List<Destination> all() =>
      List<Destination>.unmodifiable(_destinations.values);

  /// Destination with [id], or null when no such destination has been
  /// registered. Does not consult persistence — only in-memory state.
  Destination? byId(String id) => _destinations[id];

  /// Read the current `DestinationSchedule` for [id]. Reads from the
  /// in-memory cache; the cache is populated by `addDestination` and
  /// kept current by `setStartDate` / `setEndDate`. Throws
  /// `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-A+C+F — schedule read surface for
  // downstream fillBatch time-window filtering.
  Future<DestinationSchedule> scheduleOf(String id) async {
    final cached = _schedules[id];
    if (cached != null) return cached;
    final persisted = await backend.readSchedule(id);
    if (persisted != null) {
      _schedules[id] = persisted;
      return persisted;
    }
    throw ArgumentError.value(
      id,
      'id',
      'no destination registered with id $id',
    );
  }

  /// Assign [startDate] to the destination identified by [id]. The
  /// assignment is one-shot immutable — a subsequent call throws
  /// `StateError` (REQ-d00129-C).
  ///
  /// When [startDate] is at or before `DateTime.now()`, the call
  /// triggers historical replay synchronously in the same transaction
  /// as the schedule write (REQ-d00129-D). Replay walks the event log
  /// past `fill_cursor`, builds batches via the destination's own
  /// `canAddToBatch` and `transform`, and enqueues matching events into
  /// the destination's FIFO so rows are indistinguishable from those
  /// `fillBatch` would produce during live operation (REQ-d00130-A+B).
  /// When [startDate] is in the future, no replay runs — events
  /// accumulate in `event_log` and are batched by `fillBatch` once the
  /// wall-clock crosses `startDate` (REQ-d00129-E).
  ///
  /// Emits a `system.destination_start_date_set` audit event in the
  /// same transaction as the schedule write (and replay, when
  /// applicable).
  ///
  /// Throws `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-C — setStartDate throws StateError if already
  // set; the value is immutable once assigned.
  // Implements: REQ-d00129-D — past startDate triggers historical replay
  // synchronously inside the same transaction as the schedule write.
  // Implements: REQ-d00129-E — future startDate does NOT trigger replay.
  // Implements: REQ-d00129-K+N — start_date audit emitted in the same
  // transaction as the schedule write and replay.
  Future<void> setStartDate(
    String id,
    DateTime startDate, {
    required Initiator initiator,
  }) async {
    if (!_destinations.containsKey(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    final current = _schedules[id] ?? const DestinationSchedule();
    if (current.startDate != null) {
      throw StateError(
        'DestinationRegistry.setStartDate($id): startDate is already set '
        'to ${current.startDate}; startDate is immutable once assigned '
        '(REQ-d00129-C).',
      );
    }
    final updated = DestinationSchedule(
      startDate: startDate,
      endDate: current.endDate,
    );
    // The schedule write, replay (when applicable), and audit emission
    // must all commit together. Running everything in the same
    // transaction provides the serialization guarantee REQ-d00130-C
    // relies on: a concurrent record() serializes behind this
    // transaction and walks candidates strictly past the advanced
    // fill_cursor.
    await backend.transaction((txn) async {
      await backend.writeScheduleTxn(txn, id, updated);
      if (!startDate.isAfter(DateTime.now())) {
        // Implements: REQ-d00129-D — past startDate triggers replay in
        // the same transaction as the schedule write. _destinations[id]
        // is known non-null because the unknown-id check above
        // returned early otherwise.
        // Native destinations (`serializesNatively == true`) require the
        // local `Source` so replay can mint a library-built
        // `BatchEnvelopeMetadata` instead of calling `transform`
        // (REQ-d00152-B replay parity, mirrors `fillBatch`).
        await runHistoricalReplay(
          txn,
          _destinations[id]!,
          updated,
          backend,
          source: _eventStore.source,
        );
      }
      // REQ-d00129-E: future startDate takes the else branch; replay is
      // skipped.
      await _emitDestinationAuditInTxn(
        txn,
        entryType: kDestinationStartDateSetEntryType,
        data: <String, Object?>{
          'id': id,
          'start_date': startDate.toUtc().toIso8601String(),
        },
        initiator: initiator,
      );
    });
    // Update the in-memory cache only after the transaction commits, so
    // a rolled-back transaction does not leave the registry advertising
    // a schedule that was not persisted.
    _schedules[id] = updated;
  }

  /// Mutate the destination's `endDate` to [endDate] and return a
  /// `SetEndDateResult` describing the transition (REQ-d00129-F):
  ///
  /// - `closed` — call transitions currently-active to currently-closed.
  /// - `scheduled` — new `endDate` is in the future.
  /// - `applied` — no change in current active-vs-closed classification.
  ///
  /// Emits a `system.destination_end_date_set` audit event in the same
  /// transaction as the schedule write. The same audit entry type
  /// covers both `setEndDate` and `deactivateDestination` (the now()
  /// shorthand).
  ///
  /// Throws `ArgumentError` when [id] is not registered.
  // Implements: REQ-d00129-F — setEndDate returns closed / scheduled /
  // applied per the three-way classification.
  // Implements: REQ-d00129-L+N — end_date audit emitted in the same
  // transaction as the schedule write; covers deactivate as the
  // now() shorthand.
  Future<SetEndDateResult> setEndDate(
    String id,
    DateTime endDate, {
    required Initiator initiator,
  }) async {
    if (!_destinations.containsKey(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    final now = DateTime.now();
    final current = _schedules[id] ?? const DestinationSchedule();
    final wasActive = current.isActiveAt(now);
    final updated = DestinationSchedule(
      startDate: current.startDate,
      endDate: endDate,
    );
    final isActive = updated.isActiveAt(now);

    // Classify the two endDate snapshots (pre-call and post-call) as
    // scheduled-for-future-close or not. "Scheduled" here means "has a
    // future endDate"; it is independent of whether the destination is
    // currently active or dormant.
    final wasScheduled =
        current.endDate != null && current.endDate!.isAfter(now);
    final isScheduled = endDate.isAfter(now);

    final SetEndDateResult result;
    if (wasActive && !isActive) {
      // Active → closed at or before now.
      result = SetEndDateResult.closed;
    } else if (!wasActive && isActive) {
      // Previously closed (or dormant), now has a future endDate that
      // reopens / schedules a close window.
      result = SetEndDateResult.scheduled;
    } else if (isScheduled && !wasScheduled) {
      // No active/closed transition, but the endDate is newly in the
      // future (e.g., first assignment to a dormant destination, or
      // replacing a past endDate with a future one without crossing now).
      result = SetEndDateResult.scheduled;
    } else {
      // No state change relative to now AND no new close scheduled —
      // covers past → past, future → future without crossing now, and
      // first-time past on a dormant destination.
      result = SetEndDateResult.applied;
    }

    await backend.transaction((txn) async {
      await backend.writeScheduleTxn(txn, id, updated);
      await _emitDestinationAuditInTxn(
        txn,
        entryType: kDestinationEndDateSetEntryType,
        data: <String, Object?>{
          'id': id,
          'end_date': endDate.toUtc().toIso8601String(),
          'prior_end_date': current.endDate?.toUtc().toIso8601String(),
          'result': result.name,
        },
        initiator: initiator,
      );
    });
    _schedules[id] = updated;
    return result;
  }

  /// Set the destination's `endDate` to `DateTime.now()`, returning
  /// `SetEndDateResult.closed` (REQ-d00129-G). The audit event is
  /// emitted by the underlying `setEndDate` call.
  // Implements: REQ-d00129-G+L+N — deactivateDestination is the now()
  // shorthand for setEndDate; audit emission is delegated.
  Future<SetEndDateResult> deactivateDestination(
    String id, {
    required Initiator initiator,
  }) => setEndDate(id, DateTime.now(), initiator: initiator);

  /// Unregister [id] and drop its FIFO store + schedule record in one
  /// transaction. Emits a `system.destination_deleted` audit event in
  /// the same transaction as the FIFO + schedule drop. Throws
  /// `StateError` when the destination's `allowHardDelete` getter is
  /// `false` — the default, opt-out-only gate on permanent FIFO
  /// destruction.
  // Implements: REQ-d00129-H — deleteDestination gated on
  // allowHardDelete; atomic FIFO-store + schedule drop.
  // Implements: REQ-d00129-M+N — deletion audit emitted in the same
  // transaction as the FIFO + schedule drop.
  Future<void> deleteDestination(
    String id, {
    required Initiator initiator,
  }) async {
    final destination = _destinations[id];
    if (destination == null) {
      throw ArgumentError.value(
        id,
        'id',
        'no destination registered with id $id',
      );
    }
    if (!destination.allowHardDelete) {
      throw StateError(
        'DestinationRegistry.deleteDestination($id): destination '
        'allowHardDelete is false; hard deletion requires an explicit '
        'per-destination opt-in (REQ-d00129-H).',
      );
    }
    await backend.transaction((txn) async {
      await backend.deleteFifoStoreTxn(txn, id);
      await backend.deleteScheduleTxn(txn, id);
      await _emitDestinationAuditInTxn(
        txn,
        entryType: kDestinationDeletedEntryType,
        data: <String, Object?>{'id': id, 'allow_hard_delete': true},
        initiator: initiator,
      );
    });
    _destinations.remove(id);
    _schedules.remove(id);
  }

  /// Operator-driven wedge recovery: tombstone the FIFO head, delete
  /// pending trail rows behind it, rewind `fill_cursor`, and emit a
  /// `system.destination_wedge_recovered` audit event — all in one
  /// `backend.transaction`. The sole code path by which a FIFO row
  /// reaches `final_status == tombstoned`.
  ///
  /// Preconditions (REQ-d00144-A), checked BEFORE opening the
  /// transaction so a mis-call does not hold a write lock:
  /// - The row identified by [fifoRowId] on [destinationId] SHALL exist.
  /// - The row SHALL be the current head of the destination's FIFO
  ///   (i.e., `readFifoHead(destinationId)` returns this row). Its
  ///   `final_status` is therefore either `null` (pre-terminal) or
  ///   `FinalStatus.wedged` (blocking terminal); a `sent` or
  ///   `tombstoned` target, or a non-head target, is rejected with
  ///   `ArgumentError`.
  ///
  /// Cascade inside one `StorageBackend.transaction` (REQ-d00144-B+C+D):
  /// - Target row flips to `FinalStatus.tombstoned`; `attempts[]` and
  ///   all other fields preserved.
  /// - Every row whose `sequence_in_queue > target.sequence_in_queue`
  ///   AND whose `final_status IS null` is deleted from the FIFO store.
  /// - `fill_cursor_<destinationId>` is rewound to
  ///   `target.event_id_range.first_seq - 1`.
  /// - A `system.destination_wedge_recovered` audit event is appended.
  ///
  /// Returns a [TombstoneAndRefillResult] (REQ-d00144-E).
  // Implements: REQ-d00144-A — head-only + existence preconditions,
  // checked pre-transaction so ArgumentError does not hold a write lock.
  // Implements: REQ-d00144-B — `null|wedged -> tombstoned` flip,
  // preserves attempts[] verbatim.
  // Implements: REQ-d00144-C — trail null rows deleted.
  // Implements: REQ-d00144-D — fill_cursor rewinds to first_seq - 1.
  // Implements: REQ-d00144-E — TombstoneAndRefillResult return shape.
  // Implements: REQ-d00144-G — wedge-recovery audit emitted in the same
  // transaction as the FIFO mutations.
  Future<TombstoneAndRefillResult> tombstoneAndRefill(
    String destinationId,
    String fifoRowId, {
    required Initiator initiator,
  }) async {
    // REQ-d00144-A: pre-transaction precondition checks. readFifoHead
    // returns the first row whose final_status is null or wedged; sent
    // and tombstoned rows are skipped. So if the caller's target is the
    // head, it is automatically in {null, wedged}; if it is anything
    // else (does not exist, sent, tombstoned, or simply not-the-head),
    // the returned head will differ from fifoRowId and we reject.
    final head = await backend.readFifoHead(destinationId);
    if (head == null || head.entryId != fifoRowId) {
      throw ArgumentError.value(
        fifoRowId,
        'fifoRowId',
        'tombstoneAndRefill($destinationId, $fifoRowId): target is not '
            'the current head of the FIFO. readFifoHead returned '
            '${head?.entryId}. (REQ-d00144-A)',
      );
    }
    // head.finalStatus is null or wedged here (readFifoHead contract).

    final targetFirstSeq = head.eventIdRange.firstSeq;
    final targetLastSeq = head.eventIdRange.lastSeq;
    final targetSeqInQueue = head.sequenceInQueue;

    return backend.transaction((txn) async {
      await backend.setFinalStatusTxn(
        txn,
        destinationId,
        fifoRowId,
        FinalStatus.tombstoned,
      );
      final deletedTrailCount = await backend
          .deleteNullRowsAfterSequenceInQueueTxn(
            txn,
            destinationId,
            targetSeqInQueue,
          );
      final rewoundTo = targetFirstSeq - 1;
      await backend.writeFillCursorTxn(txn, destinationId, rewoundTo);
      final result = TombstoneAndRefillResult(
        targetRowId: fifoRowId,
        deletedTrailCount: deletedTrailCount,
        rewoundTo: rewoundTo,
      );
      await _emitDestinationAuditInTxn(
        txn,
        entryType: kDestinationWedgeRecoveredEntryType,
        data: <String, Object?>{
          'id': destinationId,
          'target_row_id': fifoRowId,
          'target_event_id_range_first_seq': targetFirstSeq,
          'target_event_id_range_last_seq': targetLastSeq,
          'deleted_trail_count': deletedTrailCount,
          'rewound_to': rewoundTo,
        },
        initiator: initiator,
      );
      return result;
    });
  }

  /// Emit a system audit event for a destination mutation inside [txn].
  /// Reads `entryTypeVersion` from the registry's
  /// `EntryTypeDefinition.registered_version` so any future schema bump
  /// updates emission and registration in lockstep — the registry is the
  /// authoritative source of truth for system entry-type versions.
  ///
  /// The aggregate is stamped as `source.identifier` (the install UUID)
  /// / `system_destination` / `finalized`; the destination identity
  /// lives in `data['id']`. Every destination mutation a single install
  /// emits therefore lands in a single per-install hash-chained system
  /// aggregate. Emission uses no flow token, metadata, security,
  /// checkpoint, or change reason. dedupeByContent is left off because
  /// each destination mutation records a distinct timeline entry.
  ///
  /// When [entryType] is NOT registered on the underlying [EventStore],
  /// the helper still calls into `appendInTxn` so the standard
  /// `_validateAppendInputs` ArgumentError surfaces inside the
  /// surrounding transaction (rolling back any prior writes). The fall-
  /// back `entryTypeVersion: 0` is never persisted — the validation
  /// throws first.
  // Implements: REQ-d00134-G — registry-sourced version stamp on every
  //   destination-mutation audit emission.
  // Implements: REQ-d00129-J+K+L+M+N (revised: aggregateId=source.identifier),
  //   REQ-d00144-G (revised), REQ-d00154-D — system events use the
  //   install UUID as their aggregate; destination identity moves into
  //   data.id so callers can still query "all audits about destination
  //   X" by filtering on entry_type AND data.id.
  Future<void> _emitDestinationAuditInTxn(
    Txn txn, {
    required String entryType,
    required Map<String, Object?> data,
    required Initiator initiator,
  }) async {
    final def = _eventStore.entryTypes.byId(entryType);
    await _eventStore.appendInTxn(
      txn,
      entryType: entryType,
      entryTypeVersion: def?.registeredVersion ?? 0,
      aggregateId: _eventStore.source.identifier,
      aggregateType: 'system_destination',
      eventType: 'finalized',
      data: data,
      initiator: initiator,
      flowToken: null,
      metadata: null,
      security: null,
      checkpointReason: null,
      changeReason: null,
      dedupeByContent: false,
    );
  }
}
