import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

void main() {
  test('console mode counts as configured even without a service account', () {
    final cfg =
        EmailConfig(senderEmail: 's@x.org', enabled: true, consoleMode: true);
    expect(cfg.isConfigured, isTrue);
  });

  test('non-console requires a gmail service account', () {
    final cfg = EmailConfig(senderEmail: 's@x.org', enabled: true);
    expect(cfg.isConfigured, isFalse);
    final cfg2 = EmailConfig(
        senderEmail: 's@x.org',
        enabled: true,
        gmailServiceAccountEmail: 'sa@x.iam');
    expect(cfg2.isConfigured, isTrue);
  });

  test('disabled is never configured', () {
    final cfg =
        EmailConfig(senderEmail: 's@x.org', enabled: false, consoleMode: true);
    expect(cfg.isConfigured, isFalse);
  });
}
