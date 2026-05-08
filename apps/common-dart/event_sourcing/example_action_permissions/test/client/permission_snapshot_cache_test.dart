// test/client/permission_snapshot_cache_test.dart
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionSnapshotCache', () {
    test('starts as Anon with no permissions', () {
      final cache = PermissionSnapshotCache();
      expect(cache.userId, isNull);
      expect(cache.principalRole, 'Anon');
      expect(cache.permissions, isEmpty);
      expect(cache.holds('anything'), isFalse);
    });

    test('update() replaces fields and notifies', () {
      final cache = PermissionSnapshotCache();
      var notified = 0;
      cache.addListener(() => notified++);
      cache.update(
        userId: 'green-user-1',
        principalRole: 'GreenTeam',
        principalUserId: 'green-user-1',
        principalActiveSite: 'green-workspace',
        permissions: <String>{'help.ask', 'notes.write.green'},
      );
      expect(cache.userId, 'green-user-1');
      expect(cache.principalRole, 'GreenTeam');
      expect(cache.permissions, <String>{'help.ask', 'notes.write.green'});
      expect(cache.holds('help.ask'), isTrue);
      expect(cache.holds('notes.write.blue'), isFalse);
      expect(notified, 1);
    });

    test('update() returns an unmodifiable permissions set', () {
      final cache = PermissionSnapshotCache();
      final perms = <String>{'help.ask'};
      cache.update(
        userId: 'x',
        principalRole: 'GreenTeam',
        principalUserId: 'x',
        principalActiveSite: null,
        permissions: perms,
      );
      expect(
        () => cache.permissions.add('hack'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
