// Verifies: DIARY-GUI-entry-overlap-resolution/A+B+C+D
import 'dart:async';

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

import '../helpers/test_helpers.dart';

DiaryEntryRow _row(
  String id,
  String start,
  String end,
  NosebleedIntensity intensity, {
  required String updatedAt,
}) {
  final data = EpistaxisEventPayload(
    startTime: start,
    startTimeZone: 'UTC',
    startTimeUtcOffset: '+00:00',
    participantId: 'P-test',
    endTime: end,
    endTimeZone: 'UTC',
    endTimeUtcOffset: '+00:00',
    intensity: intensity,
  ).toJson();
  data['updatedAt'] = updatedAt;
  return DiaryEntryRow(
    aggregateId: id,
    entryType: 'epistaxis_event',
    data: data,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReaction fake;

  setUp(() {
    fake = FakeReaction();
    for (var i = 0; i < 10; i++) {
      fake.queueDispatchResult(
        const DispatchSuccess<Object?>('agg', <String>[]),
      );
    }
  });

  void seed(List<DiaryEntryRow> rows) {
    for (final r in rows) {
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryEntriesViewName,
        Snapshot<DiaryEntryRow>(value: r, sequence: 0),
      );
    }
    fake.emitViewUpdate<DiaryEntryRow>(
      diaryEntriesViewName,
      const EndOfReplay<DiaryEntryRow>(sequence: 0),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ReActionScope(
        scope: fake,
        child: wrapWithMaterialApp(
          const OverlapCompareScreen(leftId: 'older', rightId: 'newer'),
        ),
      ),
    );
    // Initial settle allows the nested MaterialApp (from wrapWithMaterialApp)
    // to complete localization initialization and establish ViewBuilder
    // subscriptions before emitting view updates.
    await tester.pumpAndSettle();
    seed([
      _row(
        'older',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        NosebleedIntensity.dripping,
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _row(
        'newer',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        NosebleedIntensity.gushing,
        updatedAt: '2025-10-15T15:00:00.000Z',
      ),
    ]);
    await tester.pumpAndSettle();
  }

  testWidgets('pick left tombstones the right entry as a duplicate', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('overlap-pick-left')));
    await tester.pump();

    final deletes = fake.submittedActions.where(
      (a) => a.actionName == 'delete_entry',
    );
    expect(deletes, hasLength(1));
    expect(deletes.single.rawInput['aggregateId'], 'newer');
    expect(deletes.single.rawInput['changeReason'], 'duplicate');
  });

  testWidgets('pick right tombstones the left entry as a duplicate', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('overlap-pick-right')));
    await tester.pump();

    final deletes = fake.submittedActions.where(
      (a) => a.actionName == 'delete_entry',
    );
    expect(deletes, hasLength(1));
    expect(deletes.single.rawInput['aggregateId'], 'older');
    expect(deletes.single.rawInput['changeReason'], 'duplicate');
  });

  testWidgets('merge edits left to the union span and deletes right', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('overlap-merge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('overlap-merge-confirm')));
    // Both edit + delete are submitted synchronously during the tap (onConfirm
    // is a sync void callback). pumpAndSettle lets the sheet's close animation
    // finish; the extra pump() is a final drain.
    await tester.pumpAndSettle();
    await tester.pump();

    final edits = fake.submittedActions.where(
      (a) => a.actionName == 'edit_epistaxis_event',
    );
    expect(edits, hasLength(1));
    expect(edits.single.rawInput['aggregateId'], 'older');
    expect(edits.single.rawInput['startTime'], '2025-10-15T13:00:00.000Z');
    expect(edits.single.rawInput['endTime'], '2025-10-15T14:00:00.000Z');

    final deletes = fake.submittedActions.where(
      (a) => a.actionName == 'delete_entry',
    );
    expect(deletes, hasLength(1));
    expect(deletes.single.rawInput['aggregateId'], 'newer');
    expect(deletes.single.rawInput['changeReason'], 'duplicate');

    // The edit MUST precede the delete: the design's safety argument (if the
    // delete fails the pair re-surfaces, no data loss) depends on left already
    // spanning the union before right is tombstoned.
    final order = fake.submittedActions.map((a) => a.actionName).toList();
    expect(
      order.indexOf('edit_epistaxis_event'),
      lessThan(order.indexOf('delete_entry')),
    );
  });

  testWidgets('auto-pops back once a row disappears (overlap resolved)', (
    tester,
  ) async {
    // Push the screen onto a route so there is a host to pop back to.
    await tester.pumpWidget(
      ReActionScope(
        scope: fake,
        child: wrapWithMaterialApp(
          Builder(
            builder: (host) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(host).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OverlapCompareScreen(
                        leftId: 'older',
                        rightId: 'newer',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    seed([
      _row(
        'older',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        NosebleedIntensity.dripping,
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _row(
        'newer',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        NosebleedIntensity.gushing,
        updatedAt: '2025-10-15T15:00:00.000Z',
      ),
    ]);
    await tester.pumpAndSettle();
    // The live pair is shown.
    expect(find.byKey(const Key('overlap-merge')), findsOneWidget);
    expect(find.text('open'), findsNothing);

    // Resolve: the 'newer' row is tombstoned (as pick/merge would do live).
    fake.emitViewUpdate<DiaryEntryRow>(
      diaryEntriesViewName,
      const Tombstone<DiaryEntryRow>(aggregateId: 'newer', sequence: 1),
    );
    await tester.pumpAndSettle();

    // The screen auto-popped back to the host (no longer a live pair).
    expect(find.byKey(const Key('overlap-merge')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  // CUR-1548: the auto-pop must hand the SURVIVING entry back to the caller so
  // the recording flow's Confirm Record step can re-point itself at live data.
  // Keep Existing / Merge tombstone the new (`newer`) entry, so the survivor is
  // the pre-existing (`older`) one. Without this, the Confirm step keeps editing
  // the tombstoned new entry, resurrecting it and looping the participant back
  // to the Resolution Screen.
  testWidgets('auto-pop returns the surviving entry (existing kept/merged)', (
    tester,
  ) async {
    EpistaxisEntryView? survivor;
    await tester.pumpWidget(
      ReActionScope(
        scope: fake,
        child: wrapWithMaterialApp(
          Builder(
            builder: (host) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    survivor = await Navigator.of(host)
                        .push<EpistaxisEntryView?>(
                          MaterialPageRoute<EpistaxisEntryView?>(
                            builder: (_) => const OverlapCompareScreen(
                              leftId: 'older',
                              rightId: 'newer',
                            ),
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    seed([
      _row(
        'older',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        NosebleedIntensity.dripping,
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _row(
        'newer',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        NosebleedIntensity.gushing,
        updatedAt: '2025-10-15T15:00:00.000Z',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overlap-merge')), findsOneWidget);

    // The new entry is tombstoned (as Keep Existing / Merge do live).
    fake.emitViewUpdate<DiaryEntryRow>(
      diaryEntriesViewName,
      const Tombstone<DiaryEntryRow>(aggregateId: 'newer', sequence: 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(survivor, isNotNull);
    expect(survivor!.aggregateId, 'older');
  });

  // CUR-1548: Keep New tombstones the pre-existing (`older`) entry, so the
  // survivor handed back is the new (`newer`) one — the entry the recording
  // flow already tracks, so the Confirm step is unchanged (no loop, and no
  // accidental re-point away from the kept record).
  testWidgets('auto-pop returns the surviving entry (new kept)', (
    tester,
  ) async {
    EpistaxisEntryView? survivor;
    await tester.pumpWidget(
      ReActionScope(
        scope: fake,
        child: wrapWithMaterialApp(
          Builder(
            builder: (host) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    survivor = await Navigator.of(host)
                        .push<EpistaxisEntryView?>(
                          MaterialPageRoute<EpistaxisEntryView?>(
                            builder: (_) => const OverlapCompareScreen(
                              leftId: 'older',
                              rightId: 'newer',
                            ),
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    seed([
      _row(
        'older',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        NosebleedIntensity.dripping,
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _row(
        'newer',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        NosebleedIntensity.gushing,
        updatedAt: '2025-10-15T15:00:00.000Z',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overlap-merge')), findsOneWidget);

    // The pre-existing entry is tombstoned (as Keep New does live).
    fake.emitViewUpdate<DiaryEntryRow>(
      diaryEntriesViewName,
      const Tombstone<DiaryEntryRow>(aggregateId: 'older', sequence: 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(survivor, isNotNull);
    expect(survivor!.aggregateId, 'newer');
  });

  testWidgets(
    'does not pop a child route pushed on top when resolved underneath',
    (tester) async {
      // An Edit RecordingScreen is pushed on top of the compare screen. If a
      // resolving emission arrives while it is up, the compare screen must NOT
      // pop that child route out from under the user.
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ReActionScope(
          scope: fake,
          child: MaterialApp(
            navigatorKey: navKey,
            // Design-system theme so AppButton's theme extensions resolve.
            theme: buildAppTheme(),
            home: Builder(
              builder: (host) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(host).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OverlapCompareScreen(
                          leftId: 'older',
                          rightId: 'newer',
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      seed([
        _row(
          'older',
          '2025-10-15T13:00:00.000Z',
          '2025-10-15T14:00:00.000Z',
          NosebleedIntensity.dripping,
          updatedAt: '2025-10-15T14:00:00.000Z',
        ),
        _row(
          'newer',
          '2025-10-15T13:30:00.000Z',
          '2025-10-15T13:45:00.000Z',
          NosebleedIntensity.gushing,
          updatedAt: '2025-10-15T15:00:00.000Z',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overlap-merge')), findsOneWidget);

      // Push a route ON TOP of the compare screen (stands in for the Edit
      // RecordingScreen the compare screen would push).
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('child-on-top'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('child-on-top'), findsOneWidget);

      // Resolve the pair underneath while the child route is on top.
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryEntriesViewName,
        const Tombstone<DiaryEntryRow>(aggregateId: 'newer', sequence: 1),
      );
      await tester.pumpAndSettle();

      // The child route MUST still be on top — not popped out from under the
      // user by the compare screen's auto-pop.
      expect(find.text('child-on-top'), findsOneWidget);
    },
  );
}
