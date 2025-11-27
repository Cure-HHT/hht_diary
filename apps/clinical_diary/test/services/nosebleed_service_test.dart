// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation
//   REQ-p00006: Offline-First Data Entry

import 'dart:convert';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NosebleedService', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService service;
    late MockEventRepository mockRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      mockRepository = MockEventRepository();
      await mockRepository.initialize();
    });

    tearDown(() async {
      service.dispose();
      await mockRepository.close();
    });

    group('getDeviceUuid', () {
      test('generates UUID on first call', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
          repository: mockRepository,
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
          repository: mockRepository,
        );

        final uuid1 = await service.getDeviceUuid();
        final uuid2 = await service.getDeviceUuid();

        expect(uuid1, uuid2);
      });

      test('persists UUID across service instances', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
          repository: mockRepository,
        );

        final uuid1 = await service.getDeviceUuid();
        service.dispose();

        // Create new service instance
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('', 200)),
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));

        final records = await service.getLocalRecords();
        expect(records.length, 1);
      });

      test('appends to existing records', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
        );

        final records = await service.getRecordsForDate(DateTime(2024, 1, 15));

        expect(records, isEmpty);
      });

      test('returns records for specific date', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        // Records are not immediately synced in tests (no JWT token)
        final count = await service.getUnsyncedCount();

        expect(count, 2);
      });
    });

    group('clearLocalData', () {
      test('clears device UUID', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
          repository: mockRepository,
        );

        // Get UUID first
        final uuid1 = await service.getDeviceUuid();
        expect(uuid1, isNotEmpty);

        await service.clearLocalData();

        // New UUID should be generated after clear
        final uuid2 = await service.getDeviceUuid();
        expect(uuid2, isNot(equals(uuid1)));
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
          repository: mockRepository,
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
          repository: mockRepository,
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
          repository: mockRepository,
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
                    'createdAt': '2024-01-20T00:00:00.000',
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
          repository: mockRepository,
        );

        // Add local record
        await service.addRecord(date: DateTime(2024, 1, 15));

        // Fetch from cloud
        await service.fetchRecordsFromCloud();

        final records = await service.getLocalRecords();
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
          repository: mockRepository,
        );

        await service.fetchRecordsFromCloud();

        expect(fetchCalled, false);
      });
    });

    group('verifyDataIntegrity', () {
      test('returns true for valid chain', () async {
        service = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient((_) async => http.Response('{"success": true}', 200)),
          repository: mockRepository,
        );

        await service.addRecord(date: DateTime(2024, 1, 15));
        await service.addRecord(date: DateTime(2024, 1, 16));

        final isValid = await service.verifyDataIntegrity();
        expect(isValid, true);
      });
    });
  });
}

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? userId;

  @override
  Future<String?> getJwtToken() async => jwtToken;

  @override
  Future<String?> getUserId() async => userId;

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

/// Mock EventRepository using in-memory Sembast database for testing.
class MockEventRepository extends EventRepository {
  MockEventRepository()
      : _dbName = 'test_${DateTime.now().microsecondsSinceEpoch}.db',
        super(
          databaseProvider: _MockDatabaseProvider(),
        );

  final String _dbName;
  Database? _database;

  Future<void> initialize() async {
    _database = await databaseFactoryMemory.openDatabase(_dbName);
    _mockProvider.database = _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      await databaseFactoryMemory.deleteDatabase(_dbName);
      _database = null;
    }
  }

  _MockDatabaseProvider get _mockProvider =>
      databaseProvider as _MockDatabaseProvider;
}

/// Mock DatabaseProvider that accepts an injected database.
class _MockDatabaseProvider extends DatabaseProvider {
  _MockDatabaseProvider()
      : super(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

  Database? _database;

  set database(Database db) {
    _database = db;
  }

  @override
  Database get database {
    if (_database == null) {
      throw StateError('Test database not initialized');
    }
    return _database!;
  }

  @override
  bool get isInitialized => _database != null;

  @override
  Future<void> initialize() async {
    // Database is set externally via setDatabase()
  }

  @override
  Future<void> close() async {
    _database = null;
  }

  @override
  Future<void> deleteDatabase() async {
    _database = null;
  }
}
