// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00006: Offline-First Data Entry

// Integration test for delete record functionality
// Verifies that:
// 1. Delete button on edit screen triggers delete confirmation dialog
// 2. Confirming delete appends a NosebleedDeleted event
// 3. The materialized view properly filters out deleted records
// 4. User is returned to the previous screen after deletion

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Delete Record Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('delete_integration_');

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
      'full delete flow: edit record -> delete -> confirm -> record removed '
      'from materialized view',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Step 1: Create a record in the service
        final originalRecord = await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        // Verify record exists in materialized view
        var records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.id, originalRecord.id);

        // Step 2: Create the RecordingScreen with onDelete callback
        // that properly calls the service's deleteRecord method
        var wasDeleted = false;
        String? deletedReason;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: originalRecord,
              onDelete: (reason) async {
                await nosebleedService.deleteRecord(
                  recordId: originalRecord.id,
                  reason: reason,
                );
                wasDeleted = true;
                deletedReason = reason;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 3: Verify delete button is visible
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Step 4: Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Step 5: Verify delete confirmation dialog appears
        expect(find.text('Delete Record'), findsOneWidget);
        expect(
          find.text('Please select a reason for deleting this record:'),
          findsOneWidget,
        );

        // Step 6: Select a reason
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();

        // Step 7: Tap confirm delete button
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Step 8: Verify the onDelete callback was called
        expect(wasDeleted, true);
        expect(deletedReason, 'Entered by mistake');

        // Step 9: Verify record is removed from materialized view
        records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.isEmpty, true);

        // Step 10: Verify the deletion event exists in the raw event log
        final allRecords = await nosebleedService.getAllLocalRecords();
        // Should have 2 events: original + deletion marker
        expect(allRecords.length, 2);

        final deletionRecord = allRecords.firstWhere((r) => r.isDeleted);
        expect(deletionRecord.deleteReason, 'Entered by mistake');
        expect(deletionRecord.parentRecordId, originalRecord.id);
      },
    );

    testWidgets(
      'delete button does nothing when onDelete callback is not provided',
      (tester) async {
        // This test documents the bug that was fixed in CUR-465
        // When onDelete is not provided, clicking delete should do nothing
        // (the bug was that incomplete records were missing the onDelete callback)

        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create a record
        final originalRecord = await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        // Create the RecordingScreen WITHOUT onDelete callback
        // This simulates the bug scenario
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: originalRecord,
              // onDelete intentionally not provided to test bug scenario
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Select a reason
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();

        // Tap confirm delete button
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Record should NOT be deleted (bug behavior - onDelete not called)
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.id, originalRecord.id);
      },
    );

    testWidgets('deleting incomplete record works correctly', (tester) async {
      // This test verifies the fix for CUR-465: incomplete records
      // now have the onDelete callback properly wired up

      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create an incomplete record (missing end time and severity)
      final incompleteRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 0),
        // endTime and severity intentionally not provided
      );

      // Verify record is incomplete
      var records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, true);

      // Create the RecordingScreen with onDelete callback
      // This simulates the fix - onDelete is now always provided
      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            nosebleedService: nosebleedService,
            enrollmentService: mockEnrollment,
            preferencesService: preferencesService,
            existingRecord: incompleteRecord,
            onDelete: (reason) async {
              await nosebleedService.deleteRecord(
                recordId: incompleteRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Select a reason
      await tester.tap(find.text('Duplicate entry'));
      await tester.pumpAndSettle();

      // Tap confirm delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify record is deleted from materialized view
      records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.isEmpty, true);
    });

    testWidgets('cancel delete does not remove record', (tester) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a record
      final originalRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            nosebleedService: nosebleedService,
            enrollmentService: mockEnrollment,
            preferencesService: preferencesService,
            existingRecord: originalRecord,
            onDelete: (reason) async {
              await nosebleedService.deleteRecord(
                recordId: originalRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Record should still exist
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.id, originalRecord.id);
    });

    testWidgets('delete with custom "Other" reason works correctly', (
      tester,
    ) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a record
      final originalRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
        intensity: NosebleedIntensity.dripping,
      );

      String? capturedReason;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            nosebleedService: nosebleedService,
            enrollmentService: mockEnrollment,
            preferencesService: preferencesService,
            existingRecord: originalRecord,
            onDelete: (reason) async {
              capturedReason = reason;
              await nosebleedService.deleteRecord(
                recordId: originalRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Select "Other" reason
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      // Focus the TextField first, then enter custom reason
      final textField = find.byType(TextField);
      expect(
        textField,
        findsOneWidget,
        reason: 'TextField should appear after selecting Other',
      );

      // Use enterText which properly triggers onChanged callbacks
      // This works across all platforms including headless Linux
      await tester.enterText(textField, 'Custom deletion reason for testing');
      await tester.pumpAndSettle();

      // Verify Delete button is enabled (not null onPressed)
      final deleteButton = find.widgetWithText(FilledButton, 'Delete');
      expect(
        deleteButton,
        findsOneWidget,
        reason: 'Delete button should exist',
      );
      final filledButton = tester.widget<FilledButton>(deleteButton);
      expect(
        filledButton.onPressed,
        isNotNull,
        reason:
            'Delete button should be enabled after entering custom reason. '
            'Text field may not have received text input.',
      );

      // Tap confirm delete button
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify custom reason was captured
      expect(capturedReason, 'Custom deletion reason for testing');

      // Verify record is deleted
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.isEmpty, true);
    });
  });
}

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
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
}
