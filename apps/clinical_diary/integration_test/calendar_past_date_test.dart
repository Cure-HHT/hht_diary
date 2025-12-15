// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

// Integration test for CUR-543: Calendar - New event created in the past is not recorded
// Tests that:
// 1. Creating an event on a past date updates the calendar immediately (day turns red)
// 2. Clicking on the date shows the created event

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
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

  group('CUR-543: Calendar Past Date Event Creation', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('calendar_test_');

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
        enableCloudSync: false,
      );
    });

    tearDown(() async {
      nosebleedService.dispose();
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'calendar updates immediately after creating event on past date',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Calculate a past date that will be visible in the current month
        // Use max(day - 5, 1) to ensure we stay in the current month
        final now = DateTime.now();
        final pastDay = now.day > 5 ? now.day - 5 : 1;
        final pastDate = DateTime(now.year, now.month, pastDay);

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
            home: Scaffold(
              body: CalendarScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find and verify the past date is displayed (grey = not recorded)
        // The day number should be visible
        final dayText = find.text('${pastDate.day}');
        expect(dayText, findsWidgets);

        // Find the specific day cell for our past date
        // Days are rendered in Container widgets with specific colors
        // Grey (Colors.grey.shade400) = not recorded
        final dayFinder = find.ancestor(
          of: find.text('${pastDate.day}'),
          matching: find.byType(Container),
        );

        // Get the first Container that wraps the day text (the decorated one)
        final dayContainers = tester.widgetList<Container>(dayFinder);
        final decoratedContainer = dayContainers.firstWhere(
          (c) => c.decoration != null,
          orElse: () => throw StateError('No decorated container found'),
        );

        // Verify initial color is grey (not recorded)
        final initialDecoration =
            decoratedContainer.decoration! as BoxDecoration;
        expect(
          initialDecoration.color,
          equals(Colors.grey.shade400),
          reason: 'Day should initially be grey (not recorded)',
        );

        // Tap the past date
        await tester.tap(find.text('${pastDate.day}').first);
        await tester.pumpAndSettle();

        // Should show DaySelectionScreen with "What happened on this day?"
        expect(find.text('What happened on this day?'), findsOneWidget);

        // Tap "Add nosebleed event"
        await tester.tap(find.text('Add nosebleed event'));
        await tester.pumpAndSettle();

        // Should now be on RecordingScreen
        expect(find.text('Set Start Time'), findsOneWidget);

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select intensity
        expect(find.text('Dripping'), findsOneWidget);
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Confirm end time - this saves the record and navigates back
        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // BUG: After saving, we should be back at the calendar
        // and the day should be RED (nosebleed recorded)
        // Currently it stays GREY because _loadDayStatuses() is not called
        // due to Navigator.push<bool> receiving a String instead of bool

        // Verify we're back at the calendar
        expect(find.text('Select Date'), findsOneWidget);

        // Verify the day is now RED (nosebleed recorded)
        // Re-find the day container after navigation
        final updatedDayFinder = find.ancestor(
          of: find.text('${pastDate.day}'),
          matching: find.byType(Container),
        );
        final updatedDayContainers = tester.widgetList<Container>(
          updatedDayFinder,
        );
        final updatedDecoratedContainer = updatedDayContainers.firstWhere(
          (c) => c.decoration != null,
          orElse: () => throw StateError('No decorated container found'),
        );
        final updatedDecoration =
            updatedDecoratedContainer.decoration! as BoxDecoration;

        // This assertion will FAIL with the current bug
        // The day should be red (Colors.red) but remains grey
        expect(
          updatedDecoration.color,
          equals(Colors.red),
          reason:
              'Day should be red after creating nosebleed event, but it stays grey',
        );

        // Verify record was saved to datastore
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1, reason: 'Record should be saved');
        expect(records.first.intensity, NosebleedIntensity.dripping);
      },
    );

    testWidgets(
      'clicking on date with event shows the event in DateRecordsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Pre-create a record for a past date
        // Use max(day - 3, 1) to ensure we stay in the current month
        final now = DateTime.now();
        final pastDay = now.day > 3 ? now.day - 3 : 1;
        final pastDate = DateTime(now.year, now.month, pastDay);

        await nosebleedService.addRecord(
          startTime: pastDate,
          endTime: pastDate.add(const Duration(minutes: 15)),
          intensity: NosebleedIntensity.steadyStream,
        );

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
            home: Scaffold(
              body: CalendarScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The day should be red (has nosebleed event)
        final dayFinder = find.ancestor(
          of: find.text('${pastDate.day}'),
          matching: find.byType(Container),
        );
        final dayContainers = tester.widgetList<Container>(dayFinder);
        final decoratedContainer = dayContainers.firstWhere(
          (c) => c.decoration != null,
          orElse: () => throw StateError('No decorated container found'),
        );
        final decoration = decoratedContainer.decoration! as BoxDecoration;
        expect(
          decoration.color,
          equals(Colors.red),
          reason: 'Day with nosebleed should be red',
        );

        // Tap the day to view events
        await tester.tap(find.text('${pastDate.day}').first);
        await tester.pumpAndSettle();

        // Should show DateRecordsScreen with the event
        // The "Add new event" button should be visible
        expect(find.text('Add new event'), findsOneWidget);

        // Should show at least one EventListItem (Card widget with the event)
        // The event displays time and duration, not intensity text
        expect(find.byType(Card), findsWidgets);
      },
    );
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
