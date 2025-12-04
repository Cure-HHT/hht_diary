// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation
//   REQ-p00006: Offline-First Data Entry (via append_only_datastore)

import 'dart:convert';
import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NosebleedService', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService service;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('nosebleed_test_');

      // Initialize the datastore for tests with a temp path
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      await Datastore.initialize(
        config: DatastoreConfig(
          deviceId: 'test-device-id',
          userId: 'test-user-id',
          databasePath: tempDir.path,
          databaseName: 'test_events.db',
          enableEncryption: false,
        ),
      );
    });

    tearDown(() async {
      service.dispose();
      // Clean up datastore after each test
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      // Clean up temp directory
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('getDeviceUuid', () {
      test('generates UUID on first call', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final uuid = await service.getDeviceUuid();

        expect(uuid, isNotEmpty);
        // UUID v4 format check
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(uuid),
          true,
        );
      });

      test('returns same UUID on subsequent calls', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final uuid1 = await service.getDeviceUuid();
        final uuid2 = await service.getDeviceUuid();

        expect(uuid1, uuid2);
      });

      test('persists UUID across service instances', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final uuid1 = await service.getDeviceUuid();
        service.dispose();

        // Create new service instance
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final uuid2 = await service.getDeviceUuid();

        expect(uuid1, uuid2);
      });
    });

    group('generateRecordId', () {
      test('generates valid UUID', () {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final id = service.generateRecordId();

        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
          true,
        );
      });

      test('generates unique IDs', () {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final ids = <String>{};
        for (var i = 0; i < 100; i++) {
          ids.add(service.generateRecordId());
        }

        expect(ids.length, 100);
      });
    });

    group('addRecord', () {
      test('creates record with required fields', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final date = DateTime(2024, 1, 15);
        final record = await service.addRecord(date: date);

        expect(record.id, isNotEmpty);
        expect(record.date, date);
        expect(record.deviceUuid, isNotEmpty);
        expect(record.createdAt, isNotNull);
      });

      test('creates record with all optional fields', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final date = DateTime(2024, 1, 15);
        final startTime = DateTime(2024, 1, 15, 10, 30);
        final endTime = DateTime(2024, 1, 15, 10, 45);

        final record = await service.addRecord(
          date: date,
          startTime: startTime,
          endTime: endTime,
          intensity: NosebleedIntensity.dripping,
          notes: 'Test notes',
        );

        expect(record.startTime, startTime);
        expect(record.endTime, endTime);
        expect(record.intensity, NosebleedIntensity.dripping);
        expect(record.notes, 'Test notes');
        expect(record.isIncomplete, false);
      });

      test('marks record as incomplete when missing required fields', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final record = await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          // Missing endTime and intensity
        );

        expect(record.isIncomplete, true);
      });

      test('saves record to local storage', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));

        final records = await service.getLocalRecords();
        expect(records.length, 1);
      });

      test('appends to existing records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));
        await service.addRecord(date: DateTime(2024, 1, 17));

        final records = await service.getLocalRecords();
        expect(records.length, 3);
      });
    });

    group('markNoNosebleeds', () {
      test('creates no-nosebleed event', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final record = await service.markNoNosebleeds(DateTime(2024, 1, 15));

        expect(record.isNoNosebleedsEvent, true);
        expect(record.isRealEvent, false);
        expect(record.isComplete, true);
      });
    });

    group('markUnknown', () {
      test('creates unknown event', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final record = await service.markUnknown(DateTime(2024, 1, 15));

        expect(record.isUnknownEvent, true);
        expect(record.isRealEvent, false);
        expect(record.isComplete, true);
      });
    });

    group('getRecordsForDate', () {
      test('returns empty list when no records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final records = await service.getRecordsForDate(DateTime(2024, 1, 15));

        expect(records, isEmpty);
      });

      test('returns records for specific date', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 14));
        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        final records = await service.getRecordsForDate(DateTime(2024, 1, 15));

        expect(records.length, 2);
      });

      test('ignores time portion of date', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15, 0, 0));
        await service.addRecord(date: DateTime(2024, 1, 15, 23, 59));

        final records = await service.getRecordsForDate(
          DateTime(2024, 1, 15, 12, 0),
        );

        expect(records.length, 2);
      });
    });

    group('getIncompleteRecords', () {
      test('returns only incomplete records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Complete record
        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 15),
          intensity: NosebleedIntensity.dripping,
        );

        // Incomplete record
        await service.addRecord(
          date: DateTime(2024, 1, 16),
          startTime: DateTime(2024, 1, 16, 10, 0),
          // Missing endTime and intensity
        );

        // No-nosebleed event (complete)
        await service.markNoNosebleeds(DateTime(2024, 1, 17));

        final incomplete = await service.getIncompleteRecords();

        expect(incomplete.length, 1);
        expect(incomplete.first.date, DateTime(2024, 1, 16));
      });
    });

    group('getUnsyncedCount', () {
      test('returns count of records without syncedAt', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        // Records are not immediately synced in tests (no JWT token)
        final count = await service.getUnsyncedCount();

        expect(count, 2);
      });
    });

    group('clearLocalData', () {
      test('clears device UUID from preferences', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Generate a device UUID first
        final uuid1 = await service.getDeviceUuid();

        await service.clearLocalData();

        // After clearing, a new UUID should be generated
        final uuid2 = await service.getDeviceUuid();
        expect(uuid1, isNot(equals(uuid2)));
      });

      test('append-only datastore preserves records for audit trail', () async {
        // This test documents that the append-only datastore does NOT delete
        // records - this is by design for FDA 21 CFR Part 11 compliance
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        await service.clearLocalData();

        // Records are preserved in the append-only datastore
        final records = await service.getLocalRecords();
        expect(records.length, 2);
      });
    });

    group('syncAllRecords', () {
      test('sends unsynced records to server', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';
        var syncCalled = false;
        List<dynamic>? sentRecords;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            syncCalled = true;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            sentRecords = body['records'] as List<dynamic>;
            return http.Response('{"success": true}', 200);
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        // Manually trigger sync
        await service.syncAllRecords();

        expect(syncCalled, true);
        expect(sentRecords, isNotNull);
        expect(sentRecords!.length, 2);
      });

      test('does nothing when no JWT token', () async {
        mockEnrollment.jwtToken = null;
        var syncCalled = false;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            syncCalled = true;
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.syncAllRecords();

        expect(syncCalled, false);
      });

      test('does nothing when all records are synced', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';
        var syncCalled = false;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            syncCalled = true;
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // No records added
        await service.syncAllRecords();

        expect(syncCalled, false);
      });
    });

    group('updateRecord', () {
      test('creates new record with parentRecordId set', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Create original record
        final original = await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 15),
          intensity: NosebleedIntensity.spotting,
        );

        // Update it
        final updated = await service.updateRecord(
          originalRecordId: original.id,
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
          notes: 'Updated notes',
        );

        // Verify the updated record has different ID and correct parentRecordId
        expect(updated.id, isNot(equals(original.id)));
        expect(updated.parentRecordId, original.id);
        expect(updated.intensity, NosebleedIntensity.dripping);
        expect(updated.notes, 'Updated notes');
      });

      test('creates record with all update parameters', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final original = await service.addRecord(date: DateTime(2024, 1, 15));

        final updated = await service.updateRecord(
          originalRecordId: original.id,
          date: DateTime(2024, 1, 16),
          startTime: DateTime(2024, 1, 16, 14, 0),
          endTime: DateTime(2024, 1, 16, 14, 30),
          intensity: NosebleedIntensity.drippingQuickly,
          notes: 'Updated notes',
          isNoNosebleedsEvent: false,
          isUnknownEvent: false,
        );

        expect(updated.date, DateTime(2024, 1, 16));
        expect(updated.startTime, DateTime(2024, 1, 16, 14, 0));
        expect(updated.intensity, NosebleedIntensity.drippingQuickly);
      });
    });

    group('deleteRecord', () {
      test('creates deletion marker with correct fields', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Create original record
        final original = await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 15),
          intensity: NosebleedIntensity.spotting,
        );

        // Delete it
        final deletion = await service.deleteRecord(
          recordId: original.id,
          reason: 'Entered by mistake',
        );

        expect(deletion.isDeleted, true);
        expect(deletion.deleteReason, 'Entered by mistake');
        expect(deletion.parentRecordId, original.id);
        expect(deletion.id, isNotEmpty);
        expect(deletion.deviceUuid, isNotEmpty);
      });

      test('deletion record is not included in local records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Create and delete a record
        final original = await service.addRecord(date: DateTime(2024, 1, 15));

        await service.deleteRecord(
          recordId: original.id,
          reason: 'Test deletion',
        );

        // The deletion record itself should not appear (it's marked as deleted)
        final records = await service.getLocalRecords();
        // Original may still appear if materialization uses eventId (current behavior)
        // but the deletion record itself should be filtered out
        final deletedRecords = records.where((r) => r.isDeleted).toList();
        expect(deletedRecords.isEmpty, true);
      });
    });

    group('completeRecord', () {
      test('creates complete record from incomplete one', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Create incomplete record
        final incomplete = await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          // Missing endTime and intensity
        );
        expect(incomplete.isIncomplete, true);

        // Complete it
        final completed = await service.completeRecord(
          originalRecordId: incomplete.id,
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
          notes: 'Completed later',
        );

        expect(completed.isIncomplete, false);
        expect(completed.endTime, DateTime(2024, 1, 15, 10, 30));
        expect(completed.intensity, NosebleedIntensity.dripping);
        expect(completed.notes, 'Completed later');
      });
    });

    group('getRecentRecords', () {
      test('returns records from last 24 hours', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final now = DateTime.now();
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        final oneDayAgo = now.subtract(const Duration(hours: 25));

        // Record from 2 hours ago (should be included)
        await service.addRecord(
          date: twoHoursAgo,
          startTime: twoHoursAgo,
          endTime: twoHoursAgo.add(const Duration(minutes: 15)),
          intensity: NosebleedIntensity.spotting,
        );

        // Record from 25 hours ago (should not be included)
        await service.addRecord(
          date: oneDayAgo,
          startTime: oneDayAgo,
          endTime: oneDayAgo.add(const Duration(minutes: 15)),
          intensity: NosebleedIntensity.dripping,
        );

        final recent = await service.getRecentRecords();

        expect(recent.length, 1);
        expect(recent.first.intensity, NosebleedIntensity.spotting);
      });

      test('excludes records without startTime', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final now = DateTime.now();

        // Record without startTime
        await service.addRecord(date: now);

        final recent = await service.getRecentRecords();

        expect(recent.isEmpty, true);
      });

      test('sorts by startTime ascending', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final now = DateTime.now();
        final oneHourAgo = now.subtract(const Duration(hours: 1));
        final threeHoursAgo = now.subtract(const Duration(hours: 3));

        // Add in non-chronological order
        await service.addRecord(
          date: oneHourAgo,
          startTime: oneHourAgo,
          endTime: oneHourAgo.add(const Duration(minutes: 15)),
          intensity: NosebleedIntensity.dripping,
        );

        await service.addRecord(
          date: threeHoursAgo,
          startTime: threeHoursAgo,
          endTime: threeHoursAgo.add(const Duration(minutes: 15)),
          intensity: NosebleedIntensity.spotting,
        );

        final recent = await service.getRecentRecords();

        expect(recent.length, 2);
        // Should be sorted ascending by startTime
        expect(recent.first.intensity, NosebleedIntensity.spotting);
        expect(recent.last.intensity, NosebleedIntensity.dripping);
      });
    });

    group('hasRecordsForYesterday', () {
      test('returns true when records exist for yesterday', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await service.addRecord(date: yesterday);

        final hasRecords = await service.hasRecordsForYesterday();

        expect(hasRecords, true);
      });

      test('returns false when no records for yesterday', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Add record for today
        await service.addRecord(date: DateTime.now());

        final hasRecords = await service.hasRecordsForYesterday();

        expect(hasRecords, false);
      });
    });

    group('getDayStatus', () {
      test('returns notRecorded when no records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.notRecorded);
      });

      test('returns nosebleed when complete nosebleed record exists', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.nosebleed);
      });

      test('returns noNosebleed when marked as such', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.markNoNosebleeds(DateTime(2024, 1, 15));

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.noNosebleed);
      });

      test('returns unknown when marked as unknown', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.markUnknown(DateTime(2024, 1, 15));

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.unknown);
      });

      test('returns incomplete when only incomplete records exist', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          // Missing endTime and intensity
        );

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.incomplete);
      });

      test('nosebleed takes priority over other statuses', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Add incomplete record
        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 9, 0),
        );

        // Add complete nosebleed
        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        final status = await service.getDayStatus(DateTime(2024, 1, 15));

        expect(status, DayStatus.nosebleed);
      });
    });

    group('getDayStatusRange', () {
      test('returns status for each day in range', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await service.markNoNosebleeds(DateTime(2024, 1, 16));
        await service.markUnknown(DateTime(2024, 1, 17));

        final statuses = await service.getDayStatusRange(
          DateTime(2024, 1, 14),
          DateTime(2024, 1, 18),
        );

        expect(statuses[DateTime(2024, 1, 14)], DayStatus.notRecorded);
        expect(statuses[DateTime(2024, 1, 15)], DayStatus.nosebleed);
        expect(statuses[DateTime(2024, 1, 16)], DayStatus.noNosebleed);
        expect(statuses[DateTime(2024, 1, 17)], DayStatus.unknown);
        expect(statuses[DateTime(2024, 1, 18)], DayStatus.notRecorded);
      });

      test('includes end date in range', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final statuses = await service.getDayStatusRange(
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 15),
        );

        expect(statuses.length, 1);
        expect(statuses.containsKey(DateTime(2024, 1, 15)), true);
      });

      test('correctly assigns incomplete status', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Add incomplete record
        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          // Missing endTime and intensity
        );

        final statuses = await service.getDayStatusRange(
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 15),
        );

        expect(statuses[DateTime(2024, 1, 15)], DayStatus.incomplete);
      });
    });

    group('verifyDataIntegrity', () {
      test('returns true when data is intact', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        final isValid = await service.verifyDataIntegrity();

        expect(isValid, true);
      });
    });

    group('fetchRecordsFromCloud', () {
      test('fetches and stores cloud records locally', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            return http.Response(
              jsonEncode({
                'records': [
                  {
                    'id': 'cloud-record-1',
                    'date': '2024-01-20T00:00:00.000',
                    'isNoNosebleedsEvent': true,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{"success": true}', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // Add local record
        await service.addRecord(date: DateTime(2024, 1, 15));

        // Fetch from cloud
        await service.fetchRecordsFromCloud();

        final records = await service.getLocalRecords();
        expect(records.length, 2);
        // Cloud record is stored with a new eventId, but has the cloud data
        expect(records.any((r) => r.isNoNosebleedsEvent), true);
      });

      test('appends cloud records even if same date exists locally', () async {
        // Note: The append-only datastore doesn't deduplicate by record ID
        // This is expected behavior - cloud and local records are separate events
        mockEnrollment.jwtToken = 'test-jwt-token';

        // First, add a local record
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        service.dispose();

        // Now fetch a different cloud record for same date
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            return http.Response(
              jsonEncode({
                'records': [
                  {
                    'id': 'cloud-record-different-id',
                    'date': '2024-01-15T00:00:00.000',
                    'isNoNosebleedsEvent': true,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{"success": true}', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.fetchRecordsFromCloud();

        final records = await service.getLocalRecords();
        // Both records exist - append-only preserves all events
        expect(records.length, 2);
      });

      test('does nothing when no JWT token', () async {
        mockEnrollment.jwtToken = null;
        var fetchCalled = false;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            fetchCalled = true;
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.fetchRecordsFromCloud();

        expect(fetchCalled, false);
      });

      test('handles non-200 response gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            return http.Response('{"error": "Server error"}', 500);
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // Should not throw
        await service.fetchRecordsFromCloud();

        // Records should be empty (nothing fetched)
        final records = await service.getLocalRecords();
        expect(records.isEmpty, true);
      });

      test('handles network error gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // Should not throw
        await service.fetchRecordsFromCloud();
      });
    });

    group('syncAllRecords error handling', () {
      test('handles non-200 response gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            return http.Response('{"error": "Server error"}', 500);
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));

        // Should not throw
        await service.syncAllRecords();

        // Records should still be unsynced
        final count = await service.getUnsyncedCount();
        expect(count, 1);
      });

      test('handles network error gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            throw http.ClientException('Network error');
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));

        // Should not throw
        await service.syncAllRecords();
      });
    });

    group('_syncRecordToCloud error handling', () {
      test('handles sync failure gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            return http.Response('{"error": "Sync failed"}', 500);
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // Should not throw even though sync will fail
        final record = await service.addRecord(date: DateTime(2024, 1, 15));

        expect(record, isNotNull);
        expect(record.id, isNotEmpty);
      });

      test('handles network exception gracefully', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('sync')) {
            throw http.ClientException('Connection refused');
          }
          return http.Response('', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        // Should not throw
        final record = await service.addRecord(date: DateTime(2024, 1, 15));

        expect(record, isNotNull);
      });
    });

    group('fetchRecordsFromCloud with cloud records', () {
      test('fetches cloud records with all optional fields', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            return http.Response(
              jsonEncode({
                'records': [
                  {
                    'id': 'cloud-record-with-all-fields',
                    'date': '2024-01-20T00:00:00.000',
                    'startTime': '2024-01-20T10:00:00.000',
                    'endTime': '2024-01-20T10:30:00.000',
                    'intensity': 'dripping',
                    'notes': 'Cloud record notes',
                    'isNoNosebleedsEvent': false,
                    'isUnknownEvent': false,
                    'isIncomplete': false,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{"success": true}', 200);
        });

        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockClient,
        );

        await service.fetchRecordsFromCloud();

        final records = await service.getLocalRecords();
        expect(records.length, 1);
        expect(records.first.notes, 'Cloud record notes');
      });
    });
  });
}

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;

  @override
  Future<String?> getJwtToken() async => jwtToken;

  @override
  Future<bool> isEnrolled() async => jwtToken != null;

  @override
  Future<UserEnrollment?> getEnrollment() async => null;

  @override
  Future<UserEnrollment> enroll(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<void> clearEnrollment() async {}

  @override
  void dispose() {}

  @override
  Future<String?> getUserId() async => 'test-user-id';
}
