import 'package:clinical_diary/diagnostics/health_checks.dart';
import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/diagnostics/health_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

StoredEvent _event({
  required String eventId,
  required int seq,
  String? prevHash,
  String eventHash = '',
}) => StoredEvent.synthetic(
  eventId: eventId,
  aggregateId: 'agg',
  entryType: 'diary_entry',
  initiator: const UserInitiator('u1'),
  clientTimestamp: DateTime.utc(2026, 6, 4, 10, seq),
  eventHash: eventHash.isEmpty ? 'hash-$seq' : eventHash,
  sequenceNumber: seq,
  previousEventHash: prevHash,
);

WedgedFifoSummary _wedged(String dest, String err) => WedgedFifoSummary(
  destinationId: dest,
  headEntryId: 'fe',
  headEventId: 'e',
  wedgedAt: DateTime.utc(2026, 6, 4, 9),
  lastError: err,
);

/// Configurable fake implementing only the methods individual checks need.
class _FakeBackend implements StorageBackend {
  _FakeBackend({
    this.wedged = const [],
    this.seqCounter = 0,
    Map<String, int>? cursors,
    this.events = const [],
    this.throwOnWriteCursor = false,
  }) : cursors = cursors ?? {};

  final List<WedgedFifoSummary> wedged;
  final int seqCounter;
  final Map<String, int> cursors;
  final List<StoredEvent> events;
  final bool throwOnWriteCursor;
  final Map<String, int> _written = {};

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');

  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() async => wedged;

  @override
  Future<int> readSequenceCounter() async => seqCounter;

  @override
  Future<int> readFillCursor(String destinationId) async =>
      _written[destinationId] ?? cursors[destinationId] ?? -1;

  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) async {
    if (throwOnWriteCursor) throw StateError('disk full');
    _written[destinationId] = sequenceNumber;
  }

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
    String? originatorHopId,
    String? originatorIdentifier,
    String? entryType,
    DateTime? clientTimestampStart,
    DateTime? clientTimestampEnd,
  }) async => events;
}

HealthProbeContext _ctx({
  required StorageBackend backend,
  List<String> destinationIds = const ['portal'],
  bool everLinked = true,
  bool linked = true,
  bool tokenLive = true,
}) => HealthProbeContext(
  backend: backend,
  destinationIds: destinationIds,
  everLinked: everLinked,
  linked: linked,
  tokenLive: tokenLive,
  clock: ClockInfo(
    deviceNow: DateTime.utc(2026, 6, 4, 12),
    ianaZone: 'UTC',
    utcOffsetMinutes: 0,
  ),
  version: const VersionInfo(
    appVersion: '1',
    buildNumber: '1',
    platform: 'android',
    os: 'A14',
  ),
  deviceId: 'd',
);

Finding _byId(List<Finding> findings, String id) =>
    findings.firstWhere((f) => f.id == id);

