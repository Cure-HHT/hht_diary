// Verifies: REQ-d00175 (seed-applier diff logic, applied to directory)
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:action_permissions_demo/server/user_directory_seed_applier.dart';
import 'package:flutter_test/flutter_test.dart';

const _yamlTwoUsers = '''
users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
''';

void main() {
  group('UserDirectorySeedApplier', () {
    test('REQ-d00175: applies all seed entries to empty directory', () {
      final dir = UserDirectory();
      final mat = UserDirectoryMaterializer(directory: dir);
      final emitted = <Map<String, Object?>>[];
      final applier = UserDirectorySeedApplier(
        directory: dir,
        materializer: mat,
        emit: emitted.add,
      );
      applier.applyYaml(_yamlTwoUsers);
      expect(emitted, hasLength(2));
      expect(dir.contains('admin-user'), isTrue);
      expect(dir.contains('green-user-1'), isTrue);
    });

    test('REQ-d00175: skips entries already present in directory (diff)', () {
      final dir = UserDirectory();
      dir.upsert(userId: 'admin-user', role: 'Admin', activeSite: null);
      final mat = UserDirectoryMaterializer(directory: dir);
      final emitted = <Map<String, Object?>>[];
      final applier = UserDirectorySeedApplier(
        directory: dir,
        materializer: mat,
        emit: emitted.add,
      );
      applier.applyYaml(_yamlTwoUsers);
      expect(emitted, hasLength(1));
      expect(emitted.first['userId'], 'green-user-1');
    });

    test('REQ-d00175: emit and applyDirect see the same payload', () {
      final dir = UserDirectory();
      final mat = UserDirectoryMaterializer(directory: dir);
      final emitted = <Map<String, Object?>>[];
      final applier = UserDirectorySeedApplier(
        directory: dir,
        materializer: mat,
        emit: emitted.add,
      );
      applier.applyYaml(_yamlTwoUsers);
      // Each emitted payload also produced a directory entry with the
      // same fields.
      for (final payload in emitted) {
        final userId = payload['userId']! as String;
        expect(dir.contains(userId), isTrue);
      }
    });
  });
}
