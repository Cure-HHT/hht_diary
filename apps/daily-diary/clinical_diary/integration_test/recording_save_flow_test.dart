// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00006: Offline-First Data Entry

// Integration test for recording save flow
// Moved from test/screens/recording_screen_test.dart because:
// - Datastore transactions don't complete properly in widget tests
// - Navigator.pop results need proper async handling

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Recording Save Flow Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('save_flow_test_');

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
        httpClient: MockClient(
          (_) async => http.Response('{"success": true}', 200),
        ),
        enableCloudSync: false, // Disable for tests
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

    testWidgets(
      'saves and returns record ID after completing new record flow',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        String? popResult;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordingScreen(
                          nosebleedService: nosebleedService,
                          enrollmentService: mockEnrollment,
                          preferencesService: preferencesService,
                          diaryEntryDate: DateTime(2024, 1, 15),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to RecordingScreen
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Confirm end time - CUR-464: saves immediately and pops with record ID
        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // Should have popped back with a record ID
        expect(popResult, isNotNull);
        expect(popResult, isNotEmpty);

        // Verify record was actually saved to datastore
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.id, popResult);
        expect(records.first.intensity, NosebleedIntensity.dripping);
      },
    );

    testWidgets('saves and returns record ID for incomplete existing record', (
      tester,
    ) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // First, add an incomplete record to the datastore
      final incompleteRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        // Missing intensity - will be marked incomplete
      );

      // Verify record is incomplete
      var records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, true);

      String? popResult;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordingScreen(
                        nosebleedService: nosebleedService,
                        enrollmentService: mockEnrollment,
                        preferencesService: preferencesService,
                        existingRecord: incompleteRecord,
                        onDelete: (_) async {
                          // Not used in this test, but required for existing records
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to RecordingScreen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select intensity to complete the record
      await tester.tap(find.text('Dripping'));
      await tester.pumpAndSettle();

      // Verify we're on end time step
      expect(find.text('Set End Time'), findsOneWidget);

      // Tap Set End Time - CUR-464: saves immediately and pops
      await tester.tap(find.text('Set End Time'));
      await tester.pumpAndSettle();

      // Should have popped back with a record ID
      expect(popResult, isNotNull);
      expect(popResult, isNotEmpty);

      // Verify record was updated in datastore (now complete)
      records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, false);
      expect(records.first.intensity, NosebleedIntensity.dripping);
    });
  });
}

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? backendUrl;
  UserEnrollment? enrollment;

  @override
  Future<String?> getJwtToken() async => jwtToken;

  @override
  Future<bool> isEnrolled() async => jwtToken != null;

  @override
  Future<UserEnrollment?> getEnrollment() async => enrollment;

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

  @override
  Future<String?> getBackendUrl() async => backendUrl;

  @override
  Future<String?> getSyncUrl() async =>
      backendUrl != null ? '$backendUrl/api/v1/user/sync' : null;

  @override
  Future<String?> getRecordsUrl() async =>
      backendUrl != null ? '$backendUrl/api/v1/user/records' : null;
}
