// IMPLEMENTS REQUIREMENTS:
//   REQ-d00146-A: verifyEventChain walks Chain 1 across 3+ hops
//   REQ-d00146-B: ChainVerdict shape; non-throwing contract
//   REQ-d00115-K: origin_sequence_number preserved on receiver hop
//   REQ-d00145-E: receiver reassigns sequence_number from local counter
//   REQ-d00120-E: event_hash recomputed on each receiver provenance append
//
// Regression coverage for the hop-mapping logic in `_verifyChainOn`:
// the recompute-at-hop-k-1 path uses
//   - provenance[1].origin_sequence_number for k == 1
//   - provenance[k-1].ingest_sequence_number for k > 1
// which is only exercised when provenance length >= 3 (i.e. an event
// has traversed at least two receiver hops). The other verify-event-chain
// fixtures top out at two hops (origin + one receiver).

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

var _dbCounter = 0;

class _Fixture {
  _Fixture({required this.store, required this.backend});
  final EventStore store;
  final SembastBackend backend;
  Future<void> close() => backend.close();
}

Future<_Fixture> _openStore({
  required String hopId,
  String? identifier,
  String softwareVersion = 'clinical_diary@1.0.0',
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'multi-hop-$_dbCounter.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Epistaxis Event',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_redacted',
        registeredVersion: 1,
        name: 'SC Redacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_compacted',
        registeredVersion: 1,
        name: 'SC Compacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_purged',
        registeredVersion: 1,
        name: 'SC Purged',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    );
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final store = EventStore(
    backend: backend,
    entryTypes: registry,
    source: Source(
      hopId: hopId,
      identifier: identifier ?? hopId,
      softwareVersion: softwareVersion,
    ),
    securityContexts: securityContexts,
  );
  return _Fixture(store: store, backend: backend);
}

