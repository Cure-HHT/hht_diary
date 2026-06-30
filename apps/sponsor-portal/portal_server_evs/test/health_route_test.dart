// Verifies: portal exposes /health for the container readiness gate.
import 'dart:convert';
import 'dart:io';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('GET /health returns ok JSON without auth', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('h.db');
    final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db), raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    final res = await boot.router
        .call(Request('GET', Uri.parse('http://localhost/health')));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
    expect(body['status'], 'ok');
    expect(body['service'], 'portal_server_evs');
    // versions is always present (possibly empty in a bare test env).
    expect(body['versions'], isA<Map<String, Object?>>());
  });

  group('resolveVersions', () {
    test('parses the baked /app/VERSIONS manifest and merges deploy env', () {
      final dir = Directory.systemTemp.createTempSync('versions_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final manifest = File('${dir.path}/VERSIONS')
        ..writeAsStringSync([
          'portal_server_evs=0.5.1+7',
          'server_commit=abc1234',
          'diary_app=0.9.56+134',
          'portal_ui_version=1.4.1+def5678',
          'portal_deployment=reference+9abcdef',
          '', // tolerate blank lines
        ].join('\n'));

      final v = resolveVersions(
        manifestPath: manifest.path,
        environment: {
          'PORTAL_DEPLOY_SEQ': '47',
          'PORTAL_DEPLOY_SHA': 'fed4321'
        },
      );

      expect(v['portal_server_evs'], '0.5.1+7');
      expect(v['server_commit'], 'abc1234');
      expect(v['diary_app'], '0.9.56+134');
      expect(v['portal_ui_version'], '1.4.1+def5678');
      expect(v['portal_deployment'], 'reference+9abcdef');
      expect(v['deploy'], '47');
      expect(v['deploy_commit'], 'fed4321');
    });

    test('missing manifest + unset env yields an empty map (local/test)', () {
      final v = resolveVersions(
        manifestPath: '/no/such/VERSIONS',
        environment: const {},
      );
      expect(v, isEmpty);
    });
  });
}
