// test/user_directory_materializer_test.dart
// Verifies: REQ-d00174 (matrix view materializer pattern, applied to directory)
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:event_sourcing/event_sourcing.dart' show UserPrincipal;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserDirectoryMaterializer', () {
    test('REQ-d00174: applies user_provisioned payload to directory', () {
      final dir = UserDirectory();
      final m = UserDirectoryMaterializer(directory: dir);
      m.applyDirect(<String, Object?>{
        'userId': 'green-user-3',
        'role': 'GreenTeam',
        'activeSite': 'green-workspace',
      });
      final p = dir.resolve('green-user-3') as UserPrincipal;
      expect(p.activeRole, 'GreenTeam');
      expect(p.activeSite, 'green-workspace');
    });

    test('REQ-d00174: idempotent on replay (same payload)', () {
      final dir = UserDirectory();
      final m = UserDirectoryMaterializer(directory: dir);
      const payload = <String, Object?>{
        'userId': 'admin-user',
        'role': 'Admin',
        'activeSite': null,
      };
      m.applyDirect(payload);
      m.applyDirect(payload);
      expect(dir.listEntries(), hasLength(1));
    });

    test('REQ-d00174: re-application overwrites earlier role/site', () {
      final dir = UserDirectory();
      final m = UserDirectoryMaterializer(directory: dir);
      m.applyDirect(<String, Object?>{
        'userId': 'mover',
        'role': 'GreenTeam',
        'activeSite': 'green-workspace',
      });
      m.applyDirect(<String, Object?>{
        'userId': 'mover',
        'role': 'BlueTeam',
        'activeSite': 'blue-workspace',
      });
      final p = dir.resolve('mover') as UserPrincipal;
      expect(p.activeRole, 'BlueTeam');
      expect(p.activeSite, 'blue-workspace');
      expect(dir.listEntries(), hasLength(1));
    });
  });
}
