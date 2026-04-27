import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/ingest/chain_verdict.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_result.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/security/event_security_context.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/security_details.dart';
import 'package:event_sourcing_datastore/src/security/security_retention_policy.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/sync/drain.dart';
import 'package:provenance/provenance.dart';
import 'package:uuid/uuid.dart';

/// Fire-and-forget trigger into `SyncCycle.call()`.
typedef EventStoreSyncCycleTrigger = Future<void> Function();

/// Result of `EventStore.applyRetentionPolicy`: counts of rows touched by
/// the compact and purge sweeps.
// Implements: REQ-d00138-B+C+E+F — retention-sweep return type.
class RetentionResult {
  const RetentionResult({
    required this.compactedCount,
    required this.purgedCount,
  });
  final int compactedCount;
  final int purgedCount;
}

/// Phase 4.4 write API. Serves both mobile widgets and portal callers via
/// one `append` method that takes per-field arguments plus optional
/// `SecurityDetails`. Replaces `EntryService.record` (REQ-d00141-A).
///
/// `EventStore` is permission-blind (REQ-d00141-D): it exposes unguarded
/// read/write APIs to anything holding a reference. All access control
/// lives in the widget layer (Flutter widgets client-side, request
/// handlers server-side).
// Implements: REQ-d00141-A — class named EventStore, lives in event_store.dart.
// Implements: REQ-d00141-B — single append() method serving mobile + portal.
// Implements: REQ-d00141-C — per-field arguments directly, no EventDraft.
// Implements: REQ-d00141-D — permission-blind.
class EventStore {
  EventStore({
    required this.backend,
    required this.entryTypes,
    required this.source,
    required this.securityContexts,
    this.materializers = const <Materializer>[],
    this.syncCycleTrigger,
    ClockFn? clock,
    Uuid? uuid,
  }) : _clock = clock,
       _uuid = uuid ?? const Uuid();

  final StorageBackend backend;
  final EntryTypeRegistry entryTypes;
  final Source source;
  final InternalSecurityContextStore securityContexts;
  final List<Materializer> materializers;
  final EventStoreSyncCycleTrigger? syncCycleTrigger;
  final ClockFn? _clock;
  final Uuid _uuid;

  DateTime _now() => (_clock ?? () => DateTime.now().toUtc())();

  /// Append a new event. Returns the persisted `StoredEvent`, or `null`
  /// when `dedupeByContent` is true and the content matches the
  /// aggregate's most recent event.
  ///
  /// The caller MUST supply [entryTypeVersion]; the lib stamps
  /// `lib_format_version` from [StoredEvent.currentLibFormatVersion]. Local
  /// append does NOT validate [entryTypeVersion] against the registry — that
  /// is performed at ingest per REQ-d00145-M.
  // Implements: REQ-d00141-B — per-field append API; entryTypeVersion required.
  // Implements: REQ-d00141-E — lib_format_version stamped from
  //   StoredEvent.currentLibFormatVersion on every append.
  // Implements: REQ-d00141-F — append does NOT validate entryTypeVersion
  //   against the registry.
  // Implements: REQ-d00135-C — initiator replaces userId.
  // Implements: REQ-d00136-A+E — flowToken nullable; hashed.
  // Implements: REQ-d00137-C — event + security row commit atomically.
  // Implements: REQ-d00140-B+C+E — materializers fire per event; def.materialize
  //   skip honored; throw rolls back entire append.
  Future<StoredEvent?> append({
    required String entryType,
    required int entryTypeVersion,
    required String aggregateId,
    required String aggregateType,
    required String eventType,
    required Map<String, Object?> data,
    required Initiator initiator,
    String? flowToken,
    Map<String, Object?>? metadata,
    SecurityDetails? security,
    String? checkpointReason,
    String? changeReason,
    bool dedupeByContent = false,
  }) async {
    final event = await backend.transaction<StoredEvent?>((txn) async {
      return appendInTxn(
        txn,
        entryType: entryType,
        entryTypeVersion: entryTypeVersion,
        aggregateId: aggregateId,
        aggregateType: aggregateType,
        eventType: eventType,
        data: data,
        initiator: initiator,
        flowToken: flowToken,
        metadata: metadata,
        security: security,
        checkpointReason: checkpointReason,
        changeReason: changeReason,
        dedupeByContent: dedupeByContent,
      );
    });

    if (event == null) return null;
    unawaited(syncCycleTrigger?.call());
    return event;
  }

  /// True iff [event] was originated locally on this `EventStore`'s
  /// [source].
  ///
  /// Compares originator install identity (`provenance[0].identifier`)
  /// against `source.identifier` — not `source.hopId`, because two
  /// installations of the same role class are distinct originators. A
  /// receiver uses this to discriminate locally-appended events from
  /// bridged-from-upstream events without writing provenance navigation
  /// by hand.
  ///
  /// Throws `StateError` (via `event.originatorHop`) when [event] has no
  /// provenance entries; REQ-d00115 requires every event to carry at
  /// least the originator hop.
  // Implements: REQ-d00154-B — local-vs-upstream discrimination on
  // install UUID; comparison is on identifier, not hopId.
  bool isLocallyOriginated(StoredEvent event) =>
      event.originatorHop.identifier == source.identifier;

