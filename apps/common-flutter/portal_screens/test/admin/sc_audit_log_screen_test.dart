// Verifies: DIARY-GUI-audit-log-study-coordinator/A+B — the Study Coordinator
//   Audit Log View's Timestamp/User/Participant ID/Action table and the
//   Participant-ID search. Single-actor own-actions view, so there is no
//   coordinator selector.
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

AuditEntryView _entry({
  required String id,
  required String actor,
  required String email,
  required String participantId,
  required String action,
  DateTime? timestamp,
}) => AuditEntryView(
  id: id,
  timestamp: timestamp ?? DateTime.utc(2024, 10, 7, 7, 30),
  actorName: actor,
  actorRole: 'StudyCoordinator',
  actorEmail: email,
  activityLabel: action,
  participantId: participantId,
  raw: <String, dynamic>{
    'event_id': id,
    'aggregate_type': 'participant',
    'aggregate_id': participantId,
    'participant_id': participantId,
  },
);

final _entries = <AuditEntryView>[
  _entry(
    id: 'e1',
    actor: 'Dr. Sarah Johnson',
    email: 'sjohnson@clinicaltrial.com',
    participantId: '001-1001234',
    action: 'NOSE HHT questionnaire sent',
  ),
  _entry(
    id: 'e2',
    actor: 'Dr. Sarah Johnson',
    email: 'sjohnson@clinicaltrial.com',
    participantId: '001-1012345',
    action: 'QoL questionnaire sent',
    timestamp: DateTime.utc(2024, 10, 6, 3, 15),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<AuditEntryView> entries = const [],
  bool isLoading = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(
        body: ScAuditLogScreen(entries: entries, isLoading: isLoading),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Verifies: DIARY-GUI-audit-log-study-coordinator/A — Timestamp/User/
  //   Participant ID/Action columns and a row with a participant id.
  testWidgets('renders the four columns and a row with participant id', (
    tester,
  ) async {
    await _pump(tester, entries: _entries);
    expect(find.text('Timestamp'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Participant ID'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    expect(find.text('Dr. Sarah Johnson'), findsWidgets);
    expect(find.text('sjohnson@clinicaltrial.com'), findsWidgets);
    expect(find.text('001-1001234'), findsOneWidget);
    expect(find.text('NOSE HHT questionnaire sent'), findsOneWidget);
    // Figma timestamp format.
    expect(find.text('Oct 7, 2024, 7:30 AM'), findsOneWidget);
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/A+B — no coordinator
  //   selector (single actor), but the Participant-ID search is present.
  testWidgets('has a Participant-ID search and no coordinator selector', (
    tester,
  ) async {
    await _pump(tester, entries: _entries);
    expect(find.bySemanticsIdentifier('sc-audit-search'), findsOneWidget);
    expect(find.text('All Study Coordinators'), findsNothing);
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/B — Participant-ID search
  //   filters rows.
  testWidgets('searching by participant id filters the table', (tester) async {
    await _pump(tester, entries: _entries);
    expect(find.text('001-1001234'), findsOneWidget);
    expect(find.text('001-1012345'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsIdentifier('sc-audit-search'),
      '1012345',
    );
    // AppTextField.search debounces 300ms.
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('001-1012345'), findsOneWidget);
    expect(find.text('001-1001234'), findsNothing);
  });

  // Verifies: DIARY-GUI-audit-log-study-coordinator/A — a questionnaire row
  //   (aggregate is the instance, not the participant) still shows the
  //   participant id (stamped by the server) and the typed Action label.
  testWidgets('questionnaire row shows the stamped participant id + type', (
    tester,
  ) async {
    final qEntry = AuditEntryView(
      id: 'q1',
      timestamp: DateTime.utc(2024, 10, 5, 9, 0),
      actorName: 'Dr. Sarah Johnson',
      actorRole: 'StudyCoordinator',
      actorEmail: 'sjohnson@clinicaltrial.com',
      activityLabel: 'QoL questionnaire sent',
      participantId: '001-9999',
      raw: const <String, dynamic>{
        'event_id': 'q1',
        'aggregate_type': 'questionnaire_instance',
        'aggregate_id': 'inst-9',
        'participant_id': '001-9999',
      },
    );
    await _pump(tester, entries: <AuditEntryView>[qEntry]);
    expect(find.text('001-9999'), findsOneWidget);
    expect(find.text('QoL questionnaire sent'), findsOneWidget);
  });

  // Verifies: DIARY-GUI-audit-log-common/H — tapping a row opens the entry's
  //   full details (key fields + raw event).
  testWidgets('row tap opens the entry details dialog', (tester) async {
    await _pump(tester, entries: _entries);
    await tester.tap(find.text('NOSE HHT questionnaire sent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsIdentifier('sc-audit-details'), findsOneWidget);
    expect(find.text('Raw event'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    // The participant id is surfaced in the detail rows.
    expect(find.text('001-1001234'), findsWidgets);
  });

  testWidgets('empty entries renders the no-activity copy', (tester) async {
    await _pump(tester, entries: const <AuditEntryView>[]);
    expect(find.text('No activity recorded yet.'), findsOneWidget);
  });
}
