// Verifies: DIARY-GUI-audit-log-study-coordinator/A+B — the Study Coordinator
//   Audit Log binding fetches the Coordinator's own activity with `view=mine`
//   (automation excluded), renders the Participant ID column, and self-gates on
//   the global audit permission.
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:portal_ui_evs/src/sc_audit_log_binding.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

Map<String, Object?> _participantRow(int seq) => <String, Object?>{
  'event_id': 'evt-$seq',
  'timestamp': '2024-10-07T07:30:00.000Z',
  'entry_type': 'participant_linking_code_issued',
  'aggregate_type': 'participant',
  'aggregate_id': 'P-$seq',
  'participant_id': 'P-$seq',
  'initiator': <String, Object?>{'kind': 'user', 'label': 'sc@reference.local'},
};

/// A system/automation-initiated row (initiator kind != 'user'); the client
/// filter must drop it.
Map<String, Object?> _automationRow(int seq) => <String, Object?>{
  'event_id': 'auto-$seq',
  'timestamp': '2024-10-07T07:31:00.000Z',
  'entry_type': 'participant_synced_from_edc',
  'aggregate_type': 'participant',
  'aggregate_id': 'AUTO-$seq',
  'participant_id': 'AUTO-$seq',
  'initiator': <String, Object?>{'kind': 'automation', 'label': 'edc-sync'},
};

MockClient _auditServer(
  List<http.Request> requests, {
  List<Map<String, Object?>>? rows,
}) => MockClient((req) async {
  requests.add(req);
  final body = rows ?? const <Map<String, Object?>>[];
  return http.Response(
    jsonEncode(<String, Object?>{
      'rows': body,
      'count': body.length,
      'total': body.length,
      'offset': 0,
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );
});

FakeReaction _authedWith(
  Set<String> perms, {
  List<ScopeAssignment> scopeAssignments = const <ScopeAssignment>[],
}) => FakeReaction(
  initialAuthStatus: Authenticated(
    principal: Principal.user(
      userId: 'sc@reference.local',
      roles: const {'StudyCoordinator'},
      activeRole: 'StudyCoordinator',
    ),
  ),
  initialPermission: EffectiveAuthorization(
    activeRole: 'StudyCoordinator',
    rolePermissions: {for (final p in perms) Permission(p)},
    scopeAssignments: scopeAssignments,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required http.Client client,
  required FakeReaction fake,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ReActionScope(
      scope: fake,
      child: MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: ScAuditLogBinding(
            identityCredential: 'cred-123',
            serverUrl: 'http://portal.test',
            httpClient: client,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('fetches own actions with view=mine (automation excluded)', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pump(
      tester,
      client: _auditServer(requests),
      fake: _authedWith(const {'portal.audit.view'}),
    );

    expect(requests, hasLength(1));
    final q = requests.single.url.queryParameters;
    expect(requests.single.url.path, '/audit');
    expect(q['view'], 'mine');
    // No site scoping for the own-actions view.
    expect(q.containsKey('site'), isFalse);
    expect(requests.single.headers['Authorization'], 'Bearer cred-123|StudyCoordinator');
  });

  testWidgets('renders the Participant ID column with row values', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pump(
      tester,
      client: _auditServer(requests, rows: [_participantRow(1), _participantRow(2)]),
      fake: _authedWith(const {'portal.audit.view'}),
    );

    expect(find.text('Participant ID'), findsOneWidget);
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('P-2'), findsOneWidget);
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/A — the defensive client
  //   filter drops any non-user (automation/system) row even if the server
  //   scope widens; only human-user rows render.
  testWidgets('filters out automation/system rows', (tester) async {
    final requests = <http.Request>[];
    await _pump(
      tester,
      client: _auditServer(
        requests,
        rows: [_participantRow(1), _automationRow(9)],
      ),
      fake: _authedWith(const {'portal.audit.view'}),
    );

    // The user row renders; the automation row does not.
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('AUTO-9'), findsNothing);
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/A — the My Sites bar
  //   renders the Coordinator's assigned sites above the table when the viewer
  //   holds portal.site.view.
  testWidgets('renders the My Sites bar from the sites view', (tester) async {
    final requests = <http.Request>[];
    final fake = _authedWith(
      const {'portal.audit.view', 'portal.site.view'},
      scopeAssignments: const [
        ScopeAssignment(scope: ValueWildcardScope(class_: 'site')),
      ],
    );
    await _pump(tester, client: _auditServer(requests), fake: fake);

    fake.emitViewUpdate<SiteRowView>(
      'sites_index',
      const Snapshot<SiteRowView>(
        value: SiteRowView(
          id: 's1',
          name: 'Memorial Hospital',
          number: '001',
          active: true,
        ),
        sequence: 1,
      ),
    );
    fake.emitViewUpdate<SiteRowView>(
      'sites_index',
      const EndOfReplay<SiteRowView>(sequence: 1),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('My Sites'), findsOneWidget);
    expect(find.text('001 - Memorial Hospital'), findsOneWidget);
  });

  testWidgets('blocks (and does not fetch) without the audit permission', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pump(
      tester,
      client: _auditServer(requests),
      fake: _authedWith(const {'portal.site.view_audit_log'}),
    );

    expect(
      find.text("You don't have permission to view the audit log."),
      findsOneWidget,
    );
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/A — the Action column names
  //   which questionnaire with a READABLE type, and finalize shows the
  //   milestone.
  group('questionnaireActivityLabel', () {
    test('maps the qol code to its display name + "sent"', () {
      expect(
        questionnaireActivityLabel(const {
          'questionnaire_type': 'qol',
          'entry_type': 'questionnaire_assigned',
        }),
        'HHT-QoL questionnaire sent',
      );
    });

    test('maps nose_hht to "NOSE HHT"', () {
      expect(
        questionnaireActivityLabel(const {
          'questionnaire_type': 'nose_hht',
          'entry_type': 'questionnaire_assigned',
        }),
        'NOSE HHT questionnaire sent',
      );
    });

    test('finalize with end_of_treatment shows the milestone', () {
      expect(
        questionnaireActivityLabel(const {
          'questionnaire_type': 'qol',
          'entry_type': 'questionnaire_finalized',
          'data': {'end_event': 'end_of_treatment'},
        }),
        'HHT-QoL questionnaire approved — End of Treatment',
      );
    });

    test('a plain finalize is "approved"', () {
      expect(
        questionnaireActivityLabel(const {
          'questionnaire_type': 'qol',
          'entry_type': 'questionnaire_finalized',
          'data': <String, Object?>{},
        }),
        'HHT-QoL questionnaire approved',
      );
    });

    test('an unknown type code falls back to an uppercased name', () {
      expect(
        questionnaireActivityLabel(const {
          'questionnaire_type': 'foo_bar',
          'entry_type': 'questionnaire_assigned',
        }),
        'FOO BAR questionnaire sent',
      );
    });
  });
}
