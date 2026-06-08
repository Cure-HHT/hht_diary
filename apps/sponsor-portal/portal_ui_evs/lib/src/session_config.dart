import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client view of the server's effective session-timeout config.
class SessionTimeoutConfig {
  const SessionTimeoutConfig({required this.idle, required this.warning});
  final Duration idle;
  final Duration warning;

  /// Used when `/config/session` is unreachable — matches the server defaults
  /// (10 min idle / 60 s warning) so behavior degrades gracefully.
  static const SessionTimeoutConfig fallback = SessionTimeoutConfig(
    idle: Duration(minutes: 10),
    warning: Duration(seconds: 60),
  );
}

/// Pure decode of the `/config/session` JSON body.
SessionTimeoutConfig parseSessionConfig(Map<String, Object?> json) {
  final idleSec = (json['idleSeconds'] as num?)?.toInt();
  final warnSec = (json['warningSeconds'] as num?)?.toInt();
  return SessionTimeoutConfig(
    idle: idleSec == null
        ? SessionTimeoutConfig.fallback.idle
        : Duration(seconds: idleSec),
    warning: warnSec == null
        ? SessionTimeoutConfig.fallback.warning
        : Duration(seconds: warnSec),
  );
}

/// Fetches `GET /config/session`; returns [SessionTimeoutConfig.fallback] on any
/// failure so the soft-timer always has usable values.
// Implements: DIARY-GUI-portal-session-expiry/A
Future<SessionTimeoutConfig> fetchSessionConfig(String serverUrl) async {
  try {
    final r = await http.get(Uri.parse('$serverUrl/config/session'));
    if (r.statusCode != 200) return SessionTimeoutConfig.fallback;
    return parseSessionConfig(jsonDecode(r.body) as Map<String, Object?>);
  } catch (_) {
    return SessionTimeoutConfig.fallback;
  }
}
