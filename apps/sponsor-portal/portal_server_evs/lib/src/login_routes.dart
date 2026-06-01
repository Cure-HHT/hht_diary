import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'otp_store.dart';
import 'session_token.dart';

/// Minimal OTP-sender surface so routes are testable without a real transport
/// and so portal_identity need not be imported by callers as a hard type.
abstract interface class OtpSender {
  Future<void> sendOtp({required String recipientEmail, required String code});
}

typedef IdTokenVerifyFn = Future<VerificationResult> Function(String idToken);

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: const {'Content-Type': 'application/json'},
    );

/// Public login routes — mount OUTSIDE authMiddleware (no session yet).
// Implements: DIARY-DEV-portal-login-identity-verification/A+B
// Implements: DIARY-DEV-portal-login-second-factor/A+B+C
// Implements: DIARY-DEV-portal-session-token/A
Router buildLoginRouter({
  required EventStore eventStore,
  required StorageBackend backend,
  required OtpStore otpStore,
  required OtpSender otpSender,
  required String signingKey,
  required IdTokenVerifyFn verifyIdToken,
  required Map<String, Object?> identityConfig,
  DateTime Function() now = DateTime.now,
  String Function()? sidGen,
}) {
  final mintSid = sidGen ?? () => 'sid-${now().microsecondsSinceEpoch}';
  final router = Router();

  Future<Map<String, Object?>?> userForUid(String uid) async {
    final rows = await backend.findViewRows('users_index');
    for (final r in rows) {
      if (r['firebase_uid'] == uid && r['status'] == 'active') return r;
    }
    return null;
  }

  router.get('/config/identity', (Request req) => _json(identityConfig));

  router.post('/login', (Request req) async {
    final Map<String, Object?> raw;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, Object?>) {
        return _json({'error': 'bad request'}, status: 400);
      }
      raw = decoded;
    } on FormatException {
      return _json({'error': 'bad request'}, status: 400);
    }
    final idToken = raw['idToken'];
    if (idToken is! String) return _json({'error': 'bad request'}, status: 400);
    final VerificationResult v;
    try {
      v = await verifyIdToken(idToken);
    } catch (_) {
      return _json({'error': 'identity unavailable'}, status: 503);
    }
    if (!v.isValid || v.uid == null) {
      return _json({'error': 'unauthorized'}, status: 401);
    }
    final user = await userForUid(v.uid!);
    if (user == null) return _json({'error': 'unauthorized'}, status: 401);
    final email = user['email']! as String;

    final String code;
    try {
      code = otpStore.issue(userId: email, now: now());
    } on OtpRateLimited {
      return _json({'error': 'too many requests'}, status: 429);
    }
    await otpSender.sendOtp(recipientEmail: email, code: code);
    await eventStore.append(
      entryType: 'user_login_otp_issued',
      aggregateType: 'portal_user',
      aggregateId: email,
      eventType: 'user_login_otp_issued',
      data: <String, Object?>{'issued_at': now().toUtc().toIso8601String()},
      initiator: const AnonymousInitiator(ipAddress: null),
    );
    return _json({'maskedEmail': maskEmail(email)});
  });

  router.post('/login/verify-otp', (Request req) async {
    final Map<String, Object?> raw;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, Object?>) {
        return _json({'error': 'bad request'}, status: 400);
      }
      raw = decoded;
    } on FormatException {
      return _json({'error': 'bad request'}, status: 400);
    }
    final idToken = raw['idToken'];
    final code = raw['code'];
    if (idToken is! String || code is! String) {
      return _json({'error': 'bad request'}, status: 400);
    }
    final VerificationResult v;
    try {
      v = await verifyIdToken(idToken);
    } catch (_) {
      return _json({'error': 'identity unavailable'}, status: 503);
    }
    if (!v.isValid || v.uid == null) {
      return _json({'error': 'unauthorized'}, status: 401);
    }
    final user = await userForUid(v.uid!);
    if (user == null) return _json({'error': 'unauthorized'}, status: 401);
    final email = user['email']! as String;

    final result = otpStore.verify(userId: email, code: code, now: now());
    if (result != OtpResult.ok) {
      await eventStore.append(
        entryType: 'user_login_otp_failed',
        aggregateType: 'portal_user',
        aggregateId: email,
        eventType: 'user_login_otp_failed',
        data: <String, Object?>{'reason': result.name},
        initiator: const AnonymousInitiator(ipAddress: null),
      );
      return _json({'error': 'unauthorized', 'reason': result.name},
          status: 401);
    }
    await eventStore.append(
      entryType: 'user_login_otp_verified',
      aggregateType: 'portal_user',
      aggregateId: email,
      eventType: 'user_login_otp_verified',
      data: <String, Object?>{'verified_at': now().toUtc().toIso8601String()},
      initiator: const AnonymousInitiator(ipAddress: null),
    );

    final scopeRows = await backend.findViewRows('user_role_scopes');
    final roles = <String>{
      for (final r in scopeRows)
        if (r['user_id'] == email) r['role']! as String,
    };
    if (roles.isEmpty) return _json({'error': 'unauthorized'}, status: 401);
    final sid = mintSid();
    await eventStore.append(
      entryType: 'session_started',
      aggregateType: 'session',
      aggregateId: sid,
      eventType: 'session_started',
      data: <String, Object?>{
        'user_id': email,
        'started_at': now().toUtc().toIso8601String(),
      },
      initiator: const AnonymousInitiator(ipAddress: null),
    );
    final token = mintSessionToken(
        sid: sid, userId: email, signingKey: signingKey, now: now());
    return _json({'sessionToken': token});
  });

  return router;
}

/// Authed session routes — mount INSIDE the authed pipeline (bearer present).
/// Only /logout remains; active-role switching is now a per-request credential
/// claim (`<token>|<role>`) resolved by SessionTokenValidator, not a mutation.
// Implements: DIARY-DEV-portal-session-lifecycle/A
Router buildAuthedSessionRouter({
  required EventStore eventStore,
  required String signingKey,
  DateTime Function() now = DateTime.now,
}) {
  final router = Router();

  SessionToken? tokenFromRequest(Request req) {
    final h = req.headers['Authorization'];
    if (h == null || !h.startsWith('Bearer ')) return null;
    // Strip optional role claim before parsing the token.
    final raw = h.substring('Bearer '.length);
    final sep = raw.indexOf('|');
    final tokenStr = sep < 0 ? raw : raw.substring(0, sep);
    return parseSessionToken(tokenStr, signingKey: signingKey);
  }

  router.post('/logout', (Request req) async {
    final token = tokenFromRequest(req);
    if (token == null) return _json({'ok': false}, status: 400);
    await eventStore.append(
      entryType: 'session_terminated',
      aggregateType: 'session',
      aggregateId: token.sid,
      eventType: 'session_terminated',
      data: <String, Object?>{'reason': 'logout'},
      initiator: const AutomationInitiator(service: 'logout'),
    );
    return _json({'ok': true});
  });

  return router;
}

/// Dev-only: every user with a role assignment, for the dev login dropdown.
Router buildDevUsersRouter({required StorageBackend backend}) {
  final router = Router();
  router.get('/dev/users', (Request req) async {
    final rows = await backend.findViewRows('user_role_scopes');
    final byUser = <String, Set<String>>{};
    for (final r in rows) {
      (byUser[r['user_id']! as String] ??= <String>{})
          .add(r['role']! as String);
    }
    return _json({
      'users': [
        for (final e in byUser.entries)
          {'userId': e.key, 'roles': e.value.toList()},
      ],
    });
  });
  return router;
}
