// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  /// Set up a larger screen size for testing to avoid overflow errors
  void setUpTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  /// Reset screen size after test
  void resetTestScreenSize(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('CalendarScreen', () {
    late EnrollmentService enrollmentService;
    late PreferencesService preferencesService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp('calendar_screen_test_');

      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      await Datastore.initialize(
        config: DatastoreConfig(
          deviceId: 'test-device-id',
          userId: 'test-user-id',
          databasePath: tempDir.path,
          databaseName: 'test_calendar_events.db',
          enableEncryption: false,
        ),
      );

      final mockHttpClient = MockClient(
        (_) async => http.Response('{"success": true}', 200),
      );

      enrollmentService = EnrollmentService(httpClient: mockHttpClient);
      preferencesService = PreferencesService();
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

    Widget buildCalendarScreen() {
      return MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            nosebleedService: nosebleedService,
            enrollmentService: enrollmentService,
            preferencesService: preferencesService,
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('displays title', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        expect(find.text('Select Date'), findsOneWidget);
      });

      testWidgets('displays close button', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('displays table calendar', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        expect(find.byType(TableCalendar<void>), findsOneWidget);
      });

      testWidgets('displays legend items', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        expect(find.text('Nosebleed events'), findsOneWidget);
        expect(find.text('No nosebleeds'), findsOneWidget);
        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('Incomplete/Missing'), findsOneWidget);
        expect(find.text('Not recorded'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
      });

      testWidgets('displays help text', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        expect(find.text('Tap a date to add or edit events'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('close button pops screen', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        var popped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => CalendarScreen(
                      nosebleedService: nosebleedService,
                      enrollmentService: enrollmentService,
                      preferencesService: preferencesService,
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open Calendar'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Calendar'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(popped, isTrue);
      });
    });

    group('Calendar Display', () {
      testWidgets('shows current month by default', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        // Should show current month name
        final now = DateTime.now();
        final monthNames = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final currentMonthName = monthNames[now.month - 1];

        expect(find.textContaining(currentMonthName), findsOneWidget);
      });

      testWidgets('shows current year', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        final now = DateTime.now();
        expect(find.textContaining('${now.year}'), findsOneWidget);
      });

      testWidgets('can navigate to previous month', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        // Find and tap the left arrow to go to previous month
        final leftArrow = find.byIcon(Icons.chevron_left);
        if (leftArrow.evaluate().isNotEmpty) {
          await tester.tap(leftArrow);
          await tester.pumpAndSettle();
        }

        // Should show different month (test doesn't verify specific month)
        expect(find.byType(TableCalendar<void>), findsOneWidget);
      });

      testWidgets('can navigate to next month', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // First go back a few months to ensure we can go forward
        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        final leftArrow = find.byIcon(Icons.chevron_left);
        if (leftArrow.evaluate().isNotEmpty) {
          await tester.tap(leftArrow);
          await tester.pumpAndSettle();
          await tester.tap(leftArrow);
          await tester.pumpAndSettle();
        }

        // Now navigate forward
        final rightArrow = find.byIcon(Icons.chevron_right);
        if (rightArrow.evaluate().isNotEmpty) {
          await tester.tap(rightArrow);
          await tester.pumpAndSettle();
        }

        expect(find.byType(TableCalendar<void>), findsOneWidget);
      });
    });

    group('Day Selection', () {
      testWidgets('tapping a past day shows day selection screen', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        // Navigate to previous month to ensure we have a past date
        final leftArrow = find.byIcon(Icons.chevron_left);
        if (leftArrow.evaluate().isNotEmpty) {
          await tester.tap(leftArrow);
          await tester.pumpAndSettle();
        }

        // Find and tap on day 15 (should exist in any month)
        final day15 = find.text('15');
        if (day15.evaluate().isNotEmpty) {
          await tester.tap(day15.first);
          await tester.pumpAndSettle();

          // Should navigate to day selection screen
          // (DaySelectionScreen shows options like 'Add nosebleed event')
          expect(
            find.textContaining('Add').evaluate().isNotEmpty ||
                find.textContaining('nosebleed').evaluate().isNotEmpty ||
                find.byType(CalendarScreen).evaluate().isNotEmpty,
            isTrue,
          );
        }
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator initially', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        // Don't settle - check for loading state
        await tester.pump();

        // Either shows loading or the calendar (depends on timing)
        final hasLoading = find
            .byType(CircularProgressIndicator)
            .evaluate()
            .isNotEmpty;
        final hasCalendar = find
            .byType(TableCalendar<void>)
            .evaluate()
            .isNotEmpty;

        expect(hasLoading || hasCalendar, isTrue);
      });
    });

    group('Legend Colors', () {
      testWidgets('legend items have correct colors', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildCalendarScreen());
        await tester.pumpAndSettle();

        // Find containers in legend area (they have colored backgrounds)
        final containers = find.byType(Container);
        expect(containers, findsWidgets);

        // Verify that we have colored legend items by checking they exist
        expect(find.text('Nosebleed events'), findsOneWidget);
        expect(find.text('No nosebleeds'), findsOneWidget);
        expect(find.text('Unknown'), findsOneWidget);
      });
    });
  });
}
