// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00006: Offline-First Data Entry

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/feature_flags.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingScreen', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('recording_test_');

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
        enableCloudSync: false, // Disable cloud sync for unit tests
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

    group('New Record Mode', () {
      testWidgets('displays start time picker as initial step', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              diaryEntryDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show start time title
        expect(find.text('Nosebleed Start'), findsOneWidget);
        expect(find.text('Set Start Time'), findsOneWidget);
      });

      testWidgets('displays back button', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Back'), findsOneWidget);
      });

      testWidgets('displays delete button for new records', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Delete button is now shown for all records (new and existing)
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('displays summary bar with all fields', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Max Intensity'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
      });
    });

    group('Edit Mode', () {
      setUp(() {
        // Enable review screen for Edit Mode tests
        FeatureFlagService.instance.useReviewScreen = true;
      });

      tearDown(() {
        // Reset to default
        FeatureFlagService.instance.useReviewScreen = false;
      });

      testWidgets('pre-fills fields from existing record', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
          notes: 'Test notes',
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // For a complete existing record, should show the complete step
        expect(find.text('Edit Record'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
      });

      testWidgets('shows complete step for fully filled record', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show Edit Record title and Save Changes button
        expect(find.text('Edit Record'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Duration: 15 minutes'), findsOneWidget);
      });

      testWidgets('shows intensity picker for record missing intensity', (
        tester,
      ) async {
        final incompleteRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          isIncomplete: true,
          // Missing intensity and endTime
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: incompleteRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show intensity picker
        expect(find.text('Spotting'), findsOneWidget);
        expect(find.text('Dripping'), findsOneWidget);
      });

      testWidgets('shows end time picker for record missing end time', (
        tester,
      ) async {
        final incompleteRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
          isIncomplete: true,
          // Missing endTime
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: incompleteRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show end time picker
        expect(find.text('Nosebleed End Time'), findsOneWidget);
        expect(find.text('Set End Time'), findsOneWidget);
      });

      testWidgets('displays delete button for existing records', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('summary bar shows existing record values', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Summary bar should display existing values
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(find.text('10:45 AM'), findsOneWidget);
        expect(find.text('Dripping'), findsOneWidget);
      });

      // CUR-464: Test moved to integration_test/recording_save_flow_test.dart
      // Reason: Datastore transactions don't complete properly in widget tests

      testWidgets('can navigate between steps via summary bar', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on start time in summary bar
        await tester.tap(find.text('10:30 AM'));
        await tester.pumpAndSettle();

        // Should show start time picker
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Tap on intensity in summary bar
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should show intensity picker
        expect(find.text('Spotting'), findsOneWidget);
      });
    });

    group('Overlap Warning', () {
      setUp(() {
        // Enable review screen so Save Changes button is visible
        FeatureFlagService.instance.useReviewScreen = true;
      });

      tearDown(() {
        // Reset to default
        FeatureFlagService.instance.useReviewScreen = false;
      });

      testWidgets('shows overlap warning when events overlap', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overlappingRecords = [
          NosebleedRecord(
            id: 'other-1',
            startTime: DateTime(2024, 1, 15, 10, 0),
            endTime: DateTime(2024, 1, 15, 10, 30),
            intensity: NosebleedIntensity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 15), // Overlaps with other
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              allRecords: overlappingRecords,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show overlap warning
        expect(find.text('Overlapping Events Detected'), findsOneWidget);
      });

      testWidgets('excludes current record when checking overlaps', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 15),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        // allRecords includes the record being edited
        final allRecords = [existingRecord];

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              allRecords: allRecords,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT show overlap warning for itself
        expect(find.text('Overlapping Events Detected'), findsNothing);
      });

      testWidgets('shows warning but allows save when overlaps exist', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overlappingRecords = [
          NosebleedRecord(
            id: 'other-1',
            startTime: DateTime(2024, 1, 15, 10, 0),
            endTime: DateTime(2024, 1, 15, 10, 30),
            intensity: NosebleedIntensity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 15), // Overlaps with other
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              allRecords: overlappingRecords,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the save button - CUR-443: button should be ENABLED even with overlaps
        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        expect(saveButton, findsOneWidget);

        // CUR-443: The button should be enabled (overlaps don't block save)
        final filledButton = tester.widget<FilledButton>(saveButton);
        expect(filledButton.onPressed, isNotNull);

        // Should show overlap warning with time range (CUR-410)
        expect(find.text('Overlapping Events Detected'), findsOneWidget);
        expect(
          find.text(
            'This time overlaps with an existing nosebleed record from 10:00 AM to 10:30 AM',
          ),
          findsOneWidget,
        );
      });

      testWidgets('enables save button when no overlaps', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final nonOverlappingRecords = [
          NosebleedRecord(
            id: 'other-1',
            startTime: DateTime(2024, 1, 15, 8, 0), // Does not overlap
            endTime: DateTime(2024, 1, 15, 8, 30),
            intensity: NosebleedIntensity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 15),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              allRecords: nonOverlappingRecords,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the save button - it should be enabled
        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        expect(saveButton, findsOneWidget);

        // The button should be enabled (onPressed is not null)
        final filledButton = tester.widget<FilledButton>(saveButton);
        expect(filledButton.onPressed, isNotNull);

        // Should NOT show error message
        expect(
          find.text(
            'Cannot save: This event overlaps with existing events. Please adjust the time.',
          ),
          findsNothing,
        );
      });

      // CUR-449: Records on different days should not trigger overlap warning
      testWidgets(
        'does not show overlap warning for same time on different days',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // Record from yesterday at 10:00-10:30
          final yesterdayRecord = NosebleedRecord(
            id: 'yesterday-1',
            startTime: DateTime(2024, 1, 14, 10, 0),
            endTime: DateTime(2024, 1, 14, 10, 30),
            intensity: NosebleedIntensity.spotting,
          );

          // Current record is today at same time (10:00-10:30)
          final todayRecord = NosebleedRecord(
            id: 'today-1',
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
                existingRecord: todayRecord,
                allRecords: [yesterdayRecord],
                onDelete: (_) async {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Should NOT show overlap warning - different days
          expect(find.text('Overlapping Events Detected'), findsNothing);

          // Save button should be enabled
          final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
          expect(saveButton, findsOneWidget);
          final filledButton = tester.widget<FilledButton>(saveButton);
          expect(filledButton.onPressed, isNotNull);
        },
      );
    });

    group('Delete Flow', () {
      testWidgets('shows delete confirmation dialog when delete is tapped', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Should show delete confirmation dialog
        expect(find.text('Delete Record'), findsOneWidget);
        expect(
          find.text('Please select a reason for deleting this record:'),
          findsOneWidget,
        );
      });

      testWidgets('calls onDelete when delete is confirmed', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        String? deletedReason;
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (reason) async {
                deletedReason = reason;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Select a reason - use the correct text from the dialog
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();

        // Tap confirm delete button
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Should have called onDelete with the reason
        expect(deletedReason, 'Entered by mistake');
      });
    });

    group('Save Flow', () {
      // CUR-464: Test moved to integration_test/recording_save_flow_test.dart
      // Reason: Datastore transactions don't complete properly in widget tests

      setUp(() {
        // Enable review screen for Save Flow tests that expect Save Changes button
        FeatureFlagService.instance.useReviewScreen = true;
      });

      tearDown(() {
        // Reset to default
        FeatureFlagService.instance.useReviewScreen = false;
      });

      testWidgets('can navigate through existing record editing', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Provide an existing record directly
        final existingRecord = NosebleedRecord(
          id: 'edit-test-1',
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.spotting,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should be on complete step for existing record
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Edit Record'), findsOneWidget);

        // Navigate to intensity to change it
        await tester.tap(find.text('Spotting'));
        await tester.pumpAndSettle();

        // Should show intensity picker
        expect(find.text('Dripping'), findsOneWidget);

        // Change intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should now be on end time step
        expect(find.text('Nosebleed End Time'), findsOneWidget);
      });

      testWidgets('handles save failure gracefully', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create a failing mock service
        final failingService = FailingNosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: MockClient(
            (_) async => http.Response('{"success": true}', 200),
          ),
        );

        // Use today's date to avoid triggering old entry validation dialog
        final today = DateTime.now();

        // Disable validation confirmations to avoid dialogs blocking the save
        // These are now feature flags (sponsor-controlled), not user preferences
        SharedPreferences.setMockInitialValues({
          'ff_enable_short_duration_confirmation': false,
          'ff_enable_long_duration_confirmation': false,
        });
        await FeatureFlagService.instance.initialize();
        final testPreferencesService = PreferencesService();

        await tester.pumpWidget(
          wrapWithScaffold(
            RecordingScreen(
              nosebleedService: failingService,
              enrollmentService: mockEnrollment,
              preferencesService: testPreferencesService,
              diaryEntryDate: today,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Tap Set End Time - CUR-464: saves immediately (no Finished button with useReviewScreen=false)
        await tester.tap(find.text('Set End Time'));
        // Use pump with duration to allow save to attempt
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Save failure is handled silently (logged to console, no user-facing error shown)
        // The screen should still be displayed (not crashed)
        expect(find.byType(RecordingScreen), findsOneWidget);

        failingService.dispose();
      });
    });

    // CUR-408: Notes Requirement group removed - notes step removed from flow

    group('Start Time Confirmation', () {
      testWidgets('advances to intensity step after confirming start time', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show start time picker
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Should now show intensity picker
        expect(find.text('Spotting'), findsOneWidget);
        expect(find.text('Dripping'), findsOneWidget);
      });
    });

    group('End Time Validation', () {
      testWidgets('shows snackbar when end time is before start time', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 14, 0), // 2:00 PM
          endTime: DateTime(2024, 1, 15, 14, 30),
          intensity: NosebleedIntensity.dripping,
          isIncomplete: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to end time
        await tester.tap(find.text('2:30 PM'));
        await tester.pumpAndSettle();

        // Should show end time picker
        expect(find.text('Nosebleed End Time'), findsOneWidget);

        // Try to use the -15 minute adjustment multiple times to go before start
        // The start time is 2:00 PM, end time is 2:30 PM
        // We need to tap -15 three times to get to 1:45 PM (before start)
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle();

        // Now try to confirm - use the button text
        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // Should show snackbar
        expect(find.text('End time must be after start time'), findsOneWidget);
      });
    });

    // CUR-408: Notes Step group removed - notes step removed from flow

    group('Summary Bar Navigation', () {
      testWidgets('can navigate to end time via summary bar', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on end time in summary bar
        await tester.tap(find.text('10:45 AM'));
        await tester.pumpAndSettle();

        // Should show end time picker
        expect(find.text('Nosebleed End Time'), findsOneWidget);
      });
    });

    group('End Time Display in Summary', () {
      testWidgets('shows "Not set" when end time is null for new record', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // End time should show "Not set" for new records
        expect(find.text('Not set'), findsOneWidget);
      });

      testWidgets('shows (+1 day) when end date is one day after start', (
        tester,
      ) async {
        // Record spans from 11pm to 1am next day
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 23, 0), // 11:00 PM Jan 15
          endTime: DateTime(2024, 1, 16, 1, 0), // 1:00 AM Jan 16
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // End time summary should show "(+1 day)"
        expect(find.textContaining('(+1 day)'), findsOneWidget);
      });

      testWidgets('shows (+2 days) when end date is two days after start', (
        tester,
      ) async {
        // Record spans multiple days
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          startTime: DateTime(2024, 1, 15, 23, 0), // 11:00 PM Jan 15
          endTime: DateTime(2024, 1, 17, 1, 0), // 1:00 AM Jan 17
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // End time summary should show "(+2 days)"
        expect(find.textContaining('(+2 days)'), findsOneWidget);
      });

      testWidgets('does not show day offset when dates are same', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
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
              existingRecord: existingRecord,
              onDelete: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT show any day offset
        expect(find.textContaining('(+'), findsNothing);
      });

      testWidgets(
        'end time tracks start time changes for new records until explicitly set',
        (tester) async {
          await tester.pumpWidget(
            wrapWithMaterialApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Initially end time should be "Not set"
          expect(find.text('Not set'), findsOneWidget);

          // Tap +15 to adjust start time - end should still be "Not set"
          await tester.tap(find.text('+15'));
          await tester.pumpAndSettle();

          // End time should still show "Not set" (tracking is implicit, not displayed)
          expect(find.text('Not set'), findsOneWidget);
        },
      );
    });

    group('Intensity Selection', () {
      testWidgets('navigates to end time picker when intensity is selected', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              diaryEntryDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should show end time picker
        expect(find.text('Nosebleed End Time'), findsOneWidget);
        // End time in summary bar remains unset until user confirms
        // CUR-488: Changed from '--:--' to localized 'Not set'
        expect(find.text('Not set'), findsOneWidget);
      });
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

/// Mock NosebleedService that always fails on save operations
class FailingNosebleedService extends NosebleedService {
  FailingNosebleedService({
    required super.enrollmentService,
    required super.httpClient,
  });

  @override
  Future<NosebleedRecord> addRecord({
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? parentRecordId,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    throw Exception('Simulated save failure');
  }

  @override
  Future<NosebleedRecord> updateRecord({
    required String originalRecordId,
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    throw Exception('Simulated update failure');
  }
}
