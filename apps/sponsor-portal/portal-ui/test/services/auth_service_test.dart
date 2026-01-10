// Tests for AuthService, UserRole, and PortalUser
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration

import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('UserRole', () {
    group('fromString', () {
      test('parses Investigator', () {
        expect(UserRole.fromString('Investigator'), UserRole.investigator);
      });

      test('parses Sponsor', () {
        expect(UserRole.fromString('Sponsor'), UserRole.sponsor);
      });

      test('parses Auditor', () {
        expect(UserRole.fromString('Auditor'), UserRole.auditor);
      });

      test('parses Analyst', () {
        expect(UserRole.fromString('Analyst'), UserRole.analyst);
      });

      test('parses Administrator', () {
        expect(UserRole.fromString('Administrator'), UserRole.administrator);
      });

      test('parses Developer Admin', () {
        expect(UserRole.fromString('Developer Admin'), UserRole.developerAdmin);
      });

      test('defaults to investigator for unknown role', () {
        expect(UserRole.fromString('Unknown'), UserRole.investigator);
        expect(UserRole.fromString(''), UserRole.investigator);
        expect(UserRole.fromString('invalid'), UserRole.investigator);
      });
    });

    group('displayName', () {
      test('returns correct display names', () {
        expect(UserRole.investigator.displayName, 'Investigator');
        expect(UserRole.sponsor.displayName, 'Sponsor');
        expect(UserRole.auditor.displayName, 'Auditor');
        expect(UserRole.analyst.displayName, 'Analyst');
        expect(UserRole.administrator.displayName, 'Administrator');
        expect(UserRole.developerAdmin.displayName, 'Developer Admin');
      });
    });

    group('isAdmin', () {
      test('returns true for Administrator', () {
        expect(UserRole.administrator.isAdmin, isTrue);
      });

      test('returns true for Developer Admin', () {
        expect(UserRole.developerAdmin.isAdmin, isTrue);
      });

      test('returns false for non-admin roles', () {
        expect(UserRole.investigator.isAdmin, isFalse);
        expect(UserRole.sponsor.isAdmin, isFalse);
        expect(UserRole.auditor.isAdmin, isFalse);
        expect(UserRole.analyst.isAdmin, isFalse);
      });
    });
  });

  group('PortalUser', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'name': 'Test User',
        'role': 'Administrator',
        'status': 'active',
        'sites': [
          {'site_id': 'site-1', 'site_name': 'Site One'},
          {'site_id': 'site-2', 'site_name': 'Site Two'},
        ],
      };

      final user = PortalUser.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.role, UserRole.administrator);
      expect(user.status, 'active');
      expect(user.sites.length, 2);
      expect(user.sites[0]['site_id'], 'site-1');
    });

    test('fromJson handles null sites', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'name': 'Test User',
        'role': 'Investigator',
        'status': 'active',
      };

      final user = PortalUser.fromJson(json);

      expect(user.sites, isEmpty);
    });

    test('fromJson handles empty sites', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'name': 'Test User',
        'role': 'Investigator',
        'status': 'active',
        'sites': <dynamic>[],
      };

      final user = PortalUser.fromJson(json);

      expect(user.sites, isEmpty);
    });

    group('canAccessSite', () {
      test('admin can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'admin@example.com',
          name: 'Admin',
          role: UserRole.administrator,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
        expect(user.canAccessSite('another-site'), isTrue);
      });

      test('sponsor can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'sponsor@example.com',
          name: 'Sponsor',
          role: UserRole.sponsor,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('auditor can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'auditor@example.com',
          name: 'Auditor',
          role: UserRole.auditor,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('analyst can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'analyst@example.com',
          name: 'Analyst',
          role: UserRole.analyst,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('investigator can only access assigned sites', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'investigator@example.com',
          name: 'Investigator',
          role: UserRole.investigator,
          status: 'active',
          sites: [
            {'site_id': 'site-1', 'site_name': 'Site One'},
            {'site_id': 'site-2', 'site_name': 'Site Two'},
          ],
        );

        expect(user.canAccessSite('site-1'), isTrue);
        expect(user.canAccessSite('site-2'), isTrue);
        expect(user.canAccessSite('site-3'), isFalse);
        expect(user.canAccessSite('unknown'), isFalse);
      });

      test('investigator with no sites cannot access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'investigator@example.com',
          name: 'Investigator',
          role: UserRole.investigator,
          status: 'active',
          sites: [],
        );

        expect(user.canAccessSite('site-1'), isFalse);
        expect(user.canAccessSite('any-site'), isFalse);
      });
    });
  });
}
