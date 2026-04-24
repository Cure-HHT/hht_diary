import 'dart:async';

import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
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
import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';
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
}