  /// Delete the security-context row for [eventId] AND append one
  /// `security_context_redacted` event in the same transaction. The act
  /// of redaction is permanently auditable.
  // Implements: REQ-d00138-D — clearSecurityContext semantics.
  // Implements: REQ-d00138-G — redaction event is an immutable event-log row.
  Future<void> clearSecurityContext(
    String eventId, {
    required String reason,
    required Initiator redactedBy,
  }) async {
    await backend.transaction<void>((txn) async {
      final existing = await securityContexts.readInTxn(txn, eventId);
      if (existing == null) {
        throw ArgumentError.value(
          eventId,
          'eventId',
          'no security context row for event',
        );
      }
      await securityContexts.deleteInTxn(txn, eventId);
      // Implements: REQ-d00134-G — registry-sourced version stamp on the
      //   security-context redaction audit.
      // Implements: REQ-d00138-D (revised: aggregateId=source.identifier),
      //   REQ-d00154-D — system events use the install UUID as their
      //   aggregate; the redaction subject moves into
      //   `data.subject_event_id` so callers can still query "all
      //   redactions of event X" by filtering on entry_type AND
      //   data.subject_event_id.
      await appendInTxn(
        txn,
        entryType: kSecurityContextRedactedEntryType,
        entryTypeVersion: entryTypes
            .byId(kSecurityContextRedactedEntryType)!
            .registeredVersion,
        aggregateId: source.identifier,
        aggregateType: 'security_context',
        eventType: 'finalized',
        data: <String, Object?>{'subject_event_id': eventId, 'reason': reason},
        initiator: redactedBy,
        flowToken: null,
        metadata: null,
        security: null,
        checkpointReason: null,
        changeReason: null,
        dedupeByContent: false,
      );
    });
    unawaited(syncCycleTrigger?.call());
  }

  /// Apply [policy] (or [SecurityRetentionPolicy.defaults]) to the
  /// security-context sidecar store. Truncates rows past `fullRetention`,
  /// deletes rows past `fullRetention + truncatedRetention`. Emits a
  /// `system.retention_policy_applied` audit event on every sweep
  /// (zero-effect sweeps included), plus per-population
  /// `security_context_compacted` / `security_context_purged` events
  /// when those sweeps are non-empty.
  // Implements: REQ-d00138-B+C+E+F — compact + purge sweeps with audit.
  // Implements: REQ-d00138-H — per-sweep retention_policy_applied audit
  //   (always, even on empty sweeps).
  Future<RetentionResult> applyRetentionPolicy({
    SecurityRetentionPolicy? policy,
    Initiator? sweepInitiator,
  }) async {
    final p = policy ?? SecurityRetentionPolicy.defaults;
    final sweepBy =
        sweepInitiator ??
        const AutomationInitiator(service: 'retention-policy-sweep');
    final now = _now();
    final compactCutoff = now.subtract(p.fullRetention);
    final purgeCutoff = compactCutoff.subtract(p.truncatedRetention);

    final result = await backend.transaction<RetentionResult>((txn) async {
      final compactCandidates = await securityContexts
          .findUnredactedOlderThanInTxn(txn, compactCutoff);
      for (final row in compactCandidates) {
        await securityContexts.upsertInTxn(txn, row.applyTruncation(p));
      }

      final purgeCandidates = await securityContexts.findOlderThanInTxn(
        txn,
        purgeCutoff,
      );
      for (final row in purgeCandidates) {
        await securityContexts.deleteInTxn(txn, row.eventId);
      }

      if (compactCandidates.isNotEmpty) {
        // Implements: REQ-d00134-G — registry-sourced version stamp on
        //   the compact-sweep audit.
        // Implements: REQ-d00138-E (revised: aggregateId=source.identifier),
        //   REQ-d00154-D — system events use the install UUID as their
        //   aggregate.
        await appendInTxn(
          txn,
          entryType: kSecurityContextCompactedEntryType,
          entryTypeVersion: entryTypes
              .byId(kSecurityContextCompactedEntryType)!
              .registeredVersion,
          aggregateId: source.identifier,
          aggregateType: 'security_context',
          eventType: 'finalized',
          data: <String, Object?>{
            'count': compactCandidates.length,
            'cutoff': compactCutoff.toIso8601String(),
            'policy': p.toJson(),
          },
          initiator: sweepBy,
          flowToken: null,
          metadata: null,
          security: null,
          checkpointReason: null,
          changeReason: null,
          dedupeByContent: false,
        );
      }
      if (purgeCandidates.isNotEmpty) {
        // Implements: REQ-d00134-G — registry-sourced version stamp on
        //   the purge-sweep audit.
        // Implements: REQ-d00138-F (revised: aggregateId=source.identifier),
        //   REQ-d00154-D — system events use the install UUID as their
        //   aggregate.
        await appendInTxn(
          txn,
          entryType: kSecurityContextPurgedEntryType,
          entryTypeVersion: entryTypes
              .byId(kSecurityContextPurgedEntryType)!
              .registeredVersion,
          aggregateId: source.identifier,
          aggregateType: 'security_context',
          eventType: 'finalized',
          data: <String, Object?>{
            'count': purgeCandidates.length,
            'cutoff': purgeCutoff.toIso8601String(),
          },
          initiator: sweepBy,
          flowToken: null,
          metadata: null,
          security: null,
          checkpointReason: null,
          changeReason: null,
          dedupeByContent: false,
        );
      }
      // Implements: REQ-d00138-H — per-sweep audit, always emitted (the
      // operator wants a retention timeline, not just non-empty sweeps).
      // Implements: REQ-d00134-G — registry-sourced version stamp on
      //   the per-sweep retention-policy-applied audit.
      // Implements: REQ-d00138-H (revised: aggregateId=source.identifier),
      //   REQ-d00154-D — system events use the install UUID as their
      //   aggregate.
      await appendInTxn(
        txn,
        entryType: kRetentionPolicyAppliedEntryType,
        entryTypeVersion: entryTypes
            .byId(kRetentionPolicyAppliedEntryType)!
            .registeredVersion,
        aggregateId: source.identifier,
        aggregateType: 'system_retention',
        eventType: 'finalized',
        data: <String, Object?>{
          'policy_full_retention_seconds': p.fullRetention.inSeconds,
          'policy_truncated_retention_seconds': p.truncatedRetention.inSeconds,
          'events_truncated': compactCandidates.length,
          'events_purged': purgeCandidates.length,
          'cutoff_full': compactCutoff.toUtc().toIso8601String(),
          'cutoff_purge': purgeCutoff.toUtc().toIso8601String(),
        },
        initiator: sweepBy,
        flowToken: null,
        metadata: null,
        security: null,
        checkpointReason: null,
        changeReason: null,
        dedupeByContent: false,
      );
      return RetentionResult(
        compactedCount: compactCandidates.length,
        purgedCount: purgeCandidates.length,
      );
    });
    unawaited(syncCycleTrigger?.call());
    return result;
  }

