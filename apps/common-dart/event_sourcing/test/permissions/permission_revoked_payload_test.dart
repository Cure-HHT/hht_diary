// test/permissions/permission_revoked_payload_test.dart
// Verifies: REQ-d00174-B (event payload shape for permission_revoked)
import 'package:event_sourcing/src/permissions/permission_revoked_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionRevokedPayload', () {
    test('REQ-d00174-B: round-trips through JSON', () {
      const payload = PermissionRevokedPayload(
        role: 'admin',
        permissionName: 'user.invite',
      );
      final parsed = PermissionRevokedPayload.fromJson(payload.toJson());
      expect(parsed.role, 'admin');
      expect(parsed.permissionName, 'user.invite');
    });

    test('REQ-d00174-B: equality on all fields', () {
      const a = PermissionRevokedPayload(role: 'r', permissionName: 'p');
      const b = PermissionRevokedPayload(role: 'r', permissionName: 'p');
      const c = PermissionRevokedPayload(role: 'r', permissionName: 'q');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
