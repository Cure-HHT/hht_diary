// CUR-1169 / CUR-1522: HomeScreen end-to-end coverage on the native
// event_sourcing diary scope (the sole runtime after the legacy diary-client
// sync runtime was removed).
//
// The original 2729-line integration test bundled a long catalogue of
// scenarios — most of which now live in narrower, faster suites:
//
//  - Record CRUD over the runtime (add/edit/delete + drain): covered by
//    test/integration/cutover_flow_test.dart scenarios 1-3.
//  - 5-state dayStatus + reader queries: covered by cutover_flow_test.dart
//    scenario 11, plus test/services/diary_entry_reader_test.dart.
//  - HomeScreen empty state, yesterday banner Yes/No/Don't-remember,
//    Record Nosebleed navigation: covered by
//    test/screens/home_screen_test.dart.
//  - Calendar refresh after delete (CUR-586) and past-date creation
//    (CUR-543): covered by test/screens/calendar_screen_test.dart with
//    pre-seeded entries.
//  - Recording-screen save flow / partial-save / overlap detection:
//    covered by test/screens/recording_screen_test.dart and
//    test/screens/simple_recording_screen_test.dart.
//  - Enrollment flow / Active-status banner (CUR-1063): covered by
//    test/screens/clinical_trial_enrollment_screen_test.dart.
//
// What stays here is the truly cross-cutting end-to-end behaviour:
//
//  1. A pre-recorded epistaxis_event flows through bootstrap -> reader ->
//     HomeScreen -> EventListItem and surfaces in the rendered list with the
//     FlashHighlight wrapper applied.
//  2. A pre-recorded incomplete event surfaces both as an EventListItem AND
//     as the orange incomplete-records banner.
//  3. The yesterday banner hides once a yesterday-dated entry exists.
//  4. The LogoMenu opens, navigates to the Licenses page, and the legacy
//     "Check for updates" affordance is gone (CUR-990).
//
// All scenarios drive a real DiaryScopeRuntime against an in-memory
// Sembast backend (no MockClient HTTP path is exercised — the home screen
// itself doesn't issue HTTP, the destinations layer does, and that's
// covered by cutover_flow_test.dart).

import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

const _deviceId = 'home-int-device-001';
const _softwareVersion = 'clinical_diary@0.0.0+integration';
const _userId = 'home-int-user-001';

/// Bounded pumps. Avoids pumpAndSettle infinite-loop on widgets with
/// indefinite animators (Scrollbar, FlashHighlight) while still letting
/// async post-frame work complete via Dart microtasks. Mirrors the
/// `_settle` helper in test/screens/home_screen_test.dart.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

