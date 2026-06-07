// Verifies: DIARY-DEV-portal-reaction-server/D — the portal resolves its
//   /subscriptions WebSocket keepalive interval from
//   PORTAL_WS_PING_INTERVAL_SECONDS, defaulting to 20s and failing safe to the
//   default on bad input (so a misconfiguration cannot disable keepalive).

import 'package:portal_server_evs/src/ws_ping_interval.dart';
import 'package:test/test.dart';

void main() {
  group('resolveWsPingInterval', () {
    test('defaults to 20s when unset or blank', () {
      expect(resolveWsPingInterval(null), const Duration(seconds: 20));
      expect(resolveWsPingInterval(''), const Duration(seconds: 20));
      expect(resolveWsPingInterval('   '), const Duration(seconds: 20));
    });

    test('parses a positive integer as seconds', () {
      expect(resolveWsPingInterval('45'), const Duration(seconds: 45));
      expect(resolveWsPingInterval(' 30 '), const Duration(seconds: 30));
    });

    test('falls back to default on non-positive or non-numeric input', () {
      expect(resolveWsPingInterval('0'), const Duration(seconds: 20));
      expect(resolveWsPingInterval('-5'), const Duration(seconds: 20));
      expect(resolveWsPingInterval('abc'), const Duration(seconds: 20));
      expect(resolveWsPingInterval('20.5'), const Duration(seconds: 20));
    });
  });
}
