import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/diagnostics/raw_snapshot.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recursively asserts no key named [key] appears anywhere in [node]
/// (walking Maps and Lists).
void expectNoKeyAnywhere(Object? node, String key) {
  if (node is Map) {
    for (final entry in node.entries) {
      expect(
        entry.key,
        isNot(equals(key)),
        reason: 'found forbidden key "$key" in appendix',
      );
      expectNoKeyAnywhere(entry.value, key);
    }
  } else if (node is List) {
    for (final e in node) {
      expectNoKeyAnywhere(e, key);
    }
  }
}

StoredEvent _event({
  required String eventId,
  required int seq,
  String? prevHash,
  Map<String, dynamic> data = const {'answer': 'secret'},
}) {
  return StoredEvent.synthetic(
    eventId: eventId,
    aggregateId: 'agg-$eventId',
    entryType: 'diary_entry',
    initiator: const UserInitiator('u1'),
    clientTimestamp: DateTime.utc(2026, 6, 4, 10, seq),
    eventHash: 'hash-$seq',
    sequenceNumber: seq,
    data: data,
    metadata: const {'phi': 'do-not-leak'},
    previousEventHash: prevHash,
  );
}

FifoEntry _wedgedHead() => FifoEntry(
  entryId: 'fe-1',
  eventIds: const ['e1'],
  sequenceRange: (firstSeq: 1, lastSeq: 1),
  sequenceInQueue: 0,
  wireFormat: 'esd/batch@1',
  transformVersion: null,
  enqueuedAt: DateTime.utc(2026, 6, 4, 9),
  attempts: [
    AttemptResult(
      attemptedAt: DateTime.utc(2026, 6, 4, 9, 5),
      outcome: 'permanent',
      errorMessage: 'boom',
      httpStatus: 500,
    ),
  ],
  finalStatus: FinalStatus.wedged,
  sentAt: null,
);

class _FakeBackend implements StorageBackend {
  _FakeBackend({this.throwOnSeqCounter = false});

  final bool throwOnSeqCounter;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');

  @override
  Future<int> readSequenceCounter() async {
    if (throwOnSeqCounter) throw StateError('seq boom');
    return 2;
  }

  @override
  Future<int> readFillCursor(String destinationId) async => 1;

  @override
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  }) async => [_wedgedHead()];

  @override
  Future<FifoEntry?> readFifoHead(String destinationId) async => _wedgedHead();

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
    String? originatorHopId,
    String? originatorIdentifier,
    String? entryType,
    DateTime? clientTimestampStart,
    DateTime? clientTimestampEnd,
  }) async => [
    _event(eventId: 'e1', seq: 1),
    _event(eventId: 'e2', seq: 2, prevHash: 'hash-1'),
  ];
}

HealthProbeContext _ctx(StorageBackend backend) => HealthProbeContext(
  backend: backend,
  destinationIds: const ['portal'],
  everLinked: true,
  linked: true,
  tokenLive: true,
  clock: ClockInfo(
    deviceNow: DateTime.utc(2026, 6, 4, 12),
    ianaZone: 'UTC',
    utcOffsetMinutes: 0,
  ),
  version: const VersionInfo(
    appVersion: '1.2.3',
    buildNumber: '42',
    platform: 'android',
    os: 'Android 14',
  ),
  deviceId: 'device-xyz',
);

void main() {
  // Verifies: DIARY-PRD-device-health-diagnostics/C — appendix is PHI-free.
  test('no "data" key appears anywhere in the appendix (recursive)', () async {
    final out = await buildRawAppendix(_ctx(_FakeBackend()));
    expectNoKeyAnywhere(out, 'data');
    expectNoKeyAnywhere(out, 'metadata');
  });

  // Verifies: DIARY-PRD-device-health-diagnostics/C — event headers only, no body.
  test('recentEventHeaders carry headers only, no data', () async {
    final out = await buildRawAppendix(_ctx(_FakeBackend()));
    final headers = out['recentEventHeaders'] as List;
    final first = headers.first as Map;
    expect(first['eventId'], 'e1');
    expect(first['entryType'], 'diary_entry');
    expect(first['sequenceNumber'], 1);
    expect(first['eventHash'], 'hash-1');
    expect(first.containsKey('previousEventHash'), isTrue);
    expect(first.containsKey('data'), isFalse);
    expect(first.containsKey('metadata'), isFalse);
  });

  // Verifies: DIARY-DEV-device-health-checks/D — destination head + attempts surfaced.
  test(
    'destinations head carries final status + attempt outcome/error',
    () async {
      final out = await buildRawAppendix(_ctx(_FakeBackend()));
      final dests = out['destinations'] as List;
      final head = (dests.first as Map)['head'] as Map;
      final attempts = head['attempts'] as List;
      final attempt = attempts.first as Map;
      expect(attempt['outcome'], 'permanent');
      expect(attempt['error'], 'boom');
      expect(attempt['httpStatus'], 500);
    },
  );

  // Verifies: DIARY-DEV-device-health-checks/D — a throwing section is isolated.
  test(
    'a throwing section becomes {error: ...} without aborting others',
    () async {
      final out = await buildRawAppendix(
        _ctx(_FakeBackend(throwOnSeqCounter: true)),
      );
      final store = out['store'] as Map;
      expect(store.containsKey('error'), isTrue);
      // Other sections still populate.
      expect(out['device'], isA<Map<String, Object?>>());
      expect((out['device'] as Map)['id'], 'device-xyz');
      expect(out['recentEventHeaders'], isA<List<Object?>>());
    },
  );
}
