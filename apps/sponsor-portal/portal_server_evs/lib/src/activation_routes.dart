import 'dart:convert';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'activation_code_store.dart';

/// Generic, enumeration-resistant rejection message (verbatim from
/// DIARY-PRD-user-account-activation-workflow/H).
const kInvalidLinkMessage =
    'This link is no longer valid. Please contact your Administrator to '
    'request a new activation email.';

const _activationInitiator = AutomationInitiator(service: 'activation');

typedef Provisioner = Future<LookupOrProvisionResult> Function({
  required String email,
  required String displayName,
  required String password,
});

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: const {'Content-Type': 'application/json'},
    );

/// Public activation routes. MUST be mounted OUTSIDE authMiddleware: the
/// activating user has no session yet.
// Implements: DIARY-DEV-portal-activation-email-delivery/B
// Implements: DIARY-DEV-portal-identity-provisioning/A
// Implements: DIARY-DEV-portal-user-activated-binding/A+C
Router buildActivationRouter({
  required ActivationCodeStore store,
  required EventStore eventStore,
  required Provisioner provision,
  DateTime Function() now = DateTime.now,
}) {
  final router = Router();

  router.get('/activate/<code>', (Request req, String code) {
    final found = store.validate(code, now: now());
    if (found == null) {
      return _json({'valid': false, 'message': kInvalidLinkMessage});
    }
    return _json({'valid': true, 'maskedEmail': maskEmail(found.email)});
  });

  router.post('/activate', (Request req) async {
    final Map<String, Object?> raw;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, Object?>) {
        return _json({'ok': false, 'message': kInvalidLinkMessage},
            status: 400);
      }
      raw = decoded;
    } on FormatException {
      return _json({'ok': false, 'message': kInvalidLinkMessage}, status: 400);
    }
    final code = raw['code'];
    final password = raw['password'];
    if (code is! String || password is! String || password.isEmpty) {
      return _json({'ok': false, 'message': kInvalidLinkMessage}, status: 400);
    }
    final found = store.validate(code, now: now());
    if (found == null) {
      return _json({'ok': false, 'message': kInvalidLinkMessage}, status: 400);
    }
    final LookupOrProvisionResult provisioned;
    try {
      provisioned = await provision(
          email: found.email, displayName: found.email, password: password);
    } on IdentityAdminException catch (e) {
      stderr.writeln('[activate] identity provisioning failed: $e');
      return _json({'ok': false, 'message': 'Activation failed, please retry.'},
          status: 502);
    } catch (e) {
      // Any other provisioning failure. The common local-dev case: the auth
      // emulator isn't configured, so provisioning falls through to real
      // Identity Platform via Application Default Credentials and fails (e.g.
      // invalid_grant / invalid_rapt). Return a clean handled 502 instead of a
      // raw 500, and print a dev hint to the server console.
      stderr.writeln('[activate] identity provisioning failed: $e');
      final emulator = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
      if (emulator == null || emulator.isEmpty) {
        stderr.writeln(
          '[activate] HINT: FIREBASE_AUTH_EMULATOR_HOST is not set, so '
          'provisioning used Application Default Credentials against real '
          'Identity Platform. For local dev, start the auth emulator and set '
          'FIREBASE_AUTH_EMULATOR_HOST + PORTAL_IDENTITY_PROJECT_ID.',
        );
      }
      return _json({'ok': false, 'message': 'Activation failed, please retry.'},
          status: 502);
    }
    await eventStore.append(
      entryType: 'user_activated',
      aggregateType: 'portal_user',
      aggregateId: found.email,
      eventType: 'user_activated',
      data: <String, Object?>{
        'firebase_uid': provisioned.uid,
        'email': found.email,
        'status': 'active',
        'activated_at': now().toUtc().toIso8601String(),
      },
      initiator: _activationInitiator,
    );
    store.consume(code);
    return _json({'ok': true});
  });

  return router;
}
