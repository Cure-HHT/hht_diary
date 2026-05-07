// Verifies: REQ-d00154-E + REQ-d00129-O — the ingest path is a write-side
//   path that lands a wire-side audit event in `event_log` and stamps
//   receiver provenance on it. It SHALL NOT mutate the receiver's
//   `DestinationRegistry`, the receiver's `EntryTypeRegistry`, or any
//   per-destination FIFO state. Configuration on the receiver remains
//   driven exclusively by the receiver's local API calls (e.g. its own
//   `addDestination`, `setStartDate`, `setEndDate`, `deleteDestination`,
//   `tombstoneAndRefill`). Bridged system audit events are stored for
//   forensic / cross-hop observability only — they do not trigger any
//   side effect on the receiver's runtime state.
//
// Strategy: bootstrap two `AppendOnlyDatastore` instances with distinct
//   `Source.identifier` values, one acting as ORIGINATOR and one as
//   RECEIVER. The originator emits real system audit events as a side
//   effect of its own configuration calls (`addDestination`,
//   `setStartDate`, `tombstoneAndRefill`). Those audit events are read
//   off the originator's event log and re-shipped to the receiver via
//   `EventStore.ingestEvent`. The test then asserts the receiver's
//   registries / FIFOs are byte-identical pre vs post ingest, and that
//   the audit was nonetheless stored in the receiver's `event_log`.
//
// Using two real bootstrapped datastores (rather than hand-rolling
//   StoredEvent + Chain 1 hash + receiver Chain 2 stamping) keeps the
//   test focused on the invariant under test — receiver passivity —
//   without re-implementing the wire format.

import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

var _dbCounter = 0;

class _Fixture {
  _Fixture({required this.datastore, required this.backend});
  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  Future<void> close() => backend.close();
}

const EntryTypeDefinition _demoNoteDef = EntryTypeDefinition(
  id: 'demo_note',
  registeredVersion: 1,
  name: 'Demo Note',
  widgetId: 'w',
  widgetConfig: <String, Object?>{},
);

Future<_Fixture> _bootstrapDatastore({
  required String hopId,
  required String identifier,
  String softwareVersion = 'pkg@1.0.0',
  List<EntryTypeDefinition> entryTypes = const <EntryTypeDefinition>[],
  List<Destination> destinations = const <Destination>[],
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'ingest-passive-$_dbCounter.db',
  );
  final backend = SembastBackend(database: db);
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: hopId,
      identifier: identifier,
      softwareVersion: softwareVersion,
    ),
    entryTypes: entryTypes,
    destinations: destinations,
    materializers: const <Materializer>[],
    initialViewTargetVersions: const <String, Map<String, int>>{},
  );
  return _Fixture(datastore: datastore, backend: backend);
}

