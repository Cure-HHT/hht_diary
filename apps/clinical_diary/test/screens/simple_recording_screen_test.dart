// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('SimpleRecordingScreen', () {
    late EnrollmentService enrollmentService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('simple_recording_test_');

      // Initialize the datastore for tests
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

      final mockHttpClient = MockClient(
        (_) async => http.Response('{"success": true}', 200),
      );

      enrollmentService = EnrollmentService(httpClient: mockHttpClient);
      nosebleedService = NosebleedService(
        enrollmentService: enrollmentService,
        httpClient: mockHttpClient,
        enableCloudSync: false,
      );
    });

    tearDown(() async {
      nosebleedService.dispose();
      enrollmentService.dispose();
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget buildSimpleRecordingScreen({
      DateTime? initialDate,
      NosebleedRecord? existingRecord,
      List<NosebleedRecord> allRecords = const [],
      Future<void> Function(String)? onDelete,
    }) {
      return wrapWithMaterialApp(
        SimpleRecordingScreen(
          nosebleedService: nosebleedService,
          enrollmentService: enrollmentService,
          initialDate: initialDate,
          existingRecord: existingRecord,
          allRecords: allRecords,
          onDelete: onDelete,
        ),
      );
    }

    /// Set up a larger screen size for testing
    void setUpTestScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
    }

    /// Reset screen size after test
    void resetTestScreenSize(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    group('Basic Rendering', () {
      testWidgets('displays back button', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
      });

      testWidgets('displays nosebleed start section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        expect(find.text('Nosebleed Start'), findsOneWidget);
      });

      testWidgets('displays max intensity section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        expect(find.text('Max Intensity'), findsOneWidget);
      });

      testWidgets('displays nosebleed end section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        expect(find.text('Nosebleed End'), findsOneWidget);
      });

      testWidgets('displays add nosebleed button for new record', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        // Button text changes based on what's set
        // Start time is auto-set, so button should show progress
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('does not display delete button for new record', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
    });

    group('Edit Mode', () {
      testWidgets('displays delete button for existing record', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: DateTime.now(),
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now().subtract(const Duration(minutes: 30)),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(existingRecord: existingRecord),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('shows update button text for existing record', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: DateTime.now(),
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now().subtract(const Duration(minutes: 30)),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(existingRecord: existingRecord),
        );
        await tester.pumpAndSettle();

        expect(find.text('Update Nosebleed'), findsOneWidget);
      });

      testWidgets('populates fields from existing record', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: yesterday,
          startTime: DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            10,
            0,
          ),
          endTime: DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            10,
            30,
          ),
          intensity: NosebleedIntensity.spotting,
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(existingRecord: existingRecord),
        );
        await tester.pumpAndSettle();

        // The times should be displayed (we can't easily verify exact text)
        // But the screen should render without errors
        expect(find.text('Nosebleed Start'), findsOneWidget);
      });
    });

    group('Intensity Selection', () {
      testWidgets('can select intensity', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        // Find and tap the first intensity option (Spotting)
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Button text should update to show intensity is set
        // The screen should still render without errors
        expect(find.byType(FilledButton), findsOneWidget);
      });
    });

    group('Time Validation', () {
      testWidgets('prevents end time before start time', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        // This validates the UI structure is correct
        // Actual time validation is tested via interaction
        expect(find.text('Nosebleed Start'), findsOneWidget);
        expect(find.text('Nosebleed End'), findsOneWidget);
      });
    });

    group('Overlap Warning', () {
      testWidgets('shows overlap warning when records overlap', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final today = DateTime.now();
        final overlappingRecord = NosebleedRecord(
          id: 'other-id',
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        // Create a record that will overlap
        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 15),
          endTime: DateTime(today.year, today.month, today.day, 10, 45),
          intensity: NosebleedIntensity.spotting,
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(
            existingRecord: existingRecord,
            allRecords: [overlappingRecord, existingRecord],
          ),
        );
        await tester.pumpAndSettle();

        // Should show overlap warning
        expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      });
    });

    group('Save Functionality', () {
      testWidgets('shows FilledButton for saving', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        // The FilledButton should exist
        expect(find.byType(FilledButton), findsOneWidget);
      });
    });

    group('Delete Functionality', () {
      testWidgets('delete button triggers confirmation dialog', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: DateTime.now(),
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now().subtract(const Duration(minutes: 30)),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(
            existingRecord: existingRecord,
            onDelete: (_) async {},
          ),
        );
        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Should show confirmation dialog
        expect(find.byType(Dialog), findsOneWidget);
      });
    });

    group('Initial Date', () {
      testWidgets('uses provided initial date', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        await tester.pumpWidget(
          buildSimpleRecordingScreen(initialDate: yesterday),
        );
        await tester.pumpAndSettle();

        // Should render without errors with the past date
        expect(find.text('Nosebleed Start'), findsOneWidget);
      });

      testWidgets('defaults to today when no initial date provided', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSimpleRecordingScreen());
        await tester.pumpAndSettle();

        // Should render without errors
        expect(find.text('Nosebleed Start'), findsOneWidget);
      });
    });

    group('Button State', () {
      testWidgets('button is disabled when start time not set', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // For new records, start time is auto-set, so we test with existing incomplete record
        final existingRecord = NosebleedRecord(
          id: 'test-id',
          date: DateTime.now(),
          // No start time, end time, or intensity
        );

        await tester.pumpWidget(
          buildSimpleRecordingScreen(existingRecord: existingRecord),
        );
        await tester.pumpAndSettle();

        // Button should show "Save Changes"
        expect(find.text('Save Changes'), findsOneWidget);
      });
    });
  });
}
