import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/synthetic_ingest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<AppendOnlyDatastore> _bootstrapPortal(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  final backend = SembastBackend(database: db);
  return bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'portal',
      identifier: 'demo-portal',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
    entryTypes: allDemoEntryTypes,
    destinations: const <Destination>[],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'diary_entries': <String, int>{'demo_note': 1},
    },
  );
}

WirePayload _wirePayload(Uint8List bytes) => WirePayload(
  bytes: bytes,
  contentType: BatchEnvelope.wireFormat,
  transformVersion: null,
);

void main() {
  var pathCounter = 0;
  String nextPath() => 'bridge-${++pathCounter}.db';

  group('DownstreamBridge.deliver', () {
    test('valid esd/batch@1 envelope returns SendOk', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final result = await bridge.deliver(_wirePayload(envelope.encode()));
      expect(result, isA<SendOk>());
    });

    test('garbage bytes return SendPermanent (decode failure)', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final result = await bridge.deliver(
        _wirePayload(Uint8List.fromList(<int>[0, 1, 2, 3])),
      );
      expect(result, isA<SendPermanent>());
    });

    test('unsupported wireFormat returns SendPermanent', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final payload = WirePayload(
        bytes: envelope.encode(),
        contentType: 'application/x-unknown',
        transformVersion: null,
      );
      final result = await bridge.deliver(payload);
      expect(result, isA<SendPermanent>());
    });

    test('thrown StateError maps to SendTransient', () async {
      final bridge = DownstreamBridge(_ThrowingEventStore(StateError('boom')));
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final result = await bridge.deliver(_wirePayload(envelope.encode()));
      expect(result, isA<SendTransient>());
    });

    // Verifies: REQ-d00145-L
    test(
      'REQ-d00145-L: IngestLibFormatVersionAhead -> SendPermanent',
      () async {
        final stub = _ThrowingEventStore(
          const IngestLibFormatVersionAhead(
            eventId: 'e-1',
            wireVersion: 2,
            receiverVersion: 1,
          ),
        );
        final bridge = DownstreamBridge(stub);
        final result = await bridge.deliver(
          _wirePayload(Uint8List.fromList(<int>[1])),
        );
        expect(result, isA<SendPermanent>());
      },
    );

    // Verifies: REQ-d00145-M
    test(
      'REQ-d00145-M: IngestEntryTypeVersionAhead -> SendPermanent',
      () async {
        final stub = _ThrowingEventStore(
          const IngestEntryTypeVersionAhead(
            eventId: 'e-1',
            entryType: 'demo_note',
            wireVersion: 5,
            receiverVersion: 2,
          ),
        );
        final bridge = DownstreamBridge(stub);
        final result = await bridge.deliver(
          _wirePayload(Uint8List.fromList(<int>[1])),
        );
        expect(result, isA<SendPermanent>());
      },
    );
  });
}

class _ThrowingEventStore implements EventStore {
  _ThrowingEventStore(this._toThrow);
  final Object _toThrow;
  @override
  Future<IngestBatchResult> ingestBatch(
    Uint8List bytes, {
    required String wireFormat,
  }) {
    // ignore: only_throw_errors
    throw _toThrow;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
