// test/permissions/permission_snapshot_test.dart
// Verifies: REQ-d00177-A (PermissionSnapshot value type and JSON).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionSnapshot', () {
    test('REQ-d00177-A: round-trips through JSON', () {
      final snap = PermissionSnapshot(
        role: 'admin',
        grants: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
          const Permission('site.manage', scope: ScopeClass.site),
        },
        issuedAt: DateTime.utc(2026, 5, 6),
      );
      final json = snap.toJson();
      final parsed = PermissionSnapshot.fromJson(json);
      expect(parsed.role, 'admin');
      expect(parsed.grants.length, 2);
      expect(
        parsed.grants.any(
          (p) => p.name == 'user.invite' && p.scope == ScopeClass.global,
        ),
        isTrue,
      );
      expect(
        parsed.grants.any(
          (p) => p.name == 'site.manage' && p.scope == ScopeClass.site,
        ),
        isTrue,
      );
      expect(parsed.issuedAt, DateTime.utc(2026, 5, 6));
    });
  });
}
