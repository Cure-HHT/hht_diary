// End-to-end round-trip test for the native (`esd/batch@1`) FIFO row
// optimization: append events, enqueue native row through the real
// fillBatch → drain pipeline, verify storage shape (envelope_metadata
// stored, wire_payload null), then assert the destination receives
// reconstructed bytes that decode back to the same events.
//
// Verifies: REQ-d00119-B+K + REQ-d00152-B+E end-to-end on the happy
// path. Composes bootstrapAppendOnlyDatastore → EntryService.record →
// fillBatch (native branch) → SyncCycle.call → drain → native re-encode
// → Destination.send. A regression at any wire — fillBatch's envelope
// minting, on-disk shape, or drain-side reconstruction — fails this
// test even when the per-feature tests still pass individually.

import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Native `esd/batch@1` destination. Declares
/// `serializesNatively == true` so `fillBatch` builds the envelope
/// metadata from `Source` and skips [transform] entirely. `send`
/// records every payload it receives so the test can assert
/// retry-determinism and content.
// Implements: REQ-d00152-A — concrete native destination.
class _NativeBatchDestination extends Destination {
  _NativeBatchDestination({
    required this.id,
    required List<SendResult> script,
    this.batchCapacity = 5,
  }) : _script = script;

  @override
  final String id;

  final int batchCapacity;
  final List<SendResult> _script;

  /// Every send() call: the payload handed in.
  final List<WirePayload> sent = <WirePayload>[];

  @override
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  String get wireFormat => BatchEnvelope.wireFormat;

  // Implements: REQ-d00152-A — native destinations declare this true so
  // fillBatch routes through the envelope-minting branch.
  @override
  bool get serializesNatively => true;

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < batchCapacity;

  /// Native destinations do not own a transform — `fillBatch` builds the
  /// envelope from `Source` instead. Any call here is a contract
  /// violation by `fillBatch` (REQ-d00152-B).
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    throw StateError(
      '_NativeBatchDestination($id).transform invoked: fillBatch must '
      'build envelope metadata from Source instead (REQ-d00152-B)',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    if (_script.isEmpty) {
      throw StateError(
        '_NativeBatchDestination($id): send() called but script is exhausted',
      );
    }
    return _script.removeAt(0);
  }
}

