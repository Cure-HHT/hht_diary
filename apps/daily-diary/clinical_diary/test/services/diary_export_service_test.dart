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

Future<({SembastBackend backend, EntryService service})> _setupFixture() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'diary-export-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry()..register(_defFor('epistaxis_event'));
  final service = EntryService(
    backend: backend,
    entryTypes: registry,
    syncCycleTrigger: () async {},
    deviceInfo: const DeviceInfo(
      deviceId: 'device-test',
      softwareVersion: 'clinical_diary@0.0.0',
      userId: 'user-test',
    ),
  );
  return (backend: backend, service: service);
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
    test('exportAll on an empty log returns an empty events list', () async {
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
      expect(result.payload['events'], isEmpty);
      expect(result.payload['exportedAt'], isA<String>());

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
      expect(events.length, 2);

      // Each event must carry an event_id, aggregate_id, entry_type, and
      // event_type (the StoredEvent.toJson contract).
      for (final raw in events) {
        final ev = raw as Map<String, Object?>;
        expect(ev['event_id'], isA<String>());
        expect(ev['aggregate_id'], isA<String>());
        expect(ev['entry_type'], 'epistaxis_event');
        expect(ev['event_type'], 'finalized');
      }
      final aggregateIds = events
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
}
