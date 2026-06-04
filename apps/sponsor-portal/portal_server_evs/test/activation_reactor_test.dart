import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:portal_server_evs/src/activation_code_store.dart';
import 'package:portal_server_evs/src/activation_reactor.dart';
import 'package:test/test.dart';

class _CaptureTransport implements EmailTransport {
  String? to;
  RenderedEmail? email;
  @override
  Future<void> send(RenderedEmail e, {required String to}) async {
    this.to = to;
    email = e;
  }
}

/// Mimics a delivery failure (e.g. GmailWifTransport's Google-ADC error) so the
/// reactor's crash-guard can be exercised.
class _ThrowingTransport implements EmailTransport {
  @override
  Future<void> send(RenderedEmail e, {required String to}) async {
    throw StateError('email backend unavailable (simulated ADC failure)');
  }
}

void main() {
  test('on user_activation_code_issued: mints a code and emails the link',
      () async {
    final store = ActivationCodeStore(codeGen: () => 'AB-CD');
    final transport = _CaptureTransport();
    final reactor = ActivationReactor(
      store: store,
      emailSender: ActivationEmailSender(transport: transport),
      portalUrl: 'https://portal.test',
    );

    // StoredEvent.synthetic is the @visibleForTesting factory; it constructs
    // a fully populated event without hash-chain bookkeeping.
    final event = StoredEvent.synthetic(
      eventId: 'e1',
      aggregateId: 'jane@site.org',
      entryType: 'user_activation_code_issued',
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: DateTime.utc(2026, 6, 1),
      eventHash: 'fakehash',
      data: <String, dynamic>{
        'expires_at': '2026-06-15T00:00:00.000Z',
        'reissue': false,
      },
    );

    await reactor.handleIssued(event);

    expect(transport.to, 'jane@site.org');
    // Link is built from portalUrl (the UI origin) at the root path with ?code=,
    // so it opens the Flutter activation page on any host.
    expect(
      transport.email!.text,
      contains('https://portal.test/?code=AB-CD'),
    );
    expect(
      store.validate('AB-CD', now: DateTime.utc(2026, 6, 2))?.email,
      'jane@site.org',
    );
  });

  // Regression: a failing email backend must NOT propagate out of handleIssued
  // (an unhandled exception in the fire-and-forget reactor crashed the whole
  // portal). The code is still minted so activation works via retry/console.
  test('email delivery failure is swallowed; the code is still minted',
      () async {
    final store = ActivationCodeStore(codeGen: () => 'XY-ZZ');
    final reactor = ActivationReactor(
      store: store,
      emailSender: ActivationEmailSender(transport: _ThrowingTransport()),
      portalUrl: 'https://portal.test',
    );
    final event = StoredEvent.synthetic(
      eventId: 'e2',
      aggregateId: 'jane@site.org',
      entryType: 'user_activation_code_issued',
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: DateTime.utc(2026, 6, 1),
      eventHash: 'fakehash',
      data: <String, dynamic>{
        'expires_at': '2026-06-15T00:00:00.000Z',
        'reissue': false,
      },
    );

    // Must complete normally (no throw) despite the backend failing.
    await expectLater(reactor.handleIssued(event), completes);
    // And the activation code is still valid — delivery failure doesn't block
    // the participant/admin from activating with the code.
    expect(
      store.validate('XY-ZZ', now: DateTime.utc(2026, 6, 2))?.email,
      'jane@site.org',
    );
  });
}
