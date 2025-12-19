// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

// CUR-586: Integration test for calendar refresh after deleting the only event
// Tests that:
// 1. Creating an event on a past date turns the calendar date RED
// 2. Deleting that event should turn the calendar date back to GREY
// 3. Navigation via back button properly triggers calendar refresh

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/main.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CET timezone offset in minutes (UTC+1 = 60 minutes)
const int cetOffsetMinutes = 60;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set up flavor for tests
  F.appFlavor = Flavor.dev;
  AppConfig.testApiBaseOverride = 'https://test.example.com/api';

  group('CUR-586: Calendar Refresh After Delete', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Override device timezone to CET for consistent test behavior
      TimezoneConverter.testDeviceOffsetMinutes = cetOffsetMinutes;
      TimezoneService.instance.testTimezoneOverride = 'Europe/Paris';

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('cal_delete_test_');

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
    });

    tearDown(() async {
      // Reset timezone overrides
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;

      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'CUR-586: Calendar date should turn grey after deleting the only event',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Calculate yesterday's date
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final yesterdayDay = yesterday.day.toString();

        // Launch the actual ClinicalDiaryApp
        await tester.pumpWidget(const ClinicalDiaryApp());
        await tester.pumpAndSettle();

        // ===== STEP 1: Click on Calendar tab =====
        debugPrint('Step 1: Click Calendar tab');
        final calendarTab = find.byIcon(Icons.calendar_today);
        expect(
          calendarTab,
          findsOneWidget,
          reason: 'Calendar tab should exist',
        );
        await tester.tap(calendarTab);
        await tester.pumpAndSettle();

        // ===== STEP 2: Verify yesterday is NOT red initially =====
        debugPrint('Step 2: Verify yesterday ($yesterdayDay) is not red');
        final yesterdayText = find.text(yesterdayDay);
        expect(
          yesterdayText,
          findsWidgets,
          reason: 'Yesterday should be visible',
        );

        // Find the day cell and verify it's grey (not recorded)
        final initialDayContainer = _findDayContainer(tester, yesterdayDay);
        expect(
          initialDayContainer.color,
          equals(Colors.grey.shade400),
          reason: 'Day should initially be grey (not recorded)',
        );

        // ===== STEP 3: Click on yesterday to add an event =====
        debugPrint('Step 3: Click on yesterday ($yesterdayDay)');
        await tester.tap(yesterdayText.first);
        await tester.pumpAndSettle();

        // ===== STEP 4: Click "Add nosebleed event" =====
        debugPrint('Step 4: Click Add nosebleed event');
        await tester.tap(find.textContaining('Add nosebleed'));
        await tester.pumpAndSettle();

        // ===== STEP 5: Set start time =====
        debugPrint('Step 5: Click Set Start Time');
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // ===== STEP 6: Select intensity =====
        debugPrint('Step 6: Click Dripping');
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // ===== STEP 7: Set end time (+5 min) =====
        debugPrint('Step 7: Click +5 and Set End Time');
        await tester.tap(find.text('+5'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // ===== STEP 8: Verify we're back at the calendar =====
        debugPrint('Step 8: Verify back on Calendar');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        expect(find.text('Select Date'), findsOneWidget);

        // ===== STEP 9: Verify the day is now RED =====
        debugPrint('Step 9: Verify yesterday ($yesterdayDay) is now red');
        final redDayContainer = _findDayContainer(tester, yesterdayDay);
        expect(
          redDayContainer.color,
          equals(Colors.red),
          reason: 'Day should be red after creating nosebleed event',
        );

        // ===== STEP 10: Click on the red date to view events =====
        debugPrint('Step 10: Click on red date to view events');
        await tester.tap(find.text(yesterdayDay).first);
        await tester.pumpAndSettle();

        // Should show DateRecordsScreen with 1 event
        expect(find.text('1 event'), findsOneWidget);
        expect(find.text('Add new event'), findsOneWidget);

        // ===== STEP 11: Click on the event to edit it =====
        debugPrint('Step 11: Click on event to edit');
        // Find the Card (event list item) and tap it
        final eventCard = find.byType(Card);
        expect(eventCard, findsOneWidget, reason: 'Should have one event card');
        await tester.tap(eventCard);
        await tester.pumpAndSettle();

        // Should be on RecordingScreen for editing
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // ===== STEP 12: Click delete button =====
        debugPrint('Step 12: Click delete button');
        final deleteButton = find.byIcon(Icons.delete_outline);
        expect(
          deleteButton,
          findsOneWidget,
          reason: 'Delete button should exist',
        );
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // ===== STEP 13: Select delete reason and confirm =====
        debugPrint('Step 13: Confirm delete');
        expect(find.text('Delete Record'), findsOneWidget);
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // ===== STEP 14: After delete, navigation returns to calendar =====
        // The navigation flow is: RecordingScreen -> delete -> pop back to calendar
        // (DateRecordsScreen was popped when navigating to RecordingScreen)
        debugPrint('Step 14: Verify back on Calendar after delete');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Debug: show current screen
        debugPrint('=== After delete, checking screen ===');
        for (final element in find.byType(Text).evaluate().take(30)) {
          final textWidget = element.widget as Text;
          debugPrint('Text: "${textWidget.data}"');
        }

        // Verify we're on the calendar
        expect(find.text('Select Date'), findsOneWidget);

        // ===== STEP 15: CRITICAL - Verify the date is NO LONGER RED =====
        // This is where the bug manifests - the date stays red because
        // the calendar doesn't refresh after navigating back
        debugPrint('Step 15: CRITICAL - Verify day is no longer red');

        // Debug: show all text to help diagnose
        debugPrint('=== Calendar state after returning from delete ===');
        for (final element in find.byType(Text).evaluate().take(20)) {
          final textWidget = element.widget as Text;
          debugPrint('Text: "${textWidget.data}"');
        }

        // THIS ASSERTION WILL FAIL WITH THE BUG
        // The day should be grey (not recorded) after deleting the only event
        final finalDayContainer = _findDayContainer(tester, yesterdayDay);
        expect(
          finalDayContainer.color,
          equals(Colors.grey.shade400),
          reason:
              'CUR-586: Day should return to grey after deleting the only event, '
              'but it stays red because calendar does not refresh',
        );

        // Verify the record was actually deleted from datastore
        final allEvents = await Datastore.instance.repository.getAllEvents();
        final activeRecords = allEvents.where(
          (e) =>
              e.eventType == 'NosebleedRecordCreated' &&
              !allEvents.any(
                (d) =>
                    d.eventType == 'NosebleedRecordDeleted' &&
                    d.aggregateId == e.aggregateId,
              ),
        );
        expect(
          activeRecords,
          isEmpty,
          reason: 'No active nosebleed records should exist after delete',
        );

        debugPrint('CUR-586 test completed!');
      },
    );
  });
}

/// Helper to find the decorated container for a specific day in the calendar
BoxDecoration _findDayContainer(WidgetTester tester, String dayText) {
  final dayFinder = find.ancestor(
    of: find.text(dayText),
    matching: find.byType(Container),
  );

  final dayContainers = tester.widgetList<Container>(dayFinder);
  final decoratedContainer = dayContainers.firstWhere(
    (c) => c.decoration != null && c.decoration is BoxDecoration,
    orElse: () =>
        throw StateError('No decorated container found for day $dayText'),
  );

  return decoratedContainer.decoration! as BoxDecoration;
}