// Verifies: DIARY-PRD-mobile-offline-first/A+B+C
// Verifies: DIARY-PRD-mobile-application/A+B
void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    setUpTestFlavor();
  });

  group('HomeScreen Integration', () {
    late DiaryScopeRuntime diaryScope;
    late MockEnrollmentService enrollment;
    late TaskService tasks;

    setUp(() async {
      // Fix device timezone to UTC+0 so that toDisplayedDateTime with
      // startTimeZone='UTC' is an identity transform (stored == displayed).
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';
      SharedPreferences.setMockInitialValues({});
      enrollment = MockEnrollmentService();
      tasks = TaskService();
      // The diary surface reads/writes through the native reactive composition
      // root. Build a real in-memory diary scope and seed it via its action
      // submitter so the DiaryViewBuilder surfaces entries live.
      final scopeDb = await newDatabaseFactoryMemory().openDatabase(
        'home-int-scope-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      diaryScope = await bootstrapDiaryScope(
        backend: SembastBackend(database: scopeDb),
        deviceId: _deviceId,
        softwareVersion: _softwareVersion,
        localUserId: _userId,
      );
    });

    tearDown(() async {
      await diaryScope.dispose();
      tasks.dispose();
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;
    });

    Future<void> pumpHomeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ReActionScope(
          scope: diaryScope.scope,
          child: wrapWithMaterialApp(
            HomeScreen(
              diaryScope: diaryScope,
              deviceId: _deviceId,
              enrollmentService: enrollment,
              taskService: tasks,
            ),
          ),
        ),
      );
      await _settle(tester);
    }

    /// Submit a diary action through the new scope inside `runAsync` so the
    /// store's internal real-timer async fires under the fake test clock, then
    /// pump so the resulting view emission reaches the DiaryViewBuilder.
    Future<void> submitAction(
      WidgetTester tester,
      String actionName,
      Map<String, Object?> rawInput,
    ) async {
      await tester.runAsync(() async {
        await diaryScope.scope.actionSubmitter.submit(
          ActionSubmission(actionName: actionName, rawInput: rawInput),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
    }

    /// `EpistaxisEventPayload.toJson` rawInput for [start] / optional [end].
    Map<String, Object?> epistaxisInput(DateTime start, {DateTime? end}) {
      return EpistaxisEventPayload(
        startTime: start.toIso8601String(),
        startTimeZone: 'UTC',
        startTimeUtcOffset: '+00:00',
        participantId: 'P-test',
        endTime: end?.toIso8601String(),
        endTimeZone: end == null ? null : 'UTC',
        endTimeUtcOffset: end == null ? null : '+00:00',
        intensity: end == null ? null : NosebleedIntensity.dripping,
      ).toJson();
    }

    // -----------------------------------------------------------------------
    // 1. End-to-end: a finalized epistaxis_event recorded via the real
    //    EntryService surfaces on the HomeScreen as an EventListItem,
    //    wrapped in a FlashHighlight (CUR-464).
    // -----------------------------------------------------------------------
    testWidgets(
      'seeded finalized event renders as an EventListItem inside FlashHighlight',
      (tester) async {
        final now = DateTime.now();
        await pumpHomeScreen(tester);
        await submitAction(
          tester,
          'record_epistaxis_event',
          epistaxisInput(
            DateTime(now.year, now.month, now.day, 10),
            end: DateTime(now.year, now.month, now.day, 10, 30),
          ),
        );
        await _settle(tester);

        // The event surfaces as exactly one list item.
        expect(find.byType(EventListItem), findsOneWidget);
        // CUR-464: the list item is wrapped in FlashHighlight so newly
        // created entries can flash on the home page.
        expect(find.byType(FlashHighlight), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 2. End-to-end: a checkpointed (incomplete) event renders both as a
    //    list item AND as the orange incomplete-records banner above the list.
    // -----------------------------------------------------------------------
    testWidgets(
      'incomplete (checkpoint) event surfaces in list and incomplete banner',
      (tester) async {
        final now = DateTime.now();
        await pumpHomeScreen(tester);
        // No endTime / no intensity — checkpoint is incomplete.
        await submitAction(
          tester,
          'checkpoint_epistaxis_event',
          epistaxisInput(DateTime(now.year, now.month, now.day, 9)),
        );
        await _settle(tester);

        // Surfaces as one list item.
        expect(find.byType(EventListItem), findsOneWidget);
        // The incomplete alert is consolidated as a row inside the "Needs your
        // attention" tile. Before the checkpoint existed the whole Task List
        // section was hidden (count 0 → no section at all, CUR-1519), so the
        // tile is built fresh once the checkpoint arrives — with count > 0 it
        // starts expanded, surfacing the alert row immediately.
        expect(find.text('Needs your attention'), findsOneWidget);
        expect(find.text('1 incomplete record'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Yesterday banner hides when yesterday has at least one entry.
    //    The empty-state path (banner visible, Yes/No/Don't remember
    //    buttons reachable) is asserted in home_screen_test.dart; this is
    //    the inverse claim.
    // -----------------------------------------------------------------------
    testWidgets(
      'yesterday banner is hidden when a yesterday-dated entry exists',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await pumpHomeScreen(tester);
        await submitAction(
          tester,
          'record_epistaxis_event',
          epistaxisInput(
            DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
            end: DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              10,
              30,
            ),
          ),
        );
        await _settle(tester);

        // YesterdayBanner widget is gone — hasYesterdayRecords=true short-
        // circuits the conditional in HomeScreen.build.
        expect(find.byType(YesterdayBanner), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 4. Logo menu navigation: tap the logo, choose Licenses, see the
    //    LicensesPage. The legacy "Check for updates" affordance is gone
    //    (CUR-990).
    // -----------------------------------------------------------------------
    testWidgets(
      'logo menu navigates to LicensesPage and omits "Check for updates"',
      (tester) async {
        await pumpHomeScreen(tester);

        // Open the LogoMenu (PopupMenuButton).
        await tester.tap(find.byType(LogoMenu));
        await _settle(tester);

        // CUR-990: the legacy "Check for updates" option is gone.
        expect(find.text('Check for updates'), findsNothing);

        // Tap the Licenses menu item.
        final licensesEntry = find.text('Licenses');
        expect(licensesEntry, findsWidgets);
        await tester.tap(licensesEntry.first);
        await _settle(tester);

        // The LicensesPage (Flutter's built-in license screen) is now on top.
        expect(find.byType(LicensesPage), findsOneWidget);
      },
    );
  });
}
