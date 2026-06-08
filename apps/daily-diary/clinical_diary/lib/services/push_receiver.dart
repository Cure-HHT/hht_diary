// Implements: DIARY-DEV-pluggable-push-transport/D — the device-side push
//   receive seam. A [PushReceiver] yields [RemoteMessage]s into the EXISTING
//   diary_sync_triggers FCM stream-factory seam, so the receipt -> event ->
//   reconcile path (and the event names fcm_token_registered /
//   fcm_message_received) are unchanged regardless of transport.
//
//   - [FcmPushReceiver] is the real path (firebase_messaging) for android/ios.
//   - [LocalSocketPushReceiver] rides the portal /api/v1/user/push WS for the
//     web/Linux diary on the local-stack (no FCM, no emulator).
import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Source of inbound pushes for the device. The diary wires [messages] into
/// `installDiarySyncTriggers(fcmOnMessageStreamFactory: ...)`.
abstract class PushReceiver {
  /// Stream of inbound pushes as [RemoteMessage]s (the same type the FCM path
  /// emits), so downstream handling is transport-agnostic.
  Stream<RemoteMessage> get messages;

  /// Releases resources (subscriptions / sockets). Safe to call repeatedly.
  Future<void> dispose();
}

/// firebase_messaging-backed receiver: the real cloud path. Merges the
/// foreground `onMessage` and notification-tap `onMessageOpenedApp` streams.
class FcmPushReceiver implements PushReceiver {
  @override
  Stream<RemoteMessage> get messages =>
      StreamGroup.merge<RemoteMessage>(<Stream<RemoteMessage>>[
        FirebaseMessaging.onMessage,
        FirebaseMessaging.onMessageOpenedApp,
      ]);

  @override
  Future<void> dispose() async {
    /* streams are owned by FirebaseMessaging */
  }
}

/// Minimal duplex text socket the [LocalSocketPushReceiver] rides. Abstracted so
/// the receiver's frame handling is unit-testable without a real WebSocket.
abstract class PushSocket {
  /// Inbound text frames from the server.
  Stream<String> get incoming;

  /// Send a text frame to the server.
  void send(String data);

  /// Close the socket.
  Future<void> close();
}

/// [PushSocket] over a real [WebSocketChannel] (web + Linux via
/// web_socket_channel).
class WebSocketPushSocket implements PushSocket {
  WebSocketPushSocket(this._channel);

  /// Connects to [url] (e.g. `ws://host:8080/api/v1/user/push`).
  factory WebSocketPushSocket.connect(Uri url) =>
      WebSocketPushSocket(WebSocketChannel.connect(url));

  final WebSocketChannel _channel;

  Future<void> get ready => _channel.ready;

  @override
  Stream<String> get incoming =>
      _channel.stream.map((dynamic e) => e is String ? e : e.toString());

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close();
}

/// Receives pushes over the portal's participant-scoped local-push WebSocket.
///
/// Handshake: on [start] it sends `{"type":"auth","token":"<participant-jwt>"}`
/// (the same JWT the diary uses for /ingest and /user/state). Server `push`
/// frames (`{"type":"push","data":{...}}`) are mapped to [RemoteMessage]s whose
/// `data` is the same string/string payload (`type`, `flowToken`) the FCM path
/// carries, so the diary's `_recordFcmReceipt` handles them unchanged.
/// `auth_ok` and `ping`
/// frames are ignored.
class LocalSocketPushReceiver implements PushReceiver {
  LocalSocketPushReceiver({
    required PushSocket socket,
    required Future<String?> Function() authToken,
  }) : _socket = socket,
       _authToken = authToken;

  final PushSocket _socket;
  final Future<String?> Function() _authToken;
  final StreamController<RemoteMessage> _out =
      StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _sub;

  @override
  Stream<RemoteMessage> get messages => _out.stream;

  /// Authenticates and begins forwarding push frames. Returns once the auth
  /// frame has been sent; delivery is asynchronous thereafter.
  Future<void> start() async {
    _sub = _socket.incoming.listen(
      _onFrame,
      onError: (Object e) {
        debugPrint('[LocalPush] socket error: $e');
      },
    );
    final token = await _authToken();
    if (token == null || token.isEmpty) {
      debugPrint('[LocalPush] no participant token yet — not authenticating');
      return;
    }
    _socket.send(jsonEncode(<String, dynamic>{'type': 'auth', 'token': token}));
  }

  void _onFrame(String raw) {
    Map<String, dynamic>? frame;
    try {
      frame = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (frame['type'] != 'push') return; // ignore auth_ok / ping / auth_denied
    final data = frame['data'];
    final stringData = <String, dynamic>{
      if (data is Map)
        for (final entry in data.entries) entry.key.toString(): entry.value,
    };
    _out.add(RemoteMessage(data: stringData));
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _socket.close();
    await _out.close();
  }
}
