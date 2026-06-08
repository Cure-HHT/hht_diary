// Verifies: DIARY-DEV-reactive-read-path/A
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
    'DiaryViewBuilder yields a DiaryView reflecting a recorded entry',
    (tester) async {
      final rt = (await tester.runAsync(() async {
        final db = await newDatabaseFactoryMemory().openDatabase(
          'dvb-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        return bootstrapDiaryScope(
          backend: SembastBackend(database: db),
          deviceId: 'D',
          softwareVersion: 'clinical_diary@0.0.0-test',
          localUserId: 'P',
        );
      }))!;
      addTearDown(rt.dispose);

      await tester.pumpWidget(
        ReActionScope(
          scope: rt.scope,
          child: MaterialApp(
            home: Scaffold(
              body: DiaryViewBuilder(
                builder: (context, DiaryView view) => Text(
                  'n:${view.entries.length}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await rt.scope.actionSubmitter.submit(
          const ActionSubmission(
            actionName: 'record_no_epistaxis_day',
            rawInput: {'date': '2025-10-15', 'participantId': 'P'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      await tester.pump();
      expect(find.text('n:1'), findsOneWidget);
    },
  );
}
