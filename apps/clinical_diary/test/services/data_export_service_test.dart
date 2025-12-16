// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:convert';
import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/models/app_state_export.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/data_export_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('DataExportService', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late FeatureFlagService featureFlagService;
    late DataExportService exportService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();
      featureFlagService = FeatureFlagService.instance;

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('export_test_');

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

      nosebleedService = NosebleedService(
        enrollmentService: mockEnrollment,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      exportService = DataExportService(
        nosebleedService: nosebleedService,
        preferencesService: preferencesService,
        enrollmentService: mockEnrollment,
        featureFlagService: featureFlagService,
      );
    });

    tearDown(() async {
      nosebleedService.dispose();
      // Clean up datastore after each test
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      // Clean up temp directory
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('exportAppState', () {
      test('exports valid JSON with all required fields', () async {
        final jsonString = await exportService.exportAppState();

        // Should be valid JSON
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        // Check required top-level fields
        expect(json['exportVersion'], isA<int>());
        expect(json['exportedAt'], isA<String>());
        expect(json['appVersion'], isA<String>());
        expect(json['deviceUuid'], isA<String>());
        expect(json['featureFlags'], isA<Map<String, dynamic>>());
        expect(json['userPreferences'], isA<Map<String, dynamic>>());
        expect(json['timezone'], isA<Map<String, dynamic>>());
        expect(json['nosebleedRecords'], isA<List<dynamic>>());
      });

      test('exports current export version', () async {
        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        expect(json['exportVersion'], AppStateExport.currentExportVersion);
      });

      test('exports device UUID', () async {
        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        expect(json['deviceUuid'], isNotEmpty);
        // UUID v4 format check
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(json['deviceUuid'] as String),
          true,
        );
      });

      test('exports user preferences', () async {
        // Set some preferences first
        await preferencesService.savePreferences(
          const UserPreferences(
            isDarkMode: true,
            largerTextAndControls: true,
            useAnimation: false,
            compactView: true,
            languageCode: 'es',
            selectedFont: 'OpenDyslexic',
          ),
        );

        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final prefs = json['userPreferences'] as Map<String, dynamic>;

        expect(prefs['isDarkMode'], true);
        expect(prefs['largerTextAndControls'], true);
        expect(prefs['useAnimation'], false);
        expect(prefs['compactView'], true);
        expect(prefs['languageCode'], 'es');
        expect(prefs['selectedFont'], 'OpenDyslexic');
      });

      test('exports timezone information', () async {
        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final tz = json['timezone'] as Map<String, dynamic>;

        expect(tz['name'], isA<String>());
        expect(tz['offsetHours'], isA<int>());
        expect(tz['offsetMinutes'], isA<int>());
      });

      test('exports feature flags', () async {
        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final flags = json['featureFlags'] as Map<String, dynamic>;

        expect(flags['useReviewScreen'], isA<bool>());
        expect(flags['useAnimations'], isA<bool>());
        expect(flags['requireOldEntryJustification'], isA<bool>());
        expect(flags['enableShortDurationConfirmation'], isA<bool>());
        expect(flags['enableLongDurationConfirmation'], isA<bool>());
        expect(flags['longDurationThresholdMinutes'], isA<int>());
        expect(flags['availableFonts'], isA<List<dynamic>>());
      });

      test('exports nosebleed records when present', () async {
        // Add a nosebleed record first
        await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 30),
        );

        final jsonString = await exportService.exportAppState();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final records = json['nosebleedRecords'] as List<dynamic>;

        expect(records, hasLength(1));
        final record = records[0] as Map<String, dynamic>;
        expect(record['startTime'], contains('2024-01-15'));
      });
    });

    group('importAppState', () {
      test('imports valid JSON and restores preferences', () async {
        // Create export JSON with specific preferences
        final exportJson = {
          'exportVersion': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.0.0',
          'deviceUuid': 'test-device-uuid',
          'featureFlags': {
            'sponsorId': null,
            'useReviewScreen': true,
            'useAnimations': false,
            'requireOldEntryJustification': true,
            'enableShortDurationConfirmation': true,
            'enableLongDurationConfirmation': true,
            'longDurationThresholdMinutes': 90,
            'useOnePageRecordingScreen': false,
            'availableFonts': ['Roboto', 'OpenDyslexic'],
          },
          'userPreferences': {
            'isDarkMode': true,
            'largerTextAndControls': true,
            'useAnimation': false,
            'compactView': true,
            'languageCode': 'fr',
            'selectedFont': 'OpenDyslexic',
          },
          'timezone': {'name': 'PST', 'offsetHours': -8, 'offsetMinutes': 0},
          'nosebleedRecords': <Map<String, dynamic>>[],
        };

        final result = await exportService.importAppState(
          jsonEncode(exportJson),
        );

        expect(result.success, true);
        expect(result.recordsImported, 0);

        // Verify preferences were restored
        final prefs = await preferencesService.getPreferences();
        expect(prefs.isDarkMode, true);
        expect(prefs.largerTextAndControls, true);
        expect(prefs.useAnimation, false);
        expect(prefs.compactView, true);
        expect(prefs.languageCode, 'fr');
        expect(prefs.selectedFont, 'OpenDyslexic');
      });

      test('returns failure for invalid JSON', () async {
        final result = await exportService.importAppState('not valid json');

        expect(result.success, false);
        expect(result.error, contains('Invalid JSON format'));
      });

      test('returns failure for missing export version', () async {
        final result = await exportService.importAppState('{}');

        expect(result.success, false);
        expect(result.error, contains('Missing export version'));
      });

      test('returns failure for unsupported export version', () async {
        final exportJson = {'exportVersion': 999};

        final result = await exportService.importAppState(
          jsonEncode(exportJson),
        );

        expect(result.success, false);
        expect(result.error, contains('newer than supported'));
      });
    });

    group('generateExportFilename', () {
      test('generates filename with correct format', () {
        final filename = exportService.generateExportFilename();

        expect(filename, startsWith('hht-diary-export-'));
        expect(filename, endsWith('.json'));
        // Should contain date pattern
        expect(
          RegExp(
            r'hht-diary-export-\d{4}-\d{2}-\d{2}-\d{6}\.json',
          ).hasMatch(filename),
          true,
        );
      });
    });

    group('import/export round-trip', () {
      test('imports nosebleed records correctly', () async {
        // Create export JSON with a nosebleed record
        final exportJson = {
          'exportVersion': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.0.0',
          'deviceUuid': 'test-device-uuid',
          'featureFlags': {
            'sponsorId': null,
            'useReviewScreen': false,
            'useAnimations': true,
            'requireOldEntryJustification': false,
            'enableShortDurationConfirmation': false,
            'enableLongDurationConfirmation': false,
            'longDurationThresholdMinutes': 60,
            'useOnePageRecordingScreen': false,
            'availableFonts': ['Roboto'],
          },
          'userPreferences': {
            'isDarkMode': false,
            'largerTextAndControls': false,
            'useAnimation': true,
            'compactView': false,
            'languageCode': 'en',
            'selectedFont': 'Roboto',
          },
          'timezone': {'name': 'UTC', 'offsetHours': 0, 'offsetMinutes': 0},
          'nosebleedRecords': [
            {
              'id': 'test-record-001',
              'startTime': '2025-01-15T10:30:00.000',
              'endTime': '2025-01-15T10:45:00.000',
              'intensity': 'dripping',
              'notes': 'Test note',
              'isNoNosebleedsEvent': false,
              'isUnknownEvent': false,
              'isIncomplete': false,
              'isDeleted': false,
              'deleteReason': null,
              'parentRecordId': null,
              'deviceUuid': 'source-device-uuid',
              'createdAt': '2025-01-15T10:30:00.000',
              'syncedAt': null,
            },
          ],
        };

        final result = await exportService.importAppState(
          jsonEncode(exportJson),
        );

        expect(result.success, true);
        expect(result.recordsImported, 1);

        // Verify the record was actually imported
        final records = await nosebleedService.getAllLocalRecords();
        expect(records, hasLength(1));
        expect(records.first.id, 'test-record-001');
      });

      test('skips duplicate records on re-import', () async {
        // First, add a record directly
        await nosebleedService.addRecord(
          startTime: DateTime(2024, 2, 20, 14, 0),
          endTime: DateTime(2024, 2, 20, 14, 15),
        );

        // Get the record ID
        final existingRecords = await nosebleedService.getAllLocalRecords();
        expect(existingRecords, hasLength(1));
        final existingId = existingRecords.first.id;

        // Create export JSON with the same record ID
        final exportJson = {
          'exportVersion': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.0.0',
          'deviceUuid': 'test-device-uuid',
          'featureFlags': {
            'sponsorId': null,
            'useReviewScreen': false,
            'useAnimations': true,
            'requireOldEntryJustification': false,
            'enableShortDurationConfirmation': false,
            'enableLongDurationConfirmation': false,
            'longDurationThresholdMinutes': 60,
            'useOnePageRecordingScreen': false,
            'availableFonts': ['Roboto'],
          },
          'userPreferences': {
            'isDarkMode': false,
            'largerTextAndControls': false,
            'useAnimation': true,
            'compactView': false,
            'languageCode': 'en',
            'selectedFont': 'Roboto',
          },
          'timezone': {'name': 'UTC', 'offsetHours': 0, 'offsetMinutes': 0},
          'nosebleedRecords': [
            {
              'id': existingId,
              'startTime': '2024-02-20T14:00:00.000',
              'endTime': '2024-02-20T14:15:00.000',
              'intensity': 'dripping',
              'notes': null,
              'isNoNosebleedsEvent': false,
              'isUnknownEvent': false,
              'isIncomplete': false,
              'isDeleted': false,
              'deleteReason': null,
              'parentRecordId': null,
              'deviceUuid': 'test-device-uuid',
              'createdAt': '2024-02-20T14:00:00.000',
              'syncedAt': null,
            },
          ],
        };

        final result = await exportService.importAppState(
          jsonEncode(exportJson),
        );

        expect(result.success, true);
        expect(result.recordsImported, 0); // Duplicate, not imported

        // Should still have only 1 record
        final records = await nosebleedService.getAllLocalRecords();
        expect(records, hasLength(1));
      });

      test('full round-trip export then import on fresh database', () async {
        // Add a record
        await nosebleedService.addRecord(
          startTime: DateTime(2024, 3, 10, 9, 0),
          endTime: DateTime(2024, 3, 10, 9, 30),
        );

        // Export
        final exportedJson = await exportService.exportAppState();

        // Clear database (simulating fresh device)
        // ignore: invalid_use_of_visible_for_testing_member
        await nosebleedService.clearLocalData(reinitialize: false);

        // Reinitialize datastore
        await Datastore.initialize(
          config: DatastoreConfig(
            deviceId: 'new-device-id',
            userId: 'test-user-id',
            databasePath: tempDir.path,
            databaseName: 'test_events_fresh.db',
            enableEncryption: false,
          ),
        );

        // Verify database is empty
        final recordsBefore = await nosebleedService.getAllLocalRecords();
        expect(recordsBefore, isEmpty);

        // Import
        final result = await exportService.importAppState(exportedJson);

        expect(result.success, true);
        expect(result.recordsImported, 1);

        // Verify the record was imported
        final recordsAfter = await nosebleedService.getAllLocalRecords();
        expect(recordsAfter, hasLength(1));
      });
    });
  });
}

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
  Future<String?> getUserId() async => 'test-user-id';

  @override
  void dispose() {}
}
