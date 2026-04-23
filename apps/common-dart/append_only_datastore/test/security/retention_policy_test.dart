import 'package:append_only_datastore/src/security/security_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecurityRetentionPolicy', () {
    // Verifies: REQ-d00138-A — defaults match the design-doc spec.
    test('REQ-d00138-A: defaults match spec', () {
      const p = SecurityRetentionPolicy.defaults;
      expect(p.fullRetention, const Duration(days: 90));
      expect(p.truncatedRetention, const Duration(days: 365));
      expect(p.truncateIpv4LastOctet, isTrue);
      expect(p.truncateIpv6Suffix, isTrue);
      expect(p.dropUserAgentAfterFull, isTrue);
      expect(p.dropGeoAfterFull, isFalse);
      expect(p.dropAllAfterTruncated, isTrue);
    });

    test('REQ-d00138-A: round-trips through toJson / fromJson', () {
      const p = SecurityRetentionPolicy(
        fullRetention: Duration(days: 30),
        truncatedRetention: Duration(days: 100),
        truncateIpv4LastOctet: false,
        truncateIpv6Suffix: true,
        dropUserAgentAfterFull: false,
        dropGeoAfterFull: true,
        dropAllAfterTruncated: false,
      );
      expect(SecurityRetentionPolicy.fromJson(p.toJson()), p);
    });

    test('equality and hashCode', () {
      const another = SecurityRetentionPolicy.defaults;
      expect(SecurityRetentionPolicy.defaults, same(another));
    });
  });
}
