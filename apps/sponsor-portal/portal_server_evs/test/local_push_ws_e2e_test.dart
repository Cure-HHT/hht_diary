// Verifies: DIARY-DEV-pluggable-push-transport/C — the full local send loop
//   over a REAL loopback WebSocket: a diary connects + authenticates in-band,
//   LocalSocketPushChannel.send delivers a frame, the client receives it. No
//   FCM, no emulator. This is the fast-iteration path the ticket exists for.
import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:comms/comms.dart';
import 'package:portal_server_evs/src/local_push_registry.dart';
import 'package:portal_server_evs/src/local_push_ws_handler.dart';
import 'package:portal_server_evs/src/local_socket_push_channel.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late LocalPushRegistry registry;
  late LocalSocketPushChannel channel;
  late dynamic server; // HttpServer

  setUp(() async {
    PayloadGuard.testOnlyDisable = false;
    PayloadGuard.commonNamePatterns = <RegExp>[];
    registry = LocalPushRegistry();
    channel = LocalSocketPushChannel(registry);
    server = await shelf_io.serve(
      localPushWsHandler(
        registry: registry,
        // Stub verifier: only "good-<pid>" tokens authenticate.
        verifier: (token) =>
            token.startsWith('good-') ? token.substring(5) : null,
        // Long ping so it never interleaves with assertions.
        pingInterval: const Duration(hours: 1),
      ),
      'localhost',
      0,
    );
  });

  tearDown(() async {
    await server.close(force: true);
  });

  WebSocketChannel connect() => WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/api/v1/user/push'),
      );

  test('authenticated diary receives a pushed frame end-to-end', () async {
    final ws = connect();
    await ws.ready;
    final frames = StreamQueue<dynamic>(ws.stream);

    ws.sink.add(jsonEncode({'type': 'auth', 'token': 'good-P1'}));
    final authAck = jsonDecode(await frames.next as String) as Map;
    expect(authAck['type'], equals('auth_ok'));
    expect(registry.hasConnection('P1'), isTrue);

    final result = await channel.send(
      const PushTarget(
          participantId: 'P1', platform: 'linux', routingToken: 'device-1'),
      const PushMessage(
        data: {'type': 'questionnaire_assigned', 'flowToken': 'QST1'},
        userVisible: true,
        title: 'New questionnaire',
      ),
    );
    expect(result.success, isTrue);

    final push = jsonDecode(await frames.next as String) as Map;
    expect(push['type'], equals('push'));
    expect(push['userVisible'], isTrue);
    expect(push['title'], equals('New questionnaire'));
    expect(
      push['data'],
      equals({'type': 'questionnaire_assigned', 'flowToken': 'QST1'}),
    );

    await ws.sink.close();
  });

  test('bad token is denied and not registered', () async {
    final ws = connect();
    await ws.ready;
    final frames = StreamQueue<dynamic>(ws.stream);

    ws.sink.add(jsonEncode({'type': 'auth', 'token': 'nope'}));
    final ack = jsonDecode(await frames.next as String) as Map;
    expect(ack['type'], equals('auth_denied'));
    expect(registry.hasConnection('nope'), isFalse);
  });

  test('connection deregisters on client close', () async {
    final ws = connect();
    await ws.ready;
    final frames = StreamQueue<dynamic>(ws.stream);
    ws.sink.add(jsonEncode({'type': 'auth', 'token': 'good-P9'}));
    await frames.next; // auth_ok
    expect(registry.hasConnection('P9'), isTrue);

    await ws.sink.close();
    // Allow the server to observe the close and run onDone.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(registry.hasConnection('P9'), isFalse);
  });
}
