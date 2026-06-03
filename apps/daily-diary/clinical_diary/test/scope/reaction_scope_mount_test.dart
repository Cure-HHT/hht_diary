// Verifies: DIARY-DEV-evs-stack-adoption/B (scope mounted via the reaction_widgets
//   InheritedWidget; ViewBuilder/ActionBuilder resolve it)
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('ViewBuilder under ReActionScope reflects a dispatched setting', (
    tester,
  ) async {
    // Boot the real scope on the real event loop (tester.runAsync bypasses
    // Flutter's fake-timer zone so that sembast I/O and stream callbacks run).
    final rt = await tester.runAsync(() async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'i1w-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      return bootstrapDiaryScope(
        backend: SembastBackend(database: db),
        deviceId: 'DEV-1',
        softwareVersion: 'clinical_diary@0.0.0-test',
        localUserId: 'P-test',
      );
    });
    addTearDown(rt!.dispose);

    await tester.pumpWidget(
      ReActionScope(
        scope: rt.scope,
        child: MaterialApp(
          home: Scaffold(
            body: ViewBuilder<Map<String, Object?>>(
              viewName: settingsViewName,
              mapper: (r) => r,
              aggregateIdOf: (r) => r['aggregateId'] as String,
              builder: (context, state) => Text(
                'rows:${state is Ready<Map<String, Object?>> ? state.rows.length : 0}',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );
    // Flush the initial EndOfReplay so ViewBuilder transitions to Ready.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    // Submit an action on the real event loop and wait for projection to flush.
    await tester.runAsync(() async {
      await rt.scope.actionSubmitter.submit(
        const ActionSubmission(
          actionName: 'set_user_setting',
          rawInput: {'key': 'pref.darkMode', 'value': true},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    // Pump several frames so ViewBuilder._setState microtasks and redraws drain.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('rows:1'), findsOneWidget);
  });
}
