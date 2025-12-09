// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

// Integration test for HomeScreen with records
// Moved from test/screens/home_screen_test.dart because:
// - Tests with records need full async handling
// - Datastore transactions complete properly in integration tests

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set up flavor for tests
  F.appFlavor = Flavor.dev;
  AppConfig.testApiBaseOverride = 'https://test.example.com/api';

  group('HomeScreen Integration Tests', () {
    late EnrollmentService enrollmentService;
    late AuthService authService;
    late PreferencesService preferencesService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('home_screen_int_test_');

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
      return MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeScreen(
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

    group('Record Display', () {
      testWidgets('displays records for today', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add a record for today
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should show the event list item
        expect(find.byType(EventListItem), findsOneWidget);
      });

      testWidgets('displays incomplete records with Incomplete text', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add an incomplete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          // No end time or intensity - incomplete
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should show the event list item
        expect(find.byType(EventListItem), findsOneWidget);
        // Should show "Incomplete" text
        expect(find.text('Incomplete'), findsOneWidget);
      });

      testWidgets('displays multiple records', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final today = DateTime.now();

        // Add two records at different times
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 14, 0),
          endTime: DateTime(today.year, today.month, today.day, 14, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 9, 0),
          endTime: DateTime(today.year, today.month, today.day, 9, 15),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should show both event list items
        expect(find.byType(EventListItem), findsNWidgets(2));
      });
    });

    group('Navigation with Records', () {
      testWidgets('tapping record item navigates to edit screen', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add a record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Tap the record
        await tester.tap(find.byType(EventListItem));
        await tester.pumpAndSettle();

        // Should navigate to edit mode
        expect(find.text('Edit Record'), findsOneWidget);
      });
    });

    group('Yesterday Banner with Records', () {
      testWidgets('hides yesterday banner when yesterday has records', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add a record for yesterday
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await nosebleedService.addRecord(
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
        await tester.pumpAndSettle();

        // Should NOT show the yesterday banner
        expect(find.text('Did you have nosebleeds?'), findsNothing);
      });
    });

    group('Incomplete Records Banner', () {
      testWidgets('shows incomplete records banner when incomplete exists', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add an incomplete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          // No end time - incomplete
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should show the incomplete records banner
        expect(find.text('1 incomplete record'), findsOneWidget);
        expect(find.text('Tap to complete'), findsOneWidget);
      });

      testWidgets('hides incomplete banner when all records complete', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add a complete record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should NOT show the incomplete records banner
        expect(find.text('Tap to complete'), findsNothing);
      });
    });

    group('Flash Highlight Animation', () {
      testWidgets('wraps records with FlashHighlight widget', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add a record
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Should have FlashHighlight wrapping the EventListItem
        expect(find.byType(FlashHighlight), findsOneWidget);
      });
    });

    group('Scroll to Record (CUR-489)', () {
      testWidgets('assigns GlobalKey to each record for scrolling', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add multiple records
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 9, 0),
          endTime: DateTime(today.year, today.month, today.day, 9, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 14, 0),
          endTime: DateTime(today.year, today.month, today.day, 14, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

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
    });

    group('Overlap Detection', () {
      testWidgets('shows overlap warning for overlapping records', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Add overlapping records
        final today = DateTime.now();
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 30),
          intensity: NosebleedIntensity.spotting,
        );
        await nosebleedService.addRecord(
          startTime: DateTime(today.year, today.month, today.day, 10, 15),
          endTime: DateTime(today.year, today.month, today.day, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Both records should show warning icons
        expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
      });
    });
  });
}
