// test/demo_routes_test.dart
// Verifies: REQ-d00167, REQ-d00168 — HTTP entry routes the request through
// the dispatcher and returns the correct wire shape.
import 'dart:convert';

import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_routes.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const String _yamlPermissions = '''
roles:
  - Admin
  - GreenTeam
  - BlueTeam
grants:
  Admin:
    - users.provision
  GreenTeam:
    - help.ask
    - notes.write.green
    - buttons.press.green
    - buttons.press.red
  BlueTeam:
    - help.ask
    - notes.write.blue
    - buttons.press.blue
    - buttons.press.red
''';

const String _yamlUsers = '''
users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
  - userId: blue-user
    role: BlueTeam
    activeSite: blue-workspace
''';

Future<DemoRoutes> _makeRoutes(String installId) async {
  final components = await bootstrapDemoServer(
    dbPath: 'unused',
    ephemeral: true,
    permissionsYaml: _yamlPermissions,
    usersYaml: _yamlUsers,
    installIdentifier: installId,
  );
  return DemoRoutes(
    components: components,
    projection: PollingDemoStateProjection(components: components),
  );
}

Future<Response> _post(
  DemoRoutes routes,
  String path,
  Map<String, Object?> body,
) async {
  final req = Request(
    'POST',
    Uri.parse('http://localhost$path'),
    body: jsonEncode(body),
    headers: <String, String>{'content-type': 'application/json'},
  );
  return routes.handler(req);
}

Future<Response> _get(DemoRoutes routes, String path) async {
  final req = Request('GET', Uri.parse('http://localhost$path'));
  return routes.handler(req);
}

Future<Map<String, Object?>> _readJson(Response r) async {
  final text = await r.readAsString();
  return jsonDecode(text) as Map<String, Object?>;
}

void main() {
  group('DemoRoutes', () {
    test('GET /healthz returns ok', () async {
      final routes = await _makeRoutes('00000000-0000-4000-8000-000000000020');
      final r = await _get(routes, '/healthz');
      expect(r.statusCode, 200);
      expect(await r.readAsString(), 'ok');
    });

    test(
      'POST /session/start: known userId returns role + site + permissions',
      () async {
        final routes = await _makeRoutes(
          '00000000-0000-4000-8000-000000000021',
        );
        final r = await _post(routes, '/session/start', <String, Object?>{
          'userId': 'green-user-1',
        });
        expect(r.statusCode, 200);
        final body = await _readJson(r);
        final response = SessionStartResponse.fromJson(body);
        expect(response.principalUserId, 'green-user-1');
        expect(response.principalRole, 'GreenTeam');
        expect(response.principalActiveSite, 'green-workspace');
        expect(response.snapshotPermissions, contains('help.ask'));
        expect(response.snapshotPermissions, contains('notes.write.green'));
        expect(response.snapshotPermissions, contains('buttons.press.green'));
      },
    );

    test(
      'POST /session/start: unknown userId returns Anon role + empty permissions',
      () async {
        final routes = await _makeRoutes(
          '00000000-0000-4000-8000-000000000022',
        );
        final r = await _post(routes, '/session/start', <String, Object?>{
          'userId': 'who-dis',
        });
        final body = await _readJson(r);
        final response = SessionStartResponse.fromJson(body);
        expect(response.principalUserId, isNull);
        expect(response.principalRole, 'Anon');
        expect(response.snapshotPermissions, isEmpty);
      },
    );

    test(
      'POST /dispatch: PressGreenButton happy-path returns success',
      () async {
        final routes = await _makeRoutes(
          '00000000-0000-4000-8000-000000000023',
        );
        final r = await _post(routes, '/dispatch', <String, Object?>{
          'actionName': 'PressGreenButtonAction',
          'rawInput': <String, Object?>{},
          'userId': 'green-user-1',
        });
        expect(r.statusCode, 200);
        final body = await _readJson(r);
        final response = DispatchResponse.fromJson(body);
        expect(response, isA<DispatchResponseSuccess>());
        final success = response as DispatchResponseSuccess;
        expect(success.emittedEventIds, hasLength(1));
      },
    );

    test(
      'POST /dispatch: BlueTeam pressing green is authorization_denied',
      () async {
        final routes = await _makeRoutes(
          '00000000-0000-4000-8000-000000000024',
        );
        final r = await _post(routes, '/dispatch', <String, Object?>{
          'actionName': 'PressGreenButtonAction',
          'rawInput': <String, Object?>{},
          'userId': 'blue-user',
        });
        final body = await _readJson(r);
        final response = DispatchResponse.fromJson(body);
        expect(response, isA<DispatchResponseDenied>());
        final denied = response as DispatchResponseDenied;
        expect(denied.denialKind, 'authorization_denied');
        expect(denied.permissionDenied, 'buttons.press.green');
      },
    );

    test(
      'POST /dispatch: unknown action returns unknown_action denied',
      () async {
        final routes = await _makeRoutes(
          '00000000-0000-4000-8000-000000000025',
        );
        final r = await _post(routes, '/dispatch', <String, Object?>{
          'actionName': 'NoSuchAction',
          'rawInput': <String, Object?>{},
          'userId': 'green-user-1',
        });
        final body = await _readJson(r);
        final response = DispatchResponse.fromJson(body);
        expect(response, isA<DispatchResponseDenied>());
        final denied = response as DispatchResponseDenied;
        expect(denied.denialKind, 'unknown_action');
        expect(denied.requestedName, 'NoSuchAction');
      },
    );

    test('GET /_demo/inspect returns InspectSnapshot JSON', () async {
      final routes = await _makeRoutes('00000000-0000-4000-8000-000000000026');
      final r = await _get(routes, '/_demo/inspect');
      expect(r.statusCode, 200);
      final body = await _readJson(r);
      final snap = InspectSnapshot.fromJson(body);
      expect(snap.directory, hasLength(3));
      expect(snap.matrixGrants, hasLength(9));
    });

    test('lastTrace updates after a dispatch', () async {
      final routes = await _makeRoutes('00000000-0000-4000-8000-000000000027');
      expect(routes.lastTrace(), isNull);
      await _post(routes, '/dispatch', <String, Object?>{
        'actionName': 'PressGreenButtonAction',
        'rawInput': <String, Object?>{},
        'userId': 'green-user-1',
      });
      final trace = routes.lastTrace();
      expect(trace, isNotNull);
      expect(trace!.actionName, 'PressGreenButtonAction');
      expect(trace.stages.last, 'return_success');
    });
  });
}