  void _validateAppendInputs({
    required String entryType,
    required String aggregateType,
    required String eventType,
  }) {
    if (eventType != 'finalized' &&
        eventType != 'checkpoint' &&
        eventType != 'tombstone') {
      throw ArgumentError.value(
        eventType,
        'eventType',
        'must be one of finalized, checkpoint, tombstone',
      );
    }
    if (!entryTypes.isRegistered(entryType)) {
      throw ArgumentError.value(
        entryType,
        'entryType',
        'not registered in EntryTypeRegistry',
      );
    }
    if (aggregateType.isEmpty) {
      throw ArgumentError.value(
        aggregateType,
        'aggregateType',
        'must be non-empty',
      );
    }
  }

  /// Transactional companion to [append]. Use when the caller is already
  /// inside a `backend.transaction` and wants the append to participate
  /// (e.g. so a config-mutation audit event lands atomically with the
  /// mutation that triggered it).
  ///
  /// Skips `unawaited(syncCycleTrigger?.call())` — the public [append]
  /// fires that AFTER the transaction commits.
  ///
  /// Validates inputs via [_validateAppendInputs] before doing any work,
  /// so direct callers do not need to pre-validate.
  // Implements: REQ-d00141-B (delegated transactional half).
  Future<StoredEvent?> appendInTxn(
    Txn txn, {
    required String entryType,
    required int entryTypeVersion,
    required String aggregateId,
    required String aggregateType,
    required String eventType,
    required Map<String, Object?> data,
    required Initiator initiator,
    required String? flowToken,
    required Map<String, Object?>? metadata,
    required SecurityDetails? security,
    required String? checkpointReason,
    required String? changeReason,
    required bool dedupeByContent,
  }) async {
    _validateAppendInputs(
      entryType: entryType,
      aggregateType: aggregateType,
      eventType: eventType,
    );

    final def = entryTypes.byId(entryType)!;
    final effectiveChangeReason = changeReason ?? 'initial';

    final now = _now();
    final provenance0 = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: now,
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
    );

    // dedupe-by-content
    // Implements: REQ-d00134-F — dedupeByContent matches against the
    //   most-recent event of matching entry_type within the aggregate.
    //   Multiple entry types may share an aggregate (REQ-d00154-D system
    //   events under source.identifier); dedupe scopes per entry_type so
    //   each emission stream is treated independently.
    final aggregateHistory = await backend.findEventsForAggregateInTxn(
      txn,
      aggregateId,
    );
    StoredEvent? prior;
    if (dedupeByContent) {
      for (var i = aggregateHistory.length - 1; i >= 0; i--) {
        if (aggregateHistory[i].entryType == entryType) {
          prior = aggregateHistory[i];
          break;
        }
      }
    }
    if (dedupeByContent && prior != null) {
      final priorHash = _contentHash(
        eventType: prior.eventType,
        data: prior.data,
        changeReason: (prior.metadata['change_reason'] as String?) ?? 'initial',
      );
      final candidateHash = _contentHash(
        eventType: eventType,
        data: <String, Object?>{
          ...data,
          'checkpoint_reason': ?checkpointReason,
        },
        changeReason: effectiveChangeReason,
      );
      if (candidateHash == priorHash) return null;
    }

    final previousHash = await backend.readLatestEventHash(txn);
    final sequenceNumber = await backend.nextSequenceNumber(txn);
    final eventId = _uuid.v4();

    final dataMap = <String, Object?>{
      ...data,
      'checkpoint_reason': ?checkpointReason,
    };
    final metadataMap = <String, Object?>{
      ...?metadata,
      'change_reason': effectiveChangeReason,
      'provenance': <Map<String, Object?>>[provenance0.toJson()],
    };

