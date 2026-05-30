// IMPLEMENTS REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling — auth-to-patient bridge
//
// JWT → patient_id resolver for the comms `envelopeFetchHandler` and
// `envelopeSinceHandler` factories. The handlers know nothing about
// auth; this function performs the lookup once per request and
// returns either the resolved patient_id or null (which the handler
// translates into 401 Unauthorized).
//
// Resolution path mirrors the existing fcm_token.dart logic:
//   JWT.authCode → app_users.user_id → patient_linking_codes.used_by_user_id
//   → patients.patient_id
//
// One row is expected per active link; LIMIT 1 plus the
// `used_at IS NOT NULL` filter on patient_linking_codes scopes to the
// patient currently linked to this user.

import 'package:shelf/shelf.dart';

import '../database.dart';
import '../jwt.dart';

/// Resolve the request's authenticated participant. Returns null when:
///   * the Authorization header is missing or invalid
///   * the JWT is structurally invalid or expired
///   * the user has no linked participant (`patient_linking_codes.used_at` is null)
///
/// Wire into `envelopeFetchHandler(patientResolver: jwtParticipantResolver)`.
Future<String?> jwtParticipantResolver(Request request) async {
  final auth = verifyAuthHeader(request.headers['authorization']);
  if (auth == null) return null;

  final db = Database.instance;
  final result = await db.execute(
    '''
    SELECT p.patient_id
    FROM app_users u
    LEFT JOIN patient_linking_codes plc
      ON u.user_id = plc.used_by_user_id
      AND plc.used_at IS NOT NULL
    LEFT JOIN patients p ON plc.patient_id = p.patient_id
    WHERE u.auth_code = @authCode
    LIMIT 1
    ''',
    parameters: {'authCode': auth.authCode},
    table: 'app_users',
  );
  if (result.isEmpty) return null;
  return result.first[0] as String?;
}
