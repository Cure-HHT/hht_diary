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
    expect(
      transport.email!.text,
      contains('https://portal.test/activate?code=AB-CD'),
    );
    expect(
      store.validate('AB-CD', now: DateTime.utc(2026, 6, 2))?.email,
      'jane@site.org',
    );
  });
}
