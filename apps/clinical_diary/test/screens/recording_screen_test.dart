// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00006: Offline-First Data Entry

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingScreen', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();

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
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              initialDate: DateTime(2024, 1, 15),
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
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Back'), findsOneWidget);
      });

      testWidgets('does not display delete button for new records', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });

      testWidgets('displays summary bar with all fields', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Severity'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
      });
    });

    group('Edit Mode', () {
      testWidgets('pre-fills fields from existing record', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
          notes: 'Test notes',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show Edit Record title and Save Changes button
        expect(find.text('Edit Record'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Duration: 15 minutes'), findsOneWidget);
      });

      testWidgets('shows severity picker for record missing severity', (
        tester,
      ) async {
        final incompleteRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          isIncomplete: true,
          // Missing severity and endTime
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: incompleteRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show severity picker
        expect(find.text('Spotting'), findsOneWidget);
        expect(find.text('Dripping'), findsOneWidget);
      });

      testWidgets('shows end time picker for record missing end time', (
        tester,
      ) async {
        final incompleteRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          severity: NosebleedSeverity.dripping,
          isIncomplete: true,
          // Missing endTime
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: incompleteRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show end time picker
        expect(find.text('Nosebleed End Time'), findsOneWidget);
        expect(find.text('Nosebleed Ended'), findsOneWidget);
      });

      testWidgets('displays delete button for existing records', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('summary bar shows existing record values', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Summary bar should display existing values
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(find.text('10:45 AM'), findsOneWidget);
        expect(find.text('Dripping'), findsOneWidget);
      });

      testWidgets('shows Complete Record for incomplete existing record', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final incompleteRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          // Missing severity
          isIncomplete: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: incompleteRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select a severity to proceed to complete step
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Go to end time step, then confirm to go to complete step
        // CUR-408: Notes step removed - flow goes directly to complete
        await tester.tap(find.text('Nosebleed Ended'));
        await tester.pumpAndSettle();

        // Should show Complete Record button (check by widget type)
        expect(
          find.widgetWithText(FilledButton, 'Complete Record'),
          findsOneWidget,
        );
      });

      testWidgets('can navigate between steps via summary bar', (tester) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on start time in summary bar
        await tester.tap(find.text('10:30 AM'));
        await tester.pumpAndSettle();

        // Should show start time picker
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Tap on severity in summary bar
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should show severity picker
        expect(find.text('Spotting'), findsOneWidget);
      });
    });

    group('Overlap Warning', () {
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
            date: DateTime(2024, 1, 15),
            startTime: DateTime(2024, 1, 15, 10, 0),
            endTime: DateTime(2024, 1, 15, 10, 30),
            severity: NosebleedSeverity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 15), // Overlaps with other
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
              allRecords: overlappingRecords,
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 15),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        // allRecords includes the record being edited
        final allRecords = [existingRecord];

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
              allRecords: allRecords,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT show overlap warning for itself
        expect(find.text('Overlapping Events Detected'), findsNothing);
      });

      testWidgets('disables save button when overlaps exist', (tester) async {
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
            date: DateTime(2024, 1, 15),
            startTime: DateTime(2024, 1, 15, 10, 0),
            endTime: DateTime(2024, 1, 15, 10, 30),
            severity: NosebleedSeverity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 15), // Overlaps with other
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
              allRecords: overlappingRecords,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the save button - it should be disabled
        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        expect(saveButton, findsOneWidget);

        // The button should be disabled (onPressed is null)
        final filledButton = tester.widget<FilledButton>(saveButton);
        expect(filledButton.onPressed, isNull);

        // Should show error message about overlaps
        expect(
          find.text(
            'Cannot save: This event overlaps with existing events. Please adjust the time.',
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
            date: DateTime(2024, 1, 15),
            startTime: DateTime(2024, 1, 15, 8, 0), // Does not overlap
            endTime: DateTime(2024, 1, 15, 8, 30),
            severity: NosebleedSeverity.spotting,
          ),
        ];

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 15),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
              allRecords: nonOverlappingRecords,
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
    });

    group('Delete Flow', () {
      testWidgets('shows delete confirmation dialog when delete is tapped', (
        tester,
      ) async {
        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
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
      testWidgets('navigates through flow to complete step', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              initialDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select severity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Confirm end time - CUR-408: Goes directly to complete (notes removed)
        await tester.tap(find.text('Nosebleed Ended'));
        await tester.pumpAndSettle();

        // Should show Finished button for new record
        expect(find.text('Finished'), findsOneWidget);
        expect(find.text('Record Complete'), findsOneWidget);

        // Verify the button is enabled
        final saveButton = find.widgetWithText(FilledButton, 'Finished');
        expect(saveButton, findsOneWidget);
        final button = tester.widget<FilledButton>(saveButton);
        expect(button.onPressed, isNotNull);
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          severity: NosebleedSeverity.spotting,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should be on complete step for existing record
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Edit Record'), findsOneWidget);

        // Navigate to severity to change it
        await tester.tap(find.text('Spotting'));
        await tester.pumpAndSettle();

        // Should show severity picker
        expect(find.text('Dripping'), findsOneWidget);

        // Change severity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should now be on end time step
        expect(find.text('Nosebleed End Time'), findsOneWidget);
      });

      testWidgets('shows error snackbar when save fails', (tester) async {
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

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordingScreen(
                nosebleedService: failingService,
                enrollmentService: mockEnrollment,
                initialDate: DateTime(2024, 1, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select severity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Confirm end time - CUR-408: Goes directly to complete (notes removed)
        await tester.tap(find.text('Nosebleed Ended'));
        await tester.pumpAndSettle();

        // Tap save button
        await tester.tap(find.text('Finished'));
        // Use pump with duration instead of pumpAndSettle which times out
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Should show error snackbar
        expect(find.textContaining('Failed to save'), findsOneWidget);

        failingService.dispose();
      });
    });

    // CUR-408: Notes Requirement group removed - notes step removed from flow

    group('Start Time Confirmation', () {
      testWidgets('advances to severity step after confirming start time', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show start time picker
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Should now show severity picker
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 14, 0), // 2:00 PM
          endTime: DateTime(2024, 1, 15, 14, 30),
          severity: NosebleedSeverity.dripping,
          isIncomplete: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                existingRecord: existingRecord,
              ),
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
        await tester.tap(find.text('Nosebleed Ended'));
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          severity: NosebleedSeverity.dripping,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
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

    group('Severity Selection', () {
      testWidgets('initializes end time when severity is selected', (
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
          MaterialApp(
            home: RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              initialDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select severity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Should show end time picker with initialized time
        expect(find.text('Nosebleed End Time'), findsOneWidget);
        // End time should not be '--:--' after selecting severity
        expect(find.text('--:--'), findsNothing);
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
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedSeverity? severity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? parentRecordId,
  }) async {
    throw Exception('Simulated save failure');
  }

  @override
  Future<NosebleedRecord> updateRecord({
    required String originalRecordId,
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedSeverity? severity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
  }) async {
    throw Exception('Simulated update failure');
  }
}
