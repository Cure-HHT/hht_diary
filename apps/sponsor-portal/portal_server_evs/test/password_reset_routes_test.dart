import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:portal_server_evs/src/password_reset_code_store.dart';
import 'package:portal_server_evs/src/password_reset_routes.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _CaptureSender implements ResetEmailSender {
  final List<String> urls;
  _CaptureSender(this.urls);
  @override
  Future<void> sendReset(
      {required String recipientEmail, required String resetUrl}) async {
    urls.add(resetUrl);
  }
}

class _ThrowingSender implements ResetEmailSender {
  @override
  Future<void> sendReset(
      {required String recipientEmail, required String resetUrl}) async {
    throw StateError('smtp down');
  }
}

void main() {
  // Verifies: DIARY-DEV-portal-reset-code-lifecycle/D
  // Verifies: DIARY-DEV-portal-reset-password-update/A+B
  // Verifies: DIARY-DEV-portal-reset-session-termination/A
  late EventStore store;
  late StorageBackend backend;
  late PasswordResetCodeStore codes;
  late List<String> sentUrls;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('reset.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
    codes = PasswordResetCodeStore(codeGen: () => 'R-1');
    sentUrls = <String>[];
    await store.append(
      entryType: 'user_activated',
      aggregateType: 'portal_user',
      aggregateId: 'jane@site.org',
      eventType: 'user_activated',
      data: {
        'firebase_uid': 'uid-jane',
        'email': 'jane@site.org',
        'status': 'active'
      },
      initiator: const AutomationInitiator(service: 'test'),
    );
  });

  Handler handler({
    Future<String> Function({required String email, required String password})?
        updatePassword,
  }) =>
      buildPasswordResetRouter(
        eventStore: store,
        backend: backend,
        store: codes,
        emailSender: _CaptureSender(sentUrls),
        portalUrl: 'https://portal.test',
        updatePassword: updatePassword ??
            ({required email, required password}) async => 'uid-jane',
        now: () => t0,
      ).call;

  test(
      'request for an active user mints + emails + appends requested; generic confirmation',
      () async {
    final r = await handler()(Request(
        'POST', Uri.parse('http://x/password-reset/request'),
        body: jsonEncode({'email': 'jane@site.org'})));
    expect(r.statusCode, 200);
    expect(sentUrls.single, 'https://portal.test/?reset=R-1');
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_password_reset_requested'),
        hasLength(1));
  });

  test('request for an unknown email -> SAME confirmation, no email, no event',
      () async {
    final r = await handler()(Request(
        'POST', Uri.parse('http://x/password-reset/request'),
        body: jsonEncode({'email': 'ghost@x.org'})));
    expect(r.statusCode, 200);
    expect(sentUrls, isEmpty);
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_password_reset_requested'),
        isEmpty);
  });

  test('GET valid -> {valid:true}; unknown -> {valid:false}', () async {
    codes.issue(email: 'jane@site.org', now: t0);
    final ok = await handler()(
        Request('GET', Uri.parse('http://x/password-reset/R-1')));
    expect((jsonDecode(await ok.readAsString()) as Map)['valid'], isTrue);
    final bad = await handler()(
        Request('GET', Uri.parse('http://x/password-reset/NOPE')));
    expect((jsonDecode(await bad.readAsString()) as Map)['valid'], isFalse);
  });

  test(
      'submit valid -> updates pw, appends completed + sessions_revoked, consumes',
      () async {
    final code = codes.issue(email: 'jane@site.org', now: t0);
    final r = await handler()(Request(
        'POST', Uri.parse('http://x/password-reset'),
        body: jsonEncode({'code': code, 'password': 'newpw123'})));
    expect(r.statusCode, 200);
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_password_reset_completed'),
        hasLength(1));
    expect(events.where((e) => e.eventType == 'user_sessions_revoked'),
        hasLength(1));
    final again = await handler()(Request(
        'POST', Uri.parse('http://x/password-reset'),
        body: jsonEncode({'code': code, 'password': 'newpw123'})));
    expect(again.statusCode, 400);
  });

  test(
      'submit weak password (IdP 400) -> 400 with static message, no completion, code NOT consumed',
      () async {
    final code = codes.issue(email: 'jane@site.org', now: t0);
    final r = await handler(
      updatePassword: ({required email, required password}) async =>
          throw IdentityAdminException('WEAK_PASSWORD', statusCode: 400),
    )(Request('POST', Uri.parse('http://x/password-reset'),
        body: jsonEncode({'code': code, 'password': 'x'})));
    expect(r.statusCode, 400);
    final body = jsonDecode(await r.readAsString()) as Map;
    expect(body['message'] as String, contains('strength requirements'));
    expect(
        body['message'] as String, isNot(contains('IdentityAdminException')));
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_password_reset_completed'),
        isEmpty);
    expect(
        codes.validate(code, now: t0), isNotNull); // not consumed -> retryable
  });

  test(
      'submit with infra failure (non-400) -> 503, no completion, code not consumed',
      () async {
    final code = codes.issue(email: 'jane@site.org', now: t0);
    final r = await handler(
      updatePassword: ({required email, required password}) async =>
          throw StateError('identity platform unreachable'),
    )(Request('POST', Uri.parse('http://x/password-reset'),
        body: jsonEncode({'code': code, 'password': 'newpw123'})));
    expect(r.statusCode, 503);
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_password_reset_completed'),
        isEmpty);
    expect(codes.validate(code, now: t0), isNotNull);
  });

  test(
      'request stays enumeration-resistant (200) when the email transport throws',
      () async {
    final r = await buildPasswordResetRouter(
      eventStore: store,
      backend: backend,
      store: codes,
      emailSender: _ThrowingSender(),
      portalUrl: 'https://portal.test',
      updatePassword: ({required email, required password}) async => 'uid-jane',
      now: () => t0,
    ).call(Request('POST', Uri.parse('http://x/password-reset/request'),
        body: jsonEncode({'email': 'jane@site.org'})));
    expect(r.statusCode,
        200); // NOT 500 — enumeration resistance under transport failure
  });
}
