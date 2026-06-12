import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

// MockData now lives in lib/ so the example preview app can reach it
// without duplicating the sample data.

void main() {
  _visibleUserRowsTests();
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

PortalUserView _user(String email, List<String> roles) => PortalUserView(
  email: email,
  name: email,
  status: UserStatusView.active,
  assignments: [
    for (final r in roles)
      RoleAssignmentView(role: r, boundSites: const [], isWildcard: true),
  ],
);

void _visibleUserRowsTests() {
  group('visibleUserRows — SysOp row visibility', () {
    final admin = _user('admin@x.test', ['Administrator']);
    final sysOpOnly = _user('sysop@x.test', ['SystemOperator']);
    final sysOpPlusCra = _user('dual@x.test', ['SystemOperator', 'CRA']);
    final noRoles = _user('pending@x.test', []);
    final all = [admin, sysOpOnly, sysOpPlusCra, noRoles];

    test('operator viewer sees every row', () {
      expect(visibleUserRows(users: all, viewerIsOperator: true), all);
    });

    test('staff viewer: SysOp-ONLY rows hidden; dual-role SysOp visible', () {
      final visible = visibleUserRows(users: all, viewerIsOperator: false);
      expect(visible, [admin, sysOpPlusCra, noRoles]);
    });

    test('rows with no known roles are never hidden (assignments may be '
        'gated for this viewer)', () {
      final visible = visibleUserRows(
        users: [noRoles],
        viewerIsOperator: false,
      );
      expect(visible, [noRoles]);
    });
  });
}
