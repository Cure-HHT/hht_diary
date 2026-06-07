// Verifies: DIARY-DEV-portal-reaction-server/D — the portal resolves its
//   /subscriptions WebSocket keepalive interval from
//   PORTAL_WS_PING_INTERVAL_SECONDS and FAILS FAST (throws) when it is unset or
//   invalid, so the portal refuses to boot on an unintended default.

import 'package:portal_server_evs/src/ws_ping_interval.dart';
import 'package:test/test.dart';

void main() {
  group('resolveWsPingInterval', () {
    test('parses a positive integer as seconds', () {
      expect(resolveWsPingInterval('20'), const Duration(seconds: 20));
      expect(resolveWsPingInterval(' 45 '), const Duration(seconds: 45));
    });

    test('throws when unset or blank (no implicit default)', () {
      expect(() => resolveWsPingInterval(null), throwsArgumentError);
      expect(() => resolveWsPingInterval(''), throwsArgumentError);
      expect(() => resolveWsPingInterval('   '), throwsArgumentError);
    });

    test('throws on non-positive or non-numeric input', () {
      expect(() => resolveWsPingInterval('0'), throwsArgumentError);
      expect(() => resolveWsPingInterval('-5'), throwsArgumentError);
      expect(() => resolveWsPingInterval('abc'), throwsArgumentError);
      expect(() => resolveWsPingInterval('20.5'), throwsArgumentError);
    });
  });
}
