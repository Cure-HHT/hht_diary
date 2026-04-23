import 'package:append_only_datastore/src/storage/source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Source', () {
    // Verifies: REQ-d00142-A — three fields, no userId.
    test('REQ-d00142-A: construction carries three fields (no userId)', () {
      const s = Source(
        hopId: 'mobile-device',
        identifier: 'dev-1',
        softwareVersion: 'clinical_diary@1.2.3+4',
      );
      expect(s.hopId, 'mobile-device');
      expect(s.identifier, 'dev-1');
      expect(s.softwareVersion, 'clinical_diary@1.2.3+4');
    });

    test('equality and hashCode', () {
      const a = Source(hopId: 'h', identifier: 'i', softwareVersion: 'v');
      const b = Source(hopId: 'h', identifier: 'i', softwareVersion: 'v');
      const c = Source(hopId: 'x', identifier: 'i', softwareVersion: 'v');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    // Verifies: REQ-d00142-B — well-known hopId values.
    test('REQ-d00142-B: hopId accepts well-known values', () {
      const m = Source(
        hopId: 'mobile-device',
        identifier: 'd',
        softwareVersion: 'v',
      );
      const p = Source(
        hopId: 'portal-server',
        identifier: 'h',
        softwareVersion: 'v',
      );
      expect(m.hopId, 'mobile-device');
      expect(p.hopId, 'portal-server');
    });

    // Verifies: REQ-d00142-C — softwareVersion not validated at runtime.
    test(
      'REQ-d00142-C: softwareVersion is accepted without runtime validation',
      () {
        const s = Source(
          hopId: 'mobile-device',
          identifier: 'd',
          softwareVersion: 'anything-goes',
        );
        expect(s.softwareVersion, 'anything-goes');
      },
    );
  });
}
