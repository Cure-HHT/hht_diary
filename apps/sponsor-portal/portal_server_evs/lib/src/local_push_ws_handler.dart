// Implements: DIARY-DEV-pluggable-push-transport/C — the participant-scoped
//   local-push WebSocket endpoint. A diary connects, authenticates in-band with
//   its participant JWT (the same token it uses for /ingest and /user/state),
//   and registers a live sink in [LocalPushRegistry]. LocalSocketPushChannel
//   then delivers push frames to that sink. This is a deliberately minimal,
//   single-instance local-stack transport: it does NOT use the reaction
//   view-subscription machinery, only an in-process registry.
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'local_push_registry.dart';
import 'patient_token_validator.dart';
import 'ws_keepalive_interval.dart';

/// Verifies a participant JWT and returns the participant id, or null when the
/// token is missing/invalid/expired. Injectable so tests can stub auth.
typedef ParticipantTokenVerifier = String? Function(String token);

String? _defaultVerifier(String token) =>
    verifyPatientAuthHeader('Bearer $token')?.userId;

/// Builds the shelf handler for `GET /api/v1/user/push`. Mounted only when
/// `PUSH_MODE=local`. Credentials arrive in-band (Flutter web cannot set WS
/// upgrade headers): the FIRST frame the client sends MUST be
/// `{"type":"auth","token":"<participant-jwt>"}`. On success the server replies
/// `{"type":"auth_ok"}` and registers the connection; on failure it replies
/// `{"type":"auth_denied"}` and closes. Every push is delivered as
/// `{"type":"push","data":{...}}` (see LocalSocketPushChannel).
Handler localPushWsHandler({
  required LocalPushRegistry registry,
  ParticipantTokenVerifier verifier = _defaultVerifier,
  Duration pingInterval = kWsKeepaliveInterval,
}) {
  return webSocketHandler((WebSocketChannel webSocket, String? _) {
    void Function()? deregister;
    Timer? pingTimer;

    void send(Map<String, dynamic> frame) {
      try {
        webSocket.sink.add(jsonEncode(frame));
      } catch (_) {
        // Sink closed mid-write — the stream's onDone will clean up.
      }
    }

    Future<void> close() async {
      pingTimer?.cancel();
      deregister?.call();
      deregister = null;
      try {
        await webSocket.sink.close();
      } catch (_) {/* already closed */}
    }

    webSocket.stream.listen(
      (dynamic raw) {
        // Already authenticated: ignore further client frames (the local
        // transport is server->client only; pongs need no handling).
        if (deregister != null) return;

        Map<String, dynamic>? frame;
        try {
          frame = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          frame = null;
        }
        if (frame == null || frame['type'] != 'auth') {
          send(<String, dynamic>{
            'type': 'auth_denied',
            'reason': 'expected_auth'
          });
          unawaited(close());
          return;
        }
        final token = frame['token'];
        final participantId =
            token is String && token.isNotEmpty ? verifier(token) : null;
        if (participantId == null) {
          send(<String, dynamic>{
            'type': 'auth_denied',
            'reason': 'invalid_token'
          });
          unawaited(close());
          return;
        }

        deregister = registry.register(participantId, send);
        send(<String, dynamic>{'type': 'auth_ok'});

        // App-level keepalive, mirroring the reaction /subscriptions WS
        // (CUR-1464) so an idle connection is not reaped by a proxy.
        pingTimer = Timer.periodic(
          pingInterval,
          (_) => send(<String, dynamic>{'type': 'ping'}),
        );
      },
      onDone: () => unawaited(close()),
      onError: (_) => unawaited(close()),
      cancelOnError: true,
    );
  });
}
