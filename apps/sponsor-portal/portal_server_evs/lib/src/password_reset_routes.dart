import 'dart:convert';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'password_reset_code_store.dart';

/// Minimal reset-email-sender surface so routes are testable without a real
/// transport and so callers need not import the email transport layer directly.
abstract interface class ResetEmailSender {
  Future<void> sendReset(
      {required String recipientEmail, required String resetUrl});
}

/// Injectable password-update function so routes are testable without a live
/// Identity Platform. Mirrors [IdentityAdmin.updatePasswordByEmail].
typedef UpdatePasswordFn = Future<String> Function(
    {required String email, required String password});

/// Returned verbatim when the reset link is expired, consumed, or unknown.
const kResetInvalidMessage =
    'This reset link is no longer valid. Please request a new password reset.';

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: const {'Content-Type': 'application/json'},
    );

const _resetInitiator = AnonymousInitiator(ipAddress: null);

/// Public password-reset routes — mount OUTSIDE authMiddleware (no session yet).
// Implements: DIARY-DEV-portal-reset-code-lifecycle/D
// Implements: DIARY-DEV-portal-reset-password-update/B
// Implements: DIARY-DEV-portal-reset-session-termination/A
Router buildPasswordResetRouter({
  required EventStore eventStore,
  required StorageBackend backend,
  required PasswordResetCodeStore store,
  required ResetEmailSender emailSender,
  required UpdatePasswordFn updatePassword,
  required String portalUrl,
  DateTime Function() now = DateTime.now,
}) {
  final router = Router();

  /// Returns the [users_index] row for [email] if that user is active.
  Future<bool> isActiveUser(String email) async {
    final rows = await backend.findViewRows('users_index');
    for (final r in rows) {
      if (r['email'] == email && r['status'] == 'active') return true;
    }
    return false;
  }

  // POST /password-reset/request
  // Enumeration-resistant: always returns the same confirmation regardless of
  // whether the email matches an active user. Only mints + sends if active.
  router.post('/password-reset/request', (Request req) async {
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
    final email = raw['email'];
    if (email is! String || email.isEmpty) {
      return _json({'error': 'bad request'}, status: 400);
    }

    if (await isActiveUser(email)) {
      try {
        final code = store.issue(email: email, now: now());
        final resetUrl = '$portalUrl/?reset=$code';
        await emailSender.sendReset(recipientEmail: email, resetUrl: resetUrl);
        await eventStore.append(
          entryType: 'user_password_reset_requested',
          aggregateType: 'portal_user',
          aggregateId: email,
          eventType: 'user_password_reset_requested',
          data: <String, Object?>{
            'requested_at': now().toUtc().toIso8601String()
          },
          initiator: _resetInitiator,
        );
      } on PasswordResetRateLimited {
        // Swallow: rate-limited user still receives the same generic confirmation
        // so enumeration cannot distinguish rate-limited from unknown.
      } catch (e) {
        stderr.writeln(
            '[password-reset] request handling failed: $e'); // still confirm
      }
    }

    // Always return the same body — enumeration resistant.
    return _json({'ok': true, 'expiresInHours': 24});
  });

  // GET /password-reset/<code>
  router.get('/password-reset/<code>', (Request req, String code) async {
    final found = store.validate(code, now: now());
    return _json({'valid': found != null});
  });

  // POST /password-reset  — submit new password using a valid code
  router.post('/password-reset', (Request req) async {
    final Map<String, Object?> raw;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, Object?>) {
        return _json({'ok': false, 'message': kResetInvalidMessage},
            status: 400);
      }
      raw = decoded;
    } on FormatException {
      return _json({'ok': false, 'message': kResetInvalidMessage}, status: 400);
    }

    final code = raw['code'];
    final password = raw['password'];
    if (code is! String ||
        code.isEmpty ||
        password is! String ||
        password.isEmpty) {
      return _json({'ok': false, 'message': kResetInvalidMessage}, status: 400);
    }

    final found = store.validate(code, now: now());
    if (found == null) {
      return _json({'ok': false, 'message': kResetInvalidMessage}, status: 400);
    }

    try {
      await updatePassword(email: found.email, password: password);
    } on IdentityAdminException catch (e) {
      if (e.statusCode == 400) {
        // Composition/strength rejection from Identity Platform. Static,
        // non-leaking message (do NOT echo the exception or the IdP body).
        return _json({
          'ok': false,
          'message': 'That password was rejected — it does not meet the '
              'strength requirements. Please choose a different password.',
        }, status: 400);
      }
      return _json({'ok': false, 'message': 'Reset failed, please retry.'},
          status: 503);
    } catch (_) {
      return _json({'ok': false, 'message': 'Reset failed, please retry.'},
          status: 503);
    }

    // Password updated successfully — append audit events, THEN consume code.
    // (If an append throws, the code remains retryable.)
    await eventStore.append(
      entryType: 'user_password_reset_completed',
      aggregateType: 'portal_user',
      aggregateId: found.email,
      eventType: 'user_password_reset_completed',
      data: <String, Object?>{'completed_at': now().toUtc().toIso8601String()},
      initiator: _resetInitiator,
    );
    await eventStore.append(
      entryType: 'user_sessions_revoked',
      aggregateType: 'portal_user',
      aggregateId: found.email,
      eventType: 'user_sessions_revoked',
      data: <String, Object?>{'reason': 'password_reset'},
      initiator: _resetInitiator,
    );
    store.consume(code);

    return _json({'ok': true});
  });

  return router;
}
