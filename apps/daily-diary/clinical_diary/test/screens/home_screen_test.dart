// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('HomeScreen', () {
    late EnrollmentService enrollmentService;
    late PreferencesService preferencesService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      // Use UTC timezone to avoid DST-related discrepancies between
      // commonTimezones static offsets and actual device timezone offset.
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';

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
      preferencesService = PreferencesService();
      nosebleedService = NosebleedService(
        enrollmentService: enrollmentService,
        httpClient: mockHttpClient,
        enableCloudSync: false,
      );
    });

    tearDown(() async {
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;

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

      testWidgets('user menu contains Profile item (CUR-628)', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        // Profile (patient info) remains — it's not the removed login/account screens
        expect(find.text('Profile'), findsOneWidget);
      });
    });

    // Record Display tests moved to integration_test/home_screen_integration_test.dart
    // Widget tests don't properly handle async datastore operations with records

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

      // 'tapping record item navigates to edit screen' test moved to
      // integration_test/home_screen_integration_test.dart
    });

    group('User Menu', () {
      // Note: PopupMenu items may cause overflow errors in small test screens
      // because long text like "Accessibility & Preferences" doesn't wrap.
      // We ignore overflow errors for these tests since the menu functionality
      // still works correctly.

      testWidgets('does not show login option (linking code is auth)', (
        tester,
      ) async {
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

        // Login option is hidden - linking code is the authentication mechanism
        expect(find.text('Login'), findsNothing);
      });

      testWidgets('does not show logout option (CUR-628)', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        // Logout was removed along with the login/account screens (CUR-628)
        expect(find.text('Logout'), findsNothing);
      });

      testWidgets('does not show account option (CUR-628)', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        // Account profile screen was removed (CUR-628)
        expect(find.text('Account'), findsNothing);
      });

      // CUR-1055: Enroll option must be hidden when device is already enrolled
      testWidgets('hides enroll option when already enrolled', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        // Pre-populate enrollment so _isEnrolled becomes true on init.
        // isEnrolled() checks jwtToken != null; getEnrollment() returns enrollment.
        final mockEnrollment = MockEnrollmentService()
          ..jwtToken = 'test-jwt'
          ..enrollment = UserEnrollment(
            userId: 'test-user',
            jwtToken: 'test-jwt',
            enrolledAt: DateTime.now(),
          );
        addTearDown(mockEnrollment.dispose);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            HomeScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              taskService: TaskService(),
              preferencesService: preferencesService,
              onLocaleChanged: (_) {},
              onThemeModeChanged: (_) {},
              onLargerTextChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        // Enroll option must be absent — device is already linked
        expect(
          find.text('Link to Clinical Trial'),
          findsNothing,
          reason:
              'Enroll menu item must be hidden when _isEnrolled=true '
              'to prevent duplicate enrollment attempts',
        );
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
        expect(find.text('Did you have nosebleeds?'), findsOneWidget);
      });

      // 'hides yesterday banner when yesterday has records' test moved to
      // integration_test/home_screen_integration_test.dart
    });

    // Tests with records moved to integration_test/home_screen_integration_test.dart:
    // - Incomplete Records Banner tests
    // - Flash Highlight Animation tests
    // - Scroll to Record tests (except ListView ScrollController test)
    // - Overlap Detection tests

    group('Scroll to Record (CUR-489)', () {
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

    group('Post-Linking Profile Return (CUR-1114)', () {
      testWidgets('returns to ProfileScreen after successful enrollment', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Ignore overflow errors from popup menu / profile screen layout
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        // Use MockEnrollmentService to control enrollment state
        final mockEnrollment = MockEnrollmentService();
        final mockHttpClient = MockClient(
          (_) async => http.Response('{"success": true}', 200),
        );
        final mockNosebleedService = NosebleedService(
          enrollmentService: mockEnrollment,
          httpClient: mockHttpClient,
          enableCloudSync: false,
        );
        addTearDown(() {
          mockNosebleedService.dispose();
          mockEnrollment.dispose();
        });

        await tester.pumpWidget(
          wrapWithMaterialApp(
            HomeScreen(
              nosebleedService: mockNosebleedService,
              enrollmentService: mockEnrollment,
              taskService: TaskService(),
              preferencesService: PreferencesService(),
              onLocaleChanged: (_) {},
              onThemeModeChanged: (_) {},
              onLargerTextChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open user menu and tap Profile
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();

        // Verify ProfileScreen is shown
        expect(find.byType(ProfileScreen), findsOneWidget);

        // 2. Tap "Link to Clinical Trial" button on profile
        await tester.tap(find.text('Link to Clinical Trial'));
        await tester.pumpAndSettle();

        // ProfileScreen should be popped, EnrollmentScreen should be shown
        expect(find.byType(ClinicalTrialEnrollmentScreen), findsOneWidget);
        expect(find.byType(ProfileScreen), findsNothing);

        // 3. Simulate successful enrollment by setting mock state
        mockEnrollment
          ..jwtToken = 'test-jwt-token'
          ..enrollment = UserEnrollment(
            userId: 'test-user-id',
            jwtToken: 'test-jwt-token',
            enrolledAt: DateTime(2026, 3, 30),
            linkingCode: 'ABCDE12345',
          );

        // 4. Pop the enrollment screen (simulates enrollment completion)
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // 5. CUR-1114 fix: ProfileScreen should be re-opened automatically
        expect(find.byType(ProfileScreen), findsOneWidget);
      });

      testWidgets(
        'does not return to ProfileScreen when enrollment is cancelled',
        (tester) async {
          setUpTestScreenSize(tester);
          addTearDown(() => resetTestScreenSize(tester));

          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('overflowed')) return;
            oldOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = oldOnError);

          // Use MockEnrollmentService — enrollment stays null (not enrolled)
          final mockEnrollment = MockEnrollmentService();
          final mockHttpClient = MockClient(
            (_) async => http.Response('{"success": true}', 200),
          );
          final mockNosebleedService = NosebleedService(
            enrollmentService: mockEnrollment,
            httpClient: mockHttpClient,
            enableCloudSync: false,
          );
          addTearDown(() {
            mockNosebleedService.dispose();
            mockEnrollment.dispose();
          });

          await tester.pumpWidget(
            wrapWithMaterialApp(
              HomeScreen(
                nosebleedService: mockNosebleedService,
                enrollmentService: mockEnrollment,
                taskService: TaskService(),
                preferencesService: PreferencesService(),
                onLocaleChanged: (_) {},
                onThemeModeChanged: (_) {},
                onLargerTextChanged: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open Profile
          await tester.tap(find.byIcon(Icons.person_outline));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Profile'));
          await tester.pumpAndSettle();

          // Tap enroll
          await tester.tap(find.text('Link to Clinical Trial'));
          await tester.pumpAndSettle();

          // Back out without enrolling (jwtToken stays null)
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          // Should be back on HomeScreen, NOT ProfileScreen
          expect(find.byType(ProfileScreen), findsNothing);
          expect(find.text('Nosebleed Diary'), findsOneWidget);
        },
      );

      testWidgets(
        'navigates to ProfileScreen after enrolling from dropdown menu',
        (tester) async {
          setUpTestScreenSize(tester);
          addTearDown(() => resetTestScreenSize(tester));

          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('overflowed')) return;
            oldOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = oldOnError);

          final mockEnrollment = MockEnrollmentService();
          final mockHttpClient = MockClient(
            (_) async => http.Response('{"success": true}', 200),
          );
          final mockNosebleedService = NosebleedService(
            enrollmentService: mockEnrollment,
            httpClient: mockHttpClient,
            enableCloudSync: false,
          );
          addTearDown(() {
            mockNosebleedService.dispose();
            mockEnrollment.dispose();
          });

          await tester.pumpWidget(
            wrapWithMaterialApp(
              HomeScreen(
                nosebleedService: mockNosebleedService,
                enrollmentService: mockEnrollment,
                taskService: TaskService(),
                preferencesService: PreferencesService(),
                onLocaleChanged: (_) {},
                onThemeModeChanged: (_) {},
                onLargerTextChanged: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Open dropdown menu and tap "Link to Clinical Trial" directly
          await tester.tap(find.byIcon(Icons.person_outline));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Link to Clinical Trial'));
          await tester.pumpAndSettle();

          // EnrollmentScreen should be shown (no ProfileScreen in between)
          expect(find.byType(ClinicalTrialEnrollmentScreen), findsOneWidget);

          // 2. Simulate successful enrollment
          mockEnrollment
            ..jwtToken = 'test-jwt-token'
            ..enrollment = UserEnrollment(
              userId: 'test-user-id',
              jwtToken: 'test-jwt-token',
              enrolledAt: DateTime(2026, 3, 30),
              linkingCode: 'ABCDE12345',
            );

          // 3. Pop enrollment screen
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          // 4. CUR-1114 fix: ProfileScreen should open to show badge
          expect(find.byType(ProfileScreen), findsOneWidget);
        },
      );
    });
  });
}
