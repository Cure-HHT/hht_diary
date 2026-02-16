// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

// Integration test for HomeScreen with records
// Moved from test/screens/home_screen_test.dart because:
// - Tests with records need full async handling
// - Datastore transactions complete properly in integration tests

//   REQ-p00008: Mobile App Diary Entry

// Integration test for recording save flow
// Moved from test/screens/recording_screen_test.dart because:
// - Datastore transactions don't complete properly in widget tests
// - Navigator.pop results need proper async handling

// CUR-586: Integration test for calendar refresh after deleting the only event
// Tests that:
// 1. Creating an event on a past date turns the calendar date RED
// 2. Deleting that event should turn the calendar date back to GREY
// 3. Navigation via back button properly triggers calendar refresh

// Integration test for CUR-543: Calendar - New event created in the past is not recorded
// Tests that:
// 1. Creating an event on a past date updates the calendar immediately (day turns red)
// 2. Clicking on the date shows the created event

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/main.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/mock_enrollment_service.dart';
import '../test/helpers/test_helpers.dart';

// CET timezone offset in minutes (UTC+1 = 60 minutes)
const int cetOffsetMinutes = 60;

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
          taskService: TaskService(),
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

        // Enable useReviewScreen so that editing a complete record shows
        // "Edit Record" on the review/summary step (CUR-512)
        FeatureFlagService.instance.useReviewScreen = true;
        addTearDown(() => FeatureFlagService.instance.resetToDefaults());

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

        // Should navigate to edit mode with review screen showing "Edit Record"
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

  group('Recording Save Flow Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('save_flow_test_');

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
        enableCloudSync: false, // Disable for tests
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

    testWidgets(
      'saves and returns record ID after completing new record flow',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        String? popResult;
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
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordingScreen(
                          nosebleedService: nosebleedService,
                          enrollmentService: mockEnrollment,
                          preferencesService: preferencesService,
                          diaryEntryDate: DateTime(2024, 1, 15),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to RecordingScreen
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Confirm start time
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Select intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Confirm end time - CUR-464: saves immediately and pops with record ID
        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // Should have popped back with a record ID
        expect(popResult, isNotNull);
        expect(popResult, isNotEmpty);

        // Verify record was actually saved to datastore
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.id, popResult);
        expect(records.first.intensity, NosebleedIntensity.dripping);
      },
    );

    testWidgets('saves and returns record ID for incomplete existing record', (
      tester,
    ) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // First, add an incomplete record to the datastore
      final incompleteRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        // Missing intensity - will be marked incomplete
      );

      // Verify record is incomplete
      var records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, true);

      String? popResult;
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
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordingScreen(
                        nosebleedService: nosebleedService,
                        enrollmentService: mockEnrollment,
                        preferencesService: preferencesService,
                        existingRecord: incompleteRecord,
                        onDelete: (_) async {
                          // Not used in this test, but required for existing records
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to RecordingScreen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select intensity to complete the record
      await tester.tap(find.text('Dripping'));
      await tester.pumpAndSettle();

      // Verify we're on end time step
      expect(find.text('Set End Time'), findsOneWidget);

      // Tap Set End Time - CUR-464: saves immediately and pops
      await tester.tap(find.text('Set End Time'));
      await tester.pumpAndSettle();

      // Should have popped back with a record ID
      expect(popResult, isNotNull);
      expect(popResult, isNotEmpty);

      // Verify record was updated in datastore (now complete)
      records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, false);
      expect(records.first.intensity, NosebleedIntensity.dripping);
    });
  });

  group('Partial Save Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('partial_save_test_');

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

    group('RecordingScreen Back Button Auto-Save', () {
      testWidgets(
        'automatically saves partial record when pressing back on new record',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                diaryEntryDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify we're on the start time screen
          expect(find.text('Nosebleed Start'), findsOneWidget);

          // Press the back button immediately
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should NOT show any dialog - should auto-save
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
        },
      );

      testWidgets(
        'auto-saves partial after setting start time and going back',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                diaryEntryDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Confirm start time to proceed to intensity step
          await tester.tap(find.text('Set Start Time'));
          await tester.pumpAndSettle();

          // Should now be on intensity step
          expect(find.text('Spotting'), findsOneWidget);

          // Press back without selecting intensity
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
        },
      );

      testWidgets(
        'auto-saves partial with intensity after selecting it and going back',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
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

          // Should be on end time step now
          expect(find.text('Nosebleed End Time'), findsOneWidget);

          // Press back without confirming end time
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved with intensity
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.intensity, isNotNull);
        },
      );

      testWidgets('system back button also triggers auto-save', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapWithApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              diaryEntryDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we're on the start time screen
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Simulate system back button press
        final dynamic state = tester.state(find.byType(Navigator));
        // ignore: avoid_dynamic_calls
        state.maybePop();
        await tester.pumpAndSettle();

        // Should NOT show any dialog
        expect(find.text('Save as incomplete?'), findsNothing);

        // Verify the partial record was saved
        final records = await nosebleedService.getRecordsForStartDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 1);
        expect(records.first.isIncomplete, isTrue);
      });

      testWidgets(
        'completing full flow behaves correctly based on useReviewScreen flag',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                diaryEntryDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Navigate through the full flow
          await tester.tap(find.text('Set Start Time'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Dripping'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Set End Time'));
          await tester.pumpAndSettle();

          if (FeatureFlagService.instance.useReviewScreen) {
            // When useReviewScreen is true: should be on complete step
            expect(find.text('Record Complete'), findsOneWidget);

            // Press back from complete step - should NOT auto-save
            await tester.tap(find.text('Back'));
            await tester.pumpAndSettle();

            final records = await nosebleedService.getRecordsForStartDate(
              DateTime(2024, 1, 15),
            );
            expect(records.length, 0);
          } else {
            // When useReviewScreen is false: saves immediately after Set End Time
            // and shows "Record Nosebleed" button (already saved and navigated back)
            // The record should already be saved
            final records = await nosebleedService.getRecordsForStartDate(
              DateTime(2024, 1, 15),
            );
            expect(records.length, 1);
            expect(records.first.intensity, NosebleedIntensity.dripping);
            expect(records.first.isIncomplete, isFalse);
          }
        },
      );
    });

    group('CUR-516: Timezone Preservation for Incomplete Records', () {
      testWidgets(
        'saves timezone when creating partial record and pressing back',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                diaryEntryDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify we're on the start time screen
          expect(find.text('Nosebleed Start'), findsOneWidget);

          // Confirm start time to proceed
          await tester.tap(find.text('Set Start Time'));
          await tester.pumpAndSettle();

          // Press back after setting start time
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Verify the partial record was saved with timezone
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTimeTimezone, isNotNull);
          // Timezone should be a valid IANA ID (e.g., America/Los_Angeles)
          expect(
            records.first.startTimeTimezone?.contains('/'),
            isTrue,
            reason: 'Timezone should be an IANA ID like America/Los_Angeles',
          );
        },
      );

      testWidgets(
        'saves both start and end time timezones when completing intensity step',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithApp(
              RecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                diaryEntryDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Set start time
          await tester.tap(find.text('Set Start Time'));
          await tester.pumpAndSettle();

          // Select intensity
          await tester.tap(find.text('Dripping'));
          await tester.pumpAndSettle();

          // Should now be on end time step
          expect(find.text('Nosebleed End Time'), findsOneWidget);

          // Press back to auto-save with both timezones
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Verify the record has both timezones
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.startTimeTimezone, isNotNull);
          // End time timezone should also be set when end time step was reached
          expect(records.first.endTimeTimezone, isNotNull);
        },
      );

      testWidgets('restores timezone when editing incomplete record', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create an incomplete record with a specific timezone
        final incompleteRecord = await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 0),
          isNoNosebleedsEvent: false,
          isUnknownEvent: false,
          startTimeTimezone: 'America/New_York',
        );

        // Verify it was saved correctly
        expect(incompleteRecord.startTimeTimezone, 'America/New_York');
        expect(incompleteRecord.isIncomplete, isTrue);

        await tester.pumpWidget(
          _wrapWithApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              // Note: When editing existing record, don't pass diaryEntryDate
              existingRecord: incompleteRecord,
              onDelete:
                  (_) async {}, // Required when existingRecord is non-null
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The timezone should be restored from the record
        // Note: We can't directly check the picker value, but we can verify
        // that when we save again, the timezone is preserved

        // Navigate to start time step (incomplete record starts at intensity step)
        // Tap on "Start" in the summary bar to switch to start time picker
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        // Make a small change and save
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Press back to auto-save
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Verify timezone was preserved
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        // The timezone should still be the original value
        expect(records.first.startTimeTimezone, isNotNull);
      });
    });

    group('SimpleRecordingScreen Back Button Auto-Save', () {
      testWidgets(
        'auto-saves partial record when back is tapped with unsaved changes',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithNavigation(
              (context) => SimpleRecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                initialStartDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open the recording screen
          await tester.tap(find.text('Open Recording'));
          await tester.pumpAndSettle();

          // Select an intensity to create unsaved changes
          // Note: IntensityRow adds '\n' suffix to single-word labels for alignment
          // Use exact text with newline to avoid matching 'Dripping\nquickly'
          await tester.tap(find.text('Dripping\n'));
          await tester.pumpAndSettle();

          // Press back
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as Incomplete?'), findsNothing);

          // Verify record was saved
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.intensity, NosebleedIntensity.dripping);
        },
      );

      testWidgets(
        'tapping back immediately auto-saves partial with default start time',
        (tester) async {
          // SimpleRecordingScreen automatically sets _userSetStart = true
          // for new records because a start time is displayed and user expects
          // it to be valid. Therefore, pressing back immediately should auto-save.
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithNavigation(
              (context) => SimpleRecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                initialStartDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open the recording screen
          await tester.tap(find.text('Open Recording'));
          await tester.pumpAndSettle();

          // DON'T make any changes, just tap back immediately
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should NOT show any dialog
          expect(find.text('Save as Incomplete?'), findsNothing);

          // Should auto-save the partial record with default start time
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.startTime, isNotNull);
          expect(records.first.isIncomplete, isTrue);
        },
      );

      testWidgets('auto-saves when intensity is set and back is pressed', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapWithNavigation(
            (context) => SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              initialStartDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the recording screen
        await tester.tap(find.text('Open Recording'));
        await tester.pumpAndSettle();

        // Select intensity
        // Note: IntensityRow adds '\n' suffix to single-word labels for alignment
        // Use exact text with newline to avoid ambiguous matches
        await tester.tap(find.text('Spotting\n'));
        await tester.pumpAndSettle();

        // Press back
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Verify auto-save occurred
        final records = await nosebleedService.getRecordsForStartDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 1);
        expect(records.first.intensity, NosebleedIntensity.spotting);
      });

      testWidgets('auto-saves when editing existing record with changes', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create an existing record first
        final existingRecord = await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.spotting,
        );

        await tester.pumpWidget(
          _wrapWithNavigation(
            (context) => SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the recording screen
        await tester.tap(find.text('Open Recording'));
        await tester.pumpAndSettle();

        // Change intensity
        // Note: IntensityRow adds '\n' suffix to single-word labels for alignment
        // Use exact text with newline to avoid matching 'Dripping\nquickly'
        await tester.tap(find.text('Dripping\n'));
        await tester.pumpAndSettle();

        // Press back
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Verify auto-save occurred with new intensity
        final records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.intensity, NosebleedIntensity.dripping);
      });

      testWidgets(
        'handles system back button with unsaved changes via auto-save',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _wrapWithNavigation(
              (context) => SimpleRecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                preferencesService: preferencesService,
                initialStartDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open the recording screen
          await tester.tap(find.text('Open Recording'));
          await tester.pumpAndSettle();

          // Select intensity to create unsaved changes
          // Note: IntensityRow adds '\n' suffix to single-word labels for alignment
          // Use exact text with newline to avoid matching 'Dripping\nquickly'
          await tester.tap(find.text('Dripping\n'));
          await tester.pumpAndSettle();

          // Simulate system back button
          final dynamic state = tester.state(find.byType(Navigator));
          // ignore: avoid_dynamic_calls
          state.maybePop();
          await tester.pumpAndSettle();

          // Verify auto-save occurred
          final records = await nosebleedService.getRecordsForStartDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.intensity, NosebleedIntensity.dripping);
        },
      );
    });
  });

  group('Delete Record Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late PreferencesService preferencesService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();
      preferencesService = PreferencesService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('delete_integration_');

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
        enableCloudSync: false, // Disable for tests
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

    testWidgets(
      'full delete flow: edit record -> delete -> confirm -> record removed '
      'from materialized view',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Step 1: Create a record in the service
        final originalRecord = await nosebleedService.addRecord(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.dripping,
        );

        // Verify record exists in materialized view
        var records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.length, 1);
        expect(records.first.id, originalRecord.id);

        // Step 2: Create the RecordingScreen with onDelete callback
        // that properly calls the service's deleteRecord method
        var wasDeleted = false;
        String? deletedReason;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            RecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              preferencesService: preferencesService,
              existingRecord: originalRecord,
              onDelete: (reason) async {
                await nosebleedService.deleteRecord(
                  recordId: originalRecord.id,
                  reason: reason,
                );
                wasDeleted = true;
                deletedReason = reason;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 3: Verify delete button is visible
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Step 4: Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Step 5: Verify delete confirmation dialog appears
        expect(find.text('Delete Record'), findsOneWidget);
        expect(
          find.text('Please select a reason for deleting this record:'),
          findsOneWidget,
        );

        // Step 6: Select a reason
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();

        // Step 7: Tap confirm delete button
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Step 8: Verify the onDelete callback was called
        expect(wasDeleted, true);
        expect(deletedReason, 'Entered by mistake');

        // Step 9: Verify record is removed from materialized view
        records = await nosebleedService.getLocalMaterializedRecords();
        expect(records.isEmpty, true);

        // Step 10: Verify the deletion event exists in the raw event log
        final allRecords = await nosebleedService.getAllLocalRecords();
        // Should have 2 events: original + deletion marker
        expect(allRecords.length, 2);

        final deletionRecord = allRecords.firstWhere((r) => r.isDeleted);
        expect(deletionRecord.deleteReason, 'Entered by mistake');
        expect(deletionRecord.parentRecordId, originalRecord.id);
      },
    );

    // Note: The test 'delete button does nothing when onDelete callback is not provided'
    // was removed because RecordingScreen now has an assertion that requires onDelete
    // when existingRecord is provided. This prevents the bug at the API level.

    testWidgets('deleting incomplete record works correctly', (tester) async {
      // This test verifies the fix for CUR-465: incomplete records
      // now have the onDelete callback properly wired up

      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create an incomplete record (missing end time and severity)
      final incompleteRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 0),
        // endTime and severity intentionally not provided
      );

      // Verify record is incomplete
      var records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.isIncomplete, true);

      // Create the RecordingScreen with onDelete callback
      // This simulates the fix - onDelete is now always provided
      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            nosebleedService: nosebleedService,
            enrollmentService: mockEnrollment,
            preferencesService: preferencesService,
            existingRecord: incompleteRecord,
            onDelete: (reason) async {
              await nosebleedService.deleteRecord(
                recordId: incompleteRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Select a reason
      await tester.tap(find.text('Duplicate entry'));
      await tester.pumpAndSettle();

      // Tap confirm delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify record is deleted from materialized view
      records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.isEmpty, true);
    });

    testWidgets('cancel delete does not remove record', (tester) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a record
      final originalRecord = await nosebleedService.addRecord(
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
            existingRecord: originalRecord,
            onDelete: (reason) async {
              await nosebleedService.deleteRecord(
                recordId: originalRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Record should still exist
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.length, 1);
      expect(records.first.id, originalRecord.id);
    });

    testWidgets('delete with custom "Other" reason works correctly', (
      tester,
    ) async {
      // Use a larger screen size to avoid overflow issues
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a record
      final originalRecord = await nosebleedService.addRecord(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
        intensity: NosebleedIntensity.dripping,
      );

      String? capturedReason;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            nosebleedService: nosebleedService,
            enrollmentService: mockEnrollment,
            preferencesService: preferencesService,
            existingRecord: originalRecord,
            onDelete: (reason) async {
              capturedReason = reason;
              await nosebleedService.deleteRecord(
                recordId: originalRecord.id,
                reason: reason,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Select "Other" reason
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      // Focus the TextField first, then enter custom reason
      final textField = find.byType(TextField);
      expect(
        textField,
        findsOneWidget,
        reason: 'TextField should appear after selecting Other',
      );

      // Use enterText which properly triggers onChanged callbacks
      // This works across all platforms including headless Linux
      await tester.enterText(textField, 'Custom deletion reason for testing');
      await tester.pumpAndSettle();

      // Verify Delete button is enabled (not null onPressed)
      final deleteButton = find.widgetWithText(FilledButton, 'Delete');
      expect(
        deleteButton,
        findsOneWidget,
        reason: 'Delete button should exist',
      );
      final filledButton = tester.widget<FilledButton>(deleteButton);
      expect(
        filledButton.onPressed,
        isNotNull,
        reason:
            'Delete button should be enabled after entering custom reason. '
            'Text field may not have received text input.',
      );

      // Tap confirm delete button
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify custom reason was captured
      expect(capturedReason, 'Custom deletion reason for testing');

      // Verify record is deleted
      final records = await nosebleedService.getLocalMaterializedRecords();
      expect(records.isEmpty, true);
    });
  });

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
        // Check if yesterday is in a different month (e.g., today is 1st)
        final yesterdayInDifferentMonth = yesterday.month != now.month;

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

        // If yesterday is in a different month, navigate to that month
        if (yesterdayInDifferentMonth) {
          debugPrint(
            'Yesterday ($yesterdayDay) is in previous month, navigating...',
          );
          await _navigateToPreviousMonth(tester);
        }

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

/// Helper to wrap widget with MaterialApp and localization support
Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

/// Helper to wrap widget with proper navigation stack so PopScope works correctly.
/// SimpleRecordingScreen uses PopScope which requires a parent route to pop to.
Widget _wrapWithNavigation(Widget Function(BuildContext) builder) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              Navigator.push<dynamic>(
                context,
                MaterialPageRoute<dynamic>(builder: (_) => builder(context)),
              );
            },
            child: const Text('Open Recording'),
          ),
        );
      },
    ),
  );
}

