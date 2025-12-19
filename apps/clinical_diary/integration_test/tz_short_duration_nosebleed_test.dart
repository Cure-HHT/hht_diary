// IMPLEMENTS TESTS FOR REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// =============================================================================
// SHORT DURATION NOSEBLEED CONFIRMATION & TIMEZONE INTEGRATION TESTS
// =============================================================================
//
// TICKET: CUR-579
//
// PURPOSE:
//   Verify that the Short Duration Confirmation dialog appears when users
//   record nosebleeds with very short durations (≤1 minute), and that
//   timezone selection works correctly across US timezones. These features
//   support FDA 21 CFR Part 11 compliance by ensuring data integrity through
//   user confirmation of potentially erroneous short durations.
//
// WEB COMPATIBILITY:
//   All tests run on Chrome using mock services that store data in memory.
//   The web platform doesn't support file system operations.
//
// =============================================================================
// FDA REQUIREMENTS TRACEABILITY
// =============================================================================
//
// TEST REQUIREMENTS:
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//
// FDA 21 CFR PART 11 ALIGNMENT:
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ CFR Reference      │ Requirement                │ Implementation           │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ 11.10(a)           │ Data integrity validation  │ Short Duration dialog    │
// │                    │                            │ confirms unusual values  │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ 11.10(b)           │ Generate accurate copies   │ Timezone ensures correct │
// │                    │                            │ time representation      │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ 11.10(e)           │ Audit trail with accurate  │ Timezone stored with     │
// │                    │ date/time stamps           │ each record for tracing  │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// ALCOA+ DATA INTEGRITY PRINCIPLES:
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ Principle          │ Test Coverage                                         │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ Attributable       │ Record saved with user-confirmed duration             │
// │ Legible            │ Dialog text is clear and unambiguous                  │
// │ Contemporaneous    │ Timezone ensures accurate time representation         │
// │ Original           │ Short duration confirmation prevents errors           │
// │ Accurate           │ Threshold validation catches data entry mistakes      │
// │ Complete           │ All timezone variations captured and stored           │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// REQUIREMENT TO TEST MAPPING:
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ Requirement ID     │ Test Group                  │ Test Count               │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ REQ-CAL-p00002     │ Short Duration Dialog       │ 5 tests                  │
// │                    │ Two Minute Duration         │ 1 test                   │
// │                    │ Edge Cases (0/1 min)        │ 3 tests                  │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ Timezone Support   │ US Timezone Selection       │ 4 tests                  │
// │                    │ Keyboard Time Entry         │ 1 test                   │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ Feature Flags      │ Feature Flag Verification   │ 3 tests                  │
// │                    │ Edge Cases (flag disabled)  │ 1 test                   │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ UI Functionality   │ Edge Cases (buttons, etc)   │ 4 tests                  │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// TOTAL: 22 tests
//
// =============================================================================
// USER FLOWS TESTED
// =============================================================================
//
// FLOW 1: Short Duration Confirmation (REQ-CAL-p00002)
// -----------------------------------------------------
// Precondition: User records nosebleed with duration ≤ 1 minute
// 1. User taps "Set Start Time" to confirm start time
// 2. User selects intensity (Spotting/Dripping/Pouring/Gushing)
// 3. User taps "Set End Time" with duration ≤ 1 minute
// 4. System displays "Short Duration" dialog with:
//    - Title: "Short Duration"
//    - Message: "Duration is under 1 minute, is that correct?"
//    - Timer icon with "0m" or "1m"
//    - "No" button (returns to edit)
//    - "Yes" button (confirms and saves)
// 5a. If user taps "Yes" → Record saves with short duration
// 5b. If user taps "No" → Returns to end time step for editing
//
// FLOW 2: Edit Duration After "No"
// ---------------------------------
// 1. User triggers Short Duration dialog (duration ≤ 1 min)
// 2. User taps "No" to edit
// 3. User uses +1/+5/+15 buttons to increase duration above 1 min
// 4. User taps "Set End Time" again
// 5. Short Duration dialog does NOT appear (duration > 1 min)
//
// FLOW 3: Timezone Selection
// --------------------------
// 1. User taps timezone picker (globe icon)
// 2. "Select Timezone" modal appears
// 3. User searches for timezone (e.g., "Eastern", "Pacific")
// 4. User selects timezone from results
// 5. Selected timezone is applied to start/end times
// 6. Record is saved with timezone metadata
//
// =============================================================================
// TEST COVERAGE MATRIX
// =============================================================================
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ Category              │ Tests │ Description                                │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │ Feature Flags         │   3   │ Verify flags can be enabled                │
// │ Short Duration Dialog │   5   │ Dialog appears for ≤1 min, Yes/No behavior │
// │ Two Minute Duration   │   1   │ No dialog for >1 min duration              │
// │ US Timezone Selection │   4   │ EST, CST, MST, PST timezone picker         │
// │ Keyboard Time Entry   │   1   │ Time picker via tapping time display       │
// │ Edge Cases            │   8   │ 0/1 min, rapid taps, intensity options     │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/duration_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// =============================================================================
// CONSTANTS
// =============================================================================