    final recordMap = <String, Object?>{
      'event_id': eventId,
      'aggregate_id': aggregateId,
      'aggregate_type': aggregateType,
      'entry_type': entryType,
      'entry_type_version': entryTypeVersion,
      'lib_format_version': StoredEvent.currentLibFormatVersion,
      'event_type': eventType,
      'sequence_number': sequenceNumber,
      'data': dataMap,
      'metadata': metadataMap,
      'initiator': initiator.toJson(),
      'flow_token': flowToken,
      'client_timestamp': provenance0.receivedAt.toIso8601String(),
      'previous_event_hash': previousHash,
    };
    final eventHash = _eventHash(recordMap);
    recordMap['event_hash'] = eventHash;
    final event = StoredEvent.fromMap(recordMap, 0);

    await backend.appendEvent(txn, event);

    if (security != null) {
      final row = EventSecurityContext(
        eventId: eventId,
        recordedAt: now,
        ipAddress: security.ipAddress,
        userAgent: security.userAgent,
        sessionId: security.sessionId,
        geoCountry: security.geoCountry,
        geoRegion: security.geoRegion,
        requestId: security.requestId,
      );
      await securityContexts.writeInTxn(txn, row);
    }

    if (def.materialize) {
      for (final m in materializers) {
        if (!m.appliesTo(event)) continue;
        // Implements: REQ-d00140-G+H — promoter invoked before applyInTxn,
        //   even when fromVersion == toVersion. A throw rolls back the txn.
        final target = await m.targetVersionFor(txn, backend, event.entryType);
        final promoted = m.promoter(
          entryType: event.entryType,
          fromVersion: event.entryTypeVersion,
          toVersion: target,
          data: event.data,
        );
        await m.applyInTxn(
          txn,
          backend,
          event: event,
          promotedData: promoted,
          def: def,
          aggregateHistory: List<StoredEvent>.unmodifiable(aggregateHistory),
        );
      }
    }

