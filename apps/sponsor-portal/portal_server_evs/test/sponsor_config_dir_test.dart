import 'dart:io';

import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:test/test.dart';

void main() {
  test('SPONSOR_CONFIG_DIR set + present resolves to that dir', () {
    final tmp = Directory.systemTemp.createTempSync('sponsor-cfg-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/role-permissions.yaml')
        .writeAsStringSync('roles: [SystemOperator]\ngrants: {}\n');
    final dir = resolveSponsorConfigDir(<String, String>{
      'SPONSOR_CONFIG_DIR': tmp.path,
    });
    expect(dir, tmp.path);
    expect(loadRolePermissionsYaml(dir), contains('SystemOperator'));
  });

  test('SPONSOR_CONFIG_DIR set but missing fails fast', () {
    expect(
      () => resolveSponsorConfigDir(<String, String>{
        'SPONSOR_CONFIG_DIR': '/no/such/sponsor/dir',
      }),
      throwsA(isA<StateError>()),
    );
  });

  group('walk-up (requires running from within the repo tree)', () {
    test('unset resolves to the bundled reference sponsor dir', () {
      final dir = resolveSponsorConfigDir(const <String, String>{});
      expect(dir, endsWith('deployment/reference-sponsor/deployment/sponsor'));
      expect(loadRolePermissionsYaml(dir), contains('SystemOperator'));
    });
  });

  test('loadRolePermissionsYaml fails fast when the file is absent', () {
    final tmp = Directory.systemTemp.createTempSync('sponsor-cfg-empty-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(
      () => loadRolePermissionsYaml(tmp.path),
      throwsA(isA<StateError>()),
    );
  });
}
