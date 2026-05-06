// Verifies: REQ-d00004 — local audit trail can be exported as JSON.

import 'dart:convert';

import 'package:clinical_diary/services/diary_export_service.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sembast/sembast_memory.dart';

EntryTypeDefinition _defFor(String id) => EntryTypeDefinition(
  id: id,
  registeredVersion: 1,
  name: id,
  widgetId: 'widget-$id',
  widgetConfig: const <String, Object?>{},
  effectiveDatePath: null,
);

typedef _Fixture = ({
  SembastBackend backend,
  EntryService service,
  EventStore eventStore,
});

Future<_Fixture> _setupFixture({String? deviceId}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'diary-export-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: 'mobile-device',
      identifier: deviceId ?? 'device-test',
      softwareVersion: 'clinical_diary@0.0.0',
    ),
    entryTypes: const [],
    destinations: const [],
    materializers: const [DiaryEntriesMaterializer(promoter: identityPromoter)],
    initialViewTargetVersions: const {
      'diary_entries': {'epistaxis_event': 1},
    },
  );
  // Add the user-facing entry type after the bootstrap so it's available
  // to EntryService.record. (The bootstrap auto-registers system entry
  // types; user types are registered explicitly here.)
  datastore.entryTypes.register(_defFor('epistaxis_event'));
  final service = EntryService(
    backend: backend,
    entryTypes: datastore.entryTypes,
    syncCycleTrigger: () async {},
    deviceInfo: DeviceInfo(
      deviceId: deviceId ?? 'device-test',
      softwareVersion: 'clinical_diary@0.0.0',
      userId: 'user-test',
    ),
  );
  return (backend: backend, service: service, eventStore: datastore.eventStore);
}

PackageInfo _stubPackageInfo({
  String version = '1.2.3',
  String buildNumber = '42',
}) => PackageInfo(
  appName: 'Clinical Diary',
  packageName: 'org.curehht.clinical_diary',
  version: version,
  buildNumber: buildNumber,
);

