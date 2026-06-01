import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:portal_server_evs/src/login_routes.dart';
import 'package:portal_server_evs/src/otp_store.dart';
import 'package:portal_server_evs/src/session_token.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _CaptureSender implements OtpSender {
  _CaptureSender(this.sink);
  final List<String> sink;
  @override
  Future<void> sendOtp(
      {required String recipientEmail, required String code}) async {
    sink.add(code);
  }
}

void main() {
  // Verifies: DIARY-DEV-portal-login-identity-verification/A+B
  // Verifies: DIARY-DEV-portal-login-second-factor/A+B+C
  // Verifies: DIARY-DEV-portal-session-token/A
  const key = 'k';
  late EventStore store;
  late StorageBackend backend;
  late OtpStore otp;
  late List<String> sentCodes;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('login.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
    otp = OtpStore(codeGen: () => '123456');
    sentCodes = <String>[];
    await store.append(
      entryType: 'user_role_scope',
      aggregateType: 'user_role_scope',
      aggregateId: 'jane@site.org:Administrator',
      eventType: 'role_assigned',
      data: {
        'user_id': 'jane@site.org',
        'role': 'Administrator',
        'scope': 'global'
      },
      initiator: const AutomationInitiator(service: 'test'),
    );
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

  Handler handler() => buildLoginRouter(
        eventStore: store,
        backend: backend,
        otpStore: otp,
        otpSender: _CaptureSender(sentCodes),
        signingKey: key,
        now: () => t0,
        sidGen: () => 'sid-1',
        verifyIdToken: (idToken) async => VerificationResult(
            uid: 'uid-jane', email: 'jane@site.org', emailVerified: true),
        identityConfig: const {
          'projectId': 'demo-local-stack',
          'apiKey': 'demo'
        },
      ).call;

  test('POST /login verifies token, issues OTP, emits user_login_otp_issued',
      () async {
    final r = await handler()(Request('POST', Uri.parse('http://x/login'),
        body: jsonEncode({'idToken': 'any'})));
    expect(r.statusCode, 200);
    final body = jsonDecode(await r.readAsString()) as Map<String, Object?>;
    expect(body['maskedEmail'], 'j***@s***.org');
    expect(sentCodes, contains('123456'));
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_login_otp_issued'),
        hasLength(1));
  });

  test('POST /login/verify-otp with good code mints session + session_started',
      () async {
    await handler()(Request('POST', Uri.parse('http://x/login'),
        body: jsonEncode({'idToken': 'any'})));
    final r = await handler()(Request(
        'POST', Uri.parse('http://x/login/verify-otp'),
        body: jsonEncode({'idToken': 'any', 'code': '123456'})));
    expect(r.statusCode, 200);
    final body = jsonDecode(await r.readAsString()) as Map<String, Object?>;
    final token = body['sessionToken']! as String;
    expect(parseSessionToken(token, signingKey: key)!.userId, 'jane@site.org');
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'session_started'), hasLength(1));
    expect(events.where((e) => e.eventType == 'user_login_otp_verified'),
        hasLength(1));
  });

  test('POST /login/verify-otp with bad code -> 401, no session', () async {
    await handler()(Request('POST', Uri.parse('http://x/login'),
        body: jsonEncode({'idToken': 'any'})));
    final r = await handler()(Request(
        'POST', Uri.parse('http://x/login/verify-otp'),
        body: jsonEncode({'idToken': 'any', 'code': '000000'})));
    expect(r.statusCode, 401);
    final events = await backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'session_started'), isEmpty);
    expect(events.where((e) => e.eventType == 'user_login_otp_failed'),
        hasLength(1));
  });

  test('GET /config/identity returns the injected config', () async {
    final r =
        await handler()(Request('GET', Uri.parse('http://x/config/identity')));
    expect(r.statusCode, 200);
    expect(jsonDecode(await r.readAsString()),
        containsPair('projectId', 'demo-local-stack'));
  });

  test('POST /login with malformed JSON body -> 400', () async {
    final r = await handler()(
        Request('POST', Uri.parse('http://x/login'), body: 'not json'));
    expect(r.statusCode, 400);
  });

  group('authed session routes', () {
    // Verifies: DIARY-DEV-portal-session-lifecycle/A
    // Verifies: DIARY-DEV-portal-active-role-switch/B
    Handler authed() => buildAuthedSessionRouter(
        eventStore: store,
        backend: backend,
        signingKey: key,
        now: () => t0).call;

    Future<void> startSession(String sid, String userId, String role) =>
        store.append(
            entryType: 'session_started',
            aggregateType: 'session',
            aggregateId: sid,
            eventType: 'session_started',
            data: {
              'user_id': userId,
              'active_role': role,
              'started_at': t0.toIso8601String()
            },
            initiator: const AutomationInitiator(service: 'test'));

    test('POST /logout terminates the bearer session', () async {
      await startSession('sid-1', 'jane@site.org', 'Administrator');
      final token = mintSessionToken(
          sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
      final r = await authed()(Request('POST', Uri.parse('http://x/logout'),
          headers: {'Authorization': 'Bearer $token'}));
      expect(r.statusCode, 200);
      final events = await backend.findAllEvents();
      expect(events.where((e) => e.eventType == 'session_terminated'),
          hasLength(1));
    });

    test(
        'POST /session/active-role to a held role appends session_active_role_changed',
        () async {
      await store.append(
        entryType: 'user_role_scope',
        aggregateType: 'user_role_scope',
        aggregateId: 'jane@site.org:Study Coordinator',
        eventType: 'role_assigned',
        data: {
          'user_id': 'jane@site.org',
          'role': 'StudyCoordinator',
          'scope': 'global',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );
      await startSession('sid-1', 'jane@site.org', 'Administrator');
      final token = mintSessionToken(
          sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
      final r = await authed()(Request(
          'POST', Uri.parse('http://x/session/active-role'),
          headers: {'Authorization': 'Bearer $token'},
          body: jsonEncode({'role': 'StudyCoordinator'})));
      expect(r.statusCode, 200);
      final events = await backend.findAllEvents();
      final changed = events
          .where((e) => e.eventType == 'session_active_role_changed')
          .toList();
      expect(changed, hasLength(1));
      expect(changed.single.data['active_role'], 'StudyCoordinator');
    });

    test('POST /session/active-role to an unheld role -> 403, no event',
        () async {
      await startSession('sid-1', 'jane@site.org', 'Administrator');
      final token = mintSessionToken(
          sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
      final r = await authed()(Request(
          'POST', Uri.parse('http://x/session/active-role'),
          headers: {'Authorization': 'Bearer $token'},
          body: jsonEncode({'role': 'StudyCoordinator'})));
      expect(r.statusCode, 403);
      final events = await backend.findAllEvents();
      expect(events.where((e) => e.eventType == 'session_active_role_changed'),
          isEmpty);
    });

    test('GET /dev/users lists assigned users with their roles', () async {
      final r = await buildDevUsersRouter(backend: backend)
          .call(Request('GET', Uri.parse('http://x/dev/users')));
      expect(r.statusCode, 200);
      final body = jsonDecode(await r.readAsString()) as Map<String, Object?>;
      final users = (body['users']! as List).cast<Map<String, Object?>>();
      final jane = users.firstWhere((u) => u['userId'] == 'jane@site.org');
      expect((jane['roles']! as List), contains('Administrator'));
    });
  });
}
