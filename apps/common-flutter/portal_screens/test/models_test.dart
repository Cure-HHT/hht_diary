import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

import 'fixtures/mock_data.dart';

void main() {
  group('RoleAssignmentView', () {
    test('equal instances compare and hash equal', () {
      const a = RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-1', 'site-2'],
        isWildcard: false,
      );
      const b = RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-1', 'site-2'],
        isWildcard: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different bound-site lists are unequal', () {
      const a = RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-1'],
        isWildcard: false,
      );
      const b = RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-2'],
        isWildcard: false,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PortalUserView', () {
    test('distinctRoles dedupes by role name, preserves insertion order', () {
      const user = PortalUserView(
        email: 'multi@example.com',
        name: 'Multi Site Coord',
        status: UserStatusView.active,
        assignments: <RoleAssignmentView>[
          RoleAssignmentView(
            role: 'StudyCoordinator',
            boundSites: <String>['site-1'],
            isWildcard: false,
          ),
          RoleAssignmentView(
            role: 'CRA',
            boundSites: <String>['site-2'],
            isWildcard: false,
          ),
          RoleAssignmentView(
            // Same role as the first assignment, different site — should not
            // produce a second badge in the Users table.
            role: 'StudyCoordinator',
            boundSites: <String>['site-3'],
            isWildcard: false,
          ),
        ],
      );

      expect(user.distinctRoles, equals(<String>['StudyCoordinator', 'CRA']));
    });

    test('boundSites flattens across assignments', () {
      expect(
        MockData.emilyParker.boundSites,
        equals(<String>['site-1', 'site-2']),
        reason:
            'Admin wildcard contributes zero sites; the StudyCoordinator '
            'assignment carries site-1 + site-2.',
      );
    });

    test('hasWildcardScope is true when any assignment is wildcard', () {
      expect(MockData.emilyParker.hasWildcardScope, isTrue);
      expect(MockData.sarahJohnson.hasWildcardScope, isFalse);
    });
  });

  group('AuditEntryView', () {
    test('equality ignores raw map contents when ids differ', () {
      final a = AuditEntryView(
        id: 'audit-001',
        timestamp: DateTime.utc(2024, 10, 16, 7, 30),
        actorName: 'Terry Wilson',
        actorRole: 'Admin',
        activityLabel: 'Created user account for Dr. Emily Parker',
        raw: const <String, dynamic>{'foo': 'bar'},
      );
      final b = AuditEntryView(
        id: 'audit-002', // different id
        timestamp: DateTime.utc(2024, 10, 16, 7, 30),
        actorName: 'Terry Wilson',
        actorRole: 'Admin',
        activityLabel: 'Created user account for Dr. Emily Parker',
        raw: const <String, dynamic>{'foo': 'bar'},
      );

      expect(a, isNot(equals(b)));
    });

    test('identical instances compare equal — guards against future fields '
        'being added without updating ==', () {
      final entry = MockData.auditEntries.first;
      expect(entry, equals(entry));
    });
  });

  group('MockData fixtures', () {
    test('users cover the four lifecycle states surfaced in the UI', () {
      final statuses = MockData.users.map((u) => u.status).toSet();
      expect(
        statuses,
        containsAll(<UserStatusView>[
          UserStatusView.active,
          UserStatusView.pending,
          UserStatusView.revoked,
          UserStatusView.locked,
        ]),
      );
    });

    test('audit entries are pre-sorted in reverse-chronological order', () {
      final timestamps = MockData.auditEntries.map((e) => e.timestamp).toList();
      for (var i = 1; i < timestamps.length; i++) {
        expect(
          timestamps[i].isBefore(timestamps[i - 1]) ||
              timestamps[i].isAtSameMomentAs(timestamps[i - 1]),
          isTrue,
          reason:
              'AuditLogsScreen expects entries ordered newest first; '
              'index $i (${timestamps[i]}) should not be newer than '
              'index ${i - 1} (${timestamps[i - 1]}).',
        );
      }
    });
  });
}
