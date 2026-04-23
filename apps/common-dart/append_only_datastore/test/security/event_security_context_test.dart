import 'package:append_only_datastore/src/security/event_security_context.dart';
import 'package:append_only_datastore/src/security/security_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventSecurityContext', () {
    test('round-trips through toJson/fromJson with all fields', () {
      final ctx = EventSecurityContext(
        eventId: 'e-1',
        recordedAt: DateTime.utc(2026, 4, 22, 12),
        ipAddress: '203.0.113.7',
        userAgent: 'UA/1',
        sessionId: 'sess-9',
        geoCountry: 'US',
        geoRegion: 'NY',
        requestId: 'req-1',
        redactedAt: null,
        redactionReason: null,
      );
      expect(EventSecurityContext.fromJson(ctx.toJson()), ctx);
    });

    test('null optional fields survive round-trip', () {
      final ctx = EventSecurityContext(
        eventId: 'e-2',
        recordedAt: DateTime.utc(2026, 4, 22),
      );
      expect(EventSecurityContext.fromJson(ctx.toJson()), ctx);
    });

    // Verifies: REQ-d00138-B — compact sweep truncation rules.
    test('REQ-d00138-B: applyTruncation drops UA, truncates IPv4 last octet, '
        'keeps geo by default', () {
      final ctx = EventSecurityContext(
        eventId: 'e',
        recordedAt: DateTime.utc(2026, 4, 22),
        ipAddress: '203.0.113.7',
        userAgent: 'UA/1',
        geoCountry: 'US',
        geoRegion: 'NY',
      );
      final truncated = ctx.applyTruncation(SecurityRetentionPolicy.defaults);
      expect(truncated.ipAddress, '203.0.113.0');
      expect(truncated.userAgent, isNull);
      expect(truncated.geoCountry, 'US');
      expect(truncated.geoRegion, 'NY');
    });

    test('REQ-d00138-B: IPv6 truncation keeps first 3 groups when enabled', () {
      final ctx = EventSecurityContext(
        eventId: 'e',
        recordedAt: DateTime.utc(2026, 4, 22),
        ipAddress: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
      );
      final truncated = ctx.applyTruncation(SecurityRetentionPolicy.defaults);
      expect(truncated.ipAddress, startsWith('2001:0db8:85a3'));
    });
  });
}
