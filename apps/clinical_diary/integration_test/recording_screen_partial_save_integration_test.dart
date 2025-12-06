// IMPLEMENTS REQUIREMENTS:
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingScreen Automatic Partial Save', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp(
        'recording_partial_test_',
      );

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

    // Integration tests using real Datastore and cloud sync
    group('Back Button Auto-Save Partial', () {
      testWidgets(
        'automatically saves partial record when pressing back on new record',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
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
                initialDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify we're on the start time screen
          expect(find.text('Nosebleed Start'), findsOneWidget);

          // Press the back button immediately (without any user interaction)
          await tester.tap(find.text('Back'));
          // Use pump with duration instead of pumpAndSettle to avoid timeout
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should NOT show any dialog - should auto-save
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved by checking the service
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
          // Intensity and endTime should be null since user didn't set them
          expect(records.first.intensity, isNull);
          expect(records.first.endTime, isNull);
        },
      );

      testWidgets(
        'auto-saves partial after setting start time and going back',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
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
                initialDate: DateTime(2024, 1, 15),
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
          // Use pump with duration instead of pumpAndSettle
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
          // No intensity or end time yet
          expect(records.first.intensity, isNull);
          expect(records.first.endTime, isNull);
        },
      );

      testWidgets(
        'auto-saves partial with intensity after selecting it and going back',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
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
                initialDate: DateTime(2024, 1, 15),
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
          // Use pump with duration instead of pumpAndSettle
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved with intensity
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
          expect(records.first.intensity, isNotNull);
          // End time is auto-initialized but not confirmed
          // The partial save should include whatever state is there
        },
      );

      testWidgets('system back button also triggers auto-save', (tester) async {
        // Use a larger screen size to avoid overflow issues
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
              initialDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we're on the start time screen
        expect(find.text('Nosebleed Start'), findsOneWidget);

        // Simulate system back button press using the Navigator
        final dynamic state = tester.state(find.byType(Navigator));
        // ignore: avoid_dynamic_calls
        state.maybePop();
        // Use pump with duration instead of pumpAndSettle
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Should NOT show any dialog
        expect(find.text('Save as incomplete?'), findsNothing);

        // Verify the partial record was saved
        final records = await nosebleedService.getRecordsForDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 1);
        expect(records.first.isIncomplete, isTrue);
      });

      testWidgets(
        'does not save partial when on complete step (already has save button)',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
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
                initialDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Navigate through the full flow
          // Confirm start time
          await tester.tap(find.text('Set Start Time'));
          await tester.pumpAndSettle();

          // Select intensity
          await tester.tap(find.text('Dripping'));
          await tester.pumpAndSettle();

          // Confirm end time
          await tester.tap(find.text('Set End Time'));
          await tester.pumpAndSettle();

          // Should be on complete step
          expect(find.text('Record Complete'), findsOneWidget);
          expect(find.text('Finished'), findsOneWidget);

          // Press back from complete step
          await tester.tap(find.text('Back'));
          // Use pump with duration instead of pumpAndSettle
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should NOT auto-save (user should use the Finished button)
          // Just navigate back without saving
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 0);
        },
      );
    });
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
