// Unit tests for the dev-only MockRaveClient (rave_mock.dart). Covers the
// three documented modes (`ok` / `auth_fail` / `network_fail`) plus the
// fail-loud behavior on an unknown mode.

import 'package:portal_functions/portal_functions.dart';
import 'package:rave_integration/rave_integration.dart';
import 'package:test/test.dart';

void main() {
  group('MockRaveClient', () {
    test('ok mode returns canned sites + subjects', () async {
      final client = MockRaveClient('ok');
      final sites = await client.getSites(studyOid: 'MOCK-STUDY-001');
      expect(sites, hasLength(3));
      expect(sites.first.oid, 'MOCK-001');
      expect(sites.first.isActive, isTrue);

      final subjects = await client.getSubjects(studyOid: 'MOCK-STUDY-001');
      expect(subjects, hasLength(3));
      expect(subjects.first.subjectKey, 'MOCK-001-001');
    });

    test(
      'auth_fail mode throws RaveAuthenticationException with reason code',
      () async {
        final client = MockRaveClient('auth_fail');
        await expectLater(
          client.getSites(),
          throwsA(
            isA<RaveAuthenticationException>().having(
              (e) => e.reasonCode,
              'reasonCode',
              'MOCK_AUTH_FAIL',
            ),
          ),
        );
        await expectLater(
          client.getSubjects(studyOid: 'MOCK-STUDY-001'),
          throwsA(isA<RaveAuthenticationException>()),
        );
      },
    );

    test('network_fail mode throws RaveNetworkException', () async {
      final client = MockRaveClient('network_fail');
      await expectLater(
        client.getSites(),
        throwsA(isA<RaveNetworkException>()),
      );
    });

    test('unknown mode throws loudly (typo guard)', () async {
      final client = MockRaveClient('typo-here');
      await expectLater(client.getSites(), throwsA(isA<RaveException>()));
    });

    test('close() is a no-op', () {
      MockRaveClient('ok').close(); // must not throw
    });
  });
}
