// Verifies: DIARY-DEV-portal-activation-email-delivery/B
// Verifies: DIARY-DEV-portal-identity-provisioning/A
// Verifies: DIARY-DEV-portal-user-activated-binding/A+C
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:portal_server_evs/src/activation_code_store.dart';
import 'package:portal_server_evs/src/activation_routes.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  late EventStore eventStore;
  late ActivationCodeStore store;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('act.db');
    eventStore =
        await openPortalEventStore(backend: SembastBackend(database: db));
    store = ActivationCodeStore(codeGen: () => 'AB-CD');
  });

  Router router({
    Future<LookupOrProvisionResult> Function({
      required String email,
      required String displayName,
      required String password,
    })? provision,
  }) {
    return buildActivationRouter(
      store: store,
      eventStore: eventStore,
      now: () => t0,
      provision: provision ??
          ({required email, required displayName, required password}) async =>
              const LookupOrProvisionResult(uid: 'uid-1', created: true),
    );
  }

  test('GET valid code -> masked email; invalid -> generic rejection',
      () async {
    store.issue(
        email: 'jane@site.org', expiresAt: t0.add(const Duration(days: 14)));
    final ok = await router()
        .call(Request('GET', Uri.parse('http://x/activate/AB-CD')));
    final okBody = jsonDecode(await ok.readAsString()) as Map<String, Object?>;
    expect(okBody['valid'], isTrue);
    expect(okBody['maskedEmail'], 'j***@s***.org');

    final bad = await router()
        .call(Request('GET', Uri.parse('http://x/activate/NOPE')));
    final badBody =
        jsonDecode(await bad.readAsString()) as Map<String, Object?>;
    expect(badBody['valid'], isFalse);
    expect(badBody['message'], kInvalidLinkMessage);
  });

  test(
      'POST valid -> appends user_activated(status active, firebase_uid) and consumes',
      () async {
    final code = store.issue(
        email: 'jane@site.org', expiresAt: t0.add(const Duration(days: 14)));
    final resp = await router().call(Request(
      'POST',
      Uri.parse('http://x/activate'),
      body: jsonEncode({'code': code, 'password': 'pw123456'}),
    ));
    expect(resp.statusCode, 200);

    final events = await eventStore.backend.findAllEvents();
    final activated =
        events.where((e) => e.eventType == 'user_activated').toList();
    expect(activated, hasLength(1));
    expect(activated.single.aggregateId, 'jane@site.org');
    expect(activated.single.data['firebase_uid'], 'uid-1');
    expect(activated.single.data['status'], 'active');
    expect(activated.single.initiator, isA<AutomationInitiator>());

    final again = await router().call(Request(
        'POST', Uri.parse('http://x/activate'),
        body: jsonEncode({'code': code, 'password': 'pw123456'})));
    expect(again.statusCode, 400);
    final after = await eventStore.backend.findAllEvents();
    expect(after.where((e) => e.eventType == 'user_activated'), hasLength(1));
  });

  test('POST with provisioning failure appends no event', () async {
    final code = store.issue(
        email: 'jane@site.org', expiresAt: t0.add(const Duration(days: 14)));
    final r = router(
      provision: (
              {required email,
              required displayName,
              required password}) async =>
          throw IdentityAdminException('boom', statusCode: 503),
    );
    final resp = await r.call(Request('POST', Uri.parse('http://x/activate'),
        body: jsonEncode({'code': code, 'password': 'pw123456'})));
    expect(resp.statusCode, 502);
    final events = await eventStore.backend.findAllEvents();
    expect(events.where((e) => e.eventType == 'user_activated'), isEmpty);
  });
}
