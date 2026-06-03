// Verifies: DIARY-DEV-participant-ingest/B — patient bearer token verification.
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:test/test.dart';

void main() {
  group('patient token validator', () {
    test('a freshly minted token verifies and carries its claims', () {
      final token = createPatientJwt(authCode: 'ac-1', userId: 'u-1');
      final payload = verifyPatientAuthHeader('Bearer $token');
      expect(payload, isNotNull);
      expect(payload!.userId, 'u-1');
      expect(payload.authCode, 'ac-1');
    });

    test('an expired token is rejected', () {
      final token = createPatientJwt(
        authCode: 'ac-1',
        userId: 'u-1',
        expiresIn: const Duration(seconds: -1),
      );
      expect(verifyPatientAuthHeader('Bearer $token'), isNull);
    });

    test('a tampered signature is rejected', () {
      final token = createPatientJwt(authCode: 'ac-1', userId: 'u-1');
      expect(verifyPatientAuthHeader('Bearer ${token}x'), isNull);
    });

    test('a missing or non-Bearer header is rejected', () {
      expect(verifyPatientAuthHeader(null), isNull);
      expect(verifyPatientAuthHeader('Basic abc'), isNull);
    });
  });
}
