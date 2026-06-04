import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/screens/service_mode_screen.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned backend: returns just enough for the on-demand check battery and the
/// raw appendix to run. Every un-overridden method throws via [noSuchMethod] —
/// the checks must only touch what is overridden here.
class _FakeBackend implements StorageBackend {
  _FakeBackend({this.wedged = const []});

  final List<WedgedFifoSummary> wedged;
  final Map<String, int> _kv = {};

  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() async => wedged;

  @override
  Future<int> readSequenceCounter() async => 0;

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
    String? originatorHopId,
    String? originatorIdentifier,
    String? entryType,
    DateTime? clientTimestampStart,
    DateTime? clientTimestampEnd,
  }) async => const <StoredEvent>[];

  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) async {
    _kv[destinationId] = sequenceNumber;
  }

  @override
  Future<int> readFillCursor(String destinationId) async =>
      _kv[destinationId] ?? -1;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

HealthProbeContext _ctxOver(StorageBackend backend) => HealthProbeContext(
  backend: backend,
  destinationIds: const [],
  everLinked: false,
  linked: false,
  tokenLive: false,
  clock: ClockInfo(
    deviceNow: DateTime.utc(2026, 6, 4, 12),
    ianaZone: 'UTC',
    utcOffsetMinutes: 0,
  ),
  version: const VersionInfo(
    appVersion: '1.2.3',
    buildNumber: '7',
    platform: 'android',
    os: 'test',
  ),
  deviceId: 'device-abc',
);

void main() {
  group('ServiceModeScreen', () {
    // Verifies: DIARY-GUI-service-mode-entry/B — findings render with their id
    //   and a severity indication.
    testWidgets('renders the findings list with severities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceModeScreen(
            contextBuilder: () async => _ctxOver(_FakeBackend()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service Mode'), findsOneWidget);
      expect(find.text('fifo.wedged'), findsOneWidget);
      expect(find.text('store.writable'), findsOneWidget);
      expect(find.text('auth.link'), findsOneWidget);
      // A clean fake yields no blocking finding.
      expect(find.text('BLOCKING'), findsNothing);
    });

    // Verifies: DIARY-PRD-device-health-diagnostics/B — a wedged sync queue is
    //   described as a blocking condition.
    testWidgets('surfaces a wedged FIFO as BLOCKING', (tester) async {
      final backend = _FakeBackend(
        wedged: [
          WedgedFifoSummary(
            destinationId: 'diary-server',
            headEntryId: 'entry-1',
            headEventId: 'event-1',
            wedgedAt: DateTime.utc(2026, 6, 4),
            lastError: 'schema v3 unknown',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceModeScreen(
            contextBuilder: () async => _ctxOver(backend),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('fifo.wedged'), findsOneWidget);
      expect(find.text('BLOCKING'), findsWidgets);
    });

    // Verifies: DIARY-GUI-service-mode-entry/C — copy control places the export
    //   text on the clipboard.
    testWidgets('Copy puts the rendered report on the clipboard', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text'] as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ServiceModeScreen(
            contextBuilder: () async => _ctxOver(_FakeBackend()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, hasLength(1));
      expect(copied.single, contains('DEVICE HEALTH REPORT'));
      expect(copied.single, contains('fifo.wedged'));
    });

    // Verifies: DIARY-PRD-device-health-diagnostics/D — share hands the export
    //   to the device's sharing facilities.
    testWidgets('Share invokes the share callback with the report', (
      tester,
    ) async {
      String? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceModeScreen(
            contextBuilder: () async => _ctxOver(_FakeBackend()),
            onShare: (text) async => shared = text,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(shared, isNotNull);
      expect(shared, contains('DEVICE HEALTH REPORT'));
    });

    // Verifies: DIARY-PRD-device-health-diagnostics/A — the screen degrades
    //   gracefully when the probe context itself cannot be built (e.g. a dead
    //   backend), never crashing.
    testWidgets('shows an error state when the context builder throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceModeScreen(
            contextBuilder: () async => throw StateError('backend dead'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics unavailable'), findsOneWidget);
    });
  });
}
