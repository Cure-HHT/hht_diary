// Verifies: DIARY-BASE-local-data-reset/B+C — HomeScreen disables the reset
//   menu item while participating (HARD safeguard) or when the sponsor setting
//   disallows it; enables it when not-participating + setting true.
// Verifies: DIARY-BASE-local-data-reset/D — tapping the enabled reset item shows
//   the confirm dialog and invokes onResetAllData only on confirm.
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

const _deviceId = 'device-test-001';
const _softwareVersion = 'clinical_diary@0.0.0+test';

/// Boots the native event_sourcing diary scope over an in-memory Sembast
/// backend (no outbound destinations -> no SyncCycle).
Future<DiaryScopeRuntime> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'reset-gate-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    localUserId: 'P-test',
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    setUpTestFlavor();
  });

  group('HomeScreen reset gate', () {
    late DiaryScopeRuntime runtime;
    late MockEnrollmentService enrollment;
    late TaskService tasks;
    late FakeReaction fake;

    setUp(() async {
      fake = FakeReaction();
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';
      SharedPreferences.setMockInitialValues({});
      enrollment = MockEnrollmentService();
      tasks = TaskService();
      runtime = await _bootstrap();
    });

    tearDown(() async {
      await fake.dispose();
      await runtime.dispose();
      tasks.dispose();
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      required bool resetSettingAllowsReset,
      Future<void> Function()? onResetAllData,
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ReActionScope(
          scope: fake,
          child: wrapWithMaterialApp(
            HomeScreen(
              diaryScope: runtime,
              deviceId: _deviceId,
              enrollmentService: enrollment,
              taskService: tasks,
              resetSettingAllowsReset: resetSettingAllowsReset,
              onResetAllData: onResetAllData,
            ),
          ),
        ),
      );
      await tester.pump();
      // Drive the diary views to EndOfReplay so the list settles.
      fake
        ..emitViewUpdate<DiaryEntryRow>(
          diaryEntriesViewName,
          const EndOfReplay<DiaryEntryRow>(sequence: 0),
        )
        ..emitViewUpdate<DiaryEntryRow>(
          diaryIncompleteViewName,
          const EndOfReplay<DiaryEntryRow>(sequence: 0),
        );
      await _settle(tester);
    }

    Future<void> openLogoMenu(WidgetTester tester) async {
      // Tap the LogoMenu's PopupMenuButton directly (its trigger child differs
      // between enrolled/unenrolled states, so target the menu widget itself).
      await tester.tap(find.byType(LogoMenu));
      await tester.pumpAndSettle();
    }

    testWidgets('disabled while participating, even if the setting allows', (
      tester,
    ) async {
      // Enrolled + participating (not marked not-participating).
      enrollment.jwtToken = 'jwt';
      await enrollment.setNotParticipating(false);

      await pumpScreen(tester, resetSettingAllowsReset: true);
      await openLogoMenu(tester);

      expect(
        find.text('End your study participation to reset'),
        findsOneWidget,
      );
    });

    testWidgets(
      'disabled when the setting disallows, even if not participating',
      (tester) async {
        // Unenrolled (not participating) but sponsor setting disables reset.
        await pumpScreen(tester, resetSettingAllowsReset: false);
        await openLogoMenu(tester);

        expect(
          find.text('End your study participation to reset'),
          findsOneWidget,
        );
      },
    );

    testWidgets('enabled when not participating + setting true; confirm fires '
        'callback', (tester) async {
      var resetCalled = false;
      // Unenrolled => not participating; setting true => gate open.
      await pumpScreen(
        tester,
        resetSettingAllowsReset: true,
        onResetAllData: () async => resetCalled = true,
      );
      await openLogoMenu(tester);

      // No disabled reason; item enabled.
      expect(find.text('End your study participation to reset'), findsNothing);

      // Tapping opens the confirm dialog.
      await tester.tap(find.text('Reset All Data?'));
      await tester.pumpAndSettle();
      // The dialog title reuses the same string; the Reset confirm button is
      // present.
      expect(find.text('Reset'), findsOneWidget);

      // Cancel first: callback must NOT fire.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(resetCalled, isFalse);

      // Re-open and confirm: callback fires.
      await openLogoMenu(tester);
      await tester.tap(find.text('Reset All Data?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    });
  });
}