void main() {
  group('fifo.wedged', () {
    // Verifies: DIARY-DEV-device-health-checks/B
    test('blocking when a FIFO is wedged', () async {
      final ctx = _ctx(
        backend: _FakeBackend(wedged: [_wedged('portal', 'boom')]),
      );
      final f = _byId(await runChecks(ctx), 'fifo.wedged');
      expect(f.severity, HealthSeverity.blocking);
      expect(f.detail, contains('portal'));
      expect(f.detail, contains('boom'));
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('ok when nothing wedged', () async {
      final f = _byId(
        await runChecks(_ctx(backend: _FakeBackend())),
        'fifo.wedged',
      );
      expect(f.severity, HealthSeverity.ok);
    });
  });

  group('fifo.backlog', () {
    // Verifies: DIARY-DEV-device-health-checks/B
    test('warn when backlog over threshold', () async {
      final ctx = _ctx(
        backend: _FakeBackend(seqCounter: 1000, cursors: {'portal': 0}),
      );
      final f = _byId(await runChecks(ctx), 'fifo.backlog');
      expect(f.severity, HealthSeverity.warn);
      expect(f.detail, contains('portal'));
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('ok pre-enrollment regardless of cursor', () async {
      final ctx = _ctx(
        backend: _FakeBackend(seqCounter: 1000, cursors: {'portal': 0}),
        everLinked: false,
      );
      final f = _byId(await runChecks(ctx), 'fifo.backlog');
      expect(f.severity, HealthSeverity.ok);
    });
  });

  group('chain.contiguity', () {
    // Verifies: DIARY-DEV-device-health-checks/B
    test('ok when chain intact', () async {
      final ctx = _ctx(
        backend: _FakeBackend(
          events: [
            _event(eventId: 'e1', seq: 1, eventHash: 'h1'),
            _event(eventId: 'e2', seq: 2, prevHash: 'h1', eventHash: 'h2'),
          ],
        ),
      );
      final f = _byId(await runChecks(ctx), 'chain.contiguity');
      expect(f.severity, HealthSeverity.ok);
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('blocking on chain break', () async {
      final ctx = _ctx(
        backend: _FakeBackend(
          events: [
            _event(eventId: 'e1', seq: 1, eventHash: 'h1'),
            _event(eventId: 'e2', seq: 2, prevHash: 'WRONG', eventHash: 'h2'),
          ],
        ),
      );
      final f = _byId(await runChecks(ctx), 'chain.contiguity');
      expect(f.severity, HealthSeverity.blocking);
      expect(f.detail, contains('2'));
    });
  });

  group('store.writable', () {
    // Verifies: DIARY-DEV-device-health-checks/B
    test('ok when probe writes and reads back', () async {
      final f = _byId(
        await runChecks(_ctx(backend: _FakeBackend())),
        'store.writable',
      );
      expect(f.severity, HealthSeverity.ok);
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('blocking when write throws', () async {
      final ctx = _ctx(backend: _FakeBackend(throwOnWriteCursor: true));
      final f = _byId(await runChecks(ctx), 'store.writable');
      expect(f.severity, HealthSeverity.blocking);
    });
  });

  group('auth.link', () {
    // Verifies: DIARY-DEV-device-health-checks/B
    test('info pre-enrollment', () async {
      final ctx = _ctx(backend: _FakeBackend(), everLinked: false);
      final f = _byId(await runChecks(ctx), 'auth.link');
      expect(f.severity, HealthSeverity.info);
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('ok when linked and token live', () async {
      final f = _byId(
        await runChecks(_ctx(backend: _FakeBackend())),
        'auth.link',
      );
      expect(f.severity, HealthSeverity.ok);
    });

    // Verifies: DIARY-DEV-device-health-checks/B
    test('warn when token expired', () async {
      final ctx = _ctx(backend: _FakeBackend(), linked: true, tokenLive: false);
      final f = _byId(await runChecks(ctx), 'auth.link');
      expect(f.severity, HealthSeverity.warn);
    });
  });

  group('runChecks', () {
    // Verifies: DIARY-DEV-device-health-checks/A
    test('returns one finding per default check', () async {
      final findings = await runChecks(_ctx(backend: _FakeBackend()));
      expect(findings.length, kDefaultChecks.length);
      expect(
        findings.map((f) => f.id).toSet(),
        kDefaultChecks.map((c) => c.id).toSet(),
      );
    });

    // Verifies: DIARY-DEV-device-health-checks/C
    test(
      'a throwing check yields a guarded warn and does not stop others',
      () async {
        final throwing = RegisteredCheck(
          'boom.check',
          (ctx) async => throw StateError('kaboom'),
        );
        final ok = RegisteredCheck(
          'fine.check',
          (ctx) async => Finding(
            id: 'fine.check',
            severity: HealthSeverity.ok,
            detail: 'fine',
            at: ctx.clock.deviceNow,
          ),
        );
        final findings = await runChecks(
          _ctx(backend: _FakeBackend()),
          checks: [throwing, ok],
        );
        expect(findings.length, 2);
        final boom = _byId(findings, 'boom.check');
        expect(boom.severity, HealthSeverity.warn);
        expect(boom.detail, contains('check errored'));
        expect(_byId(findings, 'fine.check').severity, HealthSeverity.ok);
      },
    );
  });
}
