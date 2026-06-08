// Verifies: DIARY-DEV-pluggable-push-transport/B — PUSH_MODE selects the push
//   transport at bootstrap (mirroring PORTAL_AUTH_MODE); `local` wires the
//   /api/v1/user/push WS route, an unknown value fails fast at boot.
import 'dart:convert';

import 'package:async/async.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<dynamic> boot(Map<String, String> env) async {
  final db = await newDatabaseFactoryMemory().openDatabase('pms.db');
  return bootstrapPortalServer(
    backend: SembastBackend(database: db),
    raveClient: DevSeedRaveClient(),
    environment: env,
  );
}

void main() {
  test('unknown PUSH_MODE fails fast at boot', () async {
    await expectLater(
      boot({'PUSH_MODE': 'carrier-pigeon', 'PORTAL_AUTH_MODE': 'dev'}),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message',
            contains('unknown PUSH_MODE=carrier-pigeon')),
      ),
    );
  });

  test('PUSH_MODE=local wires the /api/v1/user/push WS route', () async {
    final b = await boot({'PUSH_MODE': 'local', 'PORTAL_AUTH_MODE': 'dev'});
    addTearDown(b.dispose);
    final server = await shelf_io.serve(b.router.call, 'localhost', 0);
    addTearDown(() => server.close(force: true));

    final ws = WebSocketChannel.connect(
      Uri.parse('ws://localhost:${server.port}/api/v1/user/push'),
    );
    await ws.ready;
    final frames = StreamQueue<dynamic>(ws.stream);
    // A bogus token is enough to prove the route is the local-push handler:
    // it answers with an auth_denied frame rather than 404-ing.
    ws.sink.add(jsonEncode({'type': 'auth', 'token': 'bogus'}));
    final ack = jsonDecode(await frames.next as String) as Map;
    expect(ack['type'], equals('auth_denied'));
    await ws.sink.close();
  });

  test('default (fcm) does NOT expose the local-push WS route', () async {
    final b = await boot({'PORTAL_AUTH_MODE': 'dev'}); // PUSH_MODE unset -> fcm
    addTearDown(b.dispose);
    final server = await shelf_io.serve(b.router.call, 'localhost', 0);
    addTearDown(() => server.close(force: true));

    final ws = WebSocketChannel.connect(
      Uri.parse('ws://localhost:${server.port}/api/v1/user/push'),
    );
    // Route absent -> the request falls to the authed pipeline (no WS upgrade),
    // so the handshake fails and `ready` throws.
    await expectLater(ws.ready, throwsA(anything));
  });
}
