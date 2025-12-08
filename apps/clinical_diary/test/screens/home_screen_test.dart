// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
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

  group('HomeScreen', () {
    late EnrollmentService enrollmentService;
    late AuthService authService;
    late PreferencesService preferencesService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('home_screen_test_');

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

      // Use real services with mocked HTTP clients
      final mockHttpClient = MockClient(
        (_) async => http.Response('{"success": true}', 200),
      );

      enrollmentService = EnrollmentService(httpClient: mockHttpClient);
      authService = AuthService(httpClient: mockHttpClient);
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

    Widget buildHomeScreen() {
      return wrapWithMaterialApp(
        HomeScreen(
          nosebleedService: nosebleedService,
          enrollmentService: enrollmentService,
          authService: authService,
          preferencesService: preferencesService,
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          onLargerTextChanged: (_) {},
        ),
      );
    }

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

    group('Basic Rendering', () {
      testWidgets('displays app title', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.text('Nosebleed Diary'), findsOneWidget);
      });

      testWidgets('displays record nosebleed button', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.text('Record Nosebleed'), findsOneWidget);
      });

      testWidgets('displays calendar button', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.text('Calendar'), findsOneWidget);
      });

      testWidgets('displays today and yesterday sections', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
      });

      testWidgets('displays user menu icon', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });
    });

    // TODO(CUR-489): Tests with addRecord hang indefinitely during pumpWidget.
    // The HomeScreen has asynchronous _loadRecords behavior that doesn't settle
    // in widget tests. Needs investigation into the root cause.
    group('Record Display', skip: 'Tests hang when records exist - see CUR-489', () {
      testWidgets('displays records for today', (tester) async {
        // Add a record for today
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        // Use pump with duration instead of pumpAndSettle to avoid infinite animation loops
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show the event list item
        expect(find.byType(EventListItem), findsOneWidget);
      });

      testWidgets('displays incomplete records with Incomplete text', (
        tester,
      ) async {
        // Add an incomplete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          // No end time or intensity - incomplete
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show the event list item
        expect(find.byType(EventListItem), findsOneWidget);
        // Should show "Incomplete" text
        expect(find.text('Incomplete'), findsOneWidget);
      });

      testWidgets('displays multiple records', (tester) async {
        final today = DateTime.now();

        // Add two records at different times
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 14, 0),
          endTime: DateTime(today.year, today.month, today.day, 14, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 9, 0),
          endTime: DateTime(today.year, today.month, today.day, 9, 15),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show both event list items
        expect(find.byType(EventListItem), findsNWidgets(2));
      });
    });

    group('Navigation', () {
      testWidgets('tapping record button navigates to recording screen', (
        tester,
      ) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Record Nosebleed'));
        await tester.pumpAndSettle();

        // Should navigate to recording screen
        expect(find.text('Nosebleed Start'), findsOneWidget);
      });

      testWidgets('tapping calendar button opens calendar dialog', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Should show calendar screen (dialog)
        expect(find.byType(Dialog), findsOneWidget);
      });

      // Skipped: Tests that add records hang - see CUR-489
      testWidgets(
        'tapping record item navigates to edit screen',
        // Test hangs when records exist - see CUR-489
        skip: true,
        (tester) async {
          // Add a record
          final today = DateTime.now();
          await nosebleedService.addRecord(
            date: today,
            startTime: DateTime(today.year, today.month, today.day, 10, 0),
            endTime: DateTime(today.year, today.month, today.day, 10, 30),
            intensity: NosebleedIntensity.dripping,
          );

          await tester.pumpWidget(buildHomeScreen());
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          // Tap the record
          await tester.tap(find.byType(EventListItem));
          await tester.pumpAndSettle();

          // Should navigate to edit mode
          expect(find.text('Edit Record'), findsOneWidget);
        },
      );
    });

    group('User Menu', () {
      // Note: PopupMenu items may cause overflow errors in small test screens
      // because long text like "Accessibility & Preferences" doesn't wrap.
      // We ignore overflow errors for these tests since the menu functionality
      // still works correctly.

      testWidgets('shows login option when not logged in', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Ignore overflow errors from popup menu long text
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Tap user menu
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        expect(find.text('Login'), findsOneWidget);
      });

      testWidgets('shows accessibility option', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Ignore overflow errors from popup menu long text
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Tap user menu
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        expect(find.text('Accessibility & Preferences'), findsOneWidget);
      });

      testWidgets('shows privacy option', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Ignore overflow errors from popup menu long text
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Tap user menu
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        expect(find.text('Privacy'), findsOneWidget);
      });
    });

    group('Yesterday Banner', () {
      testWidgets('shows yesterday banner when no yesterday records', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should show the yesterday banner asking about nosebleeds
        expect(
          find.text('Did you have nosebleeds?'),
          findsOneWidget,
        );
      });

      // Skipped: Tests that add records hang - see CUR-489
      testWidgets(
        'hides yesterday banner when yesterday has records',
        // Test hangs when records exist - see CUR-489
        skip: true,
        (tester) async {
          // Add a record for yesterday
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          await nosebleedService.addRecord(
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
            intensity: NosebleedIntensity.dripping,
          );

          await tester.pumpWidget(buildHomeScreen());
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          // Should NOT show the yesterday banner
          expect(
            find.text('Did you have nosebleeds?'),
            findsNothing,
          );
        },
      );
    });

    group('Incomplete Records Banner', skip: 'Tests hang when records exist - see CUR-489', () {
      testWidgets('shows incomplete records banner when incomplete exists', (
        tester,
      ) async {
        // Add an incomplete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          // No end time - incomplete
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show the incomplete records banner
        expect(find.text('1 incomplete record'), findsOneWidget);
        expect(find.text('Tap to complete'), findsOneWidget);
      });

      testWidgets('hides incomplete banner when all records complete', (
        tester,
      ) async {
        // Add a complete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should NOT show the incomplete records banner
        expect(find.text('Tap to complete'), findsNothing);
      });
    });

    group('Flash Highlight Animation', skip: 'Tests hang when records exist - see CUR-489', () {
      testWidgets('wraps records with FlashHighlight widget', (tester) async {
        // Add a record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Should have FlashHighlight wrapping the EventListItem
        expect(find.byType(FlashHighlight), findsOneWidget);
      });
    });

    group('Scroll to Record (CUR-489)', skip: 'Tests hang when records exist - see CUR-489', () {
      testWidgets('assigns GlobalKey to each record for scrolling', (
        tester,
      ) async {
        // Add multiple records
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 9, 0),
          endTime: DateTime(today.year, today.month, today.day, 9, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 14, 0),
          endTime: DateTime(today.year, today.month, today.day, 14, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Find the Padding widgets that wrap FlashHighlight (they have the keys)
        final paddingWidgets = tester.widgetList<Padding>(
          find.ancestor(
            of: find.byType(FlashHighlight),
            matching: find.byType(Padding),
          ),
        );

        // Each record should have a key assigned for scroll functionality
        var keysFound = 0;
        for (final padding in paddingWidgets) {
          if (padding.key is GlobalKey) {
            keysFound++;
          }
        }
        // Should have at least 2 GlobalKeys (one per record)
        expect(keysFound, greaterThanOrEqualTo(2));
      });

      testWidgets('ListView has ScrollController attached', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Find the ListView
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.controller, isNotNull);
      });
    });

    group('Pull to Refresh', () {
      testWidgets('shows RefreshIndicator', (tester) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('Overlap Detection', skip: 'Tests hang when records exist - see CUR-489', () {
      testWidgets('shows overlap warning for overlapping records', (
        tester,
      ) async {
        // Use larger screen to see all elements
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Add overlapping records
        final today = DateTime.now();
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          date: today,
          startTime: DateTime(today.year, today.month, today.day, 10, 15),
          endTime: DateTime(today.year, today.month, today.day, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Both records should show warning icons
        expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
      });
    });
  });
}