    return event;
  }

  String _contentHash({
    required String eventType,
    required Map<String, Object?> data,
    required String changeReason,
  }) {
    final input = <String, Object?>{
      'event_type': eventType,
      'data': data,
      'change_reason': changeReason,
    };
    return sha256.convert(canonicalizeBytes(input)).toString();
  }

  // Implements: REQ-d00120-A+B (Phase 4.4 revised) — hash over the Phase
  // 4.4 identity-field set.
  String _eventHash(Map<String, Object?> recordMap) {
    final hashInput = <String, Object?>{
      'event_id': recordMap['event_id'],
      'aggregate_id': recordMap['aggregate_id'],
      'entry_type': recordMap['entry_type'],
      'event_type': recordMap['event_type'],
      'sequence_number': recordMap['sequence_number'],
      'data': recordMap['data'],
      'initiator': recordMap['initiator'],
      'flow_token': recordMap['flow_token'],
      'client_timestamp': recordMap['client_timestamp'],
      'previous_event_hash': recordMap['previous_event_hash'],
      'metadata': recordMap['metadata'],
    };
    return sha256.convert(canonicalizeBytes(hashInput)).toString();
  }

  // -----------------------------------------------------------------------
  // Destination-role (ingest) write path — Phase 4.9
  // -----------------------------------------------------------------------

  /// Process-local ingest. Opens its own transaction and delegates to
  /// [_ingestOneInTxn] with `batchContext: null`.
  ///
  /// Accepts an [incoming] StoredEvent, verifies Chain 1, checks idempotency
  /// by event_id, stamps a receiver ProvenanceEntry with Chain 2 fields
  /// (`batch_context = null`), recomputes `event_hash`, and persists.
  // Implements: REQ-d00145-G+I+J+K.
  Future<PerEventIngestOutcome> ingestEvent(StoredEvent incoming) async {
    return backend.transaction((txn) async {
      return _ingestOneInTxn(txn, incoming, batchContext: null);
    });
  }

  /// Wire-side batch ingest. Decodes [bytes] as an `esd/batch@1` envelope,
  /// runs every subject event through [_ingestOneInTxn] inside a single
  /// transaction, and stamps each with a [BatchContext] referencing this
  /// batch. Throws [IngestDecodeFailure] for any unsupported [wireFormat] or
  /// malformed bytes; throws [IngestIdentityMismatch] (rolling back the whole
  /// batch) if any subject has a hash conflict with an already-stored event.
  ///
  /// See design spec §2.5.
  // Implements: REQ-d00145-A+B+E.
  Future<IngestBatchResult> ingestBatch(
    Uint8List bytes, {
    required String wireFormat,
  }) async {
    if (wireFormat != BatchEnvelope.wireFormat) {
      throw IngestDecodeFailure(
        'unsupported wireFormat: "$wireFormat"; expected "${BatchEnvelope.wireFormat}"',
      );
    }
    final envelope = BatchEnvelope.decode(bytes);
    final wireBytesHash = sha256.convert(bytes).toString();
    final outcomes = <PerEventIngestOutcome>[];

    await backend.transaction((txn) async {
      for (var i = 0; i < envelope.events.length; i++) {
        final eventMap = envelope.events[i];
        final storedEvent = StoredEvent.fromMap(
          Map<String, Object?>.from(eventMap),
          0,
        );
        // Implements: REQ-d00145-L. Lib-format check runs first.
        if (storedEvent.libFormatVersion >
            StoredEvent.currentLibFormatVersion) {
          throw IngestLibFormatVersionAhead(
            eventId: storedEvent.eventId,
            wireVersion: storedEvent.libFormatVersion,
            receiverVersion: StoredEvent.currentLibFormatVersion,
          );
        }
        // Implements: REQ-d00145-M. Entry-type check second; def==null falls
        // through to the existing failure path inside _ingestOneInTxn.
        final def = entryTypes.byId(storedEvent.entryType);
        if (def != null &&
            storedEvent.entryTypeVersion > def.registeredVersion) {
          throw IngestEntryTypeVersionAhead(
            eventId: storedEvent.eventId,
            entryType: storedEvent.entryType,
            wireVersion: storedEvent.entryTypeVersion,
            receiverVersion: def.registeredVersion,
          );
        }
        final batchContext = BatchContext(
          batchId: envelope.batchId,
          batchPosition: i,
          batchSize: envelope.events.length,
          batchWireBytesHash: wireBytesHash,
          batchWireFormat: BatchEnvelope.wireFormat,
        );
        final outcome = await _ingestOneInTxn(
          txn,
          storedEvent,
          batchContext: batchContext,
        );
        outcomes.add(outcome);
      }
    });

    return IngestBatchResult(batchId: envelope.batchId, events: outcomes);
  }

  /// Per-event ingest logic, called from both [ingestEvent] and the
  /// `ingestBatch` loop.
  ///
  /// [batchContext] is non-null when called from `ingestBatch`, null when
  /// called from [ingestEvent].
  // Implements: REQ-d00145-D+G+K; REQ-d00120-E.
  Future<PerEventIngestOutcome> _ingestOneInTxn(
    Txn txn,
    StoredEvent incoming, {
    required BatchContext? batchContext,
  }) async {
    // 1. Chain 1 verify on the incoming provenance.
    final verdict = _verifyChainOn(incoming);
    if (!verdict.ok) {
      final failure = verdict.failures.first;
      throw IngestChainBroken(
        eventId: incoming.eventId,
        hopIndex: failure.position,
        expectedHash: failure.expectedHash,
        actualHash: failure.actualHash,
      );
    }

    // 2. Idempotency check by event_id.
    final existing = await backend.findEventByIdInTxn(txn, incoming.eventId);
    if (existing != null) {
      // Event already present — compare arrival_hash for identity check.
      final existingProv = (existing.metadata['provenance'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final thisHopEntry = existingProv.last;
      final storedArrivalHash = thisHopEntry['arrival_hash'] as String?;
      if (storedArrivalHash == incoming.eventHash) {
        // Duplicate — emit audit event, return duplicate outcome.
        await _emitDuplicateReceivedInTxn(
          txn,
          subjectEventId: incoming.eventId,
          subjectEventHashOnRecord: existing.eventHash,
          batchContext: batchContext,
        );
        return PerEventIngestOutcome(
          eventId: incoming.eventId,
          outcome: IngestOutcome.duplicate,
          resultHash: existing.eventHash,
        );
      } else {
        throw IngestIdentityMismatch(
          eventId: incoming.eventId,
          incomingHash: incoming.eventHash,
          storedArrivalHash: storedArrivalHash ?? '(null)',
        );
      }
    }

    // 3. New event — reserve a fresh local sequence_number, capture the
    //    originator's wire-supplied sequence_number, and stamp receiver
    //    provenance. Under the unified event store, "Chain 2 ordering"
    //    is the local sequence_number; the previous-ingest tail hash is
    //    the prior event in this destination's log.
    final originSeq = incoming.sequenceNumber;
    final localSeq = await backend.nextSequenceNumber(txn);
    final previousTailHash = await backend.readLatestEventHash(txn);
    final receiverEntry = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: _now(),
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
      arrivalHash: incoming.eventHash,
      previousIngestHash: previousTailHash,
      ingestSequenceNumber: localSeq,
      originSequenceNumber: originSeq,
      batchContext: batchContext,
    );

    // 4. Build the updated event with the local sequence_number and
    //    appended receiver provenance, then recompute the event hash.
    final updatedEvent = _appendReceiverProvenance(
      incoming,
      receiverEntry,
      localSeq: localSeq,
    );

    // 5. Read prior aggregate history before appendEvent so the
    //    materializer receives "events strictly before the new one"
    //    in symmetry with the append path's loop.
    final aggregateHistory = await backend.findEventsForAggregateInTxn(
      txn,
      updatedEvent.aggregateId,
    );

    // 6. Persist via the same path as origin appends.
    await backend.appendEvent(txn, updatedEvent);

    // 7. Fire materializers symmetric with the local-append path.
    // Implements: REQ-d00121-K, REQ-d00145-N — the ingest-path materializer
    //   loop runs with the same gates as the local-append loop
    //   (`def.materialize` outer gate + `m.appliesTo(event)` inner gate),
    //   inside the same transaction as `appendEvent`. System entry types
    //   ship `materialize: false` (REQ-d00154-D) so the outer gate
    //   short-circuits before any materializer is consulted. A
    //   materializer or promoter throw propagates out of `_ingestOneInTxn`
    //   and rolls back the entire ingest transaction (REQ-d00145-A
    //   all-or-nothing batch atomicity preserved).
    final def = entryTypes.byId(updatedEvent.entryType);
    if (def != null && def.materialize) {
      for (final m in materializers) {
        if (!m.appliesTo(updatedEvent)) continue;
        final target = await m.targetVersionFor(
          txn,
          backend,
          updatedEvent.entryType,
        );
        final promoted = m.promoter(
          entryType: updatedEvent.entryType,
          fromVersion: updatedEvent.entryTypeVersion,
          toVersion: target,
          data: updatedEvent.data,
        );
        await m.applyInTxn(
          txn,
          backend,
          event: updatedEvent,
          promotedData: promoted,
          def: def,
          aggregateHistory: List<StoredEvent>.unmodifiable(aggregateHistory),
        );
      }
    }

    return PerEventIngestOutcome(
      eventId: updatedEvent.eventId,
      outcome: IngestOutcome.ingested,
      resultHash: updatedEvent.eventHash,
    );
  }

  // -----------------------------------------------------------------------
  // Verification APIs — Phase 4.9 Task 10
  // -----------------------------------------------------------------------

  /// Walk Chain 1 on [event].metadata.provenance backward from tail to origin.
  /// Non-throwing; returns a [ChainVerdict] with `ok=true` when every
  /// `arrival_hash` matches the recomputed hash at that hop, `ok=false`
  /// otherwise with a list of [ChainFailure] instances describing each broken
  /// link. Returns `ok=true` for origin-only events (single-entry provenance —
  /// no inter-hop links to verify).
  ///
  /// See design spec §2.11.
  // Implements: REQ-d00146-A+B+D+E.
  Future<ChainVerdict> verifyEventChain(StoredEvent event) async {
    return _verifyChainOn(event);
  }

  /// Walk Chain 2 on this destination's event log from [fromSequenceNumber]
  /// to [toSequenceNumber] (inclusive). When [toSequenceNumber] is null,
  /// walks through the current tail. Throws [ArgumentError] if
  /// `fromSequenceNumber > toSequenceNumber`. Non-throwing otherwise; returns
  /// a [ChainVerdict] with `ok=true` when every `previous_ingest_hash` equals
  /// the stored `event_hash` of the prior ingest-stamped event in the range.
  ///
  /// Under the unified event store, the "Chain 2 ordering" is the local
  /// `sequence_number` (also recorded on the receiver-hop entry as
  /// `ingest_sequence_number` for symmetry with Chain 2 fields). Events
  /// without a receiver-stamped top provenance entry — i.e. origin appends
  /// made by this device — are skipped.
  ///
  /// See design spec §2.11.
  // Implements: REQ-d00146-C+D+E — Chain 2 walk over the unified event log.
  Future<ChainVerdict> verifyIngestChain({
    int fromSequenceNumber = 0,
    int? toSequenceNumber,
  }) async {
    final allEvents = await backend.findAllEvents();
    final ingestStamped = <StoredEvent>[];
    for (final event in allEvents) {
      final ingestSeq = _ingestSeqOf(event);
      if (ingestSeq != null) {
        ingestStamped.add(event);
      }
    }
    final tailSeq = ingestStamped.isEmpty
        ? 0
        : _ingestSeqOf(ingestStamped.last)!;
    final upperBound = toSequenceNumber ?? tailSeq;
    if (fromSequenceNumber > upperBound) {
      throw ArgumentError(
        'fromSequenceNumber ($fromSequenceNumber) must be <= '
        'toSequenceNumber ($upperBound)',
      );
    }
    final failures = <ChainFailure>[];
    StoredEvent? prev;
    for (final event in ingestStamped) {
      final thisSeq = _ingestSeqOf(event)!;
      if (thisSeq < fromSequenceNumber) continue;
      if (thisSeq > upperBound) break;
      if (thisSeq <= fromSequenceNumber) {
        // Anchor at the start of the range — not verified against
        // anything before it.
        prev = event;
        continue;
      }
      final provenance = (event.metadata['provenance'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final lastEntry = provenance.last;
      final previousIngestHash = lastEntry['previous_ingest_hash'] as String?;
      final expected = prev?.eventHash;
      if (previousIngestHash != expected) {
        failures.add(
          ChainFailure(
            position: thisSeq,
            kind: ChainFailureKind.previousIngestHashMismatch,
            expectedHash: expected ?? '(null)',
            actualHash: previousIngestHash ?? '(null)',
          ),
        );
      }
      prev = event;
    }
    return ChainVerdict(ok: failures.isEmpty, failures: failures);
  }

  /// Extract the `ingest_sequence_number` from the last provenance entry of
  /// [event], or `null` when the event was not ingest-stamped (i.e. an
  /// origin-only event with no receiver hop). Used by [verifyIngestChain]
  /// to identify each event's position in Chain 2.
  int? _ingestSeqOf(StoredEvent event) {
    final provenanceRaw = event.metadata['provenance'];
    if (provenanceRaw is! List || provenanceRaw.isEmpty) return null;
    final last = provenanceRaw.last;
    if (last is! Map<String, Object?>) return null;
    return last['ingest_sequence_number'] as int?;
  }

  /// Walk Chain 1 on [event].metadata.provenance and return a non-throwing
  /// verdict. Used by [ingestEvent] and [verifyEventChain].
  // Implements: REQ-d00146-A+B.
  ChainVerdict _verifyChainOn(StoredEvent event) {
    final provenanceRaw = event.metadata['provenance'];
    if (provenanceRaw is! List) {
      return const ChainVerdict(
        ok: false,
        failures: <ChainFailure>[
          ChainFailure(
            position: -1,
            kind: ChainFailureKind.provenanceMissing,
            expectedHash: '(list)',
            actualHash: '(missing or non-list)',
          ),
        ],
      );
    }
    final provenance = provenanceRaw.cast<Map<String, Object?>>();
    if (provenance.isEmpty) {
      return const ChainVerdict(
        ok: false,
        failures: <ChainFailure>[
          ChainFailure(
            position: -1,
            kind: ChainFailureKind.provenanceMissing,
            expectedHash: '(non-empty)',
            actualHash: '(empty)',
          ),
        ],
      );
    }
    final failures = <ChainFailure>[];
    // Walk from tail back to hop 1 (skip origin at index 0).
    //
    // Each receiver hop reassigns the stored event's `sequence_number` to
    // its local counter (REQ-d00145-E). To recompute the hash at hop k-1,
    // substitute the seq that was on the event when hop k-1 stored it:
    //
    //   - For k == 1 (recomputing the origin's hash): use the originator's
    //     wire-supplied seq, preserved on provenance[1].origin_sequence_number.
    //   - For k > 1 (recomputing a prior receiver hop's hash): use that
    //     prior hop's reassigned local seq, recorded as
    //     provenance[k-1].ingest_sequence_number.
    for (var k = provenance.length - 1; k > 0; k--) {
      final entry = provenance[k];
      final expected = entry['arrival_hash'] as String?;
      if (expected == null) {
        failures.add(
          ChainFailure(
            position: k,
            kind: ChainFailureKind.arrivalHashMismatch,
            expectedHash: '(non-null)',
            actualHash: '(null)',
          ),
        );
        continue;
      }
      final int? seqAtHopBefore;
      if (k == 1) {
        seqAtHopBefore = entry['origin_sequence_number'] as int?;
      } else {
        seqAtHopBefore = provenance[k - 1]['ingest_sequence_number'] as int?;
      }
      final recomputed = _hashWithProvenanceSlice(
        event,
        provenance.sublist(0, k),
        sequenceNumberOverride: seqAtHopBefore,
      );
      if (recomputed != expected) {
        failures.add(
          ChainFailure(
            position: k,
            kind: ChainFailureKind.arrivalHashMismatch,
            expectedHash: expected,
            actualHash: recomputed,
          ),
        );
      }
    }
    return ChainVerdict(ok: failures.isEmpty, failures: failures);
  }

  /// Build a new [StoredEvent] with [receiverEntry] appended to
  /// `metadata.provenance`, `sequence_number` reassigned to [localSeq], and
  /// `event_hash` recomputed.
  ///
  /// Under the unified event store, the receiver overwrites the wire-supplied
  /// `sequence_number` so origin and ingest events share one monotone counter
  /// per device (REQ-d00145-E). The originator's wire-supplied
  /// `sequence_number` is preserved on [receiverEntry] as
  /// `originSequenceNumber` (REQ-d00115).
  // Implements: REQ-d00120-E — hash recomputed on receiver provenance append.
  // Implements: REQ-d00145-E — local sequence_number reassignment.
  StoredEvent _appendReceiverProvenance(
    StoredEvent incoming,
    ProvenanceEntry receiverEntry, {
    required int localSeq,
  }) {
    final oldProvenance = (incoming.metadata['provenance'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final newProvenance = <Map<String, Object?>>[
      ...oldProvenance,
      receiverEntry.toJson(),
    ];
    final newMetadata = <String, Object?>{
      ...incoming.metadata,
      'provenance': newProvenance,
    };
    final recordMap = Map<String, Object?>.from(incoming.toMap());
    recordMap['metadata'] = newMetadata;
    recordMap['sequence_number'] = localSeq;
    recordMap.remove('event_hash'); // will be overwritten below
    final newHash = _eventHash(recordMap);
    recordMap['event_hash'] = newHash;
    return StoredEvent.fromMap(recordMap, localSeq);
  }

  /// Compute the hash that an event would have with its provenance replaced
  /// by [provenanceSlice] and (optionally) `sequence_number` overridden to
  /// [sequenceNumberOverride]. Used by [_verifyChainOn] to reconstruct what
  /// each intermediate hop's `event_hash` was, accounting for the receiver-
  /// side reassignment of `sequence_number` (REQ-d00145-E).
  String _hashWithProvenanceSlice(
    StoredEvent event,
    List<Map<String, Object?>> provenanceSlice, {
    int? sequenceNumberOverride,
  }) {
    final recordMap = Map<String, Object?>.from(event.toMap());
    final newMetadata = <String, Object?>{
      ...event.metadata,
      'provenance': provenanceSlice,
    };
    recordMap['metadata'] = newMetadata;
    if (sequenceNumberOverride != null) {
      recordMap['sequence_number'] = sequenceNumberOverride;
    }
    recordMap.remove('event_hash');
    return _eventHash(recordMap);
  }

  /// Caller-composed rejection audit. See design spec §2.7.
  ///
  /// Opens its own transaction and records one `ingest.batch_rejected` event
  /// under the `ingest-audit:{hopId}` aggregate with Chain 2 fields stamped on
  /// `provenance[0]`.  `batch_context` is null because no decoded batch is
  /// associated — the batch failed before or during decoding.
  ///
  /// Typical call site:
  /// ```dart
  /// try {
  ///   await store.ingestBatch(bytes, wireFormat: 'esd/batch@1');
  /// } on IngestIdentityMismatch catch (e) {
  ///   await store.logRejectedBatch(
  ///     bytes,
  ///     wireFormat: 'esd/batch@1',
  ///     reason: 'identityMismatch',
  ///     failedEventId: e.eventId,
  ///     errorDetail: e.toString(),
  ///   );
  /// }
  /// ```
  // Implements: REQ-d00145-H+I+J.
  Future<void> logRejectedBatch(
    Uint8List bytes, {
    required String wireFormat,
    required String reason,
    String? failedEventId,
    String? errorDetail,
  }) async {
    await backend.transaction((txn) async {
      final now = _now();
      final wireBytesHash = sha256.convert(bytes).toString();
      final auditAggregateId = 'ingest-audit:${source.hopId}';
      final localSeq = await backend.nextSequenceNumber(txn);
      final previousTailHash = await backend.readLatestEventHash(txn);
      final provenance0 = ProvenanceEntry(
        hop: source.hopId,
        receivedAt: now,
        identifier: source.identifier,
        softwareVersion: source.softwareVersion,
        arrivalHash: null, // receiver-originated event — no wire arrival
        previousIngestHash: previousTailHash,
        ingestSequenceNumber: localSeq,
        batchContext: null, // no decoded batch associated with a rejection
      );

      final eventId = _uuid.v4();
      final recordMap = <String, Object?>{
        'event_id': eventId,
        'aggregate_id': auditAggregateId,
        'aggregate_type': 'ingest-audit',
        'entry_type': 'ingest-audit',
        'entry_type_version': 1,
        'lib_format_version': StoredEvent.currentLibFormatVersion,
        'event_type': 'ingest.batch_rejected',
        'sequence_number': localSeq,
        'data': <String, Object?>{
          'wire_bytes': base64Encode(bytes),
          'wire_format': wireFormat,
          'byte_length': bytes.length,
          'wire_bytes_hash': wireBytesHash,
          'reason': reason,
          'failed_event_id': failedEventId,
          'error_detail': errorDetail,
        },
        'metadata': <String, Object?>{
          'provenance': <Map<String, Object?>>[provenance0.toJson()],
        },
        'initiator': const AutomationInitiator(service: 'ingest').toJson(),
        'flow_token': null,
        'client_timestamp': now.toIso8601String(),
        'previous_event_hash': previousTailHash,
      };
      final eventHash = _eventHash(recordMap);
      recordMap['event_hash'] = eventHash;
      final event = StoredEvent.fromMap(recordMap, localSeq);
      await backend.appendEvent(txn, event);
    });
  }

  /// Emit a receiver-originated `ingest.duplicate_received` audit event
  /// inside [txn]. Stamped with Chain 2 fields on `provenance[0]`.
  // Implements: REQ-d00145-D+I+J; REQ-d00115-H+I.
  Future<void> _emitDuplicateReceivedInTxn(
    Txn txn, {
    required String subjectEventId,
    required String subjectEventHashOnRecord,
    required BatchContext? batchContext,
  }) async {
    final now = _now();
    final auditAggregateId = 'ingest-audit:${source.hopId}';
    // Reserve a fresh local sequence_number; under the unified store this
    // value is also the receiver-hop's ingest_sequence_number for Chain 2.
    final localSeq = await backend.nextSequenceNumber(txn);
    final previousTailHash = await backend.readLatestEventHash(txn);

    final provenance0 = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: now,
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
      arrivalHash: null, // receiver-originated event — no wire arrival
      previousIngestHash: previousTailHash,
      ingestSequenceNumber: localSeq,
      batchContext: batchContext,
    );

    final eventId = _uuid.v4();
    final recordMap = <String, Object?>{
      'event_id': eventId,
      'aggregate_id': auditAggregateId,
      'aggregate_type': 'ingest-audit',
      'entry_type': 'ingest-audit',
      'entry_type_version': 1,
      'lib_format_version': StoredEvent.currentLibFormatVersion,
      'event_type': 'ingest.duplicate_received',
      'sequence_number': localSeq,
      'data': <String, Object?>{
        'subject_event_id': subjectEventId,
        'subject_event_hash_on_record': subjectEventHashOnRecord,
      },
      'metadata': <String, Object?>{
        'provenance': <Map<String, Object?>>[provenance0.toJson()],
      },
      'initiator': const AutomationInitiator(service: 'ingest').toJson(),
      'flow_token': null,
      'client_timestamp': now.toIso8601String(),
      'previous_event_hash': previousTailHash,
    };
    final eventHash = _eventHash(recordMap);
    recordMap['event_hash'] = eventHash;
    final event = StoredEvent.fromMap(recordMap, localSeq);
    await backend.appendEvent(txn, event);
  }
}
