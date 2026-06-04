// Verifies: DIARY-DEV-portal-seed-config/A — the sponsor seed-users JSON parses
//   into role assignments with the three scope encodings (bound / value-wildcard
//   / total-wildcard), and malformed input is rejected with a clear FormatException.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/seed_config.dart';
import 'package:test/test.dart';

void main() {
  test('parses users + assignments with all scope encodings', () {
    final seed = parseSeedUsers('''
{
  "users": [
    {
      "userId": "operator-1",
      "assignments": [
        { "role": "SystemOperator", "scope": { "class": "tier", "wildcard": true } },
        { "role": "SystemOperator", "scope": { "class": "site", "wildcard": true } }
      ]
    },
    {
      "userId": "sc-7",
      "assignments": [
        { "role": "StudyCoordinator", "scope": { "class": "site", "value": "DEV_999-001" } }
      ]
    },
    {
      "userId": "root-1",
      "assignments": [
        { "role": "SystemOperator", "scope": { "total": true } }
      ]
    }
  ]
}
''');
    expect(seed.entries, hasLength(4));
    expect(
      seed.entries[0],
      const RoleAssignmentSeedEntry(
        userId: 'operator-1',
        role: 'SystemOperator',
        scope: ValueWildcardScope(class_: 'tier'),
      ),
    );
    expect(
      seed.entries[2],
      const RoleAssignmentSeedEntry(
        userId: 'sc-7',
        role: 'StudyCoordinator',
        scope: BoundScope(class_: 'site', value: 'DEV_999-001'),
      ),
    );
    expect(
      seed.entries[3],
      const RoleAssignmentSeedEntry(
        userId: 'root-1',
        role: 'SystemOperator',
        scope: TotalWildcardScope(),
      ),
    );
  });

  test('rejects malformed input with FormatException', () {
    expect(() => parseSeedUsers('not json'), throwsFormatException);
    expect(() => parseSeedUsers('{}'), throwsFormatException); // no users
    expect(
      () => parseSeedUsers('{"users":[{"userId":"x","assignments":[]}]}'),
      throwsFormatException, // empty assignments
    );
    expect(
      () => parseSeedUsers(
          '{"users":[{"userId":"x","assignments":[{"role":"R","scope":{"class":"site"}}]}]}'),
      throwsFormatException, // scope needs value or wildcard
    );
    expect(
      () => parseSeedUsers(
          '{"users":[{"assignments":[{"role":"R","scope":{"total":true}}]}]}'),
      throwsFormatException, // missing userId
    );
  });
}
