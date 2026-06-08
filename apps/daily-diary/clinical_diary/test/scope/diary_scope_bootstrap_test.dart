// Verifies: DIARY-DEV-evs-stack-adoption/A+B
// Verifies: DIARY-DEV-action-write-path/A
// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/N — a questionnaire
//   submission finalized through the NATIVE submit_questionnaire action lands a
//   `<id>_survey` DiaryEntry event that matches DiaryServerDestination's filter
//   (so it ships through the same native destination as nosebleed records).
//
// Full round-trip through the REAL LocalScope: submit an Action via the scope's
// actionSubmitter -> it dispatches -> appends -> projection -> read it back via
// the scope's viewSource. Proves the composition root is wired correctly.
import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

Future<DiaryScopeRuntime> _boot({
  List<EntryTypeDefinition> extraEntryTypes = const [],
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'i1-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-1',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
    extraEntryTypes: extraEntryTypes,
  );
}

/// A minimal native `<id>_survey` entry type def, mirroring what main.dart now
/// registers into the native scope (id / version / name; materialized).
EntryTypeDefinition _surveyType(String questionnaireId) => EntryTypeDefinition(
  id: '${questionnaireId}_survey',
  registeredVersion: 1,
  name: questionnaireId,
);

/// A valid `submit_questionnaire` rawInput (payload-shaped), mirroring what
/// HomeScreen._recordSurveySubmission builds from a QuestionnaireSubmission.
Map<String, Object?> _submitRaw({String instanceId = 'inst-1'}) =>
    <String, Object?>{
      'instance_id': instanceId,
      'questionnaire_type': 'qol',
      'schema_version': '1.0.0',
      'content_version': '1.0.0',
      'gui_version': '1.0.0',
      'completed_at': '2025-10-16T08:30:00.000Z',
      'responses': <String, Object?>{
        'q1': <String, Object?>{
          'value': 3,
          'display_label': 'Moderately',
          'normalized_label': '3',
        },
      },
    };

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
        rawInput: {'date': '2025-10-15', 'participantId': 'P-test'},
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

  test(
    'submit_questionnaire requires the survey entry type to be registered',
    () async {
      // WITHOUT extraEntryTypes the `<id>_survey` type is unregistered, so the
      // dispatch does NOT succeed (the append-stage rejects the unknown entry
      // type). This guards Change 1: the native scope MUST be given the survey
      // entry types at bootstrap for a submission to land.
      final rt = await _boot();
      final result = await rt.scope.actionSubmitter.submit(
        ActionSubmission(
          actionName: 'submit_questionnaire',
          rawInput: _submitRaw(),
        ),
      );
      expect(result, isNot(isA<DispatchSuccess<Object?>>()));
      await rt.dispose();
    },
  );

  test('submit_questionnaire finalizes a <id>_survey DiaryEntry event matching '
      "DiaryServerDestination's filter", () async {
    // WITH the survey entry type registered (as main.dart now passes via
    // loadSurveyEntryTypes), the native action dispatches successfully and
    // appends a finalized `qol_survey` event on the instance aggregate.
    final rt = await _boot(extraEntryTypes: [_surveyType('qol')]);
    final result = await rt.scope.actionSubmitter.submit(
      ActionSubmission(
        actionName: 'submit_questionnaire',
        rawInput: _submitRaw(instanceId: 'inst-qol-1'),
      ),
    );
    expect(result, isA<DispatchSuccess<Object?>>());

    // The finalized event lands in the NATIVE store on the instance aggregate.
    final events = await rt.bundle.eventStore.backend.findEventsForAggregate(
      'inst-qol-1',
    );
    final survey = events.singleWhere(
      (e) => e.entryType == 'qol_survey' && e.eventType == 'finalized',
    );
    expect(survey.aggregateType, diaryEntryAggregateType);

    // And it matches DiaryServerDestination's filter, so it ships through the
    // SAME native destination (-> POST /api/v1/ingest/batch) as nosebleeds.
    final destination = DiaryServerDestination(
      client: MockClient((_) async => throw StateError('not sent')),
      resolveIngestUrl: () async => null,
      authToken: () async => null,
    );
    expect(destination.filter.matches(survey), isTrue);

    await rt.dispose();
  });
}
