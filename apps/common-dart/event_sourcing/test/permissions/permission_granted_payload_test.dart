// test/permissions/permission_granted_payload_test.dart
// Verifies: REQ-d00174-A (event payload shape for permission_granted)
import 'package:event_sourcing/event_sourcing.dart' show ScopeClass;
import 'package:event_sourcing/src/permissions/permission_granted_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionGrantedPayload', () {
    test('REQ-d00174-A: round-trips through JSON', () {
      const payload = PermissionGrantedPayload(
        role: 'admin',
        permissionName: 'user.invite',
        scope: ScopeClass.global,
      );
      final json = payload.toJson();
      final parsed = PermissionGrantedPayload.fromJson(json);
      expect(parsed.role, 'admin');
      expect(parsed.permissionName, 'user.invite');
      expect(parsed.scope, ScopeClass.global);
    });

    test('REQ-d00174-A: scope serializes by enum name', () {
      const payload = PermissionGrantedPayload(
        role: 'patient',
        permissionName: 'diary.submit',
        scope: ScopeClass.self,
      );
      expect(payload.toJson()['scope'], 'self');
    });

    test('REQ-d00174-A: rejects unknown scope on parse', () {
      expect(
        () => PermissionGrantedPayload.fromJson(const <String, Object?>{
          'role': 'x',
          'permissionName': 'y',
          'scope': 'not_a_scope',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
