import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/audit_format.dart';

void main() {
  test('humanizeEntryType: known override + title-cased fallback + empty', () {
    expect(
      humanizeEntryType('participant_linking_code_issued'),
      'Participant Linking Code Issued',
    );
    expect(humanizeEntryType('site_synced_from_edc'), 'Site Synced From EDC');
    expect(humanizeEntryType('some_brand_new_event'), 'Some Brand New Event');
    expect(humanizeEntryType(''), '(unknown)');
  });

  test('initiatorLabel per kind + null', () {
    expect(
      initiatorLabel({'kind': 'user', 'label': 'admin-1'}),
      'user:admin-1',
    );
    expect(
      initiatorLabel({'kind': 'automation', 'label': 'edc_sync'}),
      'auto:edc_sync',
    );
    expect(initiatorLabel({'kind': 'anonymous', 'label': 'anon'}), 'anon');
    expect(initiatorLabel(null), '(unknown)');
  });

  // Verifies: DIARY-GUI-audit-log-common/C+D — Details = affected record (by
  //   resolved name when present) plus the free-text reason.
  test('detailsSummary: resolved target name + reason; falls back to id', () {
    expect(
      detailsSummary({
        'aggregate_type': 'portal_user',
        'aggregate_id': 'mike@x.com',
        'target_name': 'Mike Lewis',
        'change_reason': 'Administrative error',
      }),
      'Mike Lewis — Reason: "Administrative error"',
    );
    // No resolved name -> the aggregate id (email) is the subject.
    expect(
      detailsSummary({
        'aggregate_type': 'portal_user',
        'aggregate_id': 'u@x.com',
      }),
      'u@x.com',
    );
    expect(
      detailsSummary({'aggregate_type': 'site', 'aggregate_id': 'DEV-001'}),
      'DEV-001',
    );
  });

  // Verifies: DIARY-GUI-audit-log-common/F — Action column prefers the
  //   server-resolved Action-Inventory name, else humanizes the entry type.
  test('auditActionName: prefers action_name, falls back to entry_type', () {
    expect(
      auditActionName({
        'action_name': 'Reactivate User Account',
        'entry_type': 'user_reactivated',
      }),
      'Reactivate User Account',
    );
    expect(
      auditActionName({'entry_type': 'site_synced_from_edc'}),
      'Site Synced From EDC',
    );
  });

  // Verifies: DIARY-GUI-audit-log-common/D — Activity label appends the affected
  //   account's email (the portal_user aggregate id), else just the action name.
  test('auditActivityLabel: appends the affected account email', () {
    expect(
      auditActivityLabel({
        'action_name': 'Reactivate User Account',
        'entry_type': 'user_reactivated',
        'aggregate_type': 'portal_user',
        'aggregate_id': 'squeeb+sc@gmail.com',
      }),
      'Reactivate User Account — squeeb+sc@gmail.com',
    );
    // Non-portal_user target: just the action name.
    expect(
      auditActivityLabel({
        'action_name': 'Site Synced From EDC',
        'entry_type': 'site_synced_from_edc',
        'aggregate_type': 'site',
        'aggregate_id': 'site-1',
      }),
      'Site Synced From EDC',
    );
  });

  // Verifies: DIARY-GUI-audit-log-common/A — User column shows the resolved
  //   display name (else email); empty for non-user initiators.
  test('auditActorName: name, then email, then empty for non-user', () {
    expect(
      auditActorName({'kind': 'user', 'label': 'e@x.com', 'name': 'Elvira K'}),
      'Elvira K',
    );
    expect(auditActorName({'kind': 'user', 'label': 'e@x.com'}), 'e@x.com');
    expect(auditActorName({'kind': 'automation', 'label': 'edc_sync'}), '');
    expect(auditActorName(null), '');
  });

  // Verifies: DIARY-GUI-audit-log-common/A — the email shown under the name in
  //   the User column: the initiator label for users, empty for non-users.
  test('auditActorEmail: label for users, empty for non-user', () {
    expect(
      auditActorEmail({'kind': 'user', 'label': 'e@x.com', 'name': 'Elvira K'}),
      'e@x.com',
    );
    expect(auditActorEmail({'kind': 'user', 'label': 'e@x.com'}), 'e@x.com');
    expect(auditActorEmail({'kind': 'automation', 'label': 'edc_sync'}), '');
    expect(auditActorEmail(null), '');
  });

  group('parseAuditRows', () {
    test('parses a single well-formed row', () {
      final rows = parseAuditRows('{"rows":[{"entry_type":"x"}]}');
      expect(rows, hasLength(1));
      expect(rows.single['entry_type'], 'x');
    });

    test('skips non-object elements (null) and keeps valid rows', () {
      final rows = parseAuditRows('{"rows":[null, {"entry_type":"y"}]}');
      expect(rows, hasLength(1));
      expect(rows.single['entry_type'], 'y');
    });

    test('empty rows list yields empty list', () {
      expect(parseAuditRows('{"rows":[]}'), isEmpty);
    });

    test('non-object JSON body yields empty list without throwing', () {
      expect(parseAuditRows('"[]"'), isEmpty);
      expect(parseAuditRows('[]'), isEmpty);
    });
  });

  group('parseAuditPage', () {
    test('reads rows and the server-reported total', () {
      final page = parseAuditPage(
        '{"rows":[{"entry_type":"x"}],"count":1,"total":204}',
      );
      expect(page.rows, hasLength(1));
      expect(page.total, 204);
    });

    test('falls back to rows.length when total is absent or malformed', () {
      expect(parseAuditPage('{"rows":[{"a":1},{"b":2}]}').total, 2);
      expect(parseAuditPage('{"rows":[{"a":1}],"total":"nope"}').total, 1);
    });
  });
}
