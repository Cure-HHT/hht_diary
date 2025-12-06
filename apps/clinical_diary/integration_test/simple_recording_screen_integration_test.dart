// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)

import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
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

import '../test/helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SimpleRecordingScreen', () {
    late MockEnrollmentService mockEnrollment;
    late NosebleedService nosebleedService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService();

      // Create a temp directory for the test database
      tempDir = await Directory.systemTemp.createTemp('simple_recording_test_');

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

    group('Incomplete Entry Preservation (CUR-405)', () {
      testWidgets(
        'auto-saves partial record when back is tapped with unsaved changes',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SimpleRecordingScreen(
                              nosebleedService: nosebleedService,
                              enrollmentService: mockEnrollment,
                              initialDate: DateTime(2024, 1, 15),
                            ),
                          ),
                        );
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

          // Initially the time picker is shown with a default time
          // User interacts by changing the time using the adjustment buttons
          // The -15 and +15 buttons exist for both start and end time pickers
          expect(find.text('+15'), findsWidgets);

          // Tap the first +15 to change the start time (this makes the user's interaction explicit)
          await tester.tap(find.text('+15').first);
          await tester.pumpAndSettle();

          // Now try to go back - should auto-save without dialog
          await tester.tap(find.text('Back'));
          // Use pump instead of pumpAndSettle due to async operations
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should NOT show any dialog - auto-save happens automatically
          expect(find.text('Save as Incomplete?'), findsNothing);

          // Verify a record was saved
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
          expect(records.first.startTime, isNotNull);
        },
      );

      testWidgets('navigates back without saving when no changes made', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
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
      });

      testWidgets('auto-saves when intensity is set and back is pressed', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SimpleRecordingScreen(
                            nosebleedService: nosebleedService,
                            enrollmentService: mockEnrollment,
                            initialDate: DateTime(2024, 1, 15),
                          ),
                        ),
                      );
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

        // Set intensity (tap on one of the intensity options)
        // The IntensityRow shows intensity options
        await tester.tap(find.text('Dripping'));
        await tester.pumpAndSettle();

        // Try to go back - should auto-save without dialog
        await tester.tap(find.text('Back'));
        // Use pump instead of pumpAndSettle due to async operations
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Should NOT show any dialog
        expect(find.text('Save as Incomplete?'), findsNothing);

        // Verify a record was saved with intensity
        final records = await nosebleedService.getRecordsForDate(
          DateTime(2024, 1, 15),
        );
        expect(records.length, 1);
        expect(records.first.isIncomplete, isTrue);
        expect(records.first.intensity, NosebleedIntensity.dripping);
      });

      testWidgets('auto-saves when editing existing record with changes', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SimpleRecordingScreen(
                            nosebleedService: nosebleedService,
                            enrollmentService: mockEnrollment,
                            existingRecord: existingRecord,
                          ),
                        ),
                      );
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

        // Change the intensity
        await tester.tap(find.text('Pouring'));
        await tester.pumpAndSettle();

        // Try to go back - should auto-save without dialog
        await tester.tap(find.text('Back'));
        // Use pump instead of pumpAndSettle due to async operations
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Should NOT show any dialog
        expect(find.text('Save as Incomplete?'), findsNothing);
      });

      testWidgets(
        'navigates back without saving when editing existing record without changes',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final existingRecord = NosebleedRecord(
            id: 'existing-1',
            date: DateTime(2024, 1, 15),
            startTime: DateTime(2024, 1, 15, 10, 30),
            endTime: DateTime(2024, 1, 15, 10, 45),
            intensity: NosebleedIntensity.dripping,
          );

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
                              existingRecord: existingRecord,
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

          // DON'T make any changes, just tap back
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();

          // Should NOT show any dialog - should just navigate back
          expect(find.text('Save as Incomplete?'), findsNothing);
          expect(didPop, isTrue);
        },
      );

      testWidgets(
        'handles system back button with unsaved changes via auto-save',
        (tester) async {
          // Use a larger screen size to avoid overflow issues
          tester.view.physicalSize = const Size(1080, 1920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SimpleRecordingScreen(
                              nosebleedService: nosebleedService,
                              enrollmentService: mockEnrollment,
                              initialDate: DateTime(2024, 1, 15),
                            ),
                          ),
                        );
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

          // User interacts by changing the start time
          await tester.tap(find.text('+15').first);
          await tester.pumpAndSettle();

          // Simulate system back button (maybePop)
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          await navigator.maybePop();
          // Use pump instead of pumpAndSettle due to async operations
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Should NOT show any dialog - auto-save happens
          expect(find.text('Save as Incomplete?'), findsNothing);

          // Verify a record was saved
          final records = await nosebleedService.getRecordsForDate(
            DateTime(2024, 1, 15),
          );
          expect(records.length, 1);
          expect(records.first.isIncomplete, isTrue);
        },
      );
    });

    group('Basic Functionality', () {
      testWidgets('displays all form sections', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithMaterialApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              initialDate: DateTime(2024, 1, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show all sections
        expect(find.text('Nosebleed Start'), findsOneWidget);
        expect(find.text('Max Intensity'), findsOneWidget);
        expect(find.text('Nosebleed End'), findsOneWidget);
      });

      testWidgets('displays back button', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithMaterialApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Back'), findsOneWidget);
      });

      testWidgets('shows delete button for existing records', (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existingRecord = NosebleedRecord(
          id: 'existing-1',
          date: DateTime(2024, 1, 15),
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithMaterialApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
              existingRecord: existingRecord,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('does not show delete button for new records', (
        tester,
      ) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithMaterialApp(
            SimpleRecordingScreen(
              nosebleedService: nosebleedService,
              enrollmentService: mockEnrollment,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
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
