import 'dart:async';
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
  // Implements: REQ-d00141-B — per-field append API.
  // Implements: REQ-d00135-C — initiator replaces userId.
  // Implements: REQ-d00136-A+E — flowToken nullable; hashed.
  // Implements: REQ-d00137-C — event + security row commit atomically.
  // Implements: REQ-d00140-B+C+E — materializers fire per event; def.materialize
  //   skip honored; throw rolls back entire append.
  Future<StoredEvent?> append({
    required String entryType,
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
    _validateAppendInputs(
      entryType: entryType,
      aggregateType: aggregateType,
      eventType: eventType,
    );

    final event = await backend.transaction<StoredEvent?>((txn) async {
      return _appendInTxn(
        txn,
        entryType: entryType,
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
      await _appendInTxn(
        txn,
        entryType: kSecurityContextRedactedEntryType,
        aggregateId: eventId,
        aggregateType: 'security_context',
        eventType: 'finalized',
        data: <String, Object?>{'reason': reason},
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
  /// deletes rows past `fullRetention + truncatedRetention`. Emits audit
  /// events per REQ-d00138-E / F. Empty sweeps emit no events.
  // Implements: REQ-d00138-B+C+E+F — compact + purge sweeps with audit.
  Future<RetentionResult> applyRetentionPolicy({
    SecurityRetentionPolicy? policy,
    Initiator? sweepInitiator,
  }) async {
    final p = policy ?? SecurityRetentionPolicy.defaults;
    final sweepBy =
        sweepInitiator ??
        const AutomationInitiator(service: 'retention-policy');
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
        await _appendInTxn(
          txn,
          entryType: kSecurityContextCompactedEntryType,
          aggregateId: 'retention-compact-${now.toIso8601String()}',
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
        await _appendInTxn(
          txn,
          entryType: kSecurityContextPurgedEntryType,
          aggregateId: 'retention-purge-${now.toIso8601String()}',
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

  /// In-transaction core of append. Used by `append`, `clearSecurityContext`,
  /// and `applyRetentionPolicy` so recursive appends (e.g. the audit event
  /// emitted when redacting) share one transaction with their trigger.
  Future<StoredEvent?> _appendInTxn(
    Txn txn, {
    required String entryType,
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
    final aggregateHistory = await backend.findEventsForAggregateInTxn(
      txn,
      aggregateId,
    );
    if (dedupeByContent && aggregateHistory.isNotEmpty) {
      final prior = aggregateHistory.last;
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
        if (m.appliesTo(event)) {
          await m.applyInTxn(
            txn,
            backend,
            event: event,
            def: def,
            aggregateHistory: List<StoredEvent>.unmodifiable(aggregateHistory),
          );
        }
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

  /// Per-event ingest logic, called from both [ingestEvent] and (in Task 8)
  /// the `ingestBatch` loop.
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

    // 3. New event — stamp receiver provenance.
    final (currentSeq, currentTailHash) = await backend.readIngestTailInTxn(
      txn,
    );
    final nextSeq = await backend.nextIngestSequenceNumber(txn);
    final receiverEntry = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: _now(),
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
      arrivalHash: incoming.eventHash,
      previousIngestHash: currentSeq == 0 ? null : currentTailHash,
      ingestSequenceNumber: nextSeq,
      batchContext: batchContext,
    );

    // 4. Build the updated event record map and recompute hash.
    final updatedEvent = _appendReceiverProvenance(incoming, receiverEntry);

    // 5. Persist.
    await backend.appendIngestedEvent(txn, updatedEvent);

    return PerEventIngestOutcome(
      eventId: updatedEvent.eventId,
      outcome: IngestOutcome.ingested,
      resultHash: updatedEvent.eventHash,
    );
  }

  /// Walk Chain 1 on [event].metadata.provenance and return a non-throwing
  /// verdict. Used by [ingestEvent] and (in Task 10) verifyEventChain.
  // Implements: REQ-d00146-A+B (partial — full verifyEventChain in Task 10).
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
      // Recompute what the hash would have been after the k-1 hop,
      // i.e., with provenance sliced to [0..k-1].
      final recomputed = _hashWithProvenanceSlice(
        event,
        provenance.sublist(0, k),
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
  /// `metadata.provenance` and `event_hash` recomputed.
  // Implements: REQ-d00120-E — hash recomputed on receiver provenance append.
  StoredEvent _appendReceiverProvenance(
    StoredEvent incoming,
    ProvenanceEntry receiverEntry,
  ) {
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
    recordMap.remove('event_hash'); // will be overwritten below
    final newHash = _eventHash(recordMap);
    recordMap['event_hash'] = newHash;
    return StoredEvent.fromMap(recordMap, incoming.sequenceNumber);
  }

  /// Compute the hash that an event would have with its provenance replaced
  /// by [provenanceSlice]. Used by [_verifyChainOn] to reconstruct what each
  /// intermediate hop's `event_hash` was.
  String _hashWithProvenanceSlice(
    StoredEvent event,
    List<Map<String, Object?>> provenanceSlice,
  ) {
    final recordMap = Map<String, Object?>.from(event.toMap());
    final newMetadata = <String, Object?>{
      ...event.metadata,
      'provenance': provenanceSlice,
    };
    recordMap['metadata'] = newMetadata;
    recordMap.remove('event_hash');
    return _eventHash(recordMap);
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
    final (currentSeq, currentTailHash) = await backend.readIngestTailInTxn(
      txn,
    );
    final nextSeq = await backend.nextIngestSequenceNumber(txn);

    final provenance0 = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: now,
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
      arrivalHash: null, // receiver-originated event — no wire arrival
      previousIngestHash: currentSeq == 0 ? null : currentTailHash,
      ingestSequenceNumber: nextSeq,
      batchContext: batchContext,
    );

    final auditAggregateId = 'ingest-audit:${source.hopId}';
    // Use nextSequenceNumber for the origin-side sequence on this event.
    // This advances the origin counter; the event is stored via the ingest
    // path (appendIngestedEvent), keyed by ingest_sequence_number.
    final localSeq = await backend.nextSequenceNumber(txn);
    final eventId = _uuid.v4();
    final previousHash = await backend.readLatestEventHash(txn);
    final recordMap = <String, Object?>{
      'event_id': eventId,
      'aggregate_id': auditAggregateId,
      'aggregate_type': 'ingest-audit',
      'entry_type': 'ingest-audit',
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
      'previous_event_hash': previousHash,
    };
    final eventHash = _eventHash(recordMap);
    recordMap['event_hash'] = eventHash;
    final event = StoredEvent.fromMap(recordMap, 0);
    await backend.appendIngestedEvent(txn, event);
  }
}