void main() {
  // Verifies: REQ-d00119-B+K — full pipeline native round trip.
  test(
    'REQ-d00119-B+K: append → fillBatch → drain end-to-end on a native '
    'destination stores envelope_metadata, nulls wire_payload, and the '
    'destination receives bytes that decode back to the appended events',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'native-rt-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final backend = SembastBackend(database: db);
      addTearDown(backend.close);

      const demoNoteDefn = EntryTypeDefinition(
        id: 'demo_note',
        registeredVersion: 1,
        name: 'demo_note',
        widgetId: 'widget-demo_note',
        widgetConfig: <String, Object?>{},
      );
      final dest = _NativeBatchDestination(
        id: 'native',
        // One transient then one OK so the same row is drained twice;
        // the test asserts retry-determinism on the reconstructed bytes.
        script: <SendResult>[
          const SendTransient(error: 'HTTP 503', httpStatus: 503),
          const SendOk(),
        ],
        batchCapacity: 5,
      );

      // Step 1: bootstrap — wires type registry, destination registry,
      // security-context store, and EventStore into AppendOnlyDatastore.
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: const Source(
          hopId: 'mobile-device',
          identifier: 'device-rt',
          softwareVersion: 'clinical_diary@1.0.0+1',
        ),
        entryTypes: [demoNoteDefn],
        destinations: [dest],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );
      final typeReg = ds.entryTypes;
      final destReg = ds.destinations;

      // Step 2: schedule the destination so fillBatch will admit events.
      final startDate = DateTime.utc(2026, 4, 25, 9);
      final recordingClock = DateTime.utc(2026, 4, 25, 9, 30);
      final fillBatchClock = DateTime.utc(2026, 4, 25, 10);
      await destReg.setStartDate(
        'native',
        startDate,
        initiator: const AutomationInitiator(service: 'test-bootstrap'),
      );
      final schedule = await destReg.scheduleOf('native');

      // Step 3: append two events via EntryService.
      final svc = EntryService(
        backend: backend,
        entryTypes: typeReg,
        deviceInfo: const DeviceInfo(
          deviceId: 'device-rt',
          softwareVersion: 'clinical_diary@1.0.0+1',
          userId: 'user-rt',
        ),
        syncCycleTrigger: () async {},
        clock: () => recordingClock,
      );
      final e1 = await svc.record(
        entryType: 'demo_note',
        aggregateId: 'agg-A',
        eventType: 'finalized',
        answers: const <String, Object?>{'title': 'first'},
      );
      final e2 = await svc.record(
        entryType: 'demo_note',
        aggregateId: 'agg-B',
        eventType: 'finalized',
        answers: const <String, Object?>{'title': 'second'},
      );
      expect(e1, isNotNull);
      expect(e2, isNotNull);

      // Step 4: fillBatch pulls both events into one native FIFO row
      // (batchCapacity = 5). The native branch mints a fresh envelope
      // from `source`, so we pass the Source reachable via
      // `ds.eventStore.source`.
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        source: ds.eventStore.source,
        clock: () => fillBatchClock,
      );

      // -- (a) Storage-shape assertions: envelope_metadata stored,
      //    wire_payload null on the freshly-enqueued head row.
      final pendingHead = await backend.readFifoHead('native');
      expect(pendingHead, isNotNull);
      expect(
        pendingHead!.wirePayload,
        isNull,
        reason:
            'native enqueue MUST null wire_payload (REQ-d00119-B); the '
            'bytes are reconstructible from envelope_metadata + event_ids.',
      );
      expect(pendingHead.envelopeMetadata, isNotNull);
      expect(pendingHead.envelopeMetadata!.batchFormatVersion, '1');
      expect(
        pendingHead.envelopeMetadata!.senderHop,
        'mobile-device',
        reason: 'fillBatch stamps the envelope sender_hop from Source.hopId',
      );
      expect(pendingHead.envelopeMetadata!.senderIdentifier, 'device-rt');
      expect(pendingHead.wireFormat, BatchEnvelope.wireFormat);
      expect(pendingHead.eventIds, [e1!.eventId, e2!.eventId]);

      // -- (b) Raw on-disk shape: confirm the persisted row carries a
      //    null wire_payload field (not just absent at the typed-API
      //    layer). This catches a regression that mistakenly stored the
      //    bytes under a different key while leaving the typed reader
      //    silently happy.
      final rawStore = StoreRef<int, Map<String, Object?>>('fifo_native');
      final rawRows = await rawStore.find(backend.databaseForTesting);
      expect(rawRows, hasLength(1));
      final raw = rawRows.single.value;
      expect(
        raw['wire_payload'],
        isNull,
        reason: 'on-disk wire_payload field MUST be null on a native row',
      );
      expect(raw['envelope_metadata'], isA<Map<Object?, Object?>>());

      // Step 5: first drain attempt — the destination is scripted to
      // SendTransient, so the row stays pending and we capture the
      // bytes the destination saw.
      final sync = SyncCycle(
        backend: backend,
        registry: destReg,
        clock: () => fillBatchClock,
      );
      await sync.call();
      expect(dest.sent, hasLength(1));
      final firstBytes = dest.sent.last.bytes;
      expect(dest.sent.last.contentType, BatchEnvelope.wireFormat);

      // -- (c) The reconstructed payload decodes back to the two events
      //    we appended in step 3. Asserts the events list survived the
      //    enqueue-side strip + drain-side reconstruction round trip.
      final firstDecoded =
          jsonDecode(utf8.decode(firstBytes)) as Map<String, Object?>;
      expect(firstDecoded['batch_format_version'], '1');
      expect(firstDecoded['sender_hop'], 'mobile-device');
      final reconstructedEvents = (firstDecoded['events']! as List)
          .cast<Map<String, Object?>>();
      expect(reconstructedEvents, hasLength(2));
      expect(
        reconstructedEvents.map((m) => m['event_id']).toList(),
        equals(<String>[e1.eventId, e2.eventId]),
      );

      // Step 6: second drain — clock advanced past the zero-jitter
      // backoff window in the default policy; SendOk lands the row.
      // Capture bytes again and assert byte-for-byte equality with the
      // first attempt: native re-encode is JCS-canonical and therefore
      // retry-deterministic (REQ-d00119-K).
      final laterClock = DateTime.utc(2026, 4, 25, 14);
      final sync2 = SyncCycle(
        backend: backend,
        registry: destReg,
        clock: () => laterClock,
      );
      await sync2.call();
      expect(dest.sent, hasLength(2));
      final secondBytes = dest.sent.last.bytes;
      expect(
        secondBytes,
        firstBytes,
        reason:
            'native re-encode MUST be byte-deterministic across retries '
            '(RFC 8785 JCS) — same envelope_metadata + same event_ids '
            'resolve to the same wire bytes.',
      );

      // Step 7: post-success state — head is gone (row marked sent)
      // and no rows wedged.
      expect(await backend.readFifoHead('native'), isNull);
      expect(await backend.anyFifoWedged(), isFalse);

      // Sanity: silence the unused-import warning on Uint8List by
      // touching the type.
      expect(secondBytes, isA<Uint8List>());
    },
  );
}
