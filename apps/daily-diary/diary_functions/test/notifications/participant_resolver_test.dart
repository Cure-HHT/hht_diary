// VERIFIES REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling — JWT → patient_id resolution

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request _request({String? authHeader}) {
  return Request(
    'GET',
    Uri.parse('http://localhost/api/v1/notifications'),
    headers: authHeader == null ? const {} : {'authorization': authHeader},
  );
}

void main() {
  tearDown(() {
    databaseQueryOverride = null;
  });

  group('jwtParticipantResolver', () {
    test('returns null on missing Authorization header', () async {
      var queried = false;
      databaseQueryOverride = (query, {parameters, table}) async {
        queried = true;
        return [];
      };

      final result = await jwtParticipantResolver(_request());

      expect(result, isNull);
      expect(queried, isFalse, reason: 'short-circuit before any DB query');
    });

    test('returns null on malformed bearer token', () async {
      databaseQueryOverride = (query, {parameters, table}) async => [];
      final result = await jwtParticipantResolver(
        _request(authHeader: 'Bearer not-a-jwt'),
      );
      expect(result, isNull);
    });

    test('returns null when user has no linked participant', () async {
      databaseQueryOverride = (query, {parameters, table}) async {
        // SELECT joins app_users → patient_linking_codes → patients;
        // when no link exists, the LEFT JOINs yield a single row with
        // patient_id = null.
        return [
          <dynamic>[null],
        ];
      };
      final token = createJwtToken(authCode: 'auth-code-123', userId: 'user-1');
      final result = await jwtParticipantResolver(
        _request(authHeader: 'Bearer $token'),
      );
      expect(result, isNull);
    });

    test('returns the linked patient_id when JWT + link both exist', () async {
      String? capturedAuthCode;
      databaseQueryOverride = (query, {parameters, table}) async {
        expect(query, contains('FROM app_users'));
        expect(query, contains('patient_linking_codes'));
        expect(query, contains('patients'));
        capturedAuthCode = parameters?['authCode'] as String?;
        return [
          <dynamic>['840-001'],
        ];
      };
      final token = createJwtToken(
        authCode: 'auth-code-abcdef',
        userId: 'user-1',
      );

      final result = await jwtParticipantResolver(
        _request(authHeader: 'Bearer $token'),
      );

      expect(result, equals('840-001'));
      expect(capturedAuthCode, equals('auth-code-abcdef'));
    });
  });
}
