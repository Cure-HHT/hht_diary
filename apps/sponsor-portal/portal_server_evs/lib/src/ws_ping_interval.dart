/// Resolves the WebSocket keepalive interval for the portal `/subscriptions`
/// endpoint from the `PORTAL_WS_PING_INTERVAL_SECONDS` environment value.
///
/// Fail-fast: the value MUST be intentionally set to a positive integer number
/// of seconds. A missing, empty, non-numeric, or non-positive value throws, so
/// the portal refuses to boot rather than fall back to an unintended default —
/// no infrastructure knob runs on an implicit value. The interval MUST stay
/// below the proxy/load-balancer idle timeout in front of `/subscriptions`
/// (e.g. the reference nginx `proxy_read_timeout`), so keepalive frames keep
/// the connection from being reaped.
// Implements: DIARY-DEV-portal-reaction-server/D
Duration resolveWsPingInterval(String? raw) {
  final value = raw?.trim() ?? '';
  final secs = int.tryParse(value);
  if (secs == null || secs <= 0) {
    throw ArgumentError(
      'PORTAL_WS_PING_INTERVAL_SECONDS must be set to a positive integer '
      'number of seconds (the /subscriptions WebSocket keepalive interval); '
      'got: ${raw == null ? '<unset>' : '"$raw"'}',
    );
  }
  return Duration(seconds: secs);
}
