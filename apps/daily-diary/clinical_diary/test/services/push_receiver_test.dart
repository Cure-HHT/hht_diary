// Verifies: DIARY-DEV-pluggable-push-transport/D — LocalSocketPushReceiver
//   authenticates with the participant JWT and maps server `push` frames to
//   RemoteMessages carrying the same data payload (type/flowToken) the FCM path
//   uses, so the diary's existing receipt path is unchanged.
import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/services/push_receiver.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [PushSocket]: records frames sent by the receiver and lets a test
/// pump server frames in.
class FakePushSocket implements PushSocket {
  final _in = StreamController<String>.broadcast();
  final List<String> sent = <String>[];
  bool closed = false;

  void serverSend(String frame) => _in.add(frame);

  @override
  Stream<String> get incoming => _in.stream;

  @override
  void send(String data) => sent.add(data);

  @override
  Future<void> close() async {
    closed = true;
    await _in.close();
  }
}

void main() {
  test('sends an auth frame with the participant token on start', () async {
    final socket = FakePushSocket();
    final receiver = LocalSocketPushReceiver(
      socket: socket,
      authToken: () async => 'jwt-123',
    );

    await receiver.start();

    expect(socket.sent, hasLength(1));
    final auth = jsonDecode(socket.sent.single) as Map<String, dynamic>;
    expect(auth['type'], equals('auth'));
    expect(auth['token'], equals('jwt-123'));
    await receiver.dispose();
  });

  test('does not authenticate when there is no token yet', () async {
    final socket = FakePushSocket();
    final receiver = LocalSocketPushReceiver(
      socket: socket,
      authToken: () async => null,
    );

    await receiver.start();

    expect(socket.sent, isEmpty);
    await receiver.dispose();
  });

  test('maps a push frame to a RemoteMessage with type + flowToken', () async {
    final socket = FakePushSocket();
    final receiver = LocalSocketPushReceiver(
      socket: socket,
      authToken: () async => 'jwt-123',
    );
    await receiver.start();

    final received = <RemoteMessage>[];
    final sub = receiver.messages.listen(received.add);

    socket.serverSend(
      jsonEncode({
        'type': 'push',
        'userVisible': true,
        'title': 'New questionnaire',
        'data': {'type': 'questionnaire_assigned', 'flowToken': 'QST1'},
      }),
    );
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(received.single.data['type'], equals('questionnaire_assigned'));
    expect(received.single.data['flowToken'], equals('QST1'));

    await sub.cancel();
    await receiver.dispose();
  });

  test('ignores auth_ok and ping frames', () async {
    final socket = FakePushSocket();
    final receiver = LocalSocketPushReceiver(
      socket: socket,
      authToken: () async => 'jwt-123',
    );
    await receiver.start();

    final received = <RemoteMessage>[];
    final sub = receiver.messages.listen(received.add);

    socket
      ..serverSend(jsonEncode({'type': 'auth_ok'}))
      ..serverSend(jsonEncode({'type': 'ping'}));
    await pumpEventQueue();

    expect(received, isEmpty);
    await sub.cancel();
    await receiver.dispose();
  });
}
