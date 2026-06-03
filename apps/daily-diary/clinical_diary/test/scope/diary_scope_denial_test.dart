// Verifies: DIARY-DEV-action-write-path/A — a denied dispatch records an
//   `action_denial` audit event and returns a clean DispatchResult, rather than
//   throwing. Requires the `action_denial` entry type to be registered in the
//   diary scope (the dispatcher persists a denial on every failed stage).
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<DiaryScopeRuntime> _boot() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'denial-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'D',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P',
  );
}

void main() {
  test(
    'an unknown action returns DispatchUnknownAction (does not throw)',
    () async {
      final rt = await _boot();
      final result = await rt.scope.actionSubmitter.submit(
        const ActionSubmission(actionName: 'no_such_action', rawInput: {}),
      );
      expect(result, isA<DispatchUnknownAction<Object?>>());
      await rt.dispose();
    },
  );

  test(
    'a parse failure returns DispatchParseDenied (does not throw)',
    () async {
      final rt = await _boot();
      // record_epistaxis_event with no startTime -> parseInput throws -> the
      // dispatcher records a parse denial and returns DispatchParseDenied.
      final result = await rt.scope.actionSubmitter.submit(
        const ActionSubmission(
          actionName: 'record_epistaxis_event',
          rawInput: <String, Object?>{},
        ),
      );
      expect(result, isA<DispatchParseDenied<Object?>>());
      await rt.dispose();
    },
  );
}
