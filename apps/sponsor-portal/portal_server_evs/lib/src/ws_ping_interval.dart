/// Resolves the WebSocket keepalive interval for the portal `/subscriptions`
/// endpoint from the `PORTAL_WS_PING_INTERVAL_SECONDS` environment value.
///
/// Defaults to 20 seconds — comfortably below the nginx `proxy_read_timeout`
/// (3600s) and any Cloud Run request timeout, while light enough to keep the
/// connection non-idle. A null/empty/non-positive/unparseable value falls back
/// to the default rather than disabling keepalive, so a misconfiguration cannot
/// silently re-introduce the idle-reap failure.
// Implements: DIARY-DEV-portal-reaction-server/D
Duration resolveWsPingInterval(String? raw) {
  const fallback = Duration(seconds: 20);
  if (raw == null || raw.trim().isEmpty) return fallback;
  final secs = int.tryParse(raw.trim());
  if (secs == null || secs <= 0) return fallback;
  return Duration(seconds: secs);
}
