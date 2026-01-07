// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry
//   REQ-p00050: Temporal Entry Validation

// Integration tests for calendar past date functionality:
//
// CUR-543: Calendar - New event created in the past is not recorded
// Tests that:
// 1. Creating an event on a past date updates the calendar immediately (day turns red)
// 2. Clicking on the date shows the created event

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/main.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
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

  // ============================================================================
  // CUR-604: Calendar timezone consistency when selecting past dates
  // ============================================================================
  //
  // USER FLOW TESTED:
  // 1. Device timezone is set to PST (America/Los_Angeles)
  // 2. User opens the app and navigates to the Calendar from the home page
  // 3. User selects a past date (e.g., December 17) from the calendar widget
  // 4. User sees the DaySelectionScreen with:
  //    - Title: the selected date (e.g., "Tuesday, December 17, 2024")
  //    - Subtitle: "What happened on this day?"
  //    - Three options: "Add nosebleed event", "No nosebleed events",
  //      "I don't recall / unknown"
  // 5. User taps "Add nosebleed event"
  // 6. User is taken to RecordingScreen where:
  //    - The DateHeader shows the same date as the calendar selection
  //    - The date picker in the event summary also shows the same date
  // 7. User changes the timezone picker from PST to EST (America/New_York)
  // 8. BUG: The date in the DateHeader shifts (e.g., Dec 17 becomes Dec 16)
  //    because the stored _startDateTime is adjusted when timezone changes,
  //    but the diaryEntryDate (calendar day context) should be preserved.
  //
  // EXPECTED BEHAVIOR:
  // The DateHeader should always show the calendar day the user selected,
  // regardless of timezone changes. Timezone affects time display, NOT the
  // calendar day being recorded.
  //
  // ============================================================================
  // Set up flavor for CUR-604 tests (only if not already configured)
  // This allows running tests on any platform (DEV, QA, PROD)
  try {
    F.appFlavor; // Check if already set (getter throws if null)
  } catch (_) {
    F.appFlavor = Flavor.dev; // Only set if not already configured
  }
  AppConfig.testApiBaseOverride ??= 'https://test.example.com/api';

  group('CUR-604: Calendar Timezone Consistency', () {
    Directory? tempDir;

    // PST timezone offset in minutes (UTC-8 = -480 minutes)
    const pstOffsetMinutes = -480;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Override device timezone to PST for consistent test behavior
      TimezoneConverter.testDeviceOffsetMinutes = pstOffsetMinutes;
      TimezoneService.instance.testTimezoneOverride = 'America/Los_Angeles';

      // Initialize the datastore for tests
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }

      if (kIsWeb) {
        // Web: Use in-memory/IndexedDB storage (no file system)
        await Datastore.initialize(
          config: const DatastoreConfig(
            deviceId: 'test-device-id',
            userId: 'test-user-id',
            databasePath: '',
            databaseName: 'test_events_cur604.db',
            enableEncryption: false,
          ),
        );
      } else {
        // Native: Create a temp directory for the test database
        tempDir = await Directory.systemTemp.createTemp('cur604_test_');
        await Datastore.initialize(
          config: DatastoreConfig(
            deviceId: 'test-device-id',
            userId: 'test-user-id',
            databasePath: tempDir!.path,
            databaseName: 'test_events.db',
            enableEncryption: false,
          ),
        );
      }
    });

    tearDown(() async {
      // Reset timezone overrides
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;

      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }

      // Clean up temp directory (native only)
      if (!kIsWeb && tempDir != null && tempDir!.existsSync()) {
        await tempDir!.delete(recursive: true);
      }
    });

    /// Helper to change timezone in the time picker
    Future<void> changeTimezone(
      WidgetTester tester,
      String targetTimezoneSearch,
    ) async {
      // Find and tap the timezone selector (shows globe icon)
      final tzSelector = find.byIcon(Icons.public);
      expect(
        tzSelector,
        findsOneWidget,
        reason: 'Timezone selector should exist',
      );
      await tester.tap(tzSelector);
      await tester.pumpAndSettle();

      // Type in search to find the timezone
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget, reason: 'Search field should exist');
      await tester.enterText(searchField, targetTimezoneSearch);
      await tester.pumpAndSettle();

      // Tap on the first search result
      final tzListTile = find.byType(ListTile).first;
      await tester.tap(tzListTile);
      await tester.pumpAndSettle();
    }

    testWidgets(
      skip: true,
      'CUR-604: date header remains consistent after timezone change PST to EST',
      (tester) async {
        // ======================================================================
        // TEST: Verify that selecting a past date from the calendar and then
        // changing timezone in the recording screen does NOT shift the date
        // displayed in the DateHeader.
        //
        // DEFECT: When user selects December 17 in PST and changes to EST,
        // the DateHeader shifts to December 16 because the stored _startDateTime
        // is being adjusted for timezone, but the calendar day context should
        // be preserved independently.
        // ======================================================================

        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Calculate a past date that will be visible in the calendar
        // Use 5 days ago to ensure it's in the current month
        final now = DateTime.now();
        final pastDay = now.day > 5 ? now.day - 5 : 1;
        final pastDate = DateTime(now.year, now.month, pastDay);
        // DaySelectionScreen uses format with year: "EEEE, MMMM d, y"
        final expectedDateStrWithYear = DateFormat(
          'EEEE, MMMM d, y',
        ).format(pastDate);
        // DateHeader uses format without year: "EEEE, MMMM d"
        final expectedDateStr = DateFormat('EEEE, MMMM d').format(pastDate);

        // Launch the actual ClinicalDiaryApp
        await tester.pumpWidget(const ClinicalDiaryApp());
        await tester.pumpAndSettle();

        // ===== STEP 1: Navigate to Calendar from home page =====
        debugPrint('Step 1: Click Calendar button on home page');
        final calendarButton = find.byIcon(Icons.calendar_today);
        expect(
          calendarButton,
          findsOneWidget,
          reason: 'Calendar button should exist on home page',
        );
        await tester.tap(calendarButton);
        await tester.pumpAndSettle();

        // ===== STEP 2: Select a past date on the calendar widget =====
        debugPrint('Step 2: Select past date ($pastDay) on calendar');
        final pastDayText = find.text('$pastDay');
        expect(
          pastDayText,
          findsWidgets,
          reason: 'Past day should be visible on calendar',
        );
        await tester.tap(pastDayText.first);
        await tester.pumpAndSettle();

        // ===== STEP 3: Verify DaySelectionScreen title and subtitle =====
        debugPrint('Step 3: Verify DaySelectionScreen content');

        // Title should show the selected date (with year)
        expect(
          find.text(expectedDateStrWithYear),
          findsOneWidget,
          reason:
              'Title should show the selected date: $expectedDateStrWithYear',
        );

        // Subtitle should be "What happened on this day?"
        expect(
          find.text('What happened on this day?'),
          findsOneWidget,
          reason: 'Subtitle should be "What happened on this day?"',
        );

        // ===== STEP 4: Verify the three options are present =====
        debugPrint('Step 4: Verify three options are present');
        expect(
          find.text('Add nosebleed event'),
          findsOneWidget,
          reason: 'Option 1: "Add nosebleed event" should exist',
        );
        expect(
          find.text('No nosebleed events'),
          findsOneWidget,
          reason: 'Option 2: "No nosebleed events" should exist',
        );
        expect(
          find.text("I don't recall / unknown"),
          findsOneWidget,
          reason: 'Option 3: "I don\'t recall / unknown" should exist',
        );

        // ===== STEP 5: Click "Add nosebleed event" =====
        debugPrint('Step 5: Click "Add nosebleed event"');
        await tester.tap(find.text('Add nosebleed event'));
        await tester.pumpAndSettle();

        // ===== STEP 6: Verify DateHeader shows correct date =====
        debugPrint('Step 6: Verify DateHeader shows selected date');

        // The DateHeader should show the date we selected from the calendar
        // Format: "EEEE, MMMM d" (e.g., "Tuesday, December 17")
        // Note: May find multiple widgets (DateHeader + date picker summary)
        final dateHeaderBeforeTzChange = find.text(expectedDateStr);
        expect(
          dateHeaderBeforeTzChange,
          findsAtLeastNWidgets(1),
          reason:
              'DateHeader should show the calendar-selected date: $expectedDateStr',
        );

        // Debug: Print all text widgets to see current state
        debugPrint('=== Before timezone change ===');
        for (final element in find.byType(Text).evaluate().take(20)) {
          final textWidget = element.widget as Text;
          final data = textWidget.data ?? '';
          if (data.isNotEmpty) {
            debugPrint('Text: "$data"');
          }
        }

        // ===== STEP 7: Change timezone from PST to EST =====
        debugPrint('Step 7: Change timezone from PST to EST');
        await changeTimezone(tester, 'New_York');

        // ===== STEP 8: DEFECT CHECK - Verify DateHeader still shows same date =====
        debugPrint(
          'Step 8: Verify DateHeader STILL shows selected date (DEFECT)',
        );

        // Debug: Print all text widgets after timezone change
        debugPrint('=== After timezone change to EST ===');
        for (final element in find.byType(Text).evaluate().take(20)) {
          final textWidget = element.widget as Text;
          final data = textWidget.data ?? '';
          if (data.isNotEmpty) {
            debugPrint('Text: "$data"');
          }
        }

        // THIS IS THE DEFECT CHECK:
        // Both the DateHeader AND date picker should show the same date.
        // Before timezone change, we found 2 widgets showing the date.
        // After timezone change, we should STILL find 2 widgets showing the
        // same date. If the bug is present, the DateHeader will shift to a
        // different date, leaving only 1 widget with the expected date.
        final dateHeaderAfterTzChange = find.text(expectedDateStr);
        expect(
          dateHeaderAfterTzChange,
          findsNWidgets(2),
          reason:
              'CUR-604 DEFECT: Both DateHeader AND date picker should show the '
              'calendar-selected date ($expectedDateStr) after changing timezone '
              'to EST. Expected 2 widgets, but if the DateHeader shifted due to '
              'timezone conversion, only 1 widget (date picker) will show the '
              'correct date. The timezone affects time display, NOT the calendar '
              'day context.',
        );

        debugPrint('CUR-604 test completed!');
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
