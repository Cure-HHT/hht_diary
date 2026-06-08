// Verifies: DIARY-PRD-entry-overlap-resolution/D+E
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets(
    'two overlapping recordings -> one ordered pair; deleting the duplicate '
    'clears it',
    (tester) async {
      final rt = (await tester.runAsync(() async {
        final db = await newDatabaseFactoryMemory().openDatabase(
          'ovl-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        return bootstrapDiaryScope(
          backend: SembastBackend(database: db),
          deviceId: 'D',
          softwareVersion: 'clinical_diary@0.0.0-test',
          localUserId: 'P',
        );
      }))!;
      addTearDown(rt.dispose);

      DiaryView? latest;
      await tester.pumpWidget(
        ReActionScope(
          scope: rt.scope,
          child: MaterialApp(
            home: Scaffold(
              body: DiaryViewBuilder(
                builder: (context, DiaryView view) {
                  latest = view;
                  return Text(
                    'n:${view.finalizedRows.length}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          ),
        ),
      );

      Future<String> record(String start, String end) async {
        final r = await rt.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'record_epistaxis_event',
            rawInput: {
              'startTime': start,
              'startTimeZone': 'UTC',
              'startTimeUtcOffset': '+00:00',
              'participantId': 'P',
              'endTime': end,
              'endTimeZone': 'UTC',
              'endTimeUtcOffset': '+00:00',
            },
          ),
        );
        return (r as DispatchSuccess<Object?>).result! as String;
      }

      late String firstId;
      late String secondId;
      await tester.runAsync(() async {
        firstId = await record(
          '2025-10-15T13:00:00.000Z',
          '2025-10-15T14:00:00.000Z',
        );
        // Space the two recordings so their updated_at timestamps differ and
        // the first-recorded is unambiguously the older (preExisting) entry.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        secondId = await record(
          '2025-10-15T13:30:00.000Z',
          '2025-10-15T13:45:00.000Z',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump();

      // Detection + ordering against REAL materialized rows.
      final pairs = overlapPairs(latest!);
      expect(pairs, hasLength(1));
      expect(pairs.single.preExisting.aggregateId, firstId);
      expect(pairs.single.justTouched.aggregateId, secondId);

      // Resolve by tombstoning the duplicate (the just-touched entry).
      await tester.runAsync(() async {
        await rt.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'delete_entry',
            rawInput: {
              'aggregateId': secondId,
              'entryType': 'epistaxis_event',
              'changeReason': 'duplicate',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump();
      await tester.pump();

      expect(overlapPairs(latest!), isEmpty);
    },
  );
}