/// Minimal Destination test double sufficient for `addDestination` and
/// for FIFO promotion via `fillBatch`. Not exported from lib because
/// `FakeDestination` (under test/test_support) ships its own SendResult
/// scripting and we do not need that machinery here — the FIFO is
/// populated by `fillBatch` and never drained.
class _NoopDestination extends Destination {
  _NoopDestination({required this.id});
  @override
  final String id;
  @override
  final String wireFormat = 'noop-v1';
  @override
  final SubscriptionFilter filter = const SubscriptionFilter();
  @override
  final Duration maxAccumulateTime = Duration.zero;
  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.isEmpty;
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    if (batch.isEmpty) {
      throw ArgumentError('_NoopDestination($id).transform: empty batch');
    }
    final json = jsonEncode(<String, Object?>{
      'event_ids': batch.map((e) => e.eventId).toList(),
    });
    return Future<WirePayload>.value(
      WirePayload(
        bytes: Uint8List.fromList(utf8.encode(json)),
        contentType: 'application/json',
        transformVersion: 'noop-v1',
      ),
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    throw StateError(
      '_NoopDestination($id).send: tests must not drain this FIFO; '
      'the rows exist for a passivity comparison only.',
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventStore ingest path — receiver-stays-passive invariant '
      '(REQ-d00154-E, REQ-d00129-O)', () {
    // Verifies: REQ-d00154-E, REQ-d00129-O — ingesting a bridged
    //   `system.destination_registered` audit MUST NOT add a destination
    //   to the receiver's `DestinationRegistry`. The destination listed
    //   in the audit's `data.id` is the originator's destination, not
    //   the receiver's; configuration on the receiver remains driven by
    //   its own local `addDestination` calls. The audit MUST still be
    //   stored in the receiver's `event_log` (REQ-d00154-F admission +
    //   ingest-path write).
    test('REQ-d00154-E: ingesting system.destination_registered does NOT '
        'mutate DestinationRegistry on the receiver', () async {
      final originator = await _bootstrapDatastore(
        hopId: 'mobile-device',
        identifier: 'install-mobile',
        destinations: <Destination>[_NoopDestination(id: 'OriginatorPrimary')],
      );
      final receiver = await _bootstrapDatastore(
        hopId: 'portal-server',
        identifier: 'install-portal',
        destinations: <Destination>[_NoopDestination(id: 'ReceiverPrimary')],
      );

      try {
        // Snapshot receiver's destination registry pre-ingest.
        final preDestIds =
            receiver.datastore.destinations.all().map((d) => d.id).toList()
              ..sort();
        expect(
          preDestIds,
          equals(<String>['ReceiverPrimary']),
          reason: 'sanity: receiver was bootstrapped with one destination',
        );

        // Trigger originator to emit a fresh `destination_registered`
        // audit by adding a second destination locally.
        await originator.datastore.destinations.addDestination(
          _NoopDestination(id: 'OriginatorSecondary'),
          initiator: const AutomationInitiator(service: 'test'),
        );

        // Read the just-emitted audit off originator's event log.
        final originatorEvents = await originator.backend.findAllEvents();
        final auditEvent = originatorEvents.firstWhere(
          (e) =>
              e.entryType == kDestinationRegisteredEntryType &&
              e.data['id'] == 'OriginatorSecondary',
          orElse: () => throw StateError(
            'originator did not emit a destination_registered audit '
            'with data.id="OriginatorSecondary"',
          ),
        );

        // Ingest the bridged audit at the receiver. ingestEvent goes
        // through the same `_ingestOneInTxn` code path as ingestBatch,
        // so the invariant tested here covers both ingest entry points
        // (single-event and batch).
        final outcome = await receiver.datastore.eventStore.ingestEvent(
          auditEvent,
        );
        expect(outcome.outcome, equals(IngestOutcome.ingested));

        // INVARIANT: receiver's destination registry is byte-identical.
        final postDestIds =
            receiver.datastore.destinations.all().map((d) => d.id).toList()
              ..sort();
        expect(
          postDestIds,
          equals(preDestIds),
          reason:
              'receiver DestinationRegistry MUST NOT be mutated by an '
              'ingested system.destination_registered audit '
              '(REQ-d00154-E, REQ-d00129-O)',
        );
        expect(
          receiver.datastore.destinations.byId('OriginatorSecondary'),
          isNull,
          reason:
              'an originator destination id (data.id="OriginatorSecondary") '
              'MUST NOT appear in the receiver registry just because the '
              'receiver ingested the audit (REQ-d00154-E)',
        );

        // The audit IS stored in the receiver's event_log.
        final receiverEvents = await receiver.backend.findAllEvents();
        final stored = receiverEvents
            .where(
              (e) =>
                  e.entryType == kDestinationRegisteredEntryType &&
                  e.data['id'] == 'OriginatorSecondary',
            )
            .toList();
        expect(
          stored,
          hasLength(1),
          reason:
              'bridged audit MUST be stored in the receiver event_log '
              'for cross-hop observability (REQ-d00154-F admission)',
        );
      } finally {
        await originator.close();
        await receiver.close();
      }
    });

    // Verifies: REQ-d00154-E, REQ-d00129-O — ingesting a bridged
    //   `system.entry_type_registry_initialized` audit MUST NOT mutate
    //   the receiver's `EntryTypeRegistry`. The originator's registry
    //   shape (encoded inside the audit's `data.registry` map) is the
    //   originator's runtime contract, not the receiver's; the
    //   receiver's registry remains exactly the set of types its own
    //   `bootstrapAppendOnlyDatastore` call registered.
    test('REQ-d00154-E: ingesting system.entry_type_registry_initialized '
        'does NOT mutate EntryTypeRegistry on the receiver', () async {
      // Originator bootstraps with one user entry type registered;
      // receiver bootstraps with NO user entry types. After the
      // originator's bootstrap, its event_log holds an
      // `entry_type_registry_initialized` audit naming `demo_note`.
      // That audit, when ingested by the receiver, must NOT cause
      // `demo_note` to register on the receiver.
      final originator = await _bootstrapDatastore(
        hopId: 'mobile-device',
        identifier: 'install-mobile',
        entryTypes: const <EntryTypeDefinition>[_demoNoteDef],
      );
      final receiver = await _bootstrapDatastore(
        hopId: 'portal-server',
        identifier: 'install-portal',
      );

      try {
        // Snapshot receiver's entry-type registry pre-ingest. The set
        // is exactly the 10 reserved system entry types
        // auto-registered by bootstrap.
        final preIds = receiver.datastore.entryTypes
            .all()
            .map((d) => d.id)
            .toSet();
        expect(
          preIds.contains('demo_note'),
          isFalse,
          reason:
              'sanity: receiver did NOT register demo_note (it was '
              'registered on the originator only)',
        );
        expect(
          preIds.length,
          equals(kReservedSystemEntryTypeIds.length),
          reason:
              'sanity: receiver registry contains exactly the 10 '
              'reserved system entry types pre-ingest',
        );

        // Read originator's bootstrap-emitted audit.
        final originatorEvents = await originator.backend.findAllEvents();
        final auditEvent = originatorEvents.firstWhere(
          (e) => e.entryType == kEntryTypeRegistryInitializedEntryType,
          orElse: () => throw StateError(
            'originator did not emit an entry_type_registry_initialized '
            'audit at bootstrap',
          ),
        );
        // Sanity: the audit's data.registry includes demo_note.
        final auditRegistry = Map<String, Object?>.from(
          auditEvent.data['registry'] as Map,
        );
        expect(
          auditRegistry.containsKey('demo_note'),
          isTrue,
          reason:
              'sanity: audit payload should reference originator-side '
              'demo_note registration',
        );

        // Ingest the bridged registry-init audit on the receiver.
        final outcome = await receiver.datastore.eventStore.ingestEvent(
          auditEvent,
        );
        expect(outcome.outcome, equals(IngestOutcome.ingested));

        // INVARIANT: receiver's entry-type registry is byte-identical.
        final postIds = receiver.datastore.entryTypes
            .all()
            .map((d) => d.id)
            .toSet();
        expect(
          postIds,
          equals(preIds),
          reason:
              'receiver EntryTypeRegistry MUST NOT be mutated by an '
              'ingested system.entry_type_registry_initialized audit '
              '(REQ-d00154-E, REQ-d00129-O)',
        );
        expect(
          receiver.datastore.entryTypes.byId('demo_note'),
          isNull,
          reason:
              'demo_note (an originator-only entry type) MUST NOT '
              'appear in the receiver registry just because the '
              'receiver ingested the registry-init audit (REQ-d00154-E)',
        );

        // The audit IS stored in the receiver's event_log.
        final receiverEvents = await receiver.backend.findAllEvents();
        final stored = receiverEvents
            .where(
              (e) =>
                  e.entryType == kEntryTypeRegistryInitializedEntryType &&
                  e.aggregateId == 'install-mobile',
            )
            .toList();
        expect(
          stored,
          hasLength(1),
          reason:
              'bridged registry-init audit MUST be stored in the '
              'receiver event_log under the originator install '
              'aggregate (REQ-d00154-F admission)',
        );
      } finally {
        await originator.close();
        await receiver.close();
      }
    });

    // Verifies: REQ-d00154-E, REQ-d00129-O — ingesting a bridged
    //   `system.destination_wedge_recovered` audit MUST NOT touch the
    //   receiver's per-destination FIFO state. The wedge recovery the
    //   audit describes happened on the originator's FIFO; the
    //   receiver's FIFOs are private state driven by its own
    //   `fillBatch` / `tombstoneAndRefill` calls. A snapshot of every
    //   receiver FIFO pre-ingest equals the same snapshot post-ingest.
    test('REQ-d00154-E: ingesting system.destination_wedge_recovered '
        'does NOT mutate FIFO state on the receiver', () async {
      // Originator: one destination so `tombstoneAndRefill` has a
      // FIFO row to operate on. The originator's bootstrap also
      // emits its own destination_registered audit which we ignore.
      final originator = await _bootstrapDatastore(
        hopId: 'mobile-device',
        identifier: 'install-mobile',
        entryTypes: const <EntryTypeDefinition>[_demoNoteDef],
        destinations: <Destination>[_NoopDestination(id: 'orig-dest')],
      );
      final receiver = await _bootstrapDatastore(
        hopId: 'portal-server',
        identifier: 'install-portal',
        destinations: <Destination>[_NoopDestination(id: 'recv-dest')],
      );

      try {
        // Set up a head FIFO row on the originator so
        // tombstoneAndRefill has something to wedge-recover. Schedule
        // the originator destination live and append one user event,
        // then run fillBatch to enqueue it.
        await originator.datastore.destinations.setStartDate(
          'orig-dest',
          DateTime.utc(2020, 1, 1),
          initiator: const AutomationInitiator(service: 'test'),
        );
        await originator.datastore.eventStore.append(
          entryType: 'demo_note',
          entryTypeVersion: 1,
          aggregateId: 'agg-orig-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{
            'answers': <String, Object?>{'k': 'v'},
          },
          initiator: const UserInitiator('u-orig'),
        );
        final origDest = originator.datastore.destinations.byId('orig-dest')!;
        final origSchedule = await originator.datastore.destinations.scheduleOf(
          'orig-dest',
        );
        await fillBatch(
          origDest,
          backend: originator.backend,
          schedule: origSchedule,
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'install-mobile',
            softwareVersion: 'pkg@1.0.0',
          ),
          clock: () => DateTime.now().toUtc().add(const Duration(days: 1)),
        );
        final origFifo = await originator.backend.listFifoEntries('orig-dest');
        expect(
          origFifo,
          isNotEmpty,
          reason: 'sanity: originator should have a FIFO head to recover',
        );
        final origHeadRowId = origFifo.first.entryId;

        // Snapshot every receiver-FIFO pre-ingest. The receiver only
        // has one destination ('recv-dest') so the snapshot is small.
        final preReceiverFifo = await receiver.backend.listFifoEntries(
          'recv-dest',
        );

        // Trigger originator's wedge recovery — emits a real
        // `system.destination_wedge_recovered` audit naming
        // 'orig-dest'.
        await originator.datastore.destinations.tombstoneAndRefill(
          'orig-dest',
          origHeadRowId,
          initiator: const AutomationInitiator(service: 'test'),
        );

        // Read the just-emitted wedge-recovery audit off the
        // originator's event log.
        final originatorEvents = await originator.backend.findAllEvents();
        final auditEvent = originatorEvents.firstWhere(
          (e) =>
              e.entryType == kDestinationWedgeRecoveredEntryType &&
              e.data['id'] == 'orig-dest',
          orElse: () => throw StateError(
            'originator did not emit a destination_wedge_recovered '
            'audit with data.id="orig-dest"',
          ),
        );

        // Ingest at receiver.
        final outcome = await receiver.datastore.eventStore.ingestEvent(
          auditEvent,
        );
        expect(outcome.outcome, equals(IngestOutcome.ingested));

        // INVARIANT: receiver's FIFO is byte-identical pre vs post
        // ingest. Compare entryId + sequenceInQueue + final status to
        // catch row insertion, deletion, status flip, or re-ordering.
        final postReceiverFifo = await receiver.backend.listFifoEntries(
          'recv-dest',
        );
        expect(
          postReceiverFifo.length,
          equals(preReceiverFifo.length),
          reason:
              'receiver FIFO row count MUST NOT change on ingest of a '
              'bridged wedge-recovery audit (REQ-d00154-E, '
              'REQ-d00129-O)',
        );
        for (var i = 0; i < preReceiverFifo.length; i++) {
          expect(
            postReceiverFifo[i].entryId,
            equals(preReceiverFifo[i].entryId),
            reason: 'FIFO entryId at index $i must be unchanged',
          );
          expect(
            postReceiverFifo[i].sequenceInQueue,
            equals(preReceiverFifo[i].sequenceInQueue),
            reason: 'FIFO sequenceInQueue at index $i must be unchanged',
          );
          expect(
            postReceiverFifo[i].finalStatus,
            equals(preReceiverFifo[i].finalStatus),
            reason: 'FIFO finalStatus at index $i must be unchanged',
          );
        }

        // Sanity: an originator-side fifoRowId MUST NOT exist on the
        // receiver's FIFO. (Bridged wedge audits name originator
        // FIFO row ids in `data.target_row_id` — this id is
        // originator-private and has no meaning on the receiver.)
        final auditTargetRowId = auditEvent.data['target_row_id'];
        for (final row in postReceiverFifo) {
          expect(
            row.entryId,
            isNot(equals(auditTargetRowId)),
            reason:
                'an originator FIFO row id (data.target_row_id) MUST '
                'NOT appear in the receiver FIFO just because the '
                'receiver ingested the audit (REQ-d00154-E)',
          );
        }

        // Sanity: the receiver does not learn about 'orig-dest' as a
        // local destination just because it ingested the audit.
        expect(
          receiver.datastore.destinations.byId('orig-dest'),
          isNull,
          reason:
              'wedge-recovery audit naming an originator destination '
              'MUST NOT register that destination on the receiver '
              '(REQ-d00154-E, REQ-d00129-O)',
        );

        // The audit IS stored in the receiver's event_log.
        final receiverEvents = await receiver.backend.findAllEvents();
        final stored = receiverEvents
            .where(
              (e) =>
                  e.entryType == kDestinationWedgeRecoveredEntryType &&
                  e.data['id'] == 'orig-dest',
            )
            .toList();
        expect(
          stored,
          hasLength(1),
          reason:
              'bridged wedge-recovery audit MUST be stored in the '
              'receiver event_log (REQ-d00154-F admission)',
        );
      } finally {
        await originator.close();
        await receiver.close();
      }
    });
  });
}
