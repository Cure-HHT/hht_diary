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

  test('detailsSummary combines aggregate + optional change reason', () {
    expect(
      detailsSummary({
        'aggregate_type': 'portal_user',
        'aggregate_id': 'u@x.com',
        'change_reason': 'edited',
      }),
      'portal_user u@x.com — edited',
    );
    expect(
      detailsSummary({'aggregate_type': 'site', 'aggregate_id': 'DEV-001'}),
      'site DEV-001',
    );
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
}