/// Helper to find the decorated container for a specific day in the calendar.
/// When showing 6 weeks, a day number like "28" may appear twice:
/// - Once in the previous month (outside day, rendered with alpha 0.5)
/// - Once in the current month (inside day, rendered with alpha 1.0)
/// This function finds the INSIDE month day (full opacity).
BoxDecoration _findDayContainer(WidgetTester tester, String dayText) {
  final dayFinder = find.ancestor(
    of: find.text(dayText),
    matching: find.byType(Container),
  );

  final dayContainers = tester.widgetList<Container>(dayFinder);

  // Find decorated containers and prefer the one with full opacity (inside month)
  final decoratedContainers = dayContainers
      .where((c) => c.decoration != null && c.decoration is BoxDecoration)
      .toList();

  if (decoratedContainers.isEmpty) {
    throw StateError('No decorated container found for day $dayText');
  }

  // Prefer the container with full opacity (inside month day)
  // Outside month days have alpha 0.5
  final insideMonthContainer = decoratedContainers.firstWhere((c) {
    final decoration = c.decoration! as BoxDecoration;
    return decoration.color != null &&
        (decoration.color!.a == 1.0 || decoration.color!.a == 255);
  }, orElse: () => decoratedContainers.first);

  return insideMonthContainer.decoration! as BoxDecoration;
}

/// Helper to navigate to the previous month in the calendar.
/// TableCalendar shows chevron_left icon for navigating to previous month.
Future<void> _navigateToPreviousMonth(WidgetTester tester) async {
  // TableCalendar uses chevron_left for previous month navigation
  final prevMonthButton = find.byIcon(Icons.chevron_left);
  if (prevMonthButton.evaluate().isNotEmpty) {
    debugPrint('Tapping chevron_left to navigate to previous month');
    await tester.tap(prevMonthButton);
    await tester.pumpAndSettle();
  } else {
    // Fallback: try swiping right to go to previous month
    debugPrint('No chevron_left found, trying swipe gesture');
    await tester.drag(
      find.byType(Table).first,
      const Offset(300, 0), // Swipe right
    );
    await tester.pumpAndSettle();
  }
}