void main() {
  group('DiaryExportService', () {
    test('exportAll on an empty user log dumps only the system audit event '
        'emitted by bootstrap', () async {
      final fx = await _setupFixture();
      final exporter = DiaryExportService(
        backend: fx.backend,
        deviceId: 'device-test-uuid',
        packageInfoLoader: () async => _stubPackageInfo(),
      );

      final result = await exporter.exportAll();

      expect(result.payload['exportVersion'], 2);
      expect(result.payload['deviceUuid'], 'device-test-uuid');
      expect(result.payload['appVersion'], '1.2.3+42');
      expect(result.payload['exportedAt'], isA<String>());

      // No user records were written; only the registry-initialized system
      // event from the bootstrap remains in the log.
      final events = result.payload['events'] as List;
      final userEvents = events
          .where(
            (e) => !(e as Map)['entry_type'].toString().startsWith('system.'),
          )
          .toList();
      expect(userEvents, isEmpty);

      // Payload must round-trip through json encode without throwing.
      expect(() => jsonEncode(result.payload), returnsNormally);
    });

    test('exportAll dumps every StoredEvent in the local log', () async {
      final fx = await _setupFixture();

      // Record two finalized events on distinct aggregates.
      await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'startTime': '2024-01-15T10:30:00Z'},
      );
      await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-2',
        eventType: 'finalized',
        answers: const <String, Object?>{'startTime': '2024-01-15T11:30:00Z'},
      );

      final exporter = DiaryExportService(
        backend: fx.backend,
        deviceId: 'device-test-uuid',
        packageInfoLoader: () async => _stubPackageInfo(),
      );
      final result = await exporter.exportAll();

      final events = result.payload['events'] as List;
      // Two user events plus the bootstrap-emitted system audit event.
      final userEvents = events
          .where(
            (e) => (e as Map)['entry_type'].toString() == 'epistaxis_event',
          )
          .toList();
      expect(userEvents.length, 2);

      // Each user event must carry an event_id, aggregate_id, entry_type,
      // and event_type (the StoredEvent.toJson contract).
      for (final raw in userEvents) {
        final ev = raw as Map<String, Object?>;
        expect(ev['event_id'], isA<String>());
        expect(ev['aggregate_id'], isA<String>());
        expect(ev['entry_type'], 'epistaxis_event');
        expect(ev['event_type'], 'finalized');
      }
      final aggregateIds = userEvents
          .map((e) => (e as Map)['aggregate_id'])
          .toSet();
      expect(aggregateIds, {'agg-1', 'agg-2'});

      // JSON-encodable.
      expect(() => jsonEncode(result.payload), returnsNormally);
    });

    test(
      'exportAll filename matches hht-diary-export-YYYY-MM-DD-HHMMSS.json',
      () async {
        final fx = await _setupFixture();
        final exporter = DiaryExportService(
          backend: fx.backend,
          deviceId: 'device-test-uuid',
          packageInfoLoader: () async => _stubPackageInfo(),
          clock: () => DateTime(2025, 4, 27, 14, 9, 5),
        );

        final result = await exporter.exportAll();

        expect(result.filename, 'hht-diary-export-2025-04-27-140905.json');
      },
    );

    test(
      'exportAll filename pattern matches the legacy regex even when clock is uncontrolled',
      () async {
        final fx = await _setupFixture();
        final exporter = DiaryExportService(
          backend: fx.backend,
          deviceId: 'device-test-uuid',
          packageInfoLoader: () async => _stubPackageInfo(),
        );

        final result = await exporter.exportAll();

        expect(
          RegExp(
            r'^hht-diary-export-\d{4}-\d{2}-\d{2}-\d{6}\.json$',
          ).hasMatch(result.filename),
          isTrue,
          reason: 'filename: ${result.filename}',
        );
      },
    );

    test('exportAll appVersion falls back when PackageInfo throws', () async {
      final fx = await _setupFixture();
      final exporter = DiaryExportService(
        backend: fx.backend,
        deviceId: 'device-test-uuid',
        packageInfoLoader: () async => throw StateError('no package info'),
      );

      final result = await exporter.exportAll();

      expect(result.payload['appVersion'], '0.0.0');
    });
  });

  group('DiaryExportService.importAll', () {
    test('importAll on an empty events list returns 0/0/0', () async {
      final fx = await _setupFixture();
      final importer = DiaryExportService(
        backend: fx.backend,
        deviceId: 'device-test-uuid',
        eventStore: fx.eventStore,
      );

      final payload = <String, Object?>{
        'exportVersion': 2,
        'exportedAt': '2026-04-27T10:00:00.000+00:00',
        'appVersion': '1.2.3+42',
        'deviceUuid': 'device-test-uuid',
        'events': const <Map<String, Object?>>[],
      };

      final result = await importer.importAll(payload);

      expect(result.imported, 0);
      expect(result.duplicates, 0);
      expect(result.skipped, 0);
    });

    test(
      'importAll re-imported into a backend that already ingested the '
      'export reports every event as duplicate (idempotent re-ingest)',
      () async {
        // Backend A: origin. Record events, export.
        final fxA = await _setupFixture(deviceId: 'device-A');
        await fxA.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-roundtrip-1',
          eventType: 'finalized',
          answers: const <String, Object?>{'startTime': '2024-01-15T10:30:00Z'},
        );
        await fxA.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-roundtrip-2',
          eventType: 'finalized',
          answers: const <String, Object?>{'startTime': '2024-01-15T11:30:00Z'},
        );

        final svcA = DiaryExportService(
          backend: fxA.backend,
          deviceId: 'device-A',
          eventStore: fxA.eventStore,
          packageInfoLoader: () async => _stubPackageInfo(),
        );
        final exported = await svcA.exportAll();
        final exportedEvents = exported.payload['events'] as List;

        // Backend B: fresh receiver. First import ingests every event.
        final fxB = await _setupFixture(deviceId: 'device-B');
        final svcB = DiaryExportService(
          backend: fxB.backend,
          deviceId: 'device-B',
          eventStore: fxB.eventStore,
          packageInfoLoader: () async => _stubPackageInfo(),
        );
        final firstResult = await svcB.importAll(exported.payload);
        expect(firstResult.imported, exportedEvents.length);
        expect(firstResult.duplicates, 0);
        expect(firstResult.skipped, 0);

        final eventsAfterFirstImport =
            (await fxB.backend.findAllEvents()).length;

        // Second import of the same payload into the same backend: every
        // event matches by event_id and the recorded arrival_hash, so the
        // EventStore reports each as a duplicate and the log size is
        // unchanged (modulo audit-trail "duplicate_received" entries the
        // library emits separately, which inflate the event log but do not
        // count toward this importer's tally).
        final secondResult = await svcB.importAll(exported.payload);

        expect(secondResult.imported, 0);
        expect(secondResult.duplicates, exportedEvents.length);
        expect(secondResult.skipped, 0);

        // Every imported event_id is still represented in backend B.
        final ingestedIds = exportedEvents
            .map((e) => (e as Map)['event_id'])
            .toSet();
        final eventsB = await fxB.backend.findAllEvents();
        for (final id in ingestedIds) {
          expect(
            eventsB.any((e) => e.eventId == id),
            isTrue,
            reason:
                'Backend B is missing imported event $id after '
                'idempotent re-import.',
          );
        }
        // Log can only grow (duplicate_received audit trail) — never shrink.
        expect(
          (await fxB.backend.findAllEvents()).length,
          greaterThanOrEqualTo(eventsAfterFirstImport),
        );
      },
    );

    test('importAll into a fresh backend ingests every event as new and the '
        'events appear in the destination backend', () async {
      // Backend A: record events, then export.
      final fxA = await _setupFixture(deviceId: 'device-A');
      await fxA.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-A-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'startTime': '2024-02-01T08:00:00Z'},
      );
      await fxA.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-A-2',
        eventType: 'finalized',
        answers: const <String, Object?>{'startTime': '2024-02-01T09:00:00Z'},
      );

      final svcA = DiaryExportService(
        backend: fxA.backend,
        deviceId: 'device-A',
        eventStore: fxA.eventStore,
        packageInfoLoader: () async => _stubPackageInfo(),
      );
      final exported = await svcA.exportAll();
      final exportedEvents = exported.payload['events'] as List;

      // Backend B: empty, distinct database.
      final fxB = await _setupFixture(deviceId: 'device-B');
      final svcB = DiaryExportService(
        backend: fxB.backend,
        deviceId: 'device-B',
        eventStore: fxB.eventStore,
        packageInfoLoader: () async => _stubPackageInfo(),
      );

      final result = await svcB.importAll(exported.payload);

      expect(result.imported, exportedEvents.length);
      expect(result.duplicates, 0);
      expect(result.skipped, 0);

      // The backend B event log now contains every imported event_id.
      final eventsB = await fxB.backend.findAllEvents();
      final ingestedIds = exportedEvents
          .map((e) => (e as Map)['event_id'])
          .toSet();
      for (final id in ingestedIds) {
        expect(
          eventsB.any((e) => e.eventId == id),
          isTrue,
          reason: 'Backend B is missing imported event $id',
        );
      }
    });

    test(
      'importAll with unsupported exportVersion throws FormatException',
      () async {
        final fx = await _setupFixture();
        final importer = DiaryExportService(
          backend: fx.backend,
          deviceId: 'device-test-uuid',
          eventStore: fx.eventStore,
        );

        final payload = <String, Object?>{
          'exportVersion': 99,
          'events': const <Map<String, Object?>>[],
        };

        expect(
          () => importer.importAll(payload),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('importAll skips a malformed event (missing event_id) and continues '
        'processing the rest', () async {
      final fxA = await _setupFixture(deviceId: 'device-A');
      await fxA.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-good',
        eventType: 'finalized',
        answers: const <String, Object?>{'startTime': '2024-03-01T08:00:00Z'},
      );
      final svcA = DiaryExportService(
        backend: fxA.backend,
        deviceId: 'device-A',
        eventStore: fxA.eventStore,
        packageInfoLoader: () async => _stubPackageInfo(),
      );
      final exported = await svcA.exportAll();
      final goodEvents = exported.payload['events'] as List;
      // Sanity check: pre-condition the test relies on.
      expect(goodEvents, isNotEmpty);

      // Insert one bad row at the front: a map missing `event_id` (and so
      // unparseable by StoredEvent.fromMap). The remainder of the events
      // should still ingest.
      final mixedEvents = <Object?>[
        <String, Object?>{'no_event_id_here': true},
        ...goodEvents,
      ];
      final payload = <String, Object?>{
        ...exported.payload,
        'events': mixedEvents,
      };

      final fxB = await _setupFixture(deviceId: 'device-B');
      final svcB = DiaryExportService(
        backend: fxB.backend,
        deviceId: 'device-B',
        eventStore: fxB.eventStore,
        packageInfoLoader: () async => _stubPackageInfo(),
      );

      final result = await svcB.importAll(payload);

      expect(result.skipped, 1);
      expect(result.imported, goodEvents.length);
      expect(result.duplicates, 0);
    });
  });
}
