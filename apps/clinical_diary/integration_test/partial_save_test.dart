// IMPLEMENTS REQUIREMENTS:
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)
//   REQ-d00004: Local-First Data Entry Implementation

// Integration test for partial save / auto-save behavior
// Moved from test/screens/recording_screen_partial_save_test.dart and
// test/screens/simple_recording_screen_test.dart because:
// - Datastore transactions don't complete properly in widget tests
// - Auto-save behavior requires async database operations

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
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

  group('Partial Save Integration Tests', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();

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
                initialDate: DateTime(2024, 1, 15),
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
          final records = await nosebleedService.getRecordsForDate(
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
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved
          final records = await nosebleedService.getRecordsForDate(
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
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as incomplete?'), findsNothing);

          // Verify the partial record was saved with intensity
          final records = await nosebleedService.getRecordsForDate(
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
              initialDate: DateTime(2024, 1, 15),
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
        final records = await nosebleedService.getRecordsForDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 1);
        expect(records.first.isIncomplete, isTrue);
      });

      testWidgets('does not save partial when on complete step', (
        tester,
      ) async {
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
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set End Time'));
        await tester.pumpAndSettle();

        // Should be on complete step
        expect(find.text('Record Complete'), findsOneWidget);

        // Press back from complete step
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Should NOT auto-save (user should use the Finished button)
        final records = await nosebleedService.getRecordsForDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 0);
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
            _wrapWithApp(
              SimpleRecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                initialDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Select an intensity to create unsaved changes
          await tester.tap(find.text('Dripping'));
          await tester.pumpAndSettle();

          // Press back
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should auto-save without dialog
          expect(find.text('Save as Incomplete?'), findsNothing);

          // Verify record was saved
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.intensity, NosebleedIntensity.dripping);
        },
      );

      testWidgets(
        'tapping back without changes navigates back without saving',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          var didPop = false;

          await tester.pumpWidget(
            MaterialApp(
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
                      onPressed: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) => SimpleRecordingScreen(
                              nosebleedService: nosebleedService,
                              enrollmentService: mockEnrollment,
                              initialDate: DateTime(2024, 1, 15),
                            ),
                          ),
                        );
                        didPop = true;
                      },
                      child: const Text('Open Recording'),
                    ),
                  );
                },
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

          // Should NOT show any dialog - should just navigate back
          expect(find.text('Save as Incomplete?'), findsNothing);
          expect(didPop, isTrue);
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
          _wrapWithApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              initialDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select intensity
        await tester.tap(find.text('Spotting'));
        await tester.pumpAndSettle();

        // Press back
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Verify auto-save occurred
        final records = await nosebleedService.getRecordsForDate(
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
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          intensity: NosebleedIntensity.spotting,
        );

        await tester.pumpWidget(
          _wrapWithApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change intensity
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Press back
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Verify auto-save occurred with new intensity
        final records = await nosebleedService.getLocalRecords();
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
            _wrapWithApp(
              SimpleRecordingScreen(
                nosebleedService: nosebleedService,
                enrollmentService: mockEnrollment,
                initialDate: DateTime(2024, 1, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Select intensity to create unsaved changes
          await tester.tap(find.text('Dripping'));
          await tester.pumpAndSettle();

          // Simulate system back button
          final dynamic state = tester.state(find.byType(Navigator));
          // ignore: avoid_dynamic_calls
          state.maybePop();
          await tester.pumpAndSettle();

          // Verify auto-save occurred
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.intensity, NosebleedIntensity.dripping);
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
