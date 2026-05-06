import 'package:audited_actions/src/permission_discovery.dart';
import 'package:test/test.dart';

void main() {
  group('emitPermissionsMigrationSql', () {
    test(
      'REQ-d00169-D: emits ON CONFLICT DO NOTHING insert per declared permission',
      () {
        final sql = emitPermissionsMigrationSql(
          declared: const {'test.hello', 'test.multi'},
          existing: const <String>{},
        );
        expect(sql, contains('INSERT INTO role_permission_matrix_permissions'));
        expect(sql, contains("'test.hello'"));
        expect(sql, contains("'test.multi'"));
        expect(sql, contains('ON CONFLICT'));
      },
    );

    test('REQ-d00169-D: skips permissions already present in DB', () {
      final sql = emitPermissionsMigrationSql(
        declared: const {'test.hello'},
        existing: const {'test.hello'},
      );
      expect(sql, isNotEmpty);
      final lines = sql.split('\n');
      final insertLines = lines.where(
        (l) => l.contains("'test.hello'") && l.contains('INSERT'),
      );
      expect(insertLines, isEmpty);
    });

    test('REQ-d00169-D: emits comments for orphan permissions in DB', () {
      final sql = emitPermissionsMigrationSql(
        declared: const {'test.hello'},
        existing: const {'test.hello', 'test.legacy'},
      );
      expect(sql, contains('-- ORPHAN'));
      expect(sql, contains('test.legacy'));
    });

    test('sorts new permissions deterministically', () {
      final sql = emitPermissionsMigrationSql(
        declared: const {'z.x', 'a.b', 'm.n'},
        existing: const <String>{},
      );
      final aIdx = sql.indexOf("'a.b'");
      final mIdx = sql.indexOf("'m.n'");
      final zIdx = sql.indexOf("'z.x'");
      expect(aIdx, lessThan(mIdx));
      expect(mIdx, lessThan(zIdx));
    });
  });
}
