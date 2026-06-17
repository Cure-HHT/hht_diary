// Verifies: DIARY-PRD-incomplete-entry-preservation/B — the Incomplete Records
//   list renders each preserved (checkpointed) record so the participant can
//   resume it. This test pins the row's text layout: the "Incomplete Record"
//   label must be separated from the formatted timestamp by a space, so the
//   row reads "Incomplete Record 10:43 AM 06/15/2026" and never the
//   space-collapsed "Incomplete Record10:43 AM 06/15/2026" (CUR-1492).

import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/screens/incomplete_records_screen.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart' show Authenticated;
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    setUpTestFlavor();
  });

  group('IncompleteRecordsScreen row text', () {
    late FakeReaction fake;

    setUp(() {
      fake = FakeReaction(
        initialAuthStatus: Authenticated(
          principal: Principal.user(
            userId: 'P-test',
            activeRole: 'participant',
            roles: const {'participant'},
          ),
        ),
      );
      // Device timezone UTC+0 so a row stored as UTC displays unchanged.
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';
    });

    tearDown(() async {
      await fake.dispose();
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;
    });

    DiaryEntryRow incompleteEpistaxisRow(DateTime start, String aggregateId) {
      final payload = EpistaxisEventPayload(
        startTime: start.toIso8601String(),
        startTimeZone: 'UTC',
        startTimeUtcOffset: '+00:00',
        participantId: 'P-test',
        intensity: NosebleedIntensity.dripping,
      );
      return DiaryEntryRow(
        aggregateId: aggregateId,
        entryType: 'epistaxis_event',
        data: payload.toJson(),
      );
    }

    void seedIncomplete(List<DiaryEntryRow> rows) {
      for (final r in rows) {
        fake.emitViewUpdate<DiaryEntryRow>(
          diaryIncompleteViewName,
          Snapshot<DiaryEntryRow>(value: r, sequence: 0),
        );
      }
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryIncompleteViewName,
        const EndOfReplay<DiaryEntryRow>(sequence: 0),
      );
    }

    testWidgets(
      'separates the "Incomplete Record" label from the timestamp with a space',
      (tester) async {
        // 10:43 AM on 06/15/2026, matching the row format hh:mm a MM/dd/yyyy.
        final start = DateTime.utc(2026, 6, 15, 10, 43);

        await tester.pumpWidget(
          ReActionScope(
            scope: fake,
            child: wrapWithMaterialApp(const IncompleteRecordsScreen()),
          ),
        );
        await tester.pump();
        seedIncomplete([incompleteEpistaxisRow(start, 'agg-inc-1')]);
        await tester.pumpAndSettle();

        // The label and timestamp are distinct Text widgets pushed apart by a
        // Spacer, but the row's merged semantics concatenate them. A leading
        // space on the timestamp guarantees the combined reading separates the
        // two, never collapsing to "Incomplete Record10:43 AM 06/15/2026".
        expect(find.text('Incomplete Record'), findsOneWidget);

        // The timestamp Text exists and begins with a space — the separator
        // that keeps the row from collapsing to "Incomplete Record<time>".
        final timestampTexts = tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => (t.data ?? '').contains('06/15/2026'))
            .toList();
        expect(timestampTexts, hasLength(1));
        final timestamp = timestampTexts.single.data!;
        expect(
          timestamp.startsWith(' '),
          isTrue,
          reason: 'timestamp must lead with a space, got "$timestamp"',
        );
        expect(
          RegExp(r'^ \d\d:\d\d [AP]M 06/15/2026$').hasMatch(timestamp),
          isTrue,
          reason: 'expected " hh:mm a 06/15/2026", got "$timestamp"',
        );
        // And no widget renders the space-collapsed form.
        expect(find.textContaining('Record0'), findsNothing);
      },
    );
  });
}
