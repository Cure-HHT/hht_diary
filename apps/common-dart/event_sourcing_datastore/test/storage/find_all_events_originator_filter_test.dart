// IMPLEMENTS REQUIREMENTS:
//   REQ-d00154-C: StorageBackend.findAllEvents accepts originatorHopId and
//                 originatorIdentifier optional named parameters; both
//                 nullable; AND'd together when both supplied; each filters
//                 on the corresponding field of provenance[0].
//
// Convention: per-test `// Verifies: REQ-d00154-C — <prose>` annotations and
// the assertion ID `REQ-d00154-C` at the start of each test description.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// Construct a StoredEvent with a single-entry provenance chain whose
// hopId / identifier are caller-supplied. Used to seed events whose
// originator differs from the bound EventStore source — i.e., the same
// backend holds events from multiple distinct originators.
StoredEvent _eventWithOrigin({
  required String eventId,
  required int sequenceNumber,
  required String hopId,
  required String identifier,
}) => StoredEvent(
  key: 0,
  eventId: eventId,
  aggregateId: 'agg-$eventId',
  aggregateType: 'DiaryEntry',
  entryType: 'epistaxis_event',
  entryTypeVersion: 1,
  libFormatVersion: 1,
  eventType: 'finalized',
  sequenceNumber: sequenceNumber,
  data: const <String, Object?>{},
  metadata: <String, Object?>{
    'change_reason': 'initial',
    'provenance': <Map<String, Object?>>[
      <String, Object?>{
        'hop': hopId,
        'received_at': '2026-04-26T00:00:00.000Z',
        'identifier': identifier,
        'software_version': 'app@1.0.0',
      },
    ],
  },
  initiator: const UserInitiator('u1'),
  clientTimestamp: DateTime.utc(2026, 4, 26),
  eventHash: 'hash-$eventId',
);

Future<SembastBackend> _openBackend() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'find-all-events-originator-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

Future<void> _seedThreeOrigins(SembastBackend backend) async {
  // Three events with distinct provenance[0] origins:
  //   - mobile-device + install-A
  //   - mobile-device + install-B
  //   - portal-server + install-P
  await backend.transaction((txn) async {
    final s1 = await backend.nextSequenceNumber(txn);
    await backend.appendEvent(
      txn,
      _eventWithOrigin(
        eventId: 'ev-mobileA',
        sequenceNumber: s1,
        hopId: 'mobile-device',
        identifier: 'install-A',
      ),
    );
    final s2 = await backend.nextSequenceNumber(txn);
    await backend.appendEvent(
      txn,
      _eventWithOrigin(
        eventId: 'ev-mobileB',
        sequenceNumber: s2,
        hopId: 'mobile-device',
        identifier: 'install-B',
      ),
    );
    final s3 = await backend.nextSequenceNumber(txn);
    await backend.appendEvent(
      txn,
      _eventWithOrigin(
        eventId: 'ev-portalP',
        sequenceNumber: s3,
        hopId: 'portal-server',
        identifier: 'install-P',
      ),
    );
  });
}

void main() {
  // Verifies: REQ-d00154-C — originatorIdentifier alone selects the unique
  // event whose provenance[0].identifier matches.
  test(
    'REQ-d00154-C: originatorIdentifier alone — install-A returns 1 event',
    () async {
      final backend = await _openBackend();
      try {
        await _seedThreeOrigins(backend);
        final result = await backend.findAllEvents(
          originatorIdentifier: 'install-A',
        );
        expect(result.map((e) => e.eventId), <String>['ev-mobileA']);
      } finally {
        await backend.close();
      }
    },
  );

  // Verifies: REQ-d00154-C — originatorHopId alone selects every event whose
  // provenance[0].hopId matches the hop class, regardless of install.
  test(
    'REQ-d00154-C: originatorHopId alone — mobile-device returns 2 events',
    () async {
      final backend = await _openBackend();
      try {
        await _seedThreeOrigins(backend);
        final result = await backend.findAllEvents(
          originatorHopId: 'mobile-device',
        );
        expect(result.map((e) => e.eventId), <String>[
          'ev-mobileA',
          'ev-mobileB',
        ]);
      } finally {
        await backend.close();
      }
    },
  );

  // Verifies: REQ-d00154-C — both filters together apply AND semantics:
  // mobile-device + install-A selects the single matching event.
  test(
    'REQ-d00154-C: both filters AND — mobile-device + install-A returns 1',
    () async {
      final backend = await _openBackend();
      try {
        await _seedThreeOrigins(backend);
        final result = await backend.findAllEvents(
          originatorHopId: 'mobile-device',
          originatorIdentifier: 'install-A',
        );
        expect(result.map((e) => e.eventId), <String>['ev-mobileA']);
      } finally {
        await backend.close();
      }
    },
  );
}
