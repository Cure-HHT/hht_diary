/// The `/subscriptions` WebSocket keepalive interval.
///
/// This is a fixed operational constant, not per-deployment configuration: the
/// portal sends a ping this often so an idle or half-open subscription
/// connection is not silently reaped by a proxy/load-balancer (which would
/// leave the reactive client believing it is still connected, so its
/// lifecycle-driven reconnect never fires). 20s is well below any sane proxy
/// idle timeout for the WS route.
///
/// COUPLING: this MUST stay below the `/subscriptions` `proxy_read_timeout` in
/// the nginx config (`deployment/reference-sponsor/deployment/nginx/nginx.conf`,
/// currently 3600s). If you change one, check the other.
// Implements: DIARY-DEV-portal-reaction-server/D
const Duration kWsKeepaliveInterval = Duration(seconds: 20);