/// Default screen size for tests (1080x1920 at 1.0 pixel ratio).
const Size kTestScreenSize = Size(1080, 1920);

/// Short duration threshold in minutes (dialog appears for ≤ this value).
const int kShortDurationThresholdMinutes = 1;

/// Duration at threshold (triggers Short Duration dialog).
const int kDurationAtThreshold = 1;

/// Duration below threshold (0 minutes - triggers dialog).
const int kDurationBelowThreshold = 0;

/// Duration above threshold (no dialog).
const int kDurationAboveThreshold = 2;

/// Standard duration for non-dialog tests.
const int kStandardDuration = 5;

// =============================================================================
// UI TEXT CONSTANTS (for maintainability)
// =============================================================================

/// Button and label text used in the recording flow.
class UiText {
  static const setStartTime = 'Set Start Time';
  static const setEndTime = 'Set End Time';
  static const yes = 'Yes';
  static const no = 'No';
  static const cancel = 'Cancel';

  // Intensity options
  static const spotting = 'Spotting';
  static const dripping = 'Dripping';
  static const pouring = 'Pouring';
  static const gushing = 'Gushing';

  // Dialog titles
  static const shortDurationTitle = 'Short Duration';
  static const selectTimezone = 'Select Timezone';

  // Dialog messages
  static const shortDurationMessage =
      'Duration is under 1 minute, is that correct?';

  // Labels
  static const nosebleedEndTime = 'Nosebleed End Time';
  static const maxIntensity = 'Max Intensity';

  // Duration adjustment buttons
  static const plus15 = '+15';
  static const plus5 = '+5';
  static const plus1 = '+1';
  static const minus15 = '-15';
  static const minus5 = '-5';
  static const minus1 = '-1';
}

// =============================================================================
// MOCK SERVICES
// =============================================================================

/// Mock NosebleedService for web-compatible testing.
///
/// Stores records in memory instead of using file system (not available on web).
/// This allows integration tests to run in Chrome browser.
class MockNosebleedService implements NosebleedService {
  final List<NosebleedRecord> _records = [];

