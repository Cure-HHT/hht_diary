// Verifies: DIARY-DEV-evs-stack-adoption/A+B
// Verifies: DIARY-DEV-action-write-path/A
//
// Full round-trip through the REAL LocalScope: submit an Action via the scope's
// actionSubmitter -> it dispatches -> appends -> projection -> read it back via
// the scope's viewSource. Proves the composition root is wired correctly.
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<DiaryScopeRuntime> _boot() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'i1-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-1',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
  );
}

Future<List<Map<String, Object?>>> _rows(
  DiaryScopeRuntime rt,
  String viewName,
) async {
  final out = <String, Map<String, Object?>>{};
  final sub = rt.scope.viewSource
      .watch<Map<String, Object?>>(viewName: viewName, mapper: (r) => r)
      .listen((u) {
        if (u is Snapshot<Map<String, Object?>>) {
          final v = u.value;
          if (v != null) {
            out[v['aggregateId'] as String? ?? v['key'] as String] = v;
          }
        }
      });
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await sub.cancel();
  return out.values.toList();
}

void main() {
  test('record_no_epistaxis_day round-trips through the scope', () async {
    final rt = await _boot();
    final result = await rt.scope.actionSubmitter.submit(
      const ActionSubmission(
        actionName: 'record_no_epistaxis_day',
        rawInput: {'date': '2025-10-15'},
      ),
    );
    expect(result, isA<DispatchSuccess<Object?>>());

    final rows = await _rows(rt, diaryEntriesViewName);
    expect(rows.map((r) => r['aggregateId']), contains('P-test:2025-10-15'));
    await rt.dispose();
  });

  test('set_user_setting round-trips through the scope', () async {
    final rt = await _boot();
    final result = await rt.scope.actionSubmitter.submit(
      const ActionSubmission(
        actionName: 'set_user_setting',
        rawInput: {'key': 'pref.darkMode', 'value': true},
      ),
    );
    expect(result, isA<DispatchSuccess<Object?>>());

    final rows = await _rows(rt, settingsViewName);
    final dark = rows.firstWhere((r) => r['key'] == 'pref.darkMode');
    expect(dark['value'], true);
    expect(dark['source'], 'user');
    await rt.dispose();
  });
}
