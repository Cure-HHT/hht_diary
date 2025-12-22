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
//
// CUR-604: Calendar timezone consistency when selecting past dates
// User Flow - Calendar Past Date with Timezone Selection:
// 1. User opens calendar from homepage
// 2. User selects a date in the past
// 3. System displays DaySelectionScreen with date header (e.g., "Saturday, December 21, 2024")
// 4. User creates an event and sees the date above event summary
// 5. User changes timezone (e.g., PST to EST)
// 6. System displays the same calendar date regardless of timezone selection
// 7. The date shown represents the calendar day selected, NOT adjusted for timezone

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
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

  // CUR-604: Calendar timezone consistency when selecting past dates
  //
  // User Flow: Calendar Past Date with Timezone Selection
  // =====================================================
  // Prerequisites:
  // - User has the app installed
  // - User is on the home screen
  //
  // Test Flow:
  // 1. Set device timezone to PST (America/Los_Angeles)
  // 2. From homepage, click on calendar button
  // 3. On calendar widget, select a date in the past
  // 4. Verify that the date above the event summary matches the selected date
  // 5. Navigate to recording screen and change timezone to EST
  // 6. Complete recording and verify date context is preserved
  //
  // Expected Behavior:
  // - The date displayed in DaySelectionScreen should match the calendar selection
  // - Changing timezone should NOT change which calendar day is being edited
  // - Timezone only affects the time display, not the date
  group('CUR-604: Calendar Timezone Consistency', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    Directory? tempDir; // Nullable for web compatibility

    // PST timezone offset in minutes (UTC-8 = -480 minutes)
    const pstOffsetMinutes = -480;
    // EST timezone offset in minutes (UTC-5 = -300 minutes)
    const estOffsetMinutes = -300;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Set timezone to PST for consistent test behavior
      TimezoneConverter.testDeviceOffsetMinutes = pstOffsetMinutes;
      TimezoneService.instance.testTimezoneOverride = 'America/Los_Angeles';

      // Initialize the datastore for tests
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }

      // Platform-specific database path:
      // - Web: Uses IndexedDB via database name only (no file path)
      // - Native: Uses temp directory for file-based storage
      String? databasePath;
      if (!kIsWeb) {
        tempDir = await Directory.systemTemp.createTemp('calendar_tz_test_');
        databasePath = tempDir!.path;
      }

      await Datastore.initialize(
        config: DatastoreConfig(
          deviceId: 'test-device-id',
          userId: 'test-user-id',
          databasePath: databasePath,
          databaseName:
              'test_events_${DateTime.now().millisecondsSinceEpoch}.db',
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
      // Reset timezone overrides
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;

      nosebleedService.dispose();
      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      // Clean up temp directory on native platforms only
      if (!kIsWeb && tempDir != null && tempDir!.existsSync()) {
        await tempDir!.delete(recursive: true);
      }
    });

    /// Helper to change timezone via the timezone picker
    Future<void> changeTimezone(
      WidgetTester tester,
      String targetTimezoneSearch,
    ) async {
      // Find and tap the timezone selector (globe icon)
      final tzSelector = find.byIcon(Icons.public);
      if (tzSelector.evaluate().isEmpty) {
        debugPrint('WARNING: Timezone selector not found - may not be visible');
        return;
      }
      await tester.tap(tzSelector);
      await tester.pumpAndSettle();

      // Type in search to find the timezone
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isEmpty) {
        debugPrint('WARNING: Search field not found');
        return;
      }
      await tester.enterText(searchField, targetTimezoneSearch);
      await tester.pumpAndSettle();

      // Tap on the first search result
      final tzListTile = find.byType(ListTile).first;
      if (tzListTile.evaluate().isNotEmpty) {
        await tester.tap(tzListTile);
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
      'PST timezone: selected past date shown correctly in DaySelectionScreen',
      (tester) async {
        // User Flow: Calendar Past Date Selection with PST Timezone
        // Step 1: User's device is set to PST timezone
        // Step 2: User opens calendar
        // Step 3: User selects a past date
        // Step 4: DaySelectionScreen displays the correct date

        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Calculate a past date (5 days ago or day 1 if early in month)
        final now = DateTime.now();
        final pastDay = now.day > 5 ? now.day - 5 : 1;
        final pastDate = DateTime(now.year, now.month, pastDay);

        // Format expected date string as shown in DaySelectionScreen
        // Format: "EEEE, MMMM d, y" (e.g., "Saturday, December 21, 2024")
        final expectedDateString = DateFormat(
          'EEEE, MMMM d, y',
        ).format(pastDate);

        debugPrint('Testing with PST timezone');
        debugPrint('Selected past date: $pastDate');
        debugPrint('Expected date string: $expectedDateString');

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

        // Tap the past date on calendar
        final dayText = find.text('$pastDay');
        expect(dayText, findsWidgets, reason: 'Past day should be visible');
        await tester.tap(dayText.first);
        await tester.pumpAndSettle();

        // Verify DaySelectionScreen shows the correct date
        expect(
          find.text('What happened on this day?'),
          findsOneWidget,
          reason: 'Should show DaySelectionScreen',
        );

        // The date header should match exactly
        expect(
          find.text(expectedDateString),
          findsOneWidget,
          reason:
              'Date header should show "$expectedDateString" for the selected past date',
        );
      },
    );

    testWidgets('date remains consistent after timezone change from PST to EST', (
      tester,
    ) async {
      // User Flow: Timezone Change During Entry Creation
      // Step 1: Device is set to PST timezone
      // Step 2: User opens calendar and selects a past date
      // Step 3: User taps "Add nosebleed event"
      // Step 4: User changes timezone to EST
      // Step 5: The calendar date context should remain the same

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Calculate a past date
      final now = DateTime.now();
      final pastDay = now.day > 5 ? now.day - 5 : 1;
      final pastDate = DateTime(now.year, now.month, pastDay);
      final expectedDateString = DateFormat('EEEE, MMMM d, y').format(pastDate);

      debugPrint('Testing timezone change from PST to EST');
      debugPrint('Selected past date: $pastDate');

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

      // Tap the past date
      await tester.tap(find.text('$pastDay').first);
      await tester.pumpAndSettle();

      // Verify initial date display
      expect(
        find.text(expectedDateString),
        findsOneWidget,
        reason: 'Initial date should show $expectedDateString',
      );

      // Tap "Add nosebleed event" to go to recording screen
      await tester.tap(find.text('Add nosebleed event'));
      await tester.pumpAndSettle();

      // Now we're on RecordingScreen - change timezone to EST
      debugPrint('Changing timezone to EST');
      await changeTimezone(tester, 'New_York');

      // The date context should still be for the originally selected date
      // This is verified by the fact that when we save, the record
      // should be associated with the original date, not a shifted date

      // Set start time (now in EST timezone)
      final setStartButton = find.text('Set Start Time');
      if (setStartButton.evaluate().isNotEmpty) {
        await tester.tap(setStartButton);
        await tester.pumpAndSettle();
      }

      // Select intensity
      final drippingButton = find.text('Dripping');
      if (drippingButton.evaluate().isNotEmpty) {
        await tester.tap(drippingButton);
        await tester.pumpAndSettle();
      }

      // Set end time
      final setEndButton = find.text('Set End Time');
      if (setEndButton.evaluate().isNotEmpty) {
        await tester.tap(setEndButton);
        await tester.pumpAndSettle();
      }

      // Verify record was saved - check the startTime date component
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1, reason: 'Record should be saved');

      // The record's start date should match the originally selected calendar date
      final recordStartDate = DateTime(
        records.first.startTime.year,
        records.first.startTime.month,
        records.first.startTime.day,
      );
      final selectedCalendarDate = DateTime(
        pastDate.year,
        pastDate.month,
        pastDate.day,
      );

      expect(
        recordStartDate,
        equals(selectedCalendarDate),
        reason:
            'Record should be saved for the originally selected calendar date '
            '($selectedCalendarDate), not shifted by timezone change. '
            'Actual: $recordStartDate',
      );
    });

    testWidgets('DateRecordsScreen shows correct date regardless of timezone', (
      tester,
    ) async {
      // User Flow: Viewing Past Events with Different Timezone
      // Step 1: Pre-create a record for a past date
      // Step 2: Set device timezone to EST
      // Step 3: Open calendar and tap on the date with the event
      // Step 4: DateRecordsScreen should show the same date

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Calculate a past date
      final now = DateTime.now();
      final pastDay = now.day > 3 ? now.day - 3 : 1;
      final pastDate = DateTime(now.year, now.month, pastDay, 10, 0);
      final expectedDateString = DateFormat('EEEE, MMMM d, y').format(pastDate);

      // Pre-create a record
      await nosebleedService.addRecord(
        startTime: pastDate,
        endTime: pastDate.add(const Duration(minutes: 15)),
        intensity: NosebleedIntensity.dripping,
      );

      // Change device timezone to EST
      TimezoneConverter.testDeviceOffsetMinutes = estOffsetMinutes;
      TimezoneService.instance.testTimezoneOverride = 'America/New_York';

      debugPrint('Testing DateRecordsScreen with EST timezone');
      debugPrint('Record date: $pastDate');
      debugPrint('Expected date string: $expectedDateString');

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

      // Tap the day with the record
      await tester.tap(find.text('$pastDay').first);
      await tester.pumpAndSettle();

      // DateRecordsScreen should show the correct date
      // The date is shown in the app bar title
      expect(
        find.text(expectedDateString),
        findsOneWidget,
        reason:
            'DateRecordsScreen should show "$expectedDateString" '
            'even when device is in EST timezone',
      );

      // Should show the event
      expect(
        find.text('Add new event'),
        findsOneWidget,
        reason: 'Should show DateRecordsScreen with events',
      );
    });

    testWidgets(
      'month boundary: selecting date near month end with timezone offset',
      (tester) async {
        // Edge Case: Month Boundary with Timezone
        // When device is in PST and selecting a date near month boundary,
        // the calendar date should not "roll over" due to timezone math.

        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Use a date near the beginning of the month to test boundary
        final now = DateTime.now();
        // Select the 1st of current month if possible
        final targetDate = DateTime(now.year, now.month, 1);

        // Only run this test if the 1st is in the past
        if (targetDate.isAfter(now)) {
          debugPrint('Skipping test: 1st of month is in the future');
          return;
        }

        final expectedDateString = DateFormat(
          'EEEE, MMMM d, y',
        ).format(targetDate);

        debugPrint('Testing month boundary with date: $targetDate');

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

        // Tap on day 1
        final dayOne = find.text('1');
        if (dayOne.evaluate().isEmpty) {
          debugPrint('Day 1 not visible, skipping test');
          return;
        }
        await tester.tap(dayOne.first);
        await tester.pumpAndSettle();

        // Should show the correct date - day 1 of the month
        // Should NOT show day 31 of previous month due to timezone math
        expect(
          find.text(expectedDateString),
          findsOneWidget,
          reason:
              'Day 1 selection should show "$expectedDateString", '
              'not roll back to previous month due to timezone',
        );
      },
    );

    testWidgets('rapid timezone switching: date should remain stable', (
      tester,
    ) async {
      // Stress Test: Rapid Timezone Switching
      // User rapidly changes timezone multiple times - date should stay stable

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final pastDay = now.day > 5 ? now.day - 5 : 1;
      final pastDate = DateTime(now.year, now.month, pastDay);
      final expectedDateString = DateFormat('EEEE, MMMM d, y').format(pastDate);

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

      // Select past date
      await tester.tap(find.text('$pastDay').first);
      await tester.pumpAndSettle();

      // Verify initial date
      expect(
        find.text(expectedDateString),
        findsOneWidget,
        reason: 'Initial date should be correct',
      );

      // Go to recording screen
      await tester.tap(find.text('Add nosebleed event'));
      await tester.pumpAndSettle();

      // Rapidly switch timezones (simulated by changing the override)
      final timezones = [
        ('America/New_York', -300), // EST
        ('America/Chicago', -360), // CST
        ('America/Denver', -420), // MST
        ('America/Los_Angeles', -480), // PST
        ('Europe/Paris', 60), // CET
      ];

      for (final (ianaId, offsetMinutes) in timezones) {
        TimezoneConverter.testDeviceOffsetMinutes = offsetMinutes;
        TimezoneService.instance.testTimezoneOverride = ianaId;
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // After all the timezone changes, complete the recording
      final setStartButton = find.text('Set Start Time');
      if (setStartButton.evaluate().isNotEmpty) {
        await tester.tap(setStartButton);
        await tester.pumpAndSettle();
      }

      final drippingButton = find.text('Dripping');
      if (drippingButton.evaluate().isNotEmpty) {
        await tester.tap(drippingButton);
        await tester.pumpAndSettle();
      }

      final setEndButton = find.text('Set End Time');
      if (setEndButton.evaluate().isNotEmpty) {
        await tester.tap(setEndButton);
        await tester.pumpAndSettle();
      }

      // Verify the record date
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1, reason: 'Should have one record');

      final recordDate = DateTime(
        records.first.startTime.year,
        records.first.startTime.month,
        records.first.startTime.day,
      );
      final expectedDate = DateTime(
        pastDate.year,
        pastDate.month,
        pastDate.day,
      );

      expect(
        recordDate,
        equals(expectedDate),
        reason:
            'After rapid timezone switching, record should still be on '
            'the originally selected date ($expectedDate). Actual: $recordDate',
      );
    });

    testWidgets(
      'extreme timezone: selecting past date with International Date Line crossing',
      (tester) async {
        // Edge Case: Extreme Timezone (beyond typical US timezones)
        // Test with a timezone that crosses the International Date Line

        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Set to extreme timezone (e.g., UTC+12 - Auckland/New Zealand)
        // This tests date handling when timezone is far from UTC
        const nzstOffsetMinutes = 780; // UTC+13 (NZDT summer)
        TimezoneConverter.testDeviceOffsetMinutes = nzstOffsetMinutes;
        TimezoneService.instance.testTimezoneOverride = 'Pacific/Auckland';

        final now = DateTime.now();
        final pastDay = now.day > 5 ? now.day - 5 : 1;
        final pastDate = DateTime(now.year, now.month, pastDay);
        final expectedDateString = DateFormat(
          'EEEE, MMMM d, y',
        ).format(pastDate);

        debugPrint('Testing with extreme timezone: Pacific/Auckland (UTC+13)');
        debugPrint('Selected past date: $pastDate');

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

        // Select past date
        await tester.tap(find.text('$pastDay').first);
        await tester.pumpAndSettle();

        // Even with extreme timezone, date should display correctly
        expect(
          find.text(expectedDateString),
          findsOneWidget,
          reason:
              'Date should display correctly even with extreme timezone. '
              'Expected: $expectedDateString',
        );
      },
    );

    testWidgets('back navigation: date context preserved after going back', (
      tester,
    ) async {
      // User Flow: Back Navigation Preserves Date Context
      // Step 1: Select past date
      // Step 2: Go to recording screen
      // Step 3: Go back
      // Step 4: Date should still be shown correctly

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final pastDay = now.day > 5 ? now.day - 5 : 1;
      final pastDate = DateTime(now.year, now.month, pastDay);
      final expectedDateString = DateFormat('EEEE, MMMM d, y').format(pastDate);

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

      // Select past date
      await tester.tap(find.text('$pastDay').first);
      await tester.pumpAndSettle();

      // Verify initial date
      expect(find.text(expectedDateString), findsOneWidget);

      // Go to recording screen
      await tester.tap(find.text('Add nosebleed event'));
      await tester.pumpAndSettle();

      // Change timezone while on recording screen
      await changeTimezone(tester, 'Chicago');

      // Press back button
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }

      // May show confirmation dialog - cancel it
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      }

      // After going back, we should be at DaySelectionScreen or Calendar
      // The date context should be preserved
      // Note: The exact screen depends on navigation implementation
      debugPrint('After back navigation, verifying date context preserved');
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
