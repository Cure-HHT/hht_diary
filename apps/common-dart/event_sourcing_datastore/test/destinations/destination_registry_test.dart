import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _StubDestination extends Destination {
  _StubDestination(this._id, {SubscriptionFilter? filter})
    : _filter = filter ?? const SubscriptionFilter();

  final String _id;
  final SubscriptionFilter _filter;

  @override
  String get id => _id;

  @override
  SubscriptionFilter get filter => _filter;

  @override
  String get wireFormat => 'stub-v1';

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.isEmpty;

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async => WirePayload(
    bytes: Uint8List.fromList(batch.first.eventId.codeUnits),
    contentType: 'text/plain',
    transformVersion: 'stub-v1',
  );

  @override
  Future<SendResult> send(WirePayload payload) async => const SendOk();
}

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

void main() {
  group('DestinationRegistry (instance-based, REQ-d00129)', () {
    late SembastBackend backend;
    late DestinationRegistry registry;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('registry-$dbCounter.db');
      registry = DestinationRegistry(backend: backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00129-A — addDestination + all() round-trip.
    test(
      'REQ-d00129-A: addDestination adds a destination and all() returns it',
      () async {
        final d = _StubDestination('primary');
        await registry.addDestination(d);
        expect(registry.all(), contains(d));
      },
    );

    // Verifies: REQ-d00129-A — destination ids are unique; duplicate
    // addDestination throws ArgumentError.
    test(
      'REQ-d00129-A: addDestination with duplicate id throws ArgumentError',
      () async {
        await registry.addDestination(_StubDestination('primary'));
        await expectLater(
          registry.addDestination(_StubDestination('primary')),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00129-A — the registry does NOT freeze on first
    // read. Subsequent addDestination after all() succeeds.
    test('REQ-d00129-A: first all() read does NOT freeze the registry; a '
        'subsequent addDestination succeeds', () async {
      await registry.addDestination(_StubDestination('primary'));
      registry.all(); // would freeze under the Phase-4 contract
      await registry.addDestination(_StubDestination('secondary'));
      expect(registry.all().map((d) => d.id), ['primary', 'secondary']);
    });

    // all() returns an unmodifiable view so callers cannot mutate the
    // registry by mutating the returned list.
    test('all() returns an unmodifiable view', () async {
      await registry.addDestination(_StubDestination('primary'));
      final dests = registry.all();
      expect(
        () => dests.add(_StubDestination('other')),
        throwsUnsupportedError,
      );
    });

    // byId returns null for unknown ids, the destination for known ids.
    test('byId returns null for unknown ids', () async {
      expect(registry.byId('ghost'), isNull);
      final d = _StubDestination('primary');
      await registry.addDestination(d);
      expect(registry.byId('primary'), same(d));
    });
  });
}
