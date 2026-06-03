import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

void main() {
  test('ConsoleTransport reports the recipient + subject to its sink',
      () async {
    final lines = <String>[];
    final t = ConsoleTransport(out: lines.add);
    await t.send(
      const RenderedEmail(subject: 'Subj', text: 'body-text', html: '<p>h</p>'),
      to: 'jane@site.org',
    );
    final joined = lines.join('\n');
    expect(joined, contains('jane@site.org'));
    expect(joined, contains('Subj'));
    expect(joined, contains('body-text'));
  });

  test('ActivationEmailSender renders + sends through its transport', () async {
    final lines = <String>[];
    final sender =
        ActivationEmailSender(transport: ConsoleTransport(out: lines.add));
    await sender.sendActivation(
        recipientEmail: 'jane@site.org',
        activationUrl: 'https://p/activate?code=Z');
    final joined = lines.join('\n');
    expect(joined, contains('jane@site.org'));
    expect(joined, contains('https://p/activate?code=Z'));
  });
}