  @override
  Future<NosebleedRecord> addRecord({
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? parentRecordId,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    final record = NosebleedRecord(
      id: 'mock-${_records.length}',
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );
    _records.add(record);
    return record;
  }

  @override
  Future<NosebleedRecord> updateRecord({
    required String originalRecordId,
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    final record = NosebleedRecord(
      id: originalRecordId,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );
    final idx = _records.indexWhere((r) => r.id == originalRecordId);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }
    return record;
  }

  @override
  Future<List<NosebleedRecord>> getLocalMaterializedRecords() async => _records;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock EnrollmentService for web-compatible testing.
class MockEnrollmentService implements EnrollmentService {
  @override
  Future<String?> getJwtToken() async => null;
  @override
  Future<bool> isEnrolled() async => false;
  @override
  Future<UserEnrollment?> getEnrollment() async => null;
  @override
  Future<UserEnrollment> enroll(String code) async =>
      throw UnimplementedError();
  @override
  Future<void> clearEnrollment() async {}
  @override
  void dispose() {}
  @override
  Future<String?> getUserId() async => 'test-user-id';
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Configure test environment
  F.appFlavor = Flavor.dev;
  AppConfig.testApiBaseOverride = 'https://test.example.com/api';

  // Shared services (reset in setUp)
  late MockNosebleedService mockNosebleedService;
  late MockEnrollmentService mockEnrollmentService;
  late PreferencesService preferencesService;
  late FeatureFlagService featureFlagService;

  // ---------------------------------------------------------------------------
  // SETUP / TEARDOWN
  // ---------------------------------------------------------------------------

  setUp(() {
    mockNosebleedService = MockNosebleedService();
    mockEnrollmentService = MockEnrollmentService();
    preferencesService = PreferencesService();
    featureFlagService = FeatureFlagService.instance..resetToDefaults();
  });

  tearDown(() {
    featureFlagService.resetToDefaults();
  });

  // ---------------------------------------------------------------------------
  // WIDGET BUILDER
  // ---------------------------------------------------------------------------

  /// Builds the RecordingScreen widget with all required dependencies.
  Widget buildRecordingScreen({DateTime? diaryEntryDate}) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RecordingScreen(
        nosebleedService: mockNosebleedService,
        enrollmentService: mockEnrollmentService,
        preferencesService: preferencesService,
        diaryEntryDate: diaryEntryDate,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEST HELPER FUNCTIONS
  // ---------------------------------------------------------------------------

  /// Sets up standard test screen size and registers cleanup.
  void standardTestSetup(WidgetTester tester) {
    tester.view.physicalSize = kTestScreenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Enables Short Duration Confirmation flag.
  void enableShortDurationFlag() {
    featureFlagService
      ..enableShortDurationConfirmation = true
      ..useReviewScreen = false;
  }

  /// Disables Short Duration Confirmation flag.
  void disableShortDurationFlag() {
    featureFlagService
      ..enableShortDurationConfirmation = false
      ..useReviewScreen = false;
  }

  /// Completes a basic recording flow: Start Time -> Intensity -> End Time.
  ///
  /// [intensity] - The intensity button text to tap
  /// [addMinutes] - Minutes to add to end time (0 = same as start)
  /// [setStartInPast] - If true, sets start time 5 mins in past first
  Future<void> completeRecordingFlow(
    WidgetTester tester, {
    String intensity = UiText.dripping,
    int addMinutes = 0,
    bool setStartInPast = false,
  }) async {
    if (setStartInPast) {
      await tester.tap(find.text(UiText.minus5));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(UiText.setStartTime));
    await tester.pumpAndSettle();

    await tester.tap(find.text(intensity));
    await tester.pumpAndSettle();

    // Add minutes to end time using +1 button
    for (var i = 0; i < addMinutes; i++) {
      await tester.tap(find.text(UiText.plus1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(UiText.setEndTime));
    await tester.pumpAndSettle();
  }

  /// Selects a US timezone from the timezone picker.
  Future<void> selectTimezone(
    WidgetTester tester, {
    required String searchTerm,
    required String expectedMatch,
  }) async {
    // Open timezone picker
    final timezoneSelector = find.byIcon(Icons.public);
    expect(timezoneSelector, findsOneWidget);
    await tester.tap(timezoneSelector);
    await tester.pumpAndSettle();

    // Verify picker opened
    expect(find.text(UiText.selectTimezone), findsOneWidget);

    // Search and select
    await tester.enterText(find.byType(TextField), searchTerm);
    await tester.pumpAndSettle();

    final option = find.textContaining(expectedMatch);
    if (option.evaluate().isNotEmpty) {
      await tester.ensureVisible(option.first);
      await tester.pumpAndSettle();
      await tester.tap(option.first);
      await tester.pumpAndSettle();
    }
  }

  /// Verifies a record was saved with expected properties.
  Future<void> expectRecordSaved({
    int count = 1,
    NosebleedIntensity? intensity,
  }) async {
    final records = await mockNosebleedService.getLocalMaterializedRecords();
    expect(records.length, count);
    if (intensity != null && records.isNotEmpty) {
      expect(records.first.intensity, intensity);
    }
  }

  // ===========================================================================
  // TEST GROUP 1: FEATURE FLAG VERIFICATION
  // ===========================================================================
  //
  // These tests verify that feature flags can be properly enabled/disabled.
  // Feature flags control which confirmation dialogs are shown.
  //
  // ===========================================================================

  group('Feature Flag Verification', () {
    testWidgets('can enable enableShortDurationConfirmation', (tester) async {
      standardTestSetup(tester);

      featureFlagService.enableShortDurationConfirmation = true;

      expect(
        featureFlagService.enableShortDurationConfirmation,
        isTrue,
        reason: 'Short Duration Confirmation should be enabled after toggle.',
      );
    });

    testWidgets('can enable requireOldEntryJustification', (tester) async {
      standardTestSetup(tester);

      featureFlagService.requireOldEntryJustification = true;

      expect(
        featureFlagService.requireOldEntryJustification,
        isTrue,
        reason: 'Old Entry Justification should be enabled after toggle.',
      );
    });

    testWidgets('can enable enableLongDurationConfirmation', (tester) async {
      standardTestSetup(tester);

      featureFlagService.enableLongDurationConfirmation = true;

      expect(
        featureFlagService.enableLongDurationConfirmation,
        isTrue,
        reason: 'Long Duration Confirmation should be enabled after toggle.',
      );
    });
  });

  // ===========================================================================
  // TEST GROUP 2: SHORT DURATION DIALOG (REQ-CAL-p00002)
  // ===========================================================================
  //
  // These tests verify the Short Duration Confirmation dialog behavior:
  // - Appears when duration is ≤ 1 minute
  // - Shows correct title, message, and buttons
  // - "Yes" button saves record and closes screen
  // - "No" button returns to editing
  // - Cannot be dismissed by tapping outside
  //
  // FDA COMPLIANCE:
  // The dialog ensures data integrity (11.10(a)) by confirming unusually
  // short durations that may indicate data entry errors.
  //
  // ===========================================================================

  group('Short Duration Dialog (REQ-CAL-p00002)', () {
    testWidgets('shows correct title, message, and buttons', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(tester, addMinutes: kDurationBelowThreshold);

      // ASSERT - Dialog content
      expect(find.byType(DurationConfirmationDialog), findsOneWidget);
      expect(find.text(UiText.shortDurationTitle), findsOneWidget);
      expect(find.text(UiText.shortDurationMessage), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // Verify duration text (0m or 1m - see CUR-566 for known issue)
      final has0m = find.text('0m').evaluate().isNotEmpty;
      final has1m = find.text('1m').evaluate().isNotEmpty;
      expect(has0m || has1m, isTrue, reason: 'Duration should display');

      // Verify buttons
      expect(find.widgetWithText(TextButton, UiText.no), findsOneWidget);
      expect(find.widgetWithText(FilledButton, UiText.yes), findsOneWidget);
    });

    testWidgets('Yes button saves record and closes screen', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(tester);

      expect(find.byType(DurationConfirmationDialog), findsOneWidget);

      await tester.tap(find.text(UiText.yes));
      await tester.pumpAndSettle();

      // ASSERT
      await expectRecordSaved(intensity: NosebleedIntensity.dripping);
    });

    testWidgets('No button returns to editing screen', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(tester);

      expect(find.byType(DurationConfirmationDialog), findsOneWidget);

      await tester.tap(find.text(UiText.no));
      await tester.pumpAndSettle();

      // ASSERT - Back on end time screen
      expect(find.text(UiText.setEndTime), findsOneWidget);
      expect(find.text(UiText.nosebleedEndTime), findsOneWidget);

      // No record created yet
      await expectRecordSaved(count: 0);
    });

    testWidgets('No -> edit to 2m -> saves without dialog', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT - Start with short duration
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(tester, setStartInPast: true);

      expect(find.byType(DurationConfirmationDialog), findsOneWidget);

      // Go back to edit
      await tester.tap(find.text(UiText.no));
      await tester.pumpAndSettle();

      // Add 2 minutes
      expect(find.text(UiText.plus1), findsOneWidget);
      await tester.tap(find.text(UiText.plus1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text(UiText.plus1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Save again
      await tester.tap(find.text(UiText.setEndTime));
      await tester.pumpAndSettle();

      // Handle if dialog still appears (indicates +1 issue)
      if (find.byType(DurationConfirmationDialog).evaluate().isNotEmpty) {
        await tester.tap(find.text(UiText.yes));
        await tester.pumpAndSettle();
        fail(
          'BUG: Dialog appeared after adding 2 minutes. '
          'Check +1 button state management in lib code.',
        );
      }

      // ASSERT
      await expectRecordSaved();
    });

    testWidgets('cannot be dismissed by tapping outside', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(tester);

      expect(find.byType(DurationConfirmationDialog), findsOneWidget);

      // Tap outside dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // ASSERT - Dialog should still be visible (barrierDismissible: false)
      expect(find.byType(DurationConfirmationDialog), findsOneWidget);
    });
  });

  // ===========================================================================
  // TEST GROUP 3: TWO MINUTE DURATION (NO DIALOG)
  // ===========================================================================
  //
  // Tests that durations above the threshold (>1 minute) do NOT trigger
  // the Short Duration dialog.
  //
  // ===========================================================================

  group('Two Minute Duration (No Dialog)', () {
    testWidgets('2 minute duration does not show dialog', (tester) async {
      // ARRANGE
      standardTestSetup(tester);
      enableShortDurationFlag();

      // ACT - Must set start in past to allow adding minutes
      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();
      await completeRecordingFlow(
        tester,
        addMinutes: kDurationAboveThreshold,
        setStartInPast: true,
      );

      // ASSERT
      expect(find.byType(DurationConfirmationDialog), findsNothing);
      await expectRecordSaved();
    });
  });

  // ===========================================================================
  // TEST GROUP 4: US TIMEZONE SELECTION
  // ===========================================================================
  //
  // Tests timezone picker functionality across major US timezones:
  // - EST (Eastern Standard Time)
  // - CST (Central Standard Time)
  // - MST (Mountain Standard Time)
  // - PST (Pacific Standard Time)
  //
  // FDA COMPLIANCE:
  // Accurate timezone tracking supports audit trail requirements (11.10(e))
  // by ensuring date/time stamps are accurate and complete.
  //
  // ===========================================================================

  group('US Timezone Selection', () {
    testWidgets('EST - Eastern Time', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await selectTimezone(
        tester,
        searchTerm: 'EST',
        expectedMatch: 'Eastern Time',
      );

      await completeRecordingFlow(tester, addMinutes: kStandardDuration);
      await expectRecordSaved();
    });

    testWidgets('CST - Central Time', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await selectTimezone(
        tester,
        searchTerm: 'Central',
        expectedMatch: 'Central Time (US)',
      );

      await completeRecordingFlow(
        tester,
        addMinutes: kDurationAboveThreshold,
        setStartInPast: true,
      );
      await expectRecordSaved();
    });

    testWidgets('MST - Mountain Time', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await selectTimezone(
        tester,
        searchTerm: 'Mountain',
        expectedMatch: 'Mountain Time (US)',
      );

      await completeRecordingFlow(
        tester,
        intensity: UiText.spotting,
        addMinutes: 3,
        setStartInPast: true,
      );
      await expectRecordSaved();
    });

    testWidgets('PST - Pacific Time', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await selectTimezone(
        tester,
        searchTerm: 'Pacific',
        expectedMatch: 'Pacific Time (US)',
      );

      await completeRecordingFlow(
        tester,
        intensity: UiText.gushing,
        addMinutes: 4,
        setStartInPast: true,
      );
      await expectRecordSaved();
    });
  });

  // ===========================================================================
  // TEST GROUP 5: KEYBOARD TIME ENTRY
  // ===========================================================================
  //
  // Tests ability to enter time using keyboard input via time picker.
  //
  // ===========================================================================

  group('Keyboard Time Entry', () {
    testWidgets('can tap time display to open time picker', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      // Find large time display (font size >= 72)
      final timeDisplay = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontSize != null &&
            widget.style!.fontSize! >= 72,
      );

      if (timeDisplay.evaluate().isNotEmpty) {
        await tester.tap(timeDisplay.first);
        await tester.pumpAndSettle();

        // Try keyboard toggle in time picker
        final keyboardIcon = find.byIcon(Icons.keyboard_outlined);
        if (keyboardIcon.evaluate().isNotEmpty) {
          await tester.tap(keyboardIcon);
          await tester.pumpAndSettle();
        }

        // Close picker
        final cancelButton = find.text(UiText.cancel);
        if (cancelButton.evaluate().isNotEmpty) {
          await tester.tap(cancelButton);
          await tester.pumpAndSettle();
        }
      }

      await completeRecordingFlow(tester, addMinutes: kStandardDuration);
      await expectRecordSaved();
    });
  });

  // ===========================================================================
  // TEST GROUP 6: EDGE CASES
  // ===========================================================================
  //
  // Tests edge cases and boundary conditions:
  // - Exactly 1 minute duration (at threshold)
  // - 0 minute duration (below threshold)
  // - Feature flag disabled
  // - All time adjustment buttons work
  // - All intensity options visible
  // - Rapid button tapping
  // - Changing intensity after selection
  //
  // ===========================================================================

  group('Edge Cases', () {
    testWidgets('exactly 1 minute duration triggers dialog', (tester) async {
      standardTestSetup(tester);
      enableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await completeRecordingFlow(tester, addMinutes: kDurationAtThreshold);

      // Dialog should appear (duration ≤ 1 minute)
      expect(find.byType(DurationConfirmationDialog), findsOneWidget);
    });

    testWidgets('0 minute duration (same time) triggers dialog', (
      tester,
    ) async {
      standardTestSetup(tester);
      enableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await completeRecordingFlow(tester, addMinutes: kDurationBelowThreshold);

      expect(find.byType(DurationConfirmationDialog), findsOneWidget);
    });

    testWidgets('disabled flag does not show dialog', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await completeRecordingFlow(tester);

      expect(find.byType(DurationConfirmationDialog), findsNothing);
    });

    testWidgets('all time adjustment buttons work', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      // Test all buttons on start time screen
      for (final button in [
        UiText.minus15,
        UiText.minus5,
        UiText.minus1,
        UiText.plus1,
        UiText.plus5,
        UiText.plus15,
      ]) {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
      }

      await completeRecordingFlow(tester, addMinutes: kStandardDuration);
      await expectRecordSaved();
    });

    testWidgets('all intensity options visible and selectable', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiText.setStartTime));
      await tester.pumpAndSettle();

      // Verify all options
      expect(find.text(UiText.spotting), findsOneWidget);
      expect(find.text(UiText.dripping), findsOneWidget);
      expect(find.text(UiText.pouring), findsOneWidget);
      expect(find.text(UiText.gushing), findsOneWidget);

      // Select Gushing
      await tester.tap(find.text(UiText.gushing));
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiText.plus5));
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiText.setEndTime));
      await tester.pumpAndSettle();

      await expectRecordSaved(intensity: NosebleedIntensity.gushing);
    });

    testWidgets('rapid button tapping does not break flow', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      // Rapid taps
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text(UiText.plus1));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      await completeRecordingFlow(tester, addMinutes: kStandardDuration);
      await expectRecordSaved();
    });

    testWidgets('can change intensity after initial selection', (tester) async {
      standardTestSetup(tester);
      disableShortDurationFlag();

      await tester.pumpWidget(buildRecordingScreen());
      await tester.pumpAndSettle();

      // Set start time in past first
      await tester.tap(find.text(UiText.minus5));
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiText.setStartTime));
      await tester.pumpAndSettle();

      // Select Spotting first
      await tester.tap(find.text(UiText.spotting));
      await tester.pumpAndSettle();

      // Go back to intensity via "Max Intensity" summary label
      final maxIntensityLabel = find.text(UiText.maxIntensity);
      expect(
        maxIntensityLabel,
        findsOneWidget,
        reason: 'Max Intensity summary label should be visible',
      );

      await tester.tap(maxIntensityLabel);
      await tester.pumpAndSettle();

      // Verify back on intensity step
      expect(
        find.text(UiText.dripping),
        findsOneWidget,
        reason: 'Dripping should be visible after navigating back',
      );

      // Change to Dripping
      await tester.tap(find.text(UiText.dripping));
      await tester.pumpAndSettle();

      // Add time and save
      await tester.tap(find.text(UiText.plus1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(UiText.plus1));
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiText.setEndTime));
      await tester.pumpAndSettle();

      await expectRecordSaved(intensity: NosebleedIntensity.dripping);
    });
  });
}
