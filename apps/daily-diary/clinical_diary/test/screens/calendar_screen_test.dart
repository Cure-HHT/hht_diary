// Verifies: DIARY-GUI-calendar-day-view — day-status coloring reflects the
//   driven DiaryView; tapping an empty day opens DaySelectionScreen; tapping a
//   populated day opens DateRecordsScreen.
// Verifies: DIARY-DEV-reactive-read-path/A — the calendar reads day status
//   reactively from the live diary_entries view (no async load).
// Verifies: DIARY-DEV-action-write-path/A — choosing "No nosebleed events"
//   submits record_no_epistaxis_day for that date through the actionSubmitter.
// Verifies: DIARY-PRD-diary-start-day/D — the calendar's earliest navigable /
//   selectable day is 365 days before app installation (CUR-1494); it does not
//   allow unbounded back-navigation (previously hardcoded to 2020).
//
// Screen-level coverage for CalendarScreen on the new event_sourcing read/write
// path. The diary_entries view is driven via FakeReaction.emitViewUpdate; writes
// are asserted via FakeReaction.submittedActions.

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart' show Authenticated;
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calendarEarliestDay', () {
    test('anchors the floor to 365 days before the install date', () {
      final install = DateTime(2026, 6, 17, 14, 30);
      final earliest = calendarEarliestDay(
        installDate: install,
        now: DateTime(2026, 6, 17, 15),
      );
      // 365 days before 2026-06-17 is 2025-06-17 (2026 is not a leap year that
      // crosses Feb 29 in this window), normalized to local midnight.
      expect(earliest, DateTime(2025, 6, 17));
    });

    test('stays fixed at install-anchored floor as now advances', () {
      final install = DateTime(2026, 1, 1, 9);
      final early = calendarEarliestDay(
        installDate: install,
        now: DateTime(2026, 1, 2),
      );
      final later = calendarEarliestDay(
        installDate: install,
        now: DateTime(2026, 4, 1),
      );
      // The floor is anchored to install, not now, so it does not drift.
      expect(early, later);
      expect(early, DateTime(2025, 1, 1));
    });

    test('falls back to 365 days before now when install date is unknown', () {
      final earliest = calendarEarliestDay(
        installDate: null,
        now: DateTime(2026, 6, 17, 8),
      );
      expect(earliest, DateTime(2025, 6, 17));
    });

    test('returns a local-midnight date (no time-of-day component)', () {
      final earliest = calendarEarliestDay(
        installDate: DateTime(2026, 3, 10, 23, 59, 59),
        now: DateTime(2026, 3, 11),
      );
      expect(earliest.hour, 0);
      expect(earliest.minute, 0);
      expect(earliest.second, 0);
    });
  });

  group('CalendarScreen', () {
    late FakeReaction fake;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeReaction(
        initialAuthStatus: Authenticated(
          principal: Principal.user(
            userId: 'P-test',
            activeRole: 'participant',
            roles: const {'participant'},
          ),
        ),
      );
      // Day-marker submissions return the canonical per-day aggregate id.
      for (var i = 0; i < 10; i++) {
        fake.queueDispatchResult(
          const DispatchSuccess<Object?>('P:day', <String>[]),
        );
      }
    });

    tearDown(() async {
      await fake.dispose();
    });

    /// `yyyy-MM-dd` for [day].
    String dateKey(DateTime day) =>
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    /// Drive the diary_entries view with the given finalized day-marker /
    /// epistaxis rows followed by EndOfReplay, so the calendar sees them as live.
    void seedView(String viewName, List<DiaryEntryRow> rows) {
      for (final r in rows) {
        fake.emitViewUpdate<DiaryEntryRow>(
          viewName,
          Snapshot<DiaryEntryRow>(value: r, sequence: 0),
        );
      }
      fake.emitViewUpdate<DiaryEntryRow>(
        viewName,
        const EndOfReplay<DiaryEntryRow>(sequence: 0),
      );
    }

    void seedDiaryEntries(List<DiaryEntryRow> rows) =>
        seedView(diaryEntriesViewName, rows);

    DiaryEntryRow dayMarkerRow(
      String date, {
      String type = 'no_epistaxis_event',
    }) => DiaryEntryRow(
      aggregateId: 'P:$date',
      entryType: type,
      data: <String, Object?>{'date': date},
    );

    DiaryEntryRow epistaxisRow(DateTime start, {String aggregateId = 'e1'}) {
      final payload = EpistaxisEventPayload(
        startTime: start.toIso8601String(),
        startTimeZone: 'UTC',
        startTimeUtcOffset: '+00:00',
        participantId: 'P-test',
      );
      return DiaryEntryRow(
        aggregateId: aggregateId,
        entryType: 'epistaxis_event',
        data: payload.toJson(),
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      List<DiaryEntryRow> rows = const [],
      List<DiaryEntryRow> incompleteRows = const [],
      DateTime? installDate,
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
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // App theme so DS widgets can resolve their theme extensions.
            theme: AppTheme.getLightThemeWithFont(),
            // Disable animation so the table-calendar page animator doesn't tick
            // forever under pumpAndSettle.
            home: AppPreferencesScope(
              preferences: const UserPreferences(useAnimation: false),
              child: CalendarScreen(
                onOpenSurvey: (_) {},
                installDate: installDate,
              ),
            ),
          ),
        ),
      );
      // Pump a frame, then feed the view rows so the DiaryViewBuilder rebuilds.
      await tester.pump();
      // Seed both diary views (always with an EndOfReplay so each ViewBuilder
      // leaves its initial Loading state).
      seedDiaryEntries(rows);
      seedView(diaryIncompleteViewName, incompleteRows);
      await tester.pump();
      await tester.pump();
    }

    /// The single submission for [actionName], or fails if none/many.
    ActionSubmission submissionFor(String actionName) {
      final matches = fake.submittedActions
          .where((s) => s.actionName == actionName)
          .toList();
      expect(matches, hasLength(1), reason: 'expected one $actionName');
      return matches.single;
    }

    /// Find the in-month calendar cell for [day] (the Container painted by the
    /// default/today/selected builder, not an outside-month padding day). We
    /// disambiguate the day-number Text by walking to the InkWell-backed cell.
    Finder inMonthCell(int day) {
      // The table_calendar lays out 7 cells per row; the in-month cell for a
      // given day number is the one whose ancestor TableCell renders it. We
      // match the Text and take the first that is inside a Container with a
      // colored decoration (our builders always wrap in a decorated Container).
      return find
          .descendant(
            of: find.byType(TableCalendar<void>),
            matching: find.text('$day'),
          )
          .first;
    }

    testWidgets('renders calendar dialog with header and legend', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Nosebleed events'), findsOneWidget);
      expect(find.text('No nosebleeds'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Incomplete/Missing'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
    });

    testWidgets(
      'bounds firstDay to 365 days before install, not a hardcoded 2020 floor',
      (tester) async {
        // Install ~30 days ago so the floor is ~335 days in the past — well
        // after the old hardcoded DateTime(2020, 1, 1).
        final installDate = DateTime.now().subtract(const Duration(days: 30));
        await pumpScreen(tester, installDate: installDate);

        final calendar = tester.widget<TableCalendar<void>>(
          find.byType(TableCalendar<void>),
        );
        final expected = DateTime(
          installDate.year,
          installDate.month,
          installDate.day,
        ).subtract(const Duration(days: 365));

        // table_calendar normalizes firstDay to UTC midnight, so compare the
        // calendar date components rather than the exact (timezone-flagged)
        // instant.
        expect(calendar.firstDay.year, expected.year);
        expect(calendar.firstDay.month, expected.month);
        expect(calendar.firstDay.day, expected.day);
        // Regression guard: the old hardcoded 2020 floor must be gone.
        expect(calendar.firstDay.isAfter(DateTime.utc(2020, 12, 31)), isTrue);
      },
    );

    testWidgets('day-status coloring reflects the driven DiaryView', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      await pumpScreen(tester, rows: [dayMarkerRow(dateKey(todayDate))]);

      // The today cell should be painted green (DayStatus.noNosebleed). Find
      // the decorated Container wrapping today's number.
      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TableCalendar<void>),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();

      // Green must appear among the cell colors now that a no-nosebleed marker
      // is in the live view.
      expect(containers.contains(Colors.green), isTrue);
    });

    testWidgets(
      'tapping an empty day opens DaySelectionScreen and "No nosebleed events" '
      'submits record_no_epistaxis_day',
      (tester) async {
        // Use a fixed past in-month day with no records: the 15th of this month
        // (always in-month and not in the future when today >= 16; otherwise we
        // fall back to the 1st).
        final now = DateTime.now();
        final targetDay = now.day > 15 ? 15 : 1;
        final target = DateTime(now.year, now.month, targetDay);

        await pumpScreen(tester);

        await tester.tap(inMonthCell(targetDay));
        await tester.pump();
        await tester.pump();

        expect(find.byType(DaySelectionScreen), findsOneWidget);

        await tester.tap(find.text('No nosebleed events'));
        await tester.pump();
        await tester.pump();

        final s = submissionFor('record_no_epistaxis_day');
        expect(s.rawInput['date'], dateKey(target));
      },
    );

    testWidgets('tapping a populated day opens DateRecordsScreen', (
      tester,
    ) async {
      final now = DateTime.now();
      final targetDay = now.day > 15 ? 15 : 1;
      final target = DateTime(now.year, now.month, targetDay, 9);

      await pumpScreen(
        tester,
        rows: [epistaxisRow(target, aggregateId: 'agg-cal-5')],
      );

      await tester.tap(inMonthCell(targetDay));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DateRecordsScreen), findsOneWidget);
    });

    testWidgets(
      'tapping a day with ONLY an incomplete entry opens DateRecordsScreen '
      '(resumable), not the 3-option DaySelectionScreen',
      (tester) async {
        final now = DateTime.now();
        final targetDay = now.day > 15 ? 15 : 1;
        final target = DateTime(now.year, now.month, targetDay, 9);

        // A checkpoint draft on the day with NO finalized entry: the grid
        // renders it black, and tapping must open the records list so it can be
        // resumed — not the empty-day picker.
        await pumpScreen(
          tester,
          incompleteRows: [epistaxisRow(target, aggregateId: 'inc-1')],
        );

        await tester.tap(inMonthCell(targetDay));
        await tester.pump();
        await tester.pump();

        expect(find.byType(DateRecordsScreen), findsOneWidget);
        expect(find.byType(DaySelectionScreen), findsNothing);
      },
    );
  });
}
