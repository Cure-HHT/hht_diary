// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

import 'dart:convert';

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

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
    });

    tearDown(() {
      service.dispose();
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
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
              .hasMatch(uuid),
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
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
              .hasMatch(id),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        final date = DateTime(2024, 1, 15);
        final startTime = DateTime(2024, 1, 15, 10, 30);
        final endTime = DateTime(2024, 1, 15, 10, 45);

        final record = await service.addRecord(
          date: date,
          startTime: startTime,
          endTime: endTime,
          severity: NosebleedSeverity.dripping,
          notes: 'Test notes',
        );

        expect(record.startTime, startTime);
        expect(record.endTime, endTime);
        expect(record.severity, NosebleedSeverity.dripping);
        expect(record.notes, 'Test notes');
        expect(record.isIncomplete, false);
      });

      test('marks record as incomplete when missing required fields', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        final record = await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          // Missing endTime and severity
        );

        expect(record.isIncomplete, true);
      });

      test('saves record to local storage', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));

        final records = await service.getLocalRecords();
        expect(records.length, 1);
      });

      test('appends to existing records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        await service.addRecord(date: DateTime(2024, 1, 15, 0, 0));
        await service.addRecord(date: DateTime(2024, 1, 15, 23, 59));

        final records = await service.getRecordsForDate(DateTime(2024, 1, 15, 12, 0));

        expect(records.length, 2);
      });
    });

    group('getIncompleteRecords', () {
      test('returns only incomplete records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        // Complete record
        await service.addRecord(
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 15),
          severity: NosebleedSeverity.dripping,
        );

        // Incomplete record
        await service.addRecord(
          date: DateTime(2024, 1, 16),
          startTime: DateTime(2024, 1, 16, 10, 0),
          // Missing endTime and severity
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
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        // Records are not immediately synced in tests (no JWT token)
        final count = await service.getUnsyncedCount();

        expect(count, 2);
      });
    });

    group('clearLocalData', () {
      test('removes all local records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        await service.clearLocalData();

        final records = await service.getLocalRecords();
        expect(records, isEmpty);
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

    group('fetchRecordsFromCloud', () {
      test('fetches and merges cloud records', () async {
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
        expect(records.any((r) => r.id == 'cloud-record-1'), true);
      });

      test('does not duplicate existing records', () async {
        mockEnrollment.jwtToken = 'test-jwt-token';

        // First, add a local record
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
        );

        final localRecord = await service.addRecord(date: DateTime(2024, 1, 15));
        service.dispose();

        // Now fetch with same record ID from cloud
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('getRecords')) {
            return http.Response(
              jsonEncode({
                'records': [
                  {
                    'id': localRecord.id, // Same ID
                    'date': '2024-01-15T00:00:00.000',
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
        expect(records.length, 1); // Should not duplicate
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
}
