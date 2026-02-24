// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00076: Participation Status Badge

// Integration test for the complete enrollment flow
// Tests the following sequence:
// 1. User enrolls with a 10-character linking code
// 2. Enrollment is saved to local secure storage
// 3. Active trial badge is displayed on profile screen with enrollment details
// 4. Sponsor branding (logo) is shown on home screen (LogoMenu)

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
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

  group('Enrollment Flow Integration Tests', () {
    late EnrollmentService enrollmentService;
    late AuthService authService;
    late PreferencesService preferencesService;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp('enrollment_int_test_');
      final mockHttpClient = MockClient((request) async {
        // Mock the enrollment endpoint
        if (request.url.path.contains('/api/v1/user/link')) {
          // Simulate successful enrollment response
          return http.Response(
            '{"jwt":"mock-jwt-token","userId":"test-patient-123","patientId":"patient-456","siteId":"site-789","siteName":"Test Research Center","sitePhoneNumber":"+1-555-0123","studyPatientId":"STUDY-001"}',
            200,
          );
        }
        return http.Response('{"success": true}', 200);
      });

      enrollmentService = EnrollmentService(httpClient: mockHttpClient);

      if (Datastore.isInitialized) {
        await Datastore.instance.deleteAndReset();
      }
      await Datastore.initialize(
        config: DatastoreConfig(
          deviceId: 'test-device-id',
          userId: 'test-user-id',
          databasePath: tempDir.path,
          databaseName: 'test_enrollment.db',
          enableEncryption: false,
        ),
      );

      // Create a real EnrollmentService with mock HTTP client
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

    void setUpTestScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
    }

    void resetTestScreenSize(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    testWidgets(
      'REQ-CAL-p00049: User can enroll via enrollment page and enrollment is saved to local storage',
      (tester) async {
        setUpTestScreenSize(tester);

        // Verify user is not enrolled initially
        var isEnrolled = await enrollmentService.isEnrolled();
        expect(isEnrolled, false);

        // Load home screen
        await tester.pumpWidget(buildHomeScreen());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        // Open menu by tapping the menu button
        await tester.tap(find.byIcon(Icons.person_outline).first);
        await tester.pumpAndSettle();

        // Tap enroll option from menu
        await tester.tap(find.text('Enroll in Clinical Trial').first);
        await tester.pumpAndSettle();

        // Enter linking code in the enrollment screen
        await tester.enterText(find.byType(TextField).first, 'CAXXX');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'XXXXX');
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).last);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        // Tap enroll button to submit
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Verify enrollment was saved
        isEnrolled = await enrollmentService.isEnrolled();
        expect(isEnrolled, true);

        // Verify enrollment details are stored correctly
        final savedEnrollment = await enrollmentService.getEnrollment();
        expect(savedEnrollment, isNotNull);
        expect(savedEnrollment!.userId, 'test-patient-123');
        expect(savedEnrollment.patientId, 'patient-456');
        expect(savedEnrollment.siteId, 'site-789');
        expect(savedEnrollment.siteName, 'Test Research Center');
        expect(savedEnrollment.jwtToken, 'mock-jwt-token');
        expect(savedEnrollment.enrolledAt, isNotNull);
        expect(savedEnrollment.isLinkedToClinicalTrial, true);
      },
    );

    testWidgets(
      'REQ-d00005: Sponsor branding is displayed on home screen after enrollment',
      (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Load and display home screen
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        // Verify enrollment is active
        final isEnrolled = await enrollmentService.isEnrolled();
        expect(isEnrolled, true);

        // Verify sponsor information is available
        final enrollment = await enrollmentService.getEnrollment();
        expect(enrollment!.sponsorId, isNotNull);

        // Verify LogoMenu widget is rendered with sponsor branding
        expect(find.byType(LogoMenu), findsOneWidget);

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/images/cure-hht-grey.png',
          ),
          findsNothing,
        );
      },
    );
    testWidgets(
      'REQ-CAL-p00076: Active trial badge is displayed on profile screen after enrollment',
      (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Load and display home screen
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.person_outline).first);
        await tester.pumpAndSettle();

        // Tap enroll option from menu
        await tester.tap(find.text('Profile').first);
        await tester.pumpAndSettle();

        expect(find.text("You've joined the study"), findsOneWidget);
      },
    );
  });
}