/// Read the stored event for [eventId] from [fixture].
Future<StoredEvent> _fetchStored(_Fixture fixture, String eventId) async {
  final stored = await fixture.backend.transaction(
    (txn) async => fixture.backend.findEventByIdInTxn(txn, eventId),
  );
  expect(stored, isNotNull, reason: 'event $eventId not found');
  return stored!;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Multi-hop Chain 1 verification (REQ-d00146-A+B, REQ-d00115-K, REQ-d00145-E)',
    () {
      // -------------------------------------------------------------------
      // 3-hop chain: originator A -> mobile relay B -> portal C
      //
      // Verifies that `verifyEventChain` correctly walks back through both
      // receiver hops AND the originator-hash terminal step. This exercises
      // the hop-mapping seq-substitution logic for k > 1, which is unique
      // to chains of length >= 3.
      // -------------------------------------------------------------------
      test(
        'Verifies: REQ-d00146-A — verifyEventChain succeeds across a 3-hop chain (A->B->C)',
        () async {
          final originatorA = await _openStore(
            hopId: 'mobile-device-A',
            identifier: 'device-AAA',
          );
          final relayB = await _openStore(
            hopId: 'mobile-relay-B',
            identifier: 'relay-BBB',
            softwareVersion: 'clinical_diary@1.0.0',
          );
          final portalC = await _openStore(
            hopId: 'portal-server-C',
            identifier: 'portal-CCC',
            softwareVersion: 'portal@0.1.0',
          );

          try {
            // Hop 0: A originates two events.
            final eA1 = await originatorA.store.append(
              entryType: 'epistaxis_event',
              entryTypeVersion: 1,
              aggregateId: 'agg-3hop-1',
              aggregateType: 'DiaryEntry',
              eventType: 'finalized',
              data: const {
                'answers': {'q': 'a1'},
              },
              initiator: const UserInitiator('u1'),
            );
            final eA2 = await originatorA.store.append(
              entryType: 'epistaxis_event',
              entryTypeVersion: 1,
              aggregateId: 'agg-3hop-1',
              aggregateType: 'DiaryEntry',
              eventType: 'checkpoint',
              data: const {
                'answers': {'q': 'a2'},
              },
              initiator: const UserInitiator('u1'),
            );
            expect(eA1, isNotNull);
            expect(eA2, isNotNull);

            // Hop 1: B ingests both of A's events.
            await relayB.store.ingestEvent(eA1!);
            await relayB.store.ingestEvent(eA2!);

            // Read B's stored copies — these now carry receiver provenance
            // entries from B (length 2: [origin, B]).
            final atB1 = await _fetchStored(relayB, eA1.eventId);
            final atB2 = await _fetchStored(relayB, eA2.eventId);

            // Sanity: provenance length == 2 at this point.
            final provAtB1 = (atB1.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(
              provAtB1,
              hasLength(2),
              reason: 'B has appended one receiver hop',
            );
            // Sanity: B's local sequence_number is reassigned (independent
            // from A's per-aggregate seq).
            expect(atB1.sequenceNumber, equals(1));
            expect(atB2.sequenceNumber, equals(2));
            // The receiver hop preserves A's wire-supplied seq.
            expect(
              provAtB1.last['origin_sequence_number'],
              equals(eA1.sequenceNumber),
            );

            // Hop 2: C ingests B's stored events. From C's perspective,
            // B's stored copy IS the wire-supplied incoming event:
            // provenance is already [origin-A, receiver-B], and C will
            // append a third hop.
            final outAtC1 = await portalC.store.ingestEvent(atB1);
            final outAtC2 = await portalC.store.ingestEvent(atB2);
            expect(outAtC1.outcome, equals(IngestOutcome.ingested));
            expect(outAtC2.outcome, equals(IngestOutcome.ingested));

            // Read C's stored copies — provenance now has 3 entries.
            final atC1 = await _fetchStored(portalC, eA1.eventId);
            final atC2 = await _fetchStored(portalC, eA2.eventId);

            final provAtC1 = (atC1.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            final provAtC2 = (atC2.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(
              provAtC1,
              hasLength(3),
              reason: '3 hops: origin-A, receiver-B, receiver-C',
            );
            expect(provAtC2, hasLength(3));

            // Sanity: the hop entries identify each hop's source.
            expect(provAtC1[0]['hop'], equals('mobile-device-A'));
            expect(provAtC1[1]['hop'], equals('mobile-relay-B'));
            expect(provAtC1[2]['hop'], equals('portal-server-C'));

            // Sanity: hop-mapping data is present on the receiver entries.
            //   provenance[1].origin_sequence_number == A's wire seq
            //   provenance[1].ingest_sequence_number == B's local seq
            //   provenance[2].origin_sequence_number == B's wire seq (the
            //     event arrived at C carrying sequence_number == B's local
            //     seq, which B stamped via REQ-d00145-E)
            expect(
              provAtC1[1]['origin_sequence_number'],
              equals(eA1.sequenceNumber),
            );
            expect(
              provAtC1[1]['ingest_sequence_number'],
              equals(atB1.sequenceNumber),
            );
            expect(
              provAtC1[2]['origin_sequence_number'],
              equals(atB1.sequenceNumber),
            );

            // Core assertion: verifyEventChain walks all three hops on C
            // and finds no failures. This exercises the
            //   k > 1 -> provenance[k-1].ingest_sequence_number
            // substitution branch in `_verifyChainOn` that the 2-hop
            // fixtures cannot reach.
            final verdict1 = await portalC.store.verifyEventChain(atC1);
            expect(
              verdict1.ok,
              isTrue,
              reason:
                  'verifyEventChain must succeed across 3 hops; '
                  'failures: ${verdict1.failures}',
            );
            expect(verdict1.failures, isEmpty);

            final verdict2 = await portalC.store.verifyEventChain(atC2);
            expect(
              verdict2.ok,
              isTrue,
              reason:
                  'verifyEventChain must succeed across 3 hops; '
                  'failures: ${verdict2.failures}',
            );
            expect(verdict2.failures, isEmpty);
          } finally {
            await originatorA.close();
            await relayB.close();
            await portalC.close();
          }
        },
      );

      // -------------------------------------------------------------------
      // 4-hop chain confirms the hop-mapping recursion holds for arbitrary
      // depth. originator A -> mobile relay B -> mobile relay D -> portal C.
      // -------------------------------------------------------------------
      test(
        'Verifies: REQ-d00146-A — verifyEventChain succeeds across a 4-hop chain (A->B->D->C)',
        () async {
          final originatorA = await _openStore(
            hopId: 'mobile-device-A',
            identifier: 'device-AAA',
          );
          final relayB = await _openStore(
            hopId: 'mobile-relay-B',
            identifier: 'relay-BBB',
          );
          final relayD = await _openStore(
            hopId: 'mobile-relay-D',
            identifier: 'relay-DDD',
          );
          final portalC = await _openStore(
            hopId: 'portal-server-C',
            identifier: 'portal-CCC',
            softwareVersion: 'portal@0.1.0',
          );

          try {
            final eA = await originatorA.store.append(
              entryType: 'epistaxis_event',
              entryTypeVersion: 1,
              aggregateId: 'agg-4hop',
              aggregateType: 'DiaryEntry',
              eventType: 'finalized',
              data: const {
                'answers': {'q': 'a'},
              },
              initiator: const UserInitiator('u1'),
            );
            expect(eA, isNotNull);

            // Walk through B, D, C.
            await relayB.store.ingestEvent(eA!);
            final atB = await _fetchStored(relayB, eA.eventId);

            await relayD.store.ingestEvent(atB);
            final atD = await _fetchStored(relayD, eA.eventId);

            final outAtC = await portalC.store.ingestEvent(atD);
            expect(outAtC.outcome, equals(IngestOutcome.ingested));

            final atC = await _fetchStored(portalC, eA.eventId);
            final provAtC = (atC.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(
              provAtC,
              hasLength(4),
              reason: '4 hops: origin-A, receiver-B, receiver-D, receiver-C',
            );
            expect(provAtC[0]['hop'], equals('mobile-device-A'));
            expect(provAtC[1]['hop'], equals('mobile-relay-B'));
            expect(provAtC[2]['hop'], equals('mobile-relay-D'));
            expect(provAtC[3]['hop'], equals('portal-server-C'));

            final verdict = await portalC.store.verifyEventChain(atC);
            expect(
              verdict.ok,
              isTrue,
              reason:
                  'verifyEventChain must succeed across 4 hops; '
                  'failures: ${verdict.failures}',
            );
            expect(verdict.failures, isEmpty);
          } finally {
            await originatorA.close();
            await relayB.close();
            await relayD.close();
            await portalC.close();
          }
        },
      );
    },
  );
}
