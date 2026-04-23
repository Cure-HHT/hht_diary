import 'dart:typed_data';

import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/subscription_filter.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

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

StoredEvent _mkEvent({
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
}) => StoredEvent(
  key: 1,
  eventId: 'ev-1',
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: entryType,
  eventType: eventType,
  sequenceNumber: 1,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  userId: 'u1',
  deviceId: 'd1',
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash',
);

void main() {
  group('DestinationRegistry', () {
    setUp(DestinationRegistry.instance.reset);

    // Verifies: REQ-d00122-G — register + all() round-trip.
    test('REQ-d00122-G: register adds a destination and all() returns it', () {
      final d = _StubDestination('primary');
      DestinationRegistry.instance.register(d);
      expect(DestinationRegistry.instance.all(), contains(d));
    });

    // Verifies: REQ-d00122-A — destination ids are unique in the registry.
    test(
      'REQ-d00122-A: registering two destinations with the same id throws',
      () {
        DestinationRegistry.instance.register(_StubDestination('primary'));
        expect(
          () => DestinationRegistry.instance.register(
            _StubDestination('primary'),
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00122-G — freeze on first all() read; post-freeze
    // register throws StateError.
    test('REQ-d00122-G: first all() read freezes the registry; subsequent '
        'register() throws', () {
      DestinationRegistry.instance.register(_StubDestination('primary'));
      // First read freezes.
      DestinationRegistry.instance.all();
      expect(
        () => DestinationRegistry.instance.register(_StubDestination('other')),
        throwsStateError,
      );
    });

    // Verifies: matchingDestinations filters by each destination's filter.
    test(
      'matchingDestinations returns only destinations whose filter matches',
      () {
        final primary = _StubDestination(
          'primary',
          filter: const SubscriptionFilter(entryTypes: ['epistaxis_event']),
        );
        final surveys = _StubDestination(
          'surveys',
          filter: const SubscriptionFilter(entryTypes: ['nose_hht_survey']),
        );
        DestinationRegistry.instance
          ..register(primary)
          ..register(surveys);

        final match = DestinationRegistry.instance.matchingDestinations(
          _mkEvent(entryType: 'epistaxis_event'),
        );
        expect(match, [primary]);

        final matchSurvey = DestinationRegistry.instance.matchingDestinations(
          _mkEvent(entryType: 'nose_hht_survey'),
        );
        expect(matchSurvey, [surveys]);
      },
    );

    // Verifies: REQ-d00122-G — first matchingDestinations read also freezes.
    test('REQ-d00122-G: matchingDestinations also freezes the registry', () {
      DestinationRegistry.instance.register(_StubDestination('primary'));
      DestinationRegistry.instance.matchingDestinations(_mkEvent());
      expect(
        () => DestinationRegistry.instance.register(_StubDestination('other')),
        throwsStateError,
      );
    });

    // The returned all() list is unmodifiable so callers cannot mutate
    // the frozen registry post-read.
    test('all() returns an unmodifiable view', () {
      DestinationRegistry.instance.register(_StubDestination('primary'));
      final dests = DestinationRegistry.instance.all();
      expect(
        () => dests.add(_StubDestination('other')),
        throwsUnsupportedError,
      );
    });

    test('matchingDestinations works on an empty registry (returns empty)', () {
      expect(
        DestinationRegistry.instance.matchingDestinations(_mkEvent()),
        isEmpty,
      );
    });

    // reset() is the test-only method; confirm it unfreezes and clears.
    test('reset() clears registrations and unfreezes', () {
      DestinationRegistry.instance.register(_StubDestination('primary'));
      DestinationRegistry.instance.all(); // freezes
      DestinationRegistry.instance.reset();
      // Register again after reset — no StateError, list contains only
      // the new registration.
      DestinationRegistry.instance.register(_StubDestination('fresh'));
      expect(DestinationRegistry.instance.all().map((d) => d.id), ['fresh']);
    });
  });
}
