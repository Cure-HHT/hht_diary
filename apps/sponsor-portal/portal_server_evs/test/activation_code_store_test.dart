// Verifies: DIARY-DEV-portal-activation-code-lifecycle/A+B+C+D+E+F
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/activation_code_store.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 6, 1, 12);
  final t14 = t0.add(const Duration(days: 14));
  late EventStore eventStore;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('acs.db');
    eventStore =
        await openPortalEventStore(backend: SembastBackend(database: db));
    addTearDown(() => eventStore.close());
  });

  ActivationCodeStore newStore({String pepper = 'test-pepper'}) {
    var n = 0;
    return ActivationCodeStore(
      eventStore: eventStore,
      pepper: pepper,
      codeGen: () => 'CODE-${n++}',
    );
  }

  test('issued code validates to its email, then consume makes it single-use',
      () async {
    final s = newStore();
    final code = await s.issue(email: 'a@x.org', expiresAt: t14);
    expect((await s.validate(code, now: t0))?.email, 'a@x.org');
    await s.consume(code, now: t0);
    expect(await s.validate(code, now: t0), isNull);
  });

  test('expired code is rejected', () async {
    final s = newStore();
    final code = await s.issue(email: 'a@x.org', expiresAt: t14);
    expect(
        await s.validate(code, now: t0.add(const Duration(days: 15))), isNull);
  });

  test('issuing a new code invalidates the prior unused code for that email',
      () async {
    final s = newStore();
    final first = await s.issue(email: 'a@x.org', expiresAt: t14);
    final second = await s.issue(email: 'a@x.org', expiresAt: t14);
    expect(await s.validate(first, now: t0), isNull);
    expect((await s.validate(second, now: t0))?.email, 'a@x.org');
  });

  test('unknown code is rejected', () async {
    expect(await newStore().validate('nope', now: t0), isNull);
  });

  test(
      'pending codes survive a restart: a fresh store over the same event '
      'store validates a code issued before it, and consumption persists too',
      () async {
    final code = await newStore().issue(email: 'a@x.org', expiresAt: t14);

    // "Restart": a brand-new store instance with NO shared in-process state —
    // everything it knows comes from the activation_codes view.
    final rebooted = newStore();
    expect((await rebooted.validate(code, now: t0))?.email, 'a@x.org');

    await rebooted.consume(code, now: t0);
    final rebootedAgain = newStore();
    expect(await rebootedAgain.validate(code, now: t0), isNull);
  });

  test('the stored hash is keyed: a store with a different pepper rejects',
      () async {
    final code = await newStore().issue(email: 'a@x.org', expiresAt: t14);
    expect(
        await newStore(pepper: 'other-pepper').validate(code, now: t0), isNull);
  });

  test(
      'no event payload ever contains a cleartext activation code, and the '
      'stored hash is NOT the plain SHA-256 of the code', () async {
    final s = newStore();
    final code = await s.issue(email: 'a@x.org', expiresAt: t14);
    await s.consume(code, now: t0);

    final events = await eventStore.backend.findAllEvents();
    final lifecycle = events
        .where((e) =>
            e.eventType == 'activation_code_minted' ||
            e.eventType == 'activation_code_consumed')
        .toList();
    expect(lifecycle, hasLength(2));
    for (final e in events) {
      expect(jsonEncode(e.data), isNot(contains(code)),
          reason: '${e.eventType} payload must never carry the cleartext');
    }
    final plainSha = sha256.convert(utf8.encode(code)).toString();
    for (final e in lifecycle) {
      expect(e.data['code_hash'], isNot(plainSha),
          reason: 'stored hash must be keyed (HMAC), not a plain digest');
    }
  });

  test('consume of a superseded code does not disturb the active one',
      () async {
    final s = newStore();
    final first = await s.issue(email: 'a@x.org', expiresAt: t14);
    final second = await s.issue(email: 'a@x.org', expiresAt: t14);
    await s.consume(first, now: t0); // stale: must be a no-op
    expect((await s.validate(second, now: t0))?.email, 'a@x.org');
  });
}
